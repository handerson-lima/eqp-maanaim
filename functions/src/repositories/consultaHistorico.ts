import { Timestamp, type Firestore } from 'firebase-admin/firestore';
import {
  AcessoNaoAutorizadoError,
  MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
  mascararCpf,
  sanitizarEventoParaVoluntario,
  type EscopoAtorConsulta,
  type EventoLinhaDoTempo,
  type FichaConsultaAutorizada,
  type ParticipacaoConsultaAutorizada,
  type ResultadoConsultaFichaAutorizada,
  type ResultadoConsultaLinhaDoTempo,
} from '../domain/consultaHistorico.js';
import { avaliarAutoridadeCoordenador } from './decisaoCoordenador.js';

function serializarTimestamp(valor: unknown): string | null {
  if (!valor) return null;
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof Date) return valor.toISOString();
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().toISOString();
  }
  if (typeof valor === 'string') return valor;
  return null;
}

/**
 * Avalia dinamicamente em tempo de execução o escopo de autorização do ator (AD-9, AD-12).
 * Não se baseia em claims estáticas do token sem revalidação de vínculos vigentes.
 */
export async function determinarEscopoAtor(
  db: Firestore,
  atorUid: string,
  targetFichaId: string,
): Promise<EscopoAtorConsulta> {
  // 1. Se o ator for o próprio voluntário
  if (atorUid === targetFichaId) {
    return {
      atorUid,
      papel: 'VOLUNTARIO',
      ehProprioVoluntario: true,
    };
  }

  // 2. Verificar se o ator possui autoridade administrativa vigente (Coordenador ou Administrador)
  const autoridadeDoc = await db
    .collection('autoridadesAdministrativas')
    .doc(atorUid)
    .get();

  if (autoridadeDoc.exists) {
    const autoridade = avaliarAutoridadeCoordenador(autoridadeDoc.data(), 'Autoridade');
    if (autoridade.autorizado) {
      return {
        atorUid,
        papel: autoridade.papel === 'ADMINISTRADOR' ? 'ADMINISTRADOR' : 'COORDENADOR_GERAL',
        ehProprioVoluntario: false,
      };
    }
  }

  // 3. Leitura da ficha alvo para validação de escopo territorial (igreja) e funcional (equipes)
  const fichaDoc = await db.collection('fichas').doc(targetFichaId).get();
  if (!fichaDoc.exists) {
    // Retorna erro de acesso não autorizado para não vazar a existência ou inexistência da ficha
    throw new AcessoNaoAutorizadoError();
  }
  const fichaData = fichaDoc.data() ?? {};
  const igrejaId = String(fichaData.igrejaId ?? '').trim();

  // 4. Verificar se o ator é Pastor Local vigente da igreja da ficha
  if (igrejaId) {
    const igrejaDoc = await db.collection('igrejas').doc(igrejaId).get();
    if (igrejaDoc.exists && igrejaDoc.data()?.ativo !== false) {
      const igData = igrejaDoc.data() ?? {};
      if (igData.pastorLocalVigentePessoaId === atorUid) {
        // Validação adicional de vínculo temporal se houver pastorLocalVigenteVinculoId
        const vinculoId = igData.pastorLocalVigenteVinculoId;
        let vinculoAtivo = true;
        if (vinculoId) {
          const vDoc = await db.collection('vinculosPastorIgreja').doc(vinculoId).get();
          if (vDoc.exists) {
            const vData = vDoc.data() ?? {};
            if (vData.estado !== 'VIGENTE' || vData.pessoaId !== atorUid) {
              vinculoAtivo = false;
            }
          }
        }
        if (vinculoAtivo) {
          return {
            atorUid,
            papel: 'PASTOR_LOCAL',
            igrejaId,
            ehProprioVoluntario: false,
          };
        }
      }
    }

    // Consulta alternativa direta em vinculosPastorIgreja para pastor com vínculo vigente
    const vinculoPastoralSnap = await db
      .collection('vinculosPastorIgreja')
      .where('pessoaId', '==', atorUid)
      .where('entidadeId', '==', igrejaId)
      .where('estado', '==', 'VIGENTE')
      .limit(1)
      .get();

    if (!vinculoPastoralSnap.empty) {
      return {
        atorUid,
        papel: 'PASTOR_LOCAL',
        igrejaId,
        ehProprioVoluntario: false,
      };
    }
  }

  // 5. Verificar se o ator é Responsável de Equipe vigente de ao menos UMA equipe da ficha
  const equipesMap = new Map<string, string>();

  // 5a. Equipes com responsavelVigentePessoaId no catálogo
  const equipesCatalogoSnap = await db
    .collection('equipes')
    .where('responsavelVigentePessoaId', '==', atorUid)
    .get();

  for (const doc of equipesCatalogoSnap.docs) {
    if (doc.data()?.ativo !== false) {
      equipesMap.set(doc.id, doc.id);
    }
  }

  // 5b. Vínculos vigentes em vinculosResponsavelEquipe
  const vinculosEquipeSnap = await db
    .collection('vinculosResponsavelEquipe')
    .where('pessoaId', '==', atorUid)
    .where('estado', '==', 'VIGENTE')
    .get();

  for (const doc of vinculosEquipeSnap.docs) {
    const equipeId = String(doc.data()?.entidadeId ?? '');
    if (equipeId) {
      equipesMap.set(equipeId, equipeId);
    }
  }

  const equipeIdsDoAtor = Array.from(equipesMap.keys());
  if (equipeIdsDoAtor.length > 0) {
    // Verifica se a ficha do voluntário possui participações em alguma dessas equipes
    const partSnap = await db
      .collection('participacoes')
      .where('fichaId', '==', targetFichaId)
      .get();

    const temParticipacaoNaEquipe = partSnap.docs.some((doc) =>
      equipeIdsDoAtor.includes(String(doc.data()?.equipeId ?? '')),
    );

    if (temParticipacaoNaEquipe) {
      return {
        atorUid,
        papel: 'RESPONSAVEL_EQUIPE',
        equipeIdsAutorizadas: equipeIdsDoAtor,
        ehProprioVoluntario: false,
      };
    }
  }

  // Se nenhuma das verificações concedeu acesso
  throw new AcessoNaoAutorizadoError();
}

