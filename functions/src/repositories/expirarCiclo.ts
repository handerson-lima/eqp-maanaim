import {
  FieldValue,
  Timestamp,
  type DocumentReference,
  type Firestore,
} from 'firebase-admin/firestore';
import { ComandoDivergenteError } from '../domain/participacao.js';
import {
  type DetalheParticipacaoExpirada,
  type EntradaExpirarCiclos,
  type ResultadoExpirarCiclos,
} from '../domain/expirarCiclo.js';

const ESTADOS_TERMINAIS_CICLO = ['CANCELADO', 'CANCELADA', 'REJEITADO', 'REJEITADA', 'EXPIRADO', 'EXPIRADA'];

/** Estados não-terminais de participação (paridade com `decisaoCoordenador`). */
const ESTADOS_PENDENTES_PARTICIPACAO = [
  'RASCUNHO',
  'AGUARDANDO_PASTOR_LOCAL',
  'AGUARDANDO_RESPONSAVEL_EQUIPE',
  'AGUARDANDO_COORDENADOR',
];

const LIMITE_VERIFICACAO_PADRAO = 100;
/** Teto defensivo para evitar leituras ilimitadas acionadas por parâmetro. */
const LIMITE_MAXIMO_EXPIRACAO = 500;

const PROXIMA_ACAO_FICHA: Record<string, string> = {
  ATIVA: 'Voluntariado ativo',
  AGUARDANDO_COORDENADOR: 'Aguardando conclusão do Coordenador',
  INATIVA: 'Encerrado ao término da vigência',
  EXPIRADA: 'Vigência anual expirada',
};

function iso(valor: unknown): string {
  if (!valor) return new Date().toISOString();
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof Date) return valor.toISOString();
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().toISOString();
  }
  return String(valor);
}

