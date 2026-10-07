/**
 * Domínio de Auditoria Imutável, Outbox e Reconciliação (AD-8, AD-9, AD-10 e AD-12).
 *
 * Invariantes essenciais:
 * 1. Auditoria é append-only e materializada a partir da fila transacional `auditOutbox`.
 * 2. Estritamente SEM PII (sem CPF em texto claro, sem documentos e sem segredos/tokens).
 * 3. O consumidor de outbox é 100% idempotente (chave única = commandId).
 * 4. A materialização de auditoria NUNCA altera o estado do domínio de negócio.
 * 5. Toda operação de mutação crítica deve caber no orçamento transacional do Firestore (limite de 500 escritas).
 */

import { calcularRetencaoAte, sanitizarPii } from './privacidade.js';

export interface EntidadeReferenciada {
  tipo: string;
  id: string;
}

export interface EntradaAuditOutbox {
  commandId: string;
  correlationId?: string;
  atorUid?: string;
  actorUid?: string;
  acao?: string;
  action?: string;
  entidades?: EntidadeReferenciada[];
  antes?: Record<string, unknown> | null;
  depois?: Record<string, unknown> | null;
  metadados?: Record<string, unknown> | null;
  timestamp?: unknown;
  criadoEm?: unknown;
  processado?: boolean;
  processadoEm?: unknown;
  tentativas?: number;
  erro?: string | null;
  ultimaTentativaEm?: unknown;
}

export interface RegistroAuditoria {
  id: string; // commandId canônico
  commandId: string;
  correlationId: string;
  atorUid: string;
  acao: string;
  entidades: EntidadeReferenciada[];
  antes?: Record<string, unknown> | null;
  depois?: Record<string, unknown> | null;
  metadados?: Record<string, unknown> | null;
  timestampOriginal: unknown;
  materializadoEm: unknown;
  versaoSchema: number;
  sanitizado: boolean;
  /** Fim da retenção probatória (criação + 5 anos, UTC) — AD-12. */
  retencaoAte: string;
}

export type TipoAlertaOperacional =
  | 'OUTBOX_FALHA_PROCESSAMENTO'
  | 'COMANDO_ORFAO_SEM_OUTBOX'
  | 'AUDITORIA_INCONSISTENTE'
  | 'ORCAMENTO_TRANSACIONAL_EXCEDIDO';

export type SeveridadeAlerta = 'BAIXA' | 'MEDIA' | 'ALTA' | 'CRITICA';

export interface AlertaOperacional {
  id: string;
  tipo: TipoAlertaOperacional;
  severidade: SeveridadeAlerta;
  commandId?: string;
  motivo: string;
  detalhes?: Record<string, unknown>;
  criadoEm: unknown;
  resolvido: boolean;
}

export interface ResultadoProcessamentoOutbox {
  sucesso: boolean;
  commandId: string;
  jaProcessado: boolean;
  erro?: string;
}

export interface ResultadoReconciliacao {
  pendentesEncontrados: number;
  reconciliados: number;
  falhas: number;
  alertasEmitidos: number;
  commandIdsProcessados: string[];
  commandIdsComFalha: string[];
}

export class SolicitacaoReconciliacaoInvalidaError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SolicitacaoReconciliacaoInvalidaError';
  }
}

/**
 * Limites transacionais do Cloud Firestore.
 */
export const LIMITE_MAXIMO_OPERACOES_TRANSACAO_FIRESTORE = 500;
export const LIMITE_MAXIMO_BYTES_TRANSACAO_FIRESTORE = 10 * 1024 * 1024; // 10MB

/**
 * Valida o orçamento transacional antes de executar o commit lógico (AD-8).
 */
export function validarOrcamentoTransacional(
  numOperacoes: number,
  tamanhoEstimadoBytes = 0,
): { valido: boolean; motivo?: string } {
  if (numOperacoes <= 0) {
    return { valido: false, motivo: 'Número de operações transacionais deve ser maior que zero.' };
  }
  if (numOperacoes > LIMITE_MAXIMO_OPERACOES_TRANSACAO_FIRESTORE) {
    return {
      valido: false,
      motivo: `Orçamento transacional excedido: ${numOperacoes} operações excede o limite máximo de ${LIMITE_MAXIMO_OPERACOES_TRANSACAO_FIRESTORE}.`,
    };
  }
  if (tamanhoEstimadoBytes > LIMITE_MAXIMO_BYTES_TRANSACAO_FIRESTORE) {
    return {
      valido: false,
      motivo: `Tamanho estimado da transação (${tamanhoEstimadoBytes} bytes) excede o limite de ${LIMITE_MAXIMO_BYTES_TRANSACAO_FIRESTORE} bytes.`,
    };
  }
  return { valido: true };
}

/**
 * Sanitiza recursivamente qualquer payload destinado à coleção imutável `auditoria` (AD-8/AD-12).
 * Delega ao sanitizador canônico: remove PII/segredos por chave e mascara CPF, e-mail e telefone.
 */
export function sanitizarDadoAuditoria(valor: unknown): unknown {
  return sanitizarPii(valor);
}

/**
 * Monta o registro canônico imutável de auditoria a partir de uma entrada da outbox.
 */
export function montarRegistroAuditoriaImutavel(
  entrada: EntradaAuditOutbox,
  materializadoEm: unknown,
): RegistroAuditoria {
  const commandId = String(entrada.commandId).trim();
  const correlationId = String(entrada.correlationId ?? entrada.commandId).trim();
  const atorUid = String(entrada.atorUid ?? entrada.actorUid ?? 'SISTEMA').trim();
  const acao = String(entrada.acao ?? entrada.action ?? 'ACAO_DESCONHECIDA').trim();

  const entidades: EntidadeReferenciada[] = Array.isArray(entrada.entidades)
    ? entrada.entidades.map((e) => ({
        tipo: String(e?.tipo ?? '').toUpperCase(),
        id: String(e?.id ?? ''),
      }))
    : [];

  const antesSanitizado = entrada.antes ? (sanitizarDadoAuditoria(entrada.antes) as Record<string, unknown>) : null;
  const depoisSanitizado = entrada.depois ? (sanitizarDadoAuditoria(entrada.depois) as Record<string, unknown>) : null;
  const metadadosSanitizados = entrada.metadados ? (sanitizarDadoAuditoria(entrada.metadados) as Record<string, unknown>) : null;

  return {
    id: commandId,
    commandId,
    correlationId,
    atorUid,
    acao,
    entidades,
    antes: antesSanitizado,
    depois: depoisSanitizado,
    metadados: metadadosSanitizados,
    timestampOriginal: entrada.timestamp ?? entrada.criadoEm ?? materializadoEm,
    materializadoEm,
    versaoSchema: 1,
    sanitizado: true,
    retencaoAte: calcularRetencaoAte(new Date()),
  };
}

/**
 * Validação de parâmetros para a callable/job de reconciliação de auditoria.
 */
export function validarParametrosReconciliacao(dados: unknown): { limite: number } {
  if (dados === null || dados === undefined || typeof dados !== 'object') {
    return { limite: 50 };
  }

  const payload = dados as Record<string, unknown>;
  let limite = 50;

  if (payload.limite !== undefined) {
    const parsed = Number(payload.limite);
    if (isNaN(parsed) || !Number.isInteger(parsed) || parsed < 1 || parsed > 200) {
      throw new SolicitacaoReconciliacaoInvalidaError(
        'O parâmetro limite deve ser um número inteiro entre 1 e 200.',
      );
    }
    limite = parsed;
  }

  return { limite };
}
