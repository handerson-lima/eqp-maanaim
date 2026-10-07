/**
 * Domínio de Retenção, Anonimização e Minimização de Dados (AD-12 / LGPD).
 *
 * Fonte única para:
 * 1. Validação, hash e idempotência da rotina de retenção.
 * 2. Política de elegibilidade de anonimização (ficha terminal) e expurgo (rascunho abandonado).
 * 3. Indicadores de conformidade expostos ao painel administrativo (somente contagens).
 *
 * Nenhuma rotina aqui altera estado de domínio por conta própria: o repositório
 * aplica as decisões exclusivamente em Cloud Function autenticada e transacional.
 */

import { createHash } from 'node:crypto';
import {
  ANOS_RETENCAO,
  CPF_MASCARADO,
  NOME_ANONIMIZADO,
  POLITICA_RETENCAO_ID,
} from './privacidade.js';

export class SolicitacaoRetencaoInvalidaError extends Error {
  constructor(message = 'Dados de solicitação inválidos.') {
    super(message);
    this.name = 'SolicitacaoRetencaoInvalidaError';
  }
}

/** Prazo padrão (dias) sem atualização para expurgo de rascunho abandonado. */
export const DIAS_RASCUNHO_PADRAO = 180;
export const DIAS_RASCUNHO_MINIMO = 30;
export const DIAS_RASCUNHO_MAXIMO = 730;

export const ESTADO_FICHA_RASCUNHO = 'RASCUNHO';
export const ESTADO_PARTICIPACAO_RASCUNHO = 'RASCUNHO';

/** Estados terminais de ficha candidatos à anonimização. */
export const ESTADOS_FICHA_TERMINAIS = [
  'INATIVA',
  'CANCELADA',
  'EXPIRADA',
  'REJEITADA',
] as const;

/** Estados de participação que impedem a anonimização (vínculo ativo ou pendente). */
export const ESTADOS_PARTICIPACAO_BLOQUEANTES = [
  'ATIVA',
  'RASCUNHO',
  'AGUARDANDO_PASTOR_LOCAL',
  'AGUARDANDO_RESPONSAVEL_EQUIPE',
  'AGUARDANDO_COORDENADOR',
  'EM_RENOVACAO',
] as const;

export type MotivoRetencao = 'SOLICITACAO_TITULAR' | 'ROTINA_AGENDADA' | 'EXECUCAO_MANUAL';

export const MOTIVOS_RETENCAO: readonly MotivoRetencao[] = [
  'SOLICITACAO_TITULAR',
  'ROTINA_AGENDADA',
  'EXECUCAO_MANUAL',
];

export const ACAO_ANONIMIZAR_FICHA = 'ANONIMIZAR_FICHA';
export const ACAO_EXPURGAR_RASCUNHO = 'EXPURGAR_RASCUNHO';

export interface EntradaExecutarRetencao {
  commandId: string;
  correlationId?: string;
  motivo: MotivoRetencao;
  dryRun: boolean;
  limite: number;
  agoraIso?: string;
  /** Ator autenticado (preenchido pela Cloud Function, não pelo cliente). */
  atorUid?: string;
  payloadHash: string;
}

export interface ItemRetencao {
  fichaId: string;
  estado: string;
  acao: 'ANONIMIZAR' | 'EXPURGAR';
  motivo: MotivoRetencao;
  retencaoAte?: string;
}

export interface ResultadoExecutarRetencao {
  sucesso: boolean;
  repetido: boolean;
  commandId: string;
  dryRun: boolean;
  politicaId: string;
  totalAnalisadas: number;
  totalAnonimizadas: number;
  totalExpurgadas: number;
  ignoradas: number;
  itens: ItemRetencao[];
  processadoEm: string;
}

