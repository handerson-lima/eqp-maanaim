import { Timestamp, type Firestore } from 'firebase-admin/firestore';
import {
  AcessoNaoAutorizadoError,
  MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
  ehEstadoNegativo,
  estadoPublicoVoluntario,
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
import { classificarVigencia, type ConfiguracaoJanelaVigencia } from '../domain/vigencia.js';
import { obterConfiguracaoJanelaVigencia } from './configuracaoVigencia.js';

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

function dentroDaVigencia(data: Record<string, unknown>): boolean {
  const agora = Date.now();
  const inicio = serializarTimestamp(data.inicioVigencia);
  if (inicio) {
    const ms = Date.parse(inicio);
    if (!Number.isNaN(ms) && ms > agora) return false;
  }
  const fim = serializarTimestamp(data.fimVigencia);
  if (fim) {
    const ms = Date.parse(fim);
    if (!Number.isNaN(ms) && ms <= agora) return false;
  }
  return true;
}

function vinculoPastoralValido(
  data: Record<string, unknown> | null,
  atorUid: string,
): boolean {
  if (!data) return false;
  if (String(data.estado ?? '') !== 'VIGENTE') return false;
  if (String(data.pessoaId ?? '') !== atorUid) return false;
  return dentroDaVigencia(data);
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
          vinculoAtivo = vinculoPastoralValido(
            vDoc.exists ? (vDoc.data() ?? {}) : null,
            atorUid,
          );
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

    // Consulta alternativa direta em vinculosPastorIgreja para pastor com vínculo vigente e temporal
    if (igrejaDoc.exists && igrejaDoc.data()?.ativo !== false) {
      const vinculoPastoralSnap = await db
        .collection('vinculosPastorIgreja')
        .where('pessoaId', '==', atorUid)
        .where('entidadeId', '==', igrejaId)
        .where('estado', '==', 'VIGENTE')
        .limit(1)
        .get();

      if (
        !vinculoPastoralSnap.empty &&
        vinculoPastoralValido(vinculoPastoralSnap.docs[0].data(), atorUid)
      ) {
        return {
          atorUid,
          papel: 'PASTOR_LOCAL',
          igrejaId,
          ehProprioVoluntario: false,
        };
      }
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

  // 5b. Vínculos vigentes em vinculosPastorEquipe
  const vinculosEquipeSnap = await db
    .collection('vinculosPastorEquipe')
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
  const cpfCompleto =
    rawCpf !== '' &&
    (escopo.ehProprioVoluntario ||
      escopo.papel === 'COORDENADOR_GERAL' ||
      escopo.papel === 'ADMINISTRADOR')
      ? rawCpf
      : undefined;

  const estadoFichaBruto = String(fichaData.estado ?? 'RASCUNHO');
  const ehNegativaFicha = ehEstadoNegativo(estadoFichaBruto);
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
    estado: escopo.ehProprioVoluntario
      ? estadoPublicoVoluntario(estadoFichaBruto)
      : estadoFichaBruto,
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

  const configVigencia: ConfiguracaoJanelaVigencia =
    await obterConfiguracaoJanelaVigencia(db);

  const participacoes: ParticipacaoConsultaAutorizada[] = participacoesDocs
    .map((doc) => {
      const d = doc.data() ?? {};
      const estado = String(d.estado ?? 'RASCUNHO');
      const ehNegativa = ehEstadoNegativo(estado) || d.decisao === 'DESFAVORAVEL';
      const proximaAcao = ehNegativa
        ? MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA
        : String(d.proximaAcao ?? (estado === 'RASCUNHO' ? 'Aguardando envio da ficha' : 'Em análise'));

      const vigenciaInicio = serializarTimestamp(d.vigenciaInicio);
      const vigenciaFim = serializarTimestamp(d.vigenciaFim);
      const alertaInfo =
        estado === 'ATIVA' ? classificarVigencia(Date.now(), vigenciaFim, configVigencia) : null;

      return {
        id: doc.id,
        fichaId: String(d.fichaId ?? fichaIdEfetivo),
        equipeId: String(d.equipeId ?? ''),
        nomeEquipe: String(d.nomeEquipe ?? ''),
        estado: escopo.ehProprioVoluntario ? estadoPublicoVoluntario(estado) : estado,
        ciclo: String(d.ciclo ?? 'INICIAL'),
        proximaAcao,
        vigenciaInicio,
        vigenciaFim,
        situacaoVigencia: alertaInfo?.situacao ?? (estado === 'EXPIRADA' ? 'EXPIRADA' : null),
        diasParaVencimento: alertaInfo?.diasRestantes ?? null,
        alertaVigencia: alertaInfo?.alerta ?? null,
        emAlertaRenovacao: alertaInfo?.emAlertaRenovacao ?? false,
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

  // 1. Marco de criação da ficha (timestamp persistido e imutável)
  const criacaoTs = serializarTimestamp(fichaData.criadoEm);
  if (criacaoTs) {
    eventosBrutos.push({
      id: `criacao-${fichaIdEfetivo}`,
      tipo: 'CRIACAO_FICHA',
      etapa: 'CADASTRO',
      titulo: 'Ficha cadastral criada',
      descricao: 'Cadastro de dados permanente iniciado pelo voluntário.',
      estadoVisual: 'CONCLUIDO',
      timestamp: criacaoTs,
      ator: escopo.ehProprioVoluntario ? null : { nome: String(fichaData.nomeCompleto ?? 'Voluntário'), papel: 'VOLUNTARIO' },
      justificativaInterna: null,
    });
  }

  // 2. Marco de envio para aprovação (usa enviadoEm persistido, não atualizadoEm mutável)
  if (fichaData.estado && fichaData.estado !== 'RASCUNHO') {
    const envioTs =
      serializarTimestamp(fichaData.enviadoEm) ?? serializarTimestamp(fichaData.criadoEm);
    if (envioTs) {
      eventosBrutos.push({
        id: `envio-${fichaIdEfetivo}`,
        tipo: 'ENVIO_APROVACAO',
        etapa: 'CADASTRO',
        titulo: 'Ficha enviada para aprovação',
        descricao: 'Termo de voluntariado aceito e solicitação encaminhada ao Pastor Local.',
        estadoVisual: 'CONCLUIDO',
        timestamp: envioTs,
        ator: escopo.ehProprioVoluntario ? null : { nome: String(fichaData.nomeCompleto ?? 'Voluntário'), papel: 'VOLUNTARIO' },
        justificativaInterna: null,
      });
    }
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
    const timestamp = serializarTimestamp(e.timestamp);
    if (!timestamp) continue;
    const equipeId = e.equipeId ? String(e.equipeId) : null;
    const partId = e.participacaoId ? String(e.participacaoId) : null;
    const vinculoId = e.vinculoId ? String(e.vinculoId) : null;

    // Se houver filtro de participação, exige correspondência exata (evidências sem vínculo são excluídas)
    if (participacaoIdFiltro && partId !== participacaoIdFiltro) {
      continue;
    }

    // Responsável de Equipe: isolamento estrito por equipe; eventos sem equipe autorizada são descartados
    if (escopo.papel === 'RESPONSAVEL_EQUIPE') {
      const equipeAutorizada = !!equipeId && !!escopo.equipeIdsAutorizadas?.includes(equipeId);
      const ehExpiracao = e.tipo === 'EXPIRACAO_CICLO_ANUAL';
      if (etapa === 'RESPONSAVEL_EQUIPE' || ehExpiracao) {
        if (!equipeAutorizada) continue;
      } else {
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
          ? { nome: String(e.atorNome ?? 'Pastor Local'), papel: 'PASTOR_LOCAL', vinculoId }
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
          ? { nome: String(e.atorNome ?? 'Responsável de Equipe'), papel: 'RESPONSAVEL_EQUIPE', vinculoId }
          : null,
        equipeId,
        nomeEquipe,
        justificativaInterna: escopo.ehProprioVoluntario ? null : (e.justificativa ? String(e.justificativa) : null),
      });
    } else if (etapa === 'COORDENADOR_GERAL') {
      const homologado = decisao === 'APROVADO';
      const vigenciaInicio = serializarTimestamp(e.vigenciaInicio);
      const vigenciaFim = serializarTimestamp(e.vigenciaFim);
      eventosBrutos.push({
        id: doc.id,
        tipo: 'HOMOLOGACAO_COORDENACAO',
        etapa: 'COORDENADOR_GERAL',
        titulo: homologado ? 'Homologação e ativação anual' : 'Avaliação da coordenação',
        descricao: homologado
          ? (vigenciaInicio && vigenciaFim
              ? `Voluntariado ativo homologado para vigência de ${vigenciaInicio} a ${vigenciaFim}.`
              : 'Voluntariado homologado pelo Coordenador Geral pós-Reunião de Pastores.')
          : (escopo.ehProprioVoluntario ? MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA : 'Decisão da coordenação desfavorável registrada.'),
        estadoVisual: homologado ? 'CONCLUIDO' : 'ORIENTACAO_PASTORAL',
        timestamp,
        ator: homologado || !escopo.ehProprioVoluntario
          ? { nome: String(e.atorNome ?? 'Coordenador Geral'), papel: 'COORDENADOR_GERAL', vinculoId }
          : null,
        justificativaInterna: escopo.ehProprioVoluntario
          ? null
          : (e.justificativa ?? e.justificativaInterna ?? e.observacao ?? null) as string | null,
      });
    } else if (e.tipo === 'EXPIRACAO_CICLO_ANUAL') {
      eventosBrutos.push({
        id: doc.id,
        tipo: 'EXPIRACAO_CICLO_ANUAL',
        etapa: 'SISTEMA',
        titulo: 'Vigência anual expirada',
        descricao: 'A vigência anual foi encerrada automaticamente pelo sistema por falta de renovação.',
        estadoVisual: 'CONCLUIDO',
        timestamp,
        ator: escopo.ehProprioVoluntario ? null : { nome: 'Sistema', papel: 'SISTEMA', vinculoId: null },
        equipeId,
        justificativaInterna: null,
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
