import {
  FieldValue,
  Timestamp,
  type Firestore,
} from 'firebase-admin/firestore';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  FichaNaoAguardandoPastorError,
  FichaNaoEncontradaError,
  MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
  SemVinculoPastoralError,
  type EntradaDecidirFichaPastorLocal,
  type IgrejaEscopoPastor,
  type ItemFilaPastorLocal,
  type ResultadoDecidirFichaPastorLocal,
  type ResultadoFilaPastorLocal,
} from '../domain/decisaoPastor.js';

export interface ContextoDecisaoPastor {
  commandId: string;
  correlationId?: string;
  pastorUid: string;
}

function iso(valor: unknown): string {
  if (!valor) return new Date().toISOString();
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof Date) return valor.toISOString();
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().toISOString();
  }
  return String(valor);
}

/**
 * Consulta as pendências de voluntários aguardando aprovação pastoral
 * estritamente pertencentes às igrejas onde o usuário autenticado possui
 * vínculo pastoral vigente ativo.
 */
export async function obterFilaPastorLocalRepo(
  db: Firestore,
  pastorUid: string,
): Promise<ResultadoFilaPastorLocal> {
  // 1. Localizar igrejas sob responsabilidade pastoral vigente do usuário
  const igrejasSnap = await db
    .collection('igrejas')
    .where('pastorLocalVigentePessoaId', '==', pastorUid)
    .get();

  const igrejasMap = new Map<string, IgrejaEscopoPastor>();
  for (const doc of igrejasSnap.docs) {
    const dados = doc.data() ?? {};
    if (dados.ativo !== false) {
      igrejasMap.set(doc.id, {
        id: doc.id,
        nome: String(dados.nome ?? doc.id),
        codigo: dados.codigo ? String(dados.codigo) : undefined,
      });
    }
  }

  // Também verifica vínculos em vinculosPastorIgreja para garantir completude
  const vinculosSnap = await db
    .collection('vinculosPastorIgreja')
    .where('pessoaId', '==', pastorUid)
    .where('estado', '==', 'VIGENTE')
    .get();

  for (const doc of vinculosSnap.docs) {
    const v = doc.data() ?? {};
    const igrejaId = String(v.entidadeId ?? '');
    if (igrejaId && !igrejasMap.has(igrejaId)) {
      const igrejaDoc = await db.collection('igrejas').doc(igrejaId).get();
      if (igrejaDoc.exists && igrejaDoc.data()?.ativo !== false) {
        const dados = igrejaDoc.data() ?? {};
        igrejasMap.set(igrejaId, {
          id: igrejaId,
          nome: String(dados.nome ?? igrejaId),
          codigo: dados.codigo ? String(dados.codigo) : undefined,
        });
      }
    }
  }

  const igrejas = Array.from(igrejasMap.values()).sort((a, b) =>
    a.nome.localeCompare(b.nome, 'pt-BR'),
  );

  if (igrejas.length === 0) {
    return { pendencias: [], igrejas: [] };
  }

  const igrejaIds = igrejas.map((i) => i.id);

  // 2. Buscar pendências na projeção filaPendencias para as igrejas do pastor
  // Em Firestore, consultas 'in' suportam até 30 elementos.
  const pendencias: ItemFilaPastorLocal[] = [];
  const chunkSize = 30;

  for (let i = 0; i < igrejaIds.length; i += chunkSize) {
    const lote = igrejaIds.slice(i, i + chunkSize);
    const filaSnap = await db
      .collection('filaPendencias')
      .where('estado', '==', 'AGUARDANDO_PASTOR_LOCAL')
      .where('igrejaId', 'in', lote)
      .get();

    for (const doc of filaSnap.docs) {
      const d = doc.data() ?? {};
      const igrejaId = String(d.igrejaId ?? '');
      pendencias.push({
        id: doc.id,
        fichaId: String(d.fichaId ?? doc.id),
        voluntarioUid: String(d.voluntarioUid ?? doc.id),
        voluntarioNome: String(d.voluntarioNome ?? 'Voluntário'),
        igrejaId,
        nomeIgreja: igrejasMap.get(igrejaId)?.nome,
        estado: String(d.estado ?? 'AGUARDANDO_PASTOR_LOCAL'),
        proximaAcao: String(d.proximaAcao ?? 'Aguardando avaliação do Pastor Local'),
        ano: Number(d.ano ?? new Date().getUTCFullYear()),
        equipes: Array.isArray(d.equipes)
          ? d.equipes.map((eq: Record<string, unknown>) => ({
              equipeId: String(eq.equipeId ?? ''),
              nomeEquipe: String(eq.nomeEquipe ?? ''),
            }))
          : [],
        enviadoEm: iso(d.enviadoEm),
      });
    }
  }

  // Ordena por data de envio (mais antigas primeiro)
  pendencias.sort((a, b) => a.enviadoEm.localeCompare(b.enviadoEm));

  return { pendencias, igrejas };
}