function timestampParaMillis(valor: unknown): number | null {
  if (!valor) return null;
  if (valor instanceof Timestamp) return valor.toMillis();
  if (valor instanceof Date) return valor.getTime();
  if (typeof (valor as { toMillis?: unknown }).toMillis === 'function') {
    return (valor as { toMillis: () => number }).toMillis();
  }
  if (typeof valor === 'string') {
    const parsed = Date.parse(valor);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

function lerResultadoRecibo(dadosRecibo: Record<string, unknown>): ResultadoExpirarCiclos {
  const res = (dadosRecibo.resultado ?? {}) as Record<string, unknown>;
  return {
    sucesso: true,
    repetido: true,
    commandId: String(dadosRecibo.commandId ?? ''),
    totalVerificadas: Number(res.totalVerificadas ?? 0),
    totalExpiradas: Number(res.totalExpiradas ?? 0),
    expiradas: (res.expiradas ?? []) as DetalheParticipacaoExpirada[],
    processadoEm: iso(dadosRecibo.criadoEm ?? res.processadoEm),
  };
}

/**
 * Executa o processamento do job de expiração de ciclos com vigência vencida (AD-10 / AD-11).
 * Totalmente idempotente: reexecuções com o mesmo commandId retornam o recibo gravado,
 * a menos que o payload divirja (mesmo commandId com dados diferentes é recusado).
 */
export async function executarExpirarCiclosRepo(
  db: Firestore,
  entrada: EntradaExpirarCiclos,
): Promise<ResultadoExpirarCiclos> {
  const reciboRef = db.collection('commands').doc(entrada.commandId);

  // 1. Idempotência no nível do comando
  const reciboSnap = await reciboRef.get();
  if (reciboSnap.exists) {
    const dadosRecibo = reciboSnap.data() ?? {};
    if (
      typeof dadosRecibo.payloadHash === 'string' &&
      dadosRecibo.payloadHash !== entrada.payloadHash
    ) {
      throw new ComandoDivergenteError();
    }
    return lerResultadoRecibo({ ...dadosRecibo, commandId: entrada.commandId });
  }

  const agoraDate = entrada.agoraIso ? new Date(entrada.agoraIso) : new Date();
  const agoraMs = agoraDate.getTime();
  const agoraTs = Timestamp.fromDate(agoraDate);

  // 2. Busca participações ativas já vencidas, ordenadas pelo vencimento para
  // garantir que as mais antigas sejam atendidas primeiro (sem starvation).
  const limite = Math.min(entrada.limite ?? LIMITE_VERIFICACAO_PADRAO, LIMITE_MAXIMO_EXPIRACAO);
  const snapshotParticipacoes = await db
    .collection('participacoes')
    .where('estado', '==', 'ATIVA')
    .where('vigenciaFim', '<=', agoraTs)
    .orderBy('vigenciaFim')
    .limit(limite)
    .get();

  const participacoesCandidatas = snapshotParticipacoes.docs.filter((doc) => {
    const d = doc.data() ?? {};
    const fimMs = timestampParaMillis(d.vigenciaFim);
    return fimMs !== null && fimMs <= agoraMs;
  });

  // 2b. Dry-run: projeta o que seria expirado sem mutar estado nem gravar recibo.
  if (entrada.dryRun) {
    return {
      sucesso: true,
      repetido: false,
      commandId: entrada.commandId,
      totalVerificadas: participacoesCandidatas.length,
      totalExpiradas: 0,
      expiradas: participacoesCandidatas.map((doc) => {
        const d = doc.data() ?? {};
        return {
          participacaoId: doc.id,
          fichaId: String(d.fichaId ?? ''),
          equipeId: String(d.equipeId ?? ''),
          cicloId: d.cicloAtualId ? String(d.cicloAtualId) : null,
          fichaEstadoAnterior: '',
          fichaNovoEstado: '',
        };
      }),
      processadoEm: agoraDate.toISOString(),
    };
  }

  const expiradas: DetalheParticipacaoExpirada[] = [];
  const idsProcessados = new Set<string>();

  // 3. Processamento transacional individual para cada participação identificada
  for (const partDoc of participacoesCandidatas) {
    const partId = partDoc.id;

    const detalhe = await db.runTransaction(
      async (tx): Promise<DetalheParticipacaoExpirada | null> => {
        const partRef = db.collection('participacoes').doc(partId);
        const partSnap = await tx.get(partRef);
        if (!partSnap.exists) return null;

        const partData = partSnap.data() ?? {};
        // Invariante: se não estiver mais ATIVA ou vigenciaFim mudou, ignora
        if (partData.estado !== 'ATIVA') return null;
        const fimMs = timestampParaMillis(partData.vigenciaFim);
        if (fimMs === null || fimMs > agoraMs) return null;

        const fichaId = String(partData.fichaId ?? '');
        const equipeId = String(partData.equipeId ?? '');
        const cicloAtualId = String(partData.cicloAtualId ?? '');

        // Leitura da Ficha
        const fichaRef = db.collection('fichas').doc(fichaId);
        const fichaSnap = await tx.get(fichaRef);
        const fichaExiste = fichaSnap.exists;
        const fichaData = fichaExiste ? (fichaSnap.data() ?? {}) : {};
        const fichaEstadoAnterior = fichaExiste ? String(fichaData.estado ?? 'ATIVA') : 'DESCONHECIDO';

        // Leitura do Ciclo
        let cicloRef: DocumentReference | null = null;
        let cicloData: Record<string, unknown> | null = null;
        if (cicloAtualId) {
          const cRef = db.collection('ciclos').doc(cicloAtualId);
          const cSnap = await tx.get(cRef);
          if (cSnap.exists) {
            cicloRef = cRef;
            cicloData = cSnap.data() ?? {};
          }
        }

        // Leitura de todas as participações da mesma ficha (antes de qualquer escrita)
        const todasPartsSnap = await tx.get(
          db.collection('participacoes').where('fichaId', '==', fichaId),
        );

        // "Não continuar" encerra preservando `INATIVA`; caso contrário a
        // vigência vencida sem renovação marca `EXPIRADA` (AD-11).
        const naoContinuar = String(partData.intencaoRenovacao ?? '') === 'NAO_CONTINUAR';
        const novoEstadoParticipacao = naoContinuar ? 'INATIVA' : 'EXPIRADA';

        // Mutação da Participação
        const novaVersao = Number(partData.versao ?? 1) + 1;
        tx.update(partRef, {
          estado: novoEstadoParticipacao,
          proximaAcao: naoContinuar ? 'Encerrado ao término da vigência' : 'Vigência anual expirada',
          versao: novaVersao,
          expiradoEm: agoraTs,
          atualizadoEm: FieldValue.serverTimestamp(),
        });

        // Mutação do Ciclo
        if (cicloRef && cicloData) {
          if (!ESTADOS_TERMINAIS_CICLO.includes(String(cicloData.estado ?? ''))) {
            tx.update(cicloRef, {
              estado: 'EXPIRADA',
              expiradoEm: agoraTs,
              atualizadoEm: FieldValue.serverTimestamp(),
            });
          }
        }

        // Redução Canônica da Ficha (AD-11): só reduz fichas ATIVA e considera
        // participações pendentes e o tipo de encerramento (INATIVA vs EXPIRADA).
        const estadosFinais = todasPartsSnap.docs.map((d) =>
          d.id === partId ? novoEstadoParticipacao : String(d.data()?.estado ?? ''),
        );

        let fichaNovoEstado = fichaEstadoAnterior;
        if (fichaExiste && fichaEstadoAnterior === 'ATIVA') {
          if (estadosFinais.includes('ATIVA')) {
            fichaNovoEstado = 'ATIVA';
          } else if (estadosFinais.some((e) => ESTADOS_PENDENTES_PARTICIPACAO.includes(e))) {
            fichaNovoEstado = 'AGUARDANDO_COORDENADOR';
          } else if (estadosFinais.includes('INATIVA')) {
            fichaNovoEstado = 'INATIVA';
          } else {
            fichaNovoEstado = 'EXPIRADA';
          }

          if (fichaNovoEstado !== fichaEstadoAnterior) {
            tx.update(fichaRef, {
              estado: fichaNovoEstado,
              proximaAcao: PROXIMA_ACAO_FICHA[fichaNovoEstado] ?? 'Atualizado',
              atualizadoEm: FieldValue.serverTimestamp(),
            });
          }
        }

        // Evidência Imutável em evidenciasDecisao (AD-6 / AD-12)
        const subCommandId = `${entrada.commandId}_${partId}`;
        const evidenciaRef = db.collection('evidenciasDecisao').doc(subCommandId);
        tx.set(evidenciaRef, {
          commandId: subCommandId,
          correlationId: entrada.correlationId ?? entrada.commandId,
          tipo: 'EXPIRACAO_CICLO_ANUAL',
          participacaoId: partId,
          fichaId,
          equipeId,
          atorUid: 'SISTEMA_JOB_EXPIRACAO',
          papelAtor: 'SISTEMA',
          vigenciaFim: partData.vigenciaFim,
          mensagemExibida: naoContinuar
            ? 'Encerrado ao término da vigência'
            : 'Vigência anual expirada',
          timestamp: agoraTs,
        });

        // Evento em fichas/{fichaId}/eventos
        const eventoFichaRef = db.collection('fichas').doc(fichaId).collection('eventos').doc(subCommandId);
        tx.set(eventoFichaRef, {
          id: subCommandId,
          tipo: 'EXPIRACAO_CICLO_ANUAL',
          participacaoId: partId,
          equipeId,
          descricao: 'Vigência anual expirada pelo sistema',
          timestamp: agoraTs,
        });

        // Auditoria Append-Only no auditOutbox (AD-8 / AD-12: sem PII)
        const auditoriaRef = db.collection('auditOutbox').doc(subCommandId);
        tx.set(auditoriaRef, {
          commandId: subCommandId,
          correlationId: entrada.correlationId ?? entrada.commandId,
          ator: { uid: 'SISTEMA_JOB_EXPIRACAO', papel: 'SISTEMA' },
          acao: 'EXPIRAR_CICLO_ANUAL',
          entidades: {
            participacaoId: partId,
            fichaId,
            equipeId,
            cicloId: cicloAtualId || null,
          },
          antes: {
            estadoParticipacao: 'ATIVA',
            estadoFicha: fichaEstadoAnterior,
          },
          depois: {
            estadoParticipacao: novoEstadoParticipacao,
            estadoFicha: fichaNovoEstado,
          },
          criadoEm: FieldValue.serverTimestamp(),
        });

        return {
          participacaoId: partId,
          fichaId,
          equipeId,
          cicloId: cicloAtualId || null,
          fichaEstadoAnterior,
          fichaNovoEstado,
        };
      },
    );

    // Firestore pode reexecutar o callback em caso de contenção: só coleta uma vez.
    if (detalhe && !idsProcessados.has(detalhe.participacaoId)) {
      idsProcessados.add(detalhe.participacaoId);
      expiradas.push(detalhe);
    }
  }

  // 4. Gravação do Recibo Geral do Job em commands/{commandId} (AD-8 / AD-10)
  const resultado: ResultadoExpirarCiclos = {
    sucesso: true,
    repetido: false,
    commandId: entrada.commandId,
    totalVerificadas: participacoesCandidatas.length,
    totalExpiradas: expiradas.length,
    expiradas,
    processadoEm: agoraDate.toISOString(),
  };

  try {
    await reciboRef.create({
      commandId: entrada.commandId,
      tipo: 'EXPIRAR_CICLOS_VENCIDOS',
      estado: 'COMPLETO',
      payloadHash: entrada.payloadHash,
      resultado: {
        totalVerificadas: resultado.totalVerificadas,
        totalExpiradas: resultado.totalExpiradas,
        expiradas: resultado.expiradas,
        processadoEm: resultado.processadoEm,
      },
      criadoEm: FieldValue.serverTimestamp(),
    });
  } catch (erro) {
    // Execução concorrente registrou o recibo primeiro: devolve o persistido.
    const concorrenteSnap = await reciboRef.get();
    if (concorrenteSnap.exists) {
      return lerResultadoRecibo({
        ...(concorrenteSnap.data() ?? {}),
        commandId: entrada.commandId,
      });
    }
    throw erro;
  }

  return resultado;
}
