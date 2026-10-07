/**
 * Repositório da rotina autorizada de retenção, anonimização e expurgo (AD-12 / LGPD).
 *
 * Garantias:
 * - Mutação exclusiva em Cloud Function autenticada; Firestore/Storage negam escrita direta.
 * - `dryRun` nunca grava (nem recibo, nem auditoria).
 * - Cada ficha é processada em transação própria (≤500 operações) com recibo + `auditOutbox`.
 * - Idempotência por `commandId` + `payloadHash` (repetir é no-op).
 * - Auditoria do procedimento sem PII: IDs opacos, estado, motivo categorizado e política.
 */

import {
  FieldValue,
  Timestamp,
  type Firestore,
} from 'firebase-admin/firestore';
import { ComandoDivergenteError } from '../domain/ficha.js';
import { POLITICA_RETENCAO_ID } from '../domain/privacidade.js';
import {
  ACAO_ANONIMIZAR_FICHA,
  ACAO_EXPURGAR_RASCUNHO,
  DIAS_RASCUNHO_PADRAO,
  ESTADOS_FICHA_TERMINAIS,
  calcularIndicadoresConformidade,
  fichaElegivelParaAnonimizacao,
  fichaElegivelParaExpurgo,
  normalizarDiasRascunho,
  timestampParaMillis,
  valoresAnonimizacao,
  type EntradaExecutarRetencao,
  type IndicadoresConformidadeRetencao,
  type ItemRetencao,
  type ResultadoExecutarRetencao,
} from '../domain/retencao.js';

export const COLECAO_CONFIGURACOES = 'configuracoes';
export const DOC_CONFIG_RETENCAO = 'retencao';

/** Teto defensivo de fichas analisadas por execução. */
const LIMITE_MAXIMO_ANALISE = 500;

export interface ConfiguracaoRetencao {
  diasRascunho: number;
  expurgoAutomaticoHabilitado: boolean;
}

/**
 * Lê a configuração operacional de retenção. Quando o documento não existe,
 * usa os padrões seguros (180 dias; expurgo automático desabilitado). Falhas
 * de leitura são propagadas: um erro transitório não pode rebaixar o prazo
 * configurado (30–730 dias) e expurgar rascunhos antes do tempo.
 */
export async function obterConfiguracaoRetencao(db: Firestore): Promise<ConfiguracaoRetencao> {
  const snap = await db.collection(COLECAO_CONFIGURACOES).doc(DOC_CONFIG_RETENCAO).get();
  if (!snap.exists) {
    return { diasRascunho: DIAS_RASCUNHO_PADRAO, expurgoAutomaticoHabilitado: false };
  }
  const dados = snap.data() ?? {};
  return {
    diasRascunho: normalizarDiasRascunho(dados.diasRascunho),
    expurgoAutomaticoHabilitado: dados.expurgoAutomaticoHabilitado === true,
  };
}

function iso(valor: unknown): string {
  if (!valor) return new Date().toISOString();
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof Date) return valor.toISOString();
  if (typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate().toISOString();
  }
  if (typeof valor === 'string') return valor;
  return new Date().toISOString();
}

function lerResultadoRecibo(dadosRecibo: Record<string, unknown>): ResultadoExecutarRetencao {
  const res = (dadosRecibo.resultado ?? {}) as Record<string, unknown>;
  return {
    sucesso: true,
    repetido: true,
    commandId: String(dadosRecibo.commandId ?? ''),
    dryRun: Boolean(res.dryRun),
    politicaId: String(res.politicaId ?? POLITICA_RETENCAO_ID),
    totalAnalisadas: Number(res.totalAnalisadas ?? 0),
    totalAnonimizadas: Number(res.totalAnonimizadas ?? 0),
    totalExpurgadas: Number(res.totalExpurgadas ?? 0),
    ignoradas: Number(res.ignoradas ?? 0),
    itens: (res.itens ?? []) as ItemRetencao[],
    processadoEm: iso(res.processadoEm ?? dadosRecibo.criadoEm),
  };
}