export interface IndicadoresConformidadeRetencao {
  politicaId: string;
  anosRetencao: number;
  diasRascunho: number;
  expurgoAutomaticoHabilitado: boolean;
  totalFichas: number;
  fichasAnonimizadas: number;
  fichasAtivas: number;
  fichasElegiveisAnonimizacao: number;
  rascunhosElegiveisExpurgo: number;
  porEstado: Record<string, number>;
  geradoEm: string;
}

/**
 * Hash determinístico do payload lógico da rotina (idempotência estrita, AD-10).
 */
export function calcularPayloadHashRetencao(dados: {
  commandId: string;
  motivo: MotivoRetencao;
  limite: number;
}): string {
  return createHash('sha256')
    .update(
      JSON.stringify({
        commandId: dados.commandId.trim(),
        motivo: dados.motivo,
        limite: dados.limite,
      }),
    )
    .digest('hex');
}

export function ehMotivoRetencao(valor: unknown): valor is MotivoRetencao {
  return typeof valor === 'string' && (MOTIVOS_RETENCAO as readonly string[]).includes(valor);
}

/**
 * Valida e normaliza a entrada da callable/job de retenção.
 * `dryRun` é `true` por padrão (simulação segura).
 */
export function validarRotinaRetencao(dados: unknown): EntradaExecutarRetencao {
  if (!dados || typeof dados !== 'object') {
    throw new SolicitacaoRetencaoInvalidaError('Corpo da requisição inválido.');
  }

  const payload = dados as Record<string, unknown>;

  const commandId = typeof payload.commandId === 'string' ? payload.commandId.trim() : '';
  if (!/^[A-Za-z0-9_-]{8,160}$/.test(commandId)) {
    throw new SolicitacaoRetencaoInvalidaError(
      'commandId é obrigatório e deve conter apenas letras, números, "_" ou "-" (8 a 160 caracteres).',
    );
  }

  const motivoBruto = payload.motivo ?? 'EXECUCAO_MANUAL';
  if (!ehMotivoRetencao(motivoBruto)) {
    throw new SolicitacaoRetencaoInvalidaError('motivo de retenção inválido.');
  }

  const agoraIso = typeof payload.agoraIso === 'string' ? payload.agoraIso.trim() : undefined;
  if (agoraIso !== undefined && agoraIso !== '' && Number.isNaN(Date.parse(agoraIso))) {
    throw new SolicitacaoRetencaoInvalidaError('agoraIso inválido.');
  }

  let limite = 100;
  if (payload.limite !== undefined) {
    const parsed = Number(payload.limite);
    if (!Number.isInteger(parsed) || parsed < 1 || parsed > 200) {
      throw new SolicitacaoRetencaoInvalidaError(
        'O parâmetro limite deve ser um número inteiro entre 1 e 200.',
      );
    }
    limite = parsed;
  }

  const dryRun = payload.dryRun === undefined ? true : Boolean(payload.dryRun);

  return {
    commandId,
    correlationId:
      typeof payload.correlationId === 'string' ? payload.correlationId.trim() : undefined,
    motivo: motivoBruto,
    dryRun,
    limite,
    agoraIso,
    payloadHash: calcularPayloadHashRetencao({
      commandId,
      motivo: motivoBruto,
      limite,
    }),
  };
}

/** Normaliza `diasRascunho` para o intervalo permitido (30–730). */
export function normalizarDiasRascunho(valor: unknown): number {
  const parsed = Number(valor);
  if (!Number.isFinite(parsed) || parsed < DIAS_RASCUNHO_MINIMO || parsed > DIAS_RASCUNHO_MAXIMO) {
    return DIAS_RASCUNHO_PADRAO;
  }
  return Math.trunc(parsed);
}