/**
 * Executa a consulta autorizada de ficha e participações aplicando segregação de escopo.
 */
export async function consultarFichaAutorizadaRepo(
  db: Firestore,
  atorUid: string,
  targetFichaId?: string,
): Promise<ResultadoConsultaFichaAutorizada> {
  const fichaIdEfetivo = (!targetFichaId || targetFichaId.trim() === '')
    ? atorUid
    : targetFichaId.trim();

  const escopo = await determinarEscopoAtor(db, atorUid, fichaIdEfetivo);

  const fichaDoc = await db.collection('fichas').doc(fichaIdEfetivo).get();
  if (!fichaDoc.exists) {
    if (escopo.ehProprioVoluntario) {
      return {
        existe: false,
        participacoes: [],
        escopo: { papel: 'VOLUNTARIO', equipesFiltradas: false },
      };
    }
    throw new AcessoNaoAutorizadoError();
  }

  const fichaData = fichaDoc.data() ?? {};

  // Nome da Igreja se disponível
  let nomeIgreja: string | undefined;
  const igrejaId = String(fichaData.igrejaId ?? '');
  if (igrejaId) {
    const igDoc = await db.collection('igrejas').doc(igrejaId).get();
    if (igDoc.exists) {
      nomeIgreja = String(igDoc.data()?.nome ?? igrejaId);
    }
  }

  // Sanitização de CPF: se for voluntário ou coordenador, expõe completo; se for responsável/pastor, mascara
  const rawCpf = String(fichaData.cpf ?? '');
  const cpfMascarado = mascararCpf(rawCpf);
  const cpfCompleto = escopo.ehProprioVoluntario || escopo.papel === 'COORDENADOR_GERAL' || escopo.papel === 'ADMINISTRADOR'
    ? rawCpf
    : undefined;

  const ehNegativaFicha = String(fichaData.estado ?? '') === 'REJEITADA';
  const proximaAcaoFicha = ehNegativaFicha
    ? MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA
    : (fichaData.proximaAcao ? String(fichaData.proximaAcao) : null);

  const mensagemVoluntarioFicha = ehNegativaFicha
    ? MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA
    : (fichaData.mensagemVoluntario ? String(fichaData.mensagemVoluntario) : null);

  const fichaModel: FichaConsultaAutorizada = {
    id: fichaDoc.id,
    ownerUid: String(fichaData.ownerUid ?? fichaDoc.id),
    nomeCompleto: String(fichaData.nomeCompleto ?? ''),
    profissao: String(fichaData.profissao ?? ''),
    cpfMascarado,
    cpfCompleto,
    igrejaId,
    nomeIgreja,
    estado: String(fichaData.estado ?? 'RASCUNHO'),
    versao: Number(fichaData.versao ?? 1),
    proximaAcao: proximaAcaoFicha,
    mensagemVoluntario: mensagemVoluntarioFicha,
    atualizadoEm: serializarTimestamp(fichaData.atualizadoEm),
    criadoEm: serializarTimestamp(fichaData.criadoEm),
  };

  // Buscar participações do voluntário
  const partSnap = await db
    .collection('participacoes')
    .where('fichaId', '==', fichaIdEfetivo)
    .get();

  let participacoesDocs = partSnap.docs;

  // Se o ator for Responsável de Equipe, aplica isolamento estrito: só vê participações da sua equipe
  const equipesFiltradas = escopo.papel === 'RESPONSAVEL_EQUIPE';
  if (equipesFiltradas && escopo.equipeIdsAutorizadas) {
    participacoesDocs = participacoesDocs.filter((doc) =>
      escopo.equipeIdsAutorizadas!.includes(String(doc.data()?.equipeId ?? '')),
    );
  }

  const participacoes: ParticipacaoConsultaAutorizada[] = participacoesDocs
    .map((doc) => {
      const d = doc.data() ?? {};
      const estado = String(d.estado ?? 'RASCUNHO');
      const ehNegativa = estado === 'REJEITADA' || d.decisao === 'DESFAVORAVEL';
      const proximaAcao = ehNegativa
        ? MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA
        : String(d.proximaAcao ?? (estado === 'RASCUNHO' ? 'Aguardando envio da ficha' : 'Em análise'));

      return {
        id: doc.id,
        fichaId: String(d.fichaId ?? fichaIdEfetivo),
        equipeId: String(d.equipeId ?? ''),
        nomeEquipe: String(d.nomeEquipe ?? ''),
        estado,
        ciclo: String(d.ciclo ?? 'INICIAL'),
        proximaAcao,
        vigenciaInicio: serializarTimestamp(d.vigenciaInicio),
        vigenciaFim: serializarTimestamp(d.vigenciaFim),
        cicloAtualId: d.cicloAtualId ? String(d.cicloAtualId) : null,
        atualizadoEm: serializarTimestamp(d.atualizadoEm),
      };
    })
    .sort((a, b) => a.nomeEquipe.localeCompare(b.nomeEquipe, 'pt-BR'));

  return {
    existe: true,
    ficha: fichaModel,
    participacoes,
    escopo: {
      papel: escopo.papel,
      equipesFiltradas,
    },
  };
}