function reciboDeItem(
  commandIdItem: string,
  acao: string,
  fichaId: string,
  payloadHash: string,
  item: ItemRetencao,
): Record<string, unknown> {
  return {
    commandId: commandIdItem,
    tipo: acao,
    estado: 'COMPLETO',
    status: 'COMPLETO',
    fichaId,
    payloadHash,
    resultado: item,
    criadoEm: FieldValue.serverTimestamp(),
  };
}

function entradaAuditoria(
  commandIdItem: string,
  correlationId: string,
  atorUid: string,
  acao: string,
  fichaId: string,
  estado: string,
  motivo: string,
  retencaoAte?: string,
): Record<string, unknown> {
  const anonimizacao = acao === ACAO_ANONIMIZAR_FICHA;
  return {
    commandId: commandIdItem,
    correlationId,
    atorUid,
    actorUid: atorUid,
    acao,
    action: acao,
    entidades: [{ tipo: 'FICHA', id: fichaId }],
    fichaId,
    estado,
    motivo,
    politica: POLITICA_RETENCAO_ID,
    ...(retencaoAte ? { retencaoAte } : {}),
    antes: { estado },
    depois: anonimizacao
      ? { estado, anonimizada: true }
      : { estado: 'EXPURGADO', expurgada: true },
    // `metadados` é o único campo arbitrário propagado à auditoria imutável:
    // aqui carrega estado, motivo e política — nunca PII.
    metadados: {
      estado,
      motivo,
      politica: POLITICA_RETENCAO_ID,
      ...(retencaoAte ? { retencaoAte } : {}),
    },
    criadoEm: FieldValue.serverTimestamp(),
  };
}

async function lerParticipacoes(
  db: Firestore,
  fichaId: string,
): Promise<Array<{ id: string; ref: unknown; data: Record<string, unknown> }>> {
  const snap = await db
    .collection('participacoes')
    .where('fichaId', '==', fichaId)
    .limit(200)
    .get();
  return snap.docs.map((doc) => ({
    id: doc.id,
    ref: doc.ref,
    data: (doc.data() ?? {}) as Record<string, unknown>,
  }));
}

/**
 * Executa a rotina de retenção: expurga rascunhos abandonados e anonimiza fichas
 * terminais elegíveis. Idempotente por `commandId`; `dryRun` apenas projeta.
 */