/** Converte timestamp heterogêneo (Firestore/Date/ISO/número) em milissegundos ou null. */
export function timestampParaMillis(valor: unknown): number | null {
  if (valor === null || valor === undefined) return null;
  if (valor instanceof Date) return valor.getTime();
  if (typeof valor === 'number') return valor;
  if (typeof valor === 'string') {
    const parsed = Date.parse(valor);
    return Number.isNaN(parsed) ? null : parsed;
  }
  const comMillis = valor as { toMillis?: () => number };
  if (typeof comMillis.toMillis === 'function') return comMillis.toMillis();
  const comDate = valor as { toDate?: () => Date };
  if (typeof comDate.toDate === 'function') return comDate.toDate().getTime();
  return null;
}

/** Participação bloqueia a anonimização se estiver ativa, pendente ou em renovação. */
export function participacaoBloqueiaAnonimizacao(estado: unknown): boolean {
  return (ESTADOS_PARTICIPACAO_BLOQUEANTES as readonly string[]).includes(
    String(estado ?? '').toUpperCase(),
  );
}

export interface FichaParcialRetencao {
  estado?: unknown;
  atualizadoEm?: unknown;
  termoAceito?: unknown;
  anonimizadaEm?: unknown;
}

export interface DecisaoElegibilidade {
  elegivel: boolean;
  motivoExclusao?: string;
  retencaoAte?: string;
}

/**
 * Ficha é elegível à anonimização quando:
 * - não está já anonimizada;
 * - está em estado terminal;
 * - não possui participação ativa/pendente;
 * - e (já passaram 5 anos desde `atualizadoEm` OU motivo = SOLICITACAO_TITULAR).
 */
export function fichaElegivelParaAnonimizacao(
  ficha: FichaParcialRetencao | null | undefined,
  participacoes: ReadonlyArray<{ estado?: unknown }>,
  opcoes: { agoraMs: number; motivo: MotivoRetencao; anosRetencao?: number },
): DecisaoElegibilidade {
  if (!ficha) return { elegivel: false, motivoExclusao: 'FICHA_INEXISTENTE' };
  if (ficha.anonimizadaEm) return { elegivel: false, motivoExclusao: 'JA_ANONIMIZADA' };

  const estado = String(ficha.estado ?? '').toUpperCase();
  if (!(ESTADOS_FICHA_TERMINAIS as readonly string[]).includes(estado)) {
    return { elegivel: false, motivoExclusao: 'ESTADO_NAO_TERMINAL' };
  }

  if (participacoes.some((p) => participacaoBloqueiaAnonimizacao(p?.estado))) {
    return { elegivel: false, motivoExclusao: 'PARTICIPACAO_ATIVA_OU_PENDENTE' };
  }

  const anos = opcoes.anosRetencao ?? ANOS_RETENCAO;
  const atualizadoMs = timestampParaMillis(ficha.atualizadoEm);
  if (atualizadoMs === null) {
    return { elegivel: false, motivoExclusao: 'SEM_DATA_ATUALIZACAO' };
  }

  const retencaoAte = new Date(atualizadoMs);
  retencaoAte.setUTCFullYear(retencaoAte.getUTCFullYear() + anos);

  if (opcoes.motivo !== 'SOLICITACAO_TITULAR' && opcoes.agoraMs < retencaoAte.getTime()) {
    return { elegivel: false, motivoExclusao: 'RETENCAO_VIGENTE' };
  }

  return { elegivel: true, retencaoAte: retencaoAte.toISOString() };
}

/**
 * Rascunho é elegível ao expurgo quando:
 * - está em `RASCUNHO`;
 * - não possui `termoAceito`;
 * - todas as participações estão em `RASCUNHO`;
 * - e não é atualizado há pelo menos `diasRascunho` dias.
 */