/**
 * Consulta a linha do tempo cronológica autorizada e sanitizada da ficha e participações.
 */
export async function consultarLinhaDoTempoAutorizadaRepo(
  db: Firestore,
  atorUid: string,
  targetFichaId?: string,
  participacaoIdFiltro?: string,
): Promise<ResultadoConsultaLinhaDoTempo> {
  const fichaIdEfetivo = (!targetFichaId || targetFichaId.trim() === '')
    ? atorUid
    : targetFichaId.trim();

  const escopo = await determinarEscopoAtor(db, atorUid, fichaIdEfetivo);

  const fichaDoc = await db.collection('fichas').doc(fichaIdEfetivo).get();
  if (!fichaDoc.exists) {
    if (escopo.ehProprioVoluntario) {
      return { fichaId: fichaIdEfetivo, eventos: [], totalEventos: 0 };
    }
    throw new AcessoNaoAutorizadoError();
  }

  const fichaData = fichaDoc.data() ?? {};
  const eventosBrutos: EventoLinhaDoTempo[] = [];

  // 1. Marco de criação da ficha
  if (fichaData.criadoEm) {
    eventosBrutos.push({
      id: `criacao-${fichaIdEfetivo}`,
      tipo: 'CRIACAO_FICHA',
      etapa: 'CADASTRO',
      titulo: 'Ficha cadastral criada',
      descricao: 'Cadastro de dados permanente iniciado pelo voluntário.',
      estadoVisual: 'CONCLUIDO',
      timestamp: serializarTimestamp(fichaData.criadoEm) ?? new Date().toISOString(),
      ator: escopo.ehProprioVoluntario ? null : { nome: String(fichaData.nomeCompleto ?? 'Voluntário'), papel: 'VOLUNTARIO' },
      justificativaInterna: null,
    });
  }

  // 2. Marco de envio para aprovação
  if (fichaData.estado && fichaData.estado !== 'RASCUNHO') {
    eventosBrutos.push({
      id: `envio-${fichaIdEfetivo}`,
      tipo: 'ENVIO_APROVACAO',
      etapa: 'CADASTRO',
      titulo: 'Ficha enviada para aprovação',
      descricao: 'Termo de voluntariado aceito e solicitação encaminhada ao Pastor Local.',
      estadoVisual: 'CONCLUIDO',
      timestamp: serializarTimestamp(fichaData.atualizadoEm) ?? new Date().toISOString(),
      ator: escopo.ehProprioVoluntario ? null : { nome: String(fichaData.nomeCompleto ?? 'Voluntário'), papel: 'VOLUNTARIO' },
      justificativaInterna: null,
    });
  }

  // 3. Buscar evidências imutáveis de decisão em `evidenciasDecisao`
  const evidenciasSnap = await db
    .collection('evidenciasDecisao')
    .where('fichaId', '==', fichaIdEfetivo)
    .get();

  for (const doc of evidenciasSnap.docs) {
    const e = doc.data() ?? {};
    const etapa = String(e.etapa ?? '');
    const decisao = String(e.decisao ?? '');
    const timestamp = serializarTimestamp(e.timestamp) ?? new Date().toISOString();
    const equipeId = e.equipeId ? String(e.equipeId) : null;
    const partId = e.participacaoId ? String(e.participacaoId) : null;

    // Se houver filtro de participação, ignora evidências de outras participações
    if (participacaoIdFiltro && partId && partId !== participacaoIdFiltro) {
      continue;
    }

    // Se o ator for Responsável de Equipe, descarta evidências de outras equipes (AD-9, AD-12)
    if (escopo.papel === 'RESPONSAVEL_EQUIPE' && equipeId) {
      if (!escopo.equipeIdsAutorizadas?.includes(equipeId)) {
        continue;
      }
    }

    if (etapa === 'PASTOR_LOCAL') {
      const aprovado = decisao === 'APROVADO';
      eventosBrutos.push({
        id: doc.id,
        tipo: 'DECISAO_PASTORAL',
        etapa: 'PASTOR_LOCAL',
        titulo: aprovado ? 'Aprovação pastoral' : 'Avaliação pastoral',
        descricao: aprovado
          ? 'Ficha e conduta aprovadas pelo Pastor da igreja local.'
          : (escopo.ehProprioVoluntario ? MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA : 'Decisão pastoral desfavorável registrada.'),
        estadoVisual: aprovado ? 'CONCLUIDO' : 'ORIENTACAO_PASTORAL',
        timestamp,
        ator: aprovado || !escopo.ehProprioVoluntario
          ? { nome: String(e.atorNome ?? 'Pastor Local'), papel: 'PASTOR_LOCAL' }
          : null,
        justificativaInterna: escopo.ehProprioVoluntario ? null : (e.justificativa ? String(e.justificativa) : null),
      });
    } else if (etapa === 'RESPONSAVEL_EQUIPE') {
      const aprovado = decisao === 'APROVADO';
      // Obter nome da equipe se possível
      let nomeEquipe: string | null = null;
      if (equipeId) {
        const eqDoc = await db.collection('equipes').doc(equipeId).get();
        if (eqDoc.exists) {
          nomeEquipe = String(eqDoc.data()?.nome ?? equipeId);
        }
      }

      eventosBrutos.push({
        id: doc.id,
        tipo: 'DECISAO_RESPONSAVEL_EQUIPE',
        etapa: 'RESPONSAVEL_EQUIPE',
        titulo: aprovado
          ? `Aprovação da equipe ${nomeEquipe ?? ''}`.trim()
          : `Avaliação da equipe ${nomeEquipe ?? ''}`.trim(),
        descricao: aprovado
          ? `Participação aprovada pelo Responsável de Equipe.`
          : (escopo.ehProprioVoluntario ? MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA : 'Decisão de equipe desfavorável registrada.'),
        estadoVisual: aprovado ? 'CONCLUIDO' : 'ORIENTACAO_PASTORAL',
        timestamp,
        ator: aprovado || !escopo.ehProprioVoluntario
          ? { nome: String(e.atorNome ?? 'Responsável de Equipe'), papel: 'RESPONSAVEL_EQUIPE' }
          : null,
        equipeId,
        nomeEquipe,
        justificativaInterna: escopo.ehProprioVoluntario ? null : (e.justificativa ? String(e.justificativa) : null),
      });
    } else if (etapa === 'COORDENADOR_GERAL') {
      eventosBrutos.push({
        id: doc.id,
        tipo: 'HOMOLOGACAO_COORDENACAO',
        etapa: 'COORDENADOR_GERAL',
        titulo: 'Homologação e ativação anual',
        descricao: e.vigenciaInicio && e.vigenciaFim
          ? `Voluntariado ativo homologado para vigência de ${e.vigenciaInicio} a ${e.vigenciaFim}.`
          : 'Voluntariado homologado pelo Coordenador Geral pós-Reunião de Pastores.',
        estadoVisual: 'CONCLUIDO',
        timestamp,
        ator: { nome: String(e.atorNome ?? 'Coordenador Geral'), papel: 'COORDENADOR_GERAL' },
        justificativaInterna: escopo.ehProprioVoluntario ? null : (e.observacao ? String(e.observacao) : null),
      });
    }
  }

  // 4. Sanitizar eventos caso seja visualização do voluntário
  const eventosSanitizados = escopo.ehProprioVoluntario
    ? eventosBrutos.map(sanitizarEventoParaVoluntario)
    : eventosBrutos;

  // 5. Ordenação cronológica (mais recente primeiro)
  eventosSanitizados.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());

  return {
    fichaId: fichaIdEfetivo,
    eventos: eventosSanitizados,
    totalEventos: eventosSanitizados.length,
  };
}