/**
 * Executa transacionalmente a decisão do Pastor Local:
 * 1. Idempotência em commands/{commandId}.
 * 2. Validação da ficha existente em AGUARDANDO_PASTOR_LOCAL com expectedVersion.
 * 3. Validação do vínculo pastoral vigente do chamador para a igreja da ficha.
 * 4. Transição atômica de ficha e participações:
 *    - APROVADO: AGUARDANDO_RESPONSAVEL_EQUIPE
 *    - DESFAVORAVEL: REJEITADA com mensagem canônica para o voluntário.
 * 5. Resolução da pendência pastoral na fila.
 * 6. Evidência imutável de decisão em evidenciasDecisao.
 * 7. Recibo em commands e auditoria sem PII em auditOutbox.
 */
export async function decidirFichaPastorLocalRepo(
  db: Firestore,
  contexto: ContextoDecisaoPastor,
  entrada: EntradaDecidirFichaPastorLocal,
): Promise<ResultadoDecidirFichaPastorLocal> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const fichaRef = db.collection('fichas').doc(entrada.fichaId);
  const filaRef = db.collection('filaPendencias').doc(entrada.fichaId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);
  const evidenciaRef = db.collection('evidenciasDecisao').doc(contexto.commandId);

  return await db.runTransaction(async (tx) => {
    // 1. Verificação de idempotência no recibo
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid && dadosRecibo.uid !== contexto.pastorUid) {
        throw new SemVinculoPastoralError(
          'Operação indisponível para o usuário informado.',
        );
      }
      if (dadosRecibo.payloadHash !== entrada.payloadHash) {
        throw new ComandoDivergenteError();
      }
      const res = dadosRecibo.resultado as Record<string, unknown> | undefined;
      return {
        sucesso: true,
        repetido: true,
        decisao: entrada.decisao,
        estado: String(res?.estado ?? 'AGUARDANDO_RESPONSAVEL_EQUIPE'),
        versao: Number(res?.versao ?? 1),
        proximaAcao: String(res?.proximaAcao ?? ''),
        decididoEm: iso(dadosRecibo.criadoEm),
      };
    }

    // 2. Leitura e validação da Ficha
    const fichaSnap = await tx.get(fichaRef);
    if (!fichaSnap.exists) {
      throw new FichaNaoEncontradaError();
    }
    const fichaData = fichaSnap.data() ?? {};

    if (fichaData.estado !== 'AGUARDANDO_PASTOR_LOCAL') {
      throw new FichaNaoAguardandoPastorError();
    }

    const versaoAtual = Number(fichaData.versao ?? 1);
    if (versaoAtual !== entrada.expectedVersion) {
      throw new ConflitoVersaoError();
    }

    const igrejaId = String(fichaData.igrejaId ?? '').trim();
    if (!igrejaId) {
      throw new SemVinculoPastoralError(
        'Ficha sem igreja vinculada para validação pastoral.',
      );
    }

    // 3. Validação do Vínculo Pastoral Vigente da Igreja
    const igrejaRef = db.collection('igrejas').doc(igrejaId);
    const igrejaSnap = await tx.get(igrejaRef);
    if (!igrejaSnap.exists || igrejaSnap.data()?.ativo === false) {
      throw new SemVinculoPastoralError(
        'A igreja vinculada está inativa ou não existe.',
      );
    }

    const igrejaData = igrejaSnap.data() ?? {};
    if (igrejaData.pastorLocalVigentePessoaId !== contexto.pastorUid) {
      throw new SemVinculoPastoralError();
    }

    const vinculoVigenteId = String(
      igrejaData.pastorLocalVigenteVinculoId ?? '',
    );
    if (vinculoVigenteId) {
      const vinculoSnap = await tx.get(
        db.collection('vinculosPastorIgreja').doc(vinculoVigenteId),
      );
      if (vinculoSnap.exists) {
        const vData = vinculoSnap.data() ?? {};
        if (vData.estado !== 'VIGENTE' || vData.pessoaId !== contexto.pastorUid) {
          throw new SemVinculoPastoralError(
            'Vínculo pastoral expirado ou substituído.',
          );
        }
      }
    }

    // Busca nome do pastor para o snapshot imutável de evidência
    const pastorPessoaSnap = await tx.get(
      db.collection('pessoas').doc(contexto.pastorUid),
    );
    const pastorNome = pastorPessoaSnap.exists
      ? String(pastorPessoaSnap.data()?.nomeCompleto ?? 'Pastor Local')
      : 'Pastor Local';

    // 4. Determinação dos Novos Estados
    const novaVersao = versaoAtual + 1;
    const agora = FieldValue.serverTimestamp();
    const agoraIso = new Date().toISOString();

    const participacoesSnap = await tx.get(
      db.collection('participacoes').where('fichaId', '==', entrada.fichaId),
    );
    const participacoesDocs = participacoesSnap.docs ?? [];

    let novoEstado: string;
    let proximaAcao: string;
    let atualizacaoFicha: Record<string, unknown>;

    if (entrada.decisao === 'APROVADO') {
      novoEstado = 'AGUARDANDO_RESPONSAVEL_EQUIPE';
      proximaAcao = 'Aguardando avaliação dos Responsáveis de Equipe';

      atualizacaoFicha = {
        estado: novoEstado,
        proximaAcao,
        versao: novaVersao,
        decisaoPastoral: {
          decisao: 'APROVADO',
          pastorUid: contexto.pastorUid,
          pastorNome,
          vinculoId: vinculoVigenteId,
          decididoEm: agora,
        },
        atualizadoEm: agora,
      };

      // Atualiza participações para avançar à etapa dos responsáveis de equipe
      for (const partDoc of participacoesDocs) {
        const partData = partDoc.data() ?? {};
        if (partData.estado === 'AGUARDANDO_PASTOR_LOCAL') {
          tx.update(partDoc.ref, {
            estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
            proximaAcao: 'Aguardando avaliação do Responsável de Equipe',
            atualizadoEm: agora,
          });
        }
      }

      // Evidência imutável de aprovação
      tx.set(evidenciaRef, {
        commandId: contexto.commandId,
        fichaId: entrada.fichaId,
        etapa: 'PASTOR_LOCAL',
        decisao: 'APROVADO',
        atorUid: contexto.pastorUid,
        atorNome: pastorNome,
        papel: 'PASTOR_LOCAL',
        vinculoId: vinculoVigenteId,
        igrejaId,
        justificativa: null,
        timestamp: agora,
      });
    } else {
      // Decisão DESFAVORAVEL
      novoEstado = 'REJEITADA';
      proximaAcao = MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA;

      atualizacaoFicha = {
        estado: novoEstado,
        proximaAcao,
        mensagemVoluntario: MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
        justificativaInterna: entrada.justificativa,
        versao: novaVersao,
        decisaoPastoral: {
          decisao: 'DESFAVORAVEL',
          pastorUid: contexto.pastorUid,
          pastorNome,
          vinculoId: vinculoVigenteId,
          justificativa: entrada.justificativa,
          decididoEm: agora,
        },
        atualizadoEm: agora,
      };

      // Transiciona participações para REJEITADA com mensagem neutra
      for (const partDoc of participacoesDocs) {
        tx.update(partDoc.ref, {
          estado: 'REJEITADA',
          proximaAcao: MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
          atualizadoEm: agora,
        });
      }

      // Evidência imutável com justificativa interna
      tx.set(evidenciaRef, {
        commandId: contexto.commandId,
        fichaId: entrada.fichaId,
        etapa: 'PASTOR_LOCAL',
        decisao: 'DESFAVORAVEL',
        atorUid: contexto.pastorUid,
        atorNome: pastorNome,
        papel: 'PASTOR_LOCAL',
        vinculoId: vinculoVigenteId,
        igrejaId,
        justificativa: entrada.justificativa,
        timestamp: agora,
      });
    }

    // Persiste alteração da ficha
    tx.update(fichaRef, atualizacaoFicha);

    // Remove pendência da fila do Pastor Local (para não aparecer mais na fila)
    tx.delete(filaRef);

    // 5. Recibo Idempotente
    const resultadoOperacao = {
      sucesso: true,
      repetido: false,
      decisao: entrada.decisao,
      estado: novoEstado,
      versao: novaVersao,
      proximaAcao,
      decididoEm: agoraIso,
    };

    tx.set(reciboRef, {
      commandId: contexto.commandId,
      uid: contexto.pastorUid,
      acao: 'DECIDIR_FICHA_PASTOR_LOCAL',
      payloadHash: entrada.payloadHash,
      status: 'COMPLETO',
      resultado: resultadoOperacao,
      criadoEm: agora,
    });

    // 6. Auditoria append-only em auditOutbox estritamente SEM PII
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: entrada.correlationId ?? contexto.commandId,
      atorUid: contexto.pastorUid,
      acao: 'DECISAO_PASTORAL_REGISTRADA',
      entidades: [
        { tipo: 'FICHA', id: entrada.fichaId },
        { tipo: 'FILA_PENDENCIAS', id: entrada.fichaId },
        ...participacoesDocs.map((p) => ({ tipo: 'PARTICIPACAO', id: p.id })),
      ],
      antes: { estado: 'AGUARDANDO_PASTOR_LOCAL' },
      depois: { estado: novoEstado },
      metadados: {
        igrejaId,
        decisao: entrada.decisao,
      },
      timestamp: agora,
    });

    return resultadoOperacao;
  });
}