export function fichaElegivelParaExpurgo(
  ficha: FichaParcialRetencao | null | undefined,
  participacoes: ReadonlyArray<{ estado?: unknown }>,
  opcoes: { agoraMs: number; diasRascunho: number },
): DecisaoElegibilidade {
  if (!ficha) return { elegivel: false, motivoExclusao: 'FICHA_INEXISTENTE' };

  const estado = String(ficha.estado ?? '').toUpperCase();
  if (estado !== ESTADO_FICHA_RASCUNHO) {
    return { elegivel: false, motivoExclusao: 'ESTADO_NAO_RASCUNHO' };
  }

  if (ficha.termoAceito) {
    return { elegivel: false, motivoExclusao: 'TERMO_ACEITO' };
  }

  if (
    participacoes.some(
      (p) => String(p?.estado ?? '').toUpperCase() !== ESTADO_PARTICIPACAO_RASCUNHO,
    )
  ) {
    return { elegivel: false, motivoExclusao: 'PARTICIPACAO_AVANCADA' };
  }

  const atualizadoMs = timestampParaMillis(ficha.atualizadoEm);
  if (atualizadoMs === null) {
    return { elegivel: false, motivoExclusao: 'SEM_DATA_ATUALIZACAO' };
  }

  const limiteMs = atualizadoMs + opcoes.diasRascunho * 24 * 60 * 60 * 1000;
  if (opcoes.agoraMs < limiteMs) {
    return { elegivel: false, motivoExclusao: 'DENTRO_DO_PRAZO' };
  }

  return { elegivel: true, retencaoAte: new Date(limiteMs).toISOString() };
}

/** Valores canônicos mascarados aplicados à ficha na anonimização (AD-12). */
export function valoresAnonimizacao(): {
  nomeCompleto: string;
  cpf: string;
  profissao: string;
} {
  return {
    nomeCompleto: NOME_ANONIMIZADO,
    cpf: CPF_MASCARADO,
    profissao: '',
  };
}

/**
 * Indicadores de conformidade expostos ao painel (somente contagens, nunca IDs).
 */
export function calcularIndicadoresConformidade(
  fichas: ReadonlyArray<FichaParcialRetencao>,
  participantesPorFicha: ReadonlyArray<ReadonlyArray<{ estado?: unknown }>>,
  opcoes: {
    agoraMs: number;
    diasRascunho: number;
    expurgoAutomaticoHabilitado: boolean;
  },
): IndicadoresConformidadeRetencao {
  const porEstado: Record<string, number> = {};
  let anonimizadas = 0;
  let ativas = 0;
  let elegiveisAnonimizacao = 0;
  let rascunhosElegiveisExpurgo = 0;

  fichas.forEach((ficha, indice) => {
    const estado = String(ficha.estado ?? 'DESCONHECIDO').toUpperCase();
    porEstado[estado] = (porEstado[estado] ?? 0) + 1;
    if (ficha.anonimizadaEm) anonimizadas += 1;
    if (estado === 'ATIVA') ativas += 1;

    const participacoes = participantesPorFicha[indice] ?? [];
    if (
      fichaElegivelParaAnonimizacao(ficha, participacoes, {
        agoraMs: opcoes.agoraMs,
        motivo: 'ROTINA_AGENDADA',
      }).elegivel
    ) {
      elegiveisAnonimizacao += 1;
    }
    if (
      fichaElegivelParaExpurgo(ficha, participacoes, {
        agoraMs: opcoes.agoraMs,
        diasRascunho: opcoes.diasRascunho,
      }).elegivel
    ) {
      rascunhosElegiveisExpurgo += 1;
    }
  });

  return {
    politicaId: POLITICA_RETENCAO_ID,
    anosRetencao: ANOS_RETENCAO,
    diasRascunho: opcoes.diasRascunho,
    expurgoAutomaticoHabilitado: opcoes.expurgoAutomaticoHabilitado,
    totalFichas: fichas.length,
    fichasAnonimizadas: anonimizadas,
    fichasAtivas: ativas,
    fichasElegiveisAnonimizacao: elegiveisAnonimizacao,
    rascunhosElegiveisExpurgo: rascunhosElegiveisExpurgo,
    porEstado,
    geradoEm: new Date(opcoes.agoraMs).toISOString(),
  };
}
