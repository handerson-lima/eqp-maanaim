import {
  FieldValue,
  Timestamp,
  type DocumentSnapshot,
  type Firestore,
} from 'firebase-admin/firestore';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
  ParticipacaoNaoAguardandoResponsavelError,
  ParticipacaoNaoEncontradaError,
  SemVinculoResponsavelEquipeError,
  type EntradaDecidirParticipacaoResponsavelEquipe,
  type EquipeEscopoResponsavel,
  type ItemFilaResponsavelEquipe,
  type ResultadoDecidirParticipacaoResponsavelEquipe,
  type ResultadoFilaResponsavelEquipe,
} from '../domain/decisaoResponsavelEquipe.js';
import { reduzirEstadoFicha } from './decisaoCoordenador.js';

export interface ContextoDecisaoResponsavel {
  commandId: string;
  correlationId?: string;
  responsavelUid: string;
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
 * Consulta as participações aguardando aprovação por responsável de equipe
 * estritamente pertencentes às equipes onde o usuário autenticado possui
 * vínculo de responsabilidade vigente ativo.
 */
export async function obterFilaResponsavelEquipeRepo(
  db: Firestore,
  responsavelUid: string,
): Promise<ResultadoFilaResponsavelEquipe> {
  // 1. Localizar equipes sob responsabilidade vigente do usuário
  const equipesSnap = await db
    .collection('equipes')
    .where('responsavelVigentePessoaId', '==', responsavelUid)
    .get();

  const equipesMap = new Map<string, EquipeEscopoResponsavel>();
  for (const doc of equipesSnap.docs) {
    const dados = doc.data() ?? {};
    if (dados.ativo !== false) {
      equipesMap.set(doc.id, {
        id: doc.id,
        nome: String(dados.nome ?? doc.id),
      });
    }
  }

  // Também verifica vínculos em vinculosPastorEquipe para completude
  const vinculosSnap = await db
    .collection('vinculosPastorEquipe')
    .where('pessoaId', '==', responsavelUid)
    .where('estado', '==', 'VIGENTE')
    .get();

  for (const doc of vinculosSnap.docs) {
    const v = doc.data() ?? {};
    const equipeId = String(v.entidadeId ?? '');
    if (equipeId && !equipesMap.has(equipeId)) {
      const equipeDoc = await db.collection('equipes').doc(equipeId).get();
      if (equipeDoc.exists && equipeDoc.data()?.ativo !== false) {
        const dados = equipeDoc.data() ?? {};
        equipesMap.set(equipeId, {
          id: equipeId,
          nome: String(dados.nome ?? equipeId),
        });
      }
    }
  }

  const equipes = Array.from(equipesMap.values()).sort((a, b) =>
    a.nome.localeCompare(b.nome, 'pt-BR'),
  );

  if (equipes.length === 0) {
    return { pendencias: [], equipes: [] };
  }

  const equipeIds = equipes.map((e) => e.id);

  // 2. Buscar participações em AGUARDANDO_RESPONSAVEL_EQUIPE para as equipes do responsável
  const pendencias: ItemFilaResponsavelEquipe[] = [];
  const chunkSize = 30;

  const fichasCache = new Map<string, { nomeCompleto: string; igrejaId: string; nomeIgreja?: string }>();
  const igrejasCache = new Map<string, string>();

  for (let i = 0; i < equipeIds.length; i += chunkSize) {
    const lote = equipeIds.slice(i, i + chunkSize);
    const partSnap = await db
      .collection('participacoes')
      .where('estado', '==', 'AGUARDANDO_RESPONSAVEL_EQUIPE')
      .where('equipeId', 'in', lote)
      .get();

    for (const doc of partSnap.docs) {
      const d = doc.data() ?? {};
      const fichaId = String(d.fichaId ?? '');
      const equipeId = String(d.equipeId ?? '');

      // Enriquecimento mínimo: apenas dados do voluntário e igreja (sem expor outras equipes)
      let infoFicha = fichasCache.get(fichaId);
      if (!infoFicha && fichaId) {
        const fichaDoc = await db.collection('fichas').doc(fichaId).get();
        if (fichaDoc.exists) {
          const fData = fichaDoc.data() ?? {};
          const igrejaId = String(fData.igrejaId ?? '');
          let nomeIgreja = igrejasCache.get(igrejaId);
          if (!nomeIgreja && igrejaId) {
            const igDoc = await db.collection('igrejas').doc(igrejaId).get();
            if (igDoc.exists) {
              nomeIgreja = String(igDoc.data()?.nome ?? igrejaId);
              igrejasCache.set(igrejaId, nomeIgreja);
            }
          }
          infoFicha = {
            nomeCompleto: String(fData.nomeCompleto ?? 'Voluntário'),
            igrejaId,
            nomeIgreja,
          };
          fichasCache.set(fichaId, infoFicha);
        }
      }

      pendencias.push({
        participacaoId: doc.id,
        fichaId,
        voluntarioUid: fichaId,
        voluntarioNome: infoFicha?.nomeCompleto ?? 'Voluntário',
        igrejaId: infoFicha?.igrejaId ?? '',
        nomeIgreja: infoFicha?.nomeIgreja,
        equipeId,
        nomeEquipe: String(d.nomeEquipe ?? equipesMap.get(equipeId)?.nome ?? equipeId),
        estado: String(d.estado ?? 'AGUARDANDO_RESPONSAVEL_EQUIPE'),
        proximaAcao: String(d.proximaAcao ?? 'Aguardando avaliação do Responsável de Equipe'),
        versao: Number(d.versao ?? 1),
        enviadoEm: iso(d.atualizadoEm ?? d.criadoEm),
      });
    }
  }

  pendencias.sort((a, b) => a.voluntarioNome.localeCompare(b.voluntarioNome, 'pt-BR'));

  return { pendencias, equipes };
}

/**
 * Transição atômica para decisão de participação por Responsável de Equipe.
 * - Idempotente via `commands/{commandId}`
 * - Validação estrita do vínculo vigente do chamador para a equipe
 * - Concorrência via `expectedVersion` na participação individual
 * - Agregado independente: outras equipes da ficha não são alteradas
 * - Redução do estado da Ficha (AD-11) quando todas as equipes são resolvidas
 * - Registro de evidência imutável e outbox de auditoria sem PII
 */
export async function decidirParticipacaoResponsavelEquipeRepo(
  db: Firestore,
  contexto: ContextoDecisaoResponsavel,
  entrada: EntradaDecidirParticipacaoResponsavelEquipe,
): Promise<ResultadoDecidirParticipacaoResponsavelEquipe> {
  const reciboRef = db.collection('commands').doc(contexto.commandId);
  const participacaoRef = db.collection('participacoes').doc(entrada.participacaoId);
  const auditoriaRef = db.collection('auditOutbox').doc(contexto.commandId);
  const evidenciaRef = db.collection('evidenciasDecisao').doc(contexto.commandId);

  return await db.runTransaction(async (tx) => {
    // 1. Idempotência por recibo em commands
    const reciboSnap = await tx.get(reciboRef);
    if (reciboSnap.exists) {
      const dadosRecibo = reciboSnap.data() ?? {};
      if (dadosRecibo.uid && dadosRecibo.uid !== contexto.responsavelUid) {
        throw new SemVinculoResponsavelEquipeError(
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
        participacaoId: entrada.participacaoId,
        decisao: entrada.decisao,
        estado: String(res?.estado ?? 'AGUARDANDO_COORDENADOR'),
        versao: Number(res?.versao ?? 1),
        proximaAcao: String(res?.proximaAcao ?? ''),
        decididoEm: iso(dadosRecibo.criadoEm),
      };
    }

    // 2. Leitura e validação da Participação
    const participacaoSnap = await tx.get(participacaoRef);
    if (!participacaoSnap.exists) {
      throw new ParticipacaoNaoEncontradaError();
    }
    const partData = participacaoSnap.data() ?? {};

    if (partData.estado !== 'AGUARDANDO_RESPONSAVEL_EQUIPE') {
      throw new ParticipacaoNaoAguardandoResponsavelError();
    }

    const versaoAtual = Number(partData.versao ?? 1);
    if (versaoAtual !== entrada.expectedVersion) {
      throw new ConflitoVersaoError();
    }

    const equipeId = String(partData.equipeId ?? '').trim();
    if (!equipeId) {
      throw new SemVinculoResponsavelEquipeError(
        'Participação sem equipe vinculada.',
      );
    }

    // 3. Validação da autoridade vigente sobre a equipe
    const equipeRef = db.collection('equipes').doc(equipeId);
    const equipeSnap = await tx.get(equipeRef);
    if (!equipeSnap.exists || equipeSnap.data()?.ativo === false) {
      throw new SemVinculoResponsavelEquipeError(
        'A equipe solicitada está inativa ou não existe.',
      );
    }

    const equipeData = equipeSnap.data() ?? {};
    if (equipeData.responsavelVigentePessoaId !== contexto.responsavelUid) {
      throw new SemVinculoResponsavelEquipeError();
    }

    const vinculoVigenteId = String(
      equipeData.responsavelVigenteVinculoId ?? '',
    );
    if (vinculoVigenteId) {
      const vinculoSnap = await tx.get(
        db.collection('vinculosPastorEquipe').doc(vinculoVigenteId),
      );
      if (vinculoSnap.exists) {
        const vData = vinculoSnap.data() ?? {};
        if (vData.estado !== 'VIGENTE' || vData.pessoaId !== contexto.responsavelUid) {
          throw new SemVinculoResponsavelEquipeError(
            'Vínculo de responsável de equipe expirado ou substituído.',
          );
        }
      }
    }

    // Busca nome do responsável para o snapshot imutável de evidência
    const responsavelPessoaSnap = await tx.get(
      db.collection('pessoas').doc(contexto.responsavelUid),
    );
    const responsavelNome = responsavelPessoaSnap.exists
      ? String(responsavelPessoaSnap.data()?.nomeCompleto ?? 'Responsável de Equipe')
      : 'Responsável de Equipe';

    // Pré-leitura da ficha e das participações para a redução de estado (AD-11).
    // O SDK exige que toda leitura ocorra antes da primeira escrita da transação.
    const fichaIdReducao = String(partData.fichaId ?? '');
    const fichaRefReducao = db.collection('fichas').doc(fichaIdReducao);
    const fichaSnapReducao = fichaIdReducao
      ? await tx.get(fichaRefReducao)
      : null;
    const todasPartSnapReducao =
      fichaSnapReducao?.exists
        ? await tx.get(
            db.collection('participacoes').where('fichaId', '==', fichaIdReducao),
          )
        : null;

    // 4. Determinação dos novos estados para a participação
    const novaVersao = versaoAtual + 1;
    const agora = FieldValue.serverTimestamp();
    const agoraIso = new Date().toISOString();

    let novoEstado: string;
    let proximaAcao: string;
    let atualizacaoParticipacao: Record<string, unknown>;
    let cicloRejeitadoSnap: DocumentSnapshot | null = null;

    if (entrada.decisao === 'APROVADO') {
      novoEstado = 'AGUARDANDO_COORDENADOR';
      proximaAcao = 'Aguardando conclusão do Coordenador';

      atualizacaoParticipacao = {
        estado: novoEstado,
        proximaAcao,
        versao: novaVersao,
        decisaoResponsavel: {
          decisao: 'APROVADO',
          responsavelUid: contexto.responsavelUid,
          responsavelNome,
          equipeId,
          vinculoId: vinculoVigenteId,
          decididoEm: agora,
        },
        atualizadoEm: agora,
      };

      // Evidência imutável de aprovação
      tx.set(evidenciaRef, {
        commandId: contexto.commandId,
        fichaId: partData.fichaId,
        participacaoId: entrada.participacaoId,
        etapa: 'RESPONSAVEL_EQUIPE',
        decisao: 'APROVADO',
        atorUid: contexto.responsavelUid,
        atorNome: responsavelNome,
        papel: 'RESPONSAVEL_EQUIPE',
        equipeId,
        vinculoId: vinculoVigenteId,
        justificativa: null,
        timestamp: agora,
      });
    } else {
      // Decisão DESFAVORAVEL
      novoEstado = 'REJEITADA';
      proximaAcao = MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA;

      // Pré-leitura do ciclo associado (antes de qualquer escrita) para encerrá-lo.
      const cicloAtualId = String(partData.cicloAtualId ?? '');
      if (cicloAtualId) {
        cicloRejeitadoSnap = await tx.get(db.collection('ciclos').doc(cicloAtualId));
      }

      atualizacaoParticipacao = {
        estado: novoEstado,
        proximaAcao,
        mensagemVoluntario: MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
        justificativaInterna: entrada.justificativa,
        versao: novaVersao,
        decisaoResponsavel: {
          decisao: 'DESFAVORAVEL',
          responsavelUid: contexto.responsavelUid,
          responsavelNome,
          equipeId,
          vinculoId: vinculoVigenteId,
          justificativa: entrada.justificativa,
          decididoEm: agora,
        },
        atualizadoEm: agora,
      };

      // Evidência imutável com justificativa interna
      tx.set(evidenciaRef, {
        commandId: contexto.commandId,
        fichaId: partData.fichaId,
        participacaoId: entrada.participacaoId,
        etapa: 'RESPONSAVEL_EQUIPE',
        decisao: 'DESFAVORAVEL',
        atorUid: contexto.responsavelUid,
        atorNome: responsavelNome,
        papel: 'RESPONSAVEL_EQUIPE',
        equipeId,
        vinculoId: vinculoVigenteId,
        justificativa: entrada.justificativa,
        timestamp: agora,
      });
    }

    // Persiste atualização da participação individual (agregado isolado)
    tx.update(participacaoRef, atualizacaoParticipacao);

    // Encerra o ciclo associado quando a decisão é desfavorável (AD-11),
    // evitando ciclo não terminal órfão.
    if (cicloRejeitadoSnap?.exists) {
      const estadoCicloAtual = String(cicloRejeitadoSnap.data()?.estado ?? '');
      if (estadoCicloAtual !== 'CANCELADA' && estadoCicloAtual !== 'REJEITADA') {
        tx.update(cicloRejeitadoSnap.ref, {
          estado: 'REJEITADA',
          atualizadoEm: agora,
        });
      }
    }

    // 5. Redução e sincronização de estado da Ficha (AD-11) — usa as leituras
    // pré-transação para respeitar a ordem leitura-antes-de-escrita do SDK.
    if (fichaSnapReducao?.exists && todasPartSnapReducao) {
      // Considera o novo estado desta participação e o estado atual das demais
      const estadosDasParticipacoes = (todasPartSnapReducao.docs ?? []).map((doc) => {
        if (doc.id === entrada.participacaoId) {
          return novoEstado;
        }
        return String(doc.data()?.estado ?? '');
      });

      const aindaPossuiPendencia = estadosDasParticipacoes.some(
        (e) => e === 'AGUARDANDO_RESPONSAVEL_EQUIPE' || e === 'AGUARDANDO_PASTOR_LOCAL' || e === 'RASCUNHO',
      );

      if (!aindaPossuiPendencia) {
        const reducao = reduzirEstadoFicha(estadosDasParticipacoes);
        const fichaVersao = Number(fichaSnapReducao.data()?.versao ?? 1);

        // AD-11: a ficha permanece ATIVA quando já existe participação ativa,
        // mesmo que uma equipe adicional aguarde a conclusão do Coordenador.
        const atualizacaoFicha: Record<string, unknown> = {
          estado: reducao.estado,
          proximaAcao: reducao.proximaAcao,
          versao: fichaVersao + 1,
          atualizadoEm: agora,
        };
        if (reducao.estado === 'REJEITADA') {
          atualizacaoFicha.mensagemVoluntario = MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA;
        }
        tx.update(fichaRefReducao, atualizacaoFicha);
      }
    }

    // 6. Recibo Idempotente
    const resultadoOperacao = {
      sucesso: true,
      repetido: false,
      participacaoId: entrada.participacaoId,
      decisao: entrada.decisao,
      estado: novoEstado,
      versao: novaVersao,
      proximaAcao,
    };

    tx.create(reciboRef, {
      commandId: contexto.commandId,
      uid: contexto.responsavelUid,
      acao: 'DECIDIR_PARTICIPACAO_RESPONSAVEL_EQUIPE',
      payloadHash: entrada.payloadHash,
      status: 'COMPLETO',
      resultado: resultadoOperacao,
      criadoEm: agora,
    });

    // 7. Auditoria append-only SEM PII (AD-12)
    tx.set(auditoriaRef, {
      commandId: contexto.commandId,
      correlationId: contexto.correlationId ?? contexto.commandId,
      actorUid: contexto.responsavelUid,
      action: 'DECISAO_RESPONSAVEL_EQUIPE',
      fichaId: partData.fichaId,
      participacaoId: entrada.participacaoId,
      equipeId,
      decisao: entrada.decisao,
      novoEstado,
      criadoEm: agora,
    });

    return {
      sucesso: true,
      repetido: false,
      participacaoId: entrada.participacaoId,
      decisao: entrada.decisao,
      estado: novoEstado,
      versao: novaVersao,
      proximaAcao,
      decididoEm: agoraIso,
    };
  });
}