export async function executarRotinaRetencaoRepo(
  db: Firestore,
  entrada: EntradaExecutarRetencao,
): Promise<ResultadoExecutarRetencao> {
  const reciboRef = db.collection('commands').doc(entrada.commandId);

  // 1. Idempotência no nível do comando (repetir é no-op).
  const reciboSnap = await reciboRef.get();
  if (reciboSnap.exists) {
    const dadosRecibo = reciboSnap.data() ?? {};
    // Ausência de `payloadHash` indica recibo legado/estranho: trata como divergente
    // em vez de reportar "já processado" para um comando não relacionado.
    if (dadosRecibo.payloadHash !== entrada.payloadHash) {
      throw new ComandoDivergenteError();
    }
    return lerResultadoRecibo({ ...dadosRecibo, commandId: entrada.commandId });
  }

  const agoraDate = entrada.agoraIso ? new Date(entrada.agoraIso) : new Date();
  const agoraMs = agoraDate.getTime();
  const agoraTs = Timestamp.fromDate(agoraDate);
  const atorUid = entrada.atorUid ?? 'SISTEMA_ROTINA_RETENCAO';
  const correlationId = entrada.correlationId ?? entrada.commandId;

  const configuracao = await obterConfiguracaoRetencao(db);
  const limite = Math.min(entrada.limite, LIMITE_MAXIMO_ANALISE);

  // 2. Levanta candidatos: rascunhos abandonados + fichas terminais (se aplicável).
  const incluirAnonimizacao = !entrada.somenteExpurgo;
  const [snapRascunhos, snapTerminais] = await Promise.all([
    db
      .collection('fichas')
      .where('estado', '==', 'RASCUNHO')
      .orderBy('atualizadoEm', 'asc')
      .limit(limite)
      .get(),
    incluirAnonimizacao
      ? db
          .collection('fichas')
          .where('estado', 'in', [...ESTADOS_FICHA_TERMINAIS])
          .orderBy('atualizadoEm', 'asc')
          .limit(limite)
          .get()
      : Promise.resolve({ docs: [] as Array<{ id: string; data: () => unknown }> }),
  ]);

  const candidatos = new Map<string, { data: Record<string, unknown> }>();
  for (const doc of [...snapRascunhos.docs, ...snapTerminais.docs]) {
    candidatos.set(doc.id, { data: (doc.data() ?? {}) as Record<string, unknown> });
  }

  // 3. Avalia elegibilidade (com leitura das participações de cada ficha).
  const itens: ItemRetencao[] = [];
  let ignoradas = 0;
  let totalAnonimizadas = 0;
  let totalExpurgadas = 0;

  for (const [fichaId, { data }] of candidatos) {
    const participacoes = await lerParticipacoes(db, fichaId);
    const participacoesView = participacoes.map((p) => ({ estado: p.data.estado }));

    if (incluirAnonimizacao) {
      const anonimizacao = fichaElegivelParaAnonimizacao(data, participacoesView, {
        agoraMs,
        motivo: entrada.motivo,
      });
      if (anonimizacao.elegivel) {
        itens.push({
          fichaId,
          estado: String(data.estado ?? ''),
          acao: 'ANONIMIZAR',
          motivo: entrada.motivo,
          retencaoAte: anonimizacao.retencaoAte,
        });
        totalAnonimizadas += 1;
        continue;
      }
    }

    const expurgo = fichaElegivelParaExpurgo(data, participacoesView, {
      agoraMs,
      diasRascunho: configuracao.diasRascunho,
    });
    if (expurgo.elegivel) {
      itens.push({
        fichaId,
        estado: String(data.estado ?? ''),
        acao: 'EXPURGAR',
        motivo: entrada.motivo,
      });
      totalExpurgadas += 1;
      continue;
    }

    ignoradas += 1;
  }

  // 4. Simulação: projeta contagens/IDs sem gravar absolutamente nada.
  if (entrada.dryRun) {
    return {
      sucesso: true,
      repetido: false,
      commandId: entrada.commandId,
      dryRun: true,
      politicaId: POLITICA_RETENCAO_ID,
      totalAnalisadas: candidatos.size,
      totalAnonimizadas,
      totalExpurgadas,
      ignoradas,
      itens,
      processadoEm: agoraDate.toISOString(),
    };
  }

  // 5. Execução: cada ficha em transação própria com recibo + auditOutbox.
  const itensExecutados: ItemRetencao[] = [];
  const idsProcessados = new Set<string>();

  for (const item of itens) {
    const fichaId = item.fichaId;
    const commandIdItem = `${entrada.commandId}__${fichaId}`;
    const fichaRef = db.collection('fichas').doc(fichaId);

    const executado = await db.runTransaction(async (tx) => {
      const fichaSnap = await tx.get(fichaRef);
      if (!fichaSnap.exists) return false;
      const data = (fichaSnap.data() ?? {}) as Record<string, unknown>;

      const refsParticipacoes = await tx.get(
        db.collection('participacoes').where('fichaId', '==', fichaId),
      );
      const participacoes = refsParticipacoes.docs.map((doc) => ({
        id: doc.id,
        ref: doc.ref,
        data: (doc.data() ?? {}) as Record<string, unknown>,
      }));
      const participacoesView = participacoes.map((p) => ({ estado: p.data.estado }));

      if (item.acao === 'ANONIMIZAR') {
        const decisao = fichaElegivelParaAnonimizacao(data, participacoesView, {
          agoraMs,
          motivo: entrada.motivo,
        });
        if (!decisao.elegivel) return false;

        const mascara = valoresAnonimizacao();
        tx.update(fichaRef, {
          ...mascara,
          anonimizadaEm: agoraTs,
          anonimizadaPor: atorUid,
          atualizadoEm: agoraTs,
          versao: Number(data.versao ?? 1) + 1,
        });

        const auditoriaRef = db.collection('auditOutbox').doc(commandIdItem);
        tx.set(
          auditoriaRef,
          entradaAuditoria(
            commandIdItem,
            correlationId,
            atorUid,
            ACAO_ANONIMIZAR_FICHA,
            fichaId,
            String(data.estado ?? ''),
            entrada.motivo,
            decisao.retencaoAte,
          ),
        );
        tx.set(
          db.collection('commands').doc(commandIdItem),
          reciboDeItem(commandIdItem, ACAO_ANONIMIZAR_FICHA, fichaId, entrada.payloadHash, item),
        );
        return true;
      }

      // EXPURGAR: apenas rascunho sem aceite e com todas as participações RASCUNHO.
      const decisao = fichaElegivelParaExpurgo(data, participacoesView, {
        agoraMs,
        diasRascunho: configuracao.diasRascunho,
      });
      if (!decisao.elegivel) return false;

      for (const participacao of participacoes) {
        if (String(participacao.data.estado ?? '').toUpperCase() === 'RASCUNHO') {
          tx.delete(participacao.ref as Parameters<typeof tx.delete>[0]);
        }
      }
      tx.delete(fichaRef);

      const auditoriaRef = db.collection('auditOutbox').doc(commandIdItem);
      tx.set(
        auditoriaRef,
        entradaAuditoria(
          commandIdItem,
          correlationId,
          atorUid,
          ACAO_EXPURGAR_RASCUNHO,
          fichaId,
          String(data.estado ?? 'RASCUNHO'),
          entrada.motivo,
        ),
      );
      tx.set(
        db.collection('commands').doc(commandIdItem),
        reciboDeItem(commandIdItem, ACAO_EXPURGAR_RASCUNHO, fichaId, entrada.payloadHash, item),
      );
      return true;
    });

    if (executado && !idsProcessados.has(fichaId)) {
      idsProcessados.add(fichaId);
      itensExecutados.push(item);
    }
  }

  const resultado: ResultadoExecutarRetencao = {
    sucesso: true,
    repetido: false,
    commandId: entrada.commandId,
    dryRun: false,
    politicaId: POLITICA_RETENCAO_ID,
    totalAnalisadas: candidatos.size,
    totalAnonimizadas: itensExecutados.filter((i) => i.acao === 'ANONIMIZAR').length,
    totalExpurgadas: itensExecutados.filter((i) => i.acao === 'EXPURGAR').length,
    ignoradas,
    itens: itensExecutados,
    processadoEm: agoraDate.toISOString(),
  };

  try {
    await reciboRef.create({
      commandId: entrada.commandId,
      tipo: 'ROTINA_RETENCAO',
      estado: 'COMPLETO',
      status: 'COMPLETO',
      politicaId: POLITICA_RETENCAO_ID,
      payloadHash: entrada.payloadHash,
      resultado: {
        dryRun: false,
        politicaId: POLITICA_RETENCAO_ID,
        totalAnalisadas: resultado.totalAnalisadas,
        totalAnonimizadas: resultado.totalAnonimizadas,
        totalExpurgadas: resultado.totalExpurgadas,
        ignoradas: resultado.ignoradas,
        itens: resultado.itens,
        processadoEm: resultado.processadoEm,
      },
      criadoEm: FieldValue.serverTimestamp(),
    });
  } catch (erro) {
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

/**
 * Indicadores de conformidade de retenção (somente contagens; nunca IDs de voluntários).
 */
export async function consultarConformidadeRetencaoRepo(
  db: Firestore,
  opcoes: { agoraIso?: string } = {},
): Promise<IndicadoresConformidadeRetencao> {
  const agoraMs = opcoes.agoraIso ? Date.parse(opcoes.agoraIso) : Date.now();
  const configuracao = await obterConfiguracaoRetencao(db);

  const snapFichas = await db.collection('fichas').limit(LIMITE_MAXIMO_ANALISE).get();
  const fichas = snapFichas.docs.map((doc) => (doc.data() ?? {}) as Record<string, unknown>);

  const participantesPorFicha: Array<Array<{ estado?: unknown }>> = [];
  for (const doc of snapFichas.docs) {
    const snapParts = await db
      .collection('participacoes')
      .where('fichaId', '==', doc.id)
      .limit(200)
      .get();
    participantesPorFicha.push(
      snapParts.docs.map((p) => ({ estado: (p.data() ?? {}).estado })),
    );
  }

  return calcularIndicadoresConformidade(fichas, participantesPorFicha, {
    agoraMs,
    diasRascunho: configuracao.diasRascunho,
    expurgoAutomaticoHabilitado: configuracao.expurgoAutomaticoHabilitado,
  });
}
