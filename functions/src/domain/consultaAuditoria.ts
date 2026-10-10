/**
 * Domínio de Consulta de Auditoria Autorizada e Relatórios Operacionais (AD-8, AD-9, AD-12).
 *
 * Invariantes essenciais:
 * 1. Isolamento estrito por papel: Pastor Local acessa somente sua igreja; Responsável de Equipe somente suas equipes; Coordenador/Admin visão global.
 * 2. Prevenção de vazamento (IDOR): Tentativas de consultar fora do escopo retornam resultado vazio neutro.
 * 3. Paginação estável baseada em cursor determinístico (timestamp + commandId de desempate) com limite teto de 100 registros.
 * 4. PII estritamente minimizada e mascarada (CPF sempre com máscara; sem tokens ou credenciais).
 * 5. Consultas globais por Coordenador/Admin geram registro probatório de auditoria.
 */

import { type EntidadeReferenciada } from './auditoria.js';

export interface FiltrosConsultaAuditoria {
  igrejaId?: string;
  equipeId?: string;
  acao?: string;
  atorUid?: string;
  entidadeTipo?: string;
  entidadeId?: string;
  voluntarioId?: string;
  periodoInicio?: string;
  periodoFim?: string;
  limite?: number;
  cursor?: string;
}

export interface ItemAuditoriaAutorizado {
  id: string;
  commandId: string;
  correlationId: string;
  atorUid: string;
  acao: string;
  entidades: EntidadeReferenciada[];
  antes?: Record<string, unknown> | null;
  depois?: Record<string, unknown> | null;
  metadados?: Record<string, unknown> | null;
  timestamp: string;
  sanitizado: boolean;
}

export interface ResultadoConsultaAuditoria {
  itens: ItemAuditoriaAutorizado[];
  proximoCursor: string | null;
  temMais: boolean;
  totalRetornado: number;
}

export interface FiltrosRelatorioOperacional {
  igrejaId?: string;
  equipeId?: string;
  estado?: string;
  ano?: number;
  periodoInicio?: string;
  periodoFim?: string;
  pastorId?: string;
  voluntarioId?: string;
  limite?: number;
  cursor?: string;
}

export interface EquipeResumoRelatorio {
  equipeId: string;
  equipeNome?: string;
  estado: string;
  anoVigencia?: number;
}

export interface VoluntarioItemRelatorio {
  fichaId: string;
  nomeCompleto: string;
  cpfMascarado: string;
  igrejaId: string;
  igrejaNome?: string;
  estadoFicha: string;
  equipes: EquipeResumoRelatorio[];
}

export interface MetricasRelatorioOperacional {
  totalVoluntarios: number;
  totalFichasAtivas: number;
  totalParticipacoesAtivas: number;
  totalAguardandoAprovacao: number;
  totalCanceladasOuInativas: number;
  distribuicaoPorEquipe: Record<string, number>;
  distribuicaoPorIgreja: Record<string, number>;
  distribuicaoPorEstado: Record<string, number>;
}

export interface ResultadoRelatorioOperacional {
  metricas: MetricasRelatorioOperacional;
  voluntarios: VoluntarioItemRelatorio[];
  proximoCursor?: string | null;
  temMais?: boolean;
  totalRetornado?: number;
  geradoEm: string;
  escopoAtor: 'GLOBAL' | 'PASTOR_LOCAL' | 'RESPONSAVEL_EQUIPE';
}

export class ConsultaAuditoriaInvalidaError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConsultaAuditoriaInvalidaError';
  }
}

export class AcessoConsultaNegadoError extends Error {
  constructor(message = 'Acesso não autorizado para consulta de auditoria ou relatórios.') {
    super(message);
    this.name = 'AcessoConsultaNegadoError';
  }
}

export const LIMITE_PADRAO_PAGINACAO = 20;
export const LIMITE_MAXIMO_PAGINACAO = 100;

/**
 * Codifica cursor opaco para paginação estável (AD-9).
 */
export function codificarCursorAuditoria(timestampMs: number, commandId: string): string {
  const payload = JSON.stringify({ t: timestampMs, c: commandId });
  return Buffer.from(payload, 'utf8').toString('base64');
}

/**
 * Decodifica cursor opaco determinístico.
 */
export function decodificarCursorAuditoria(
  cursor: string,
): { timestampMs: number; commandId: string } | null {
  if (!cursor || typeof cursor !== 'string') return null;
  try {
    const raw = Buffer.from(cursor, 'base64').toString('utf8');
    const parsed = JSON.parse(raw) as { t?: unknown; c?: unknown };
    if (typeof parsed.t === 'number' && typeof parsed.c === 'string' && parsed.c.trim().length > 0) {
      return { timestampMs: parsed.t, commandId: parsed.c.trim() };
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * Codifica cursor opaco determinístico para paginação de voluntários em relatórios.
 */
export function codificarCursorRelatorio(fichaId: string): string {
  const payload = JSON.stringify({ f: fichaId });
  return Buffer.from(payload, 'utf8').toString('base64');
}

/**
 * Decodifica cursor opaco determinístico de relatório.
 */
export function decodificarCursorRelatorio(cursor: string): { fichaId: string } | null {
  if (!cursor || typeof cursor !== 'string') return null;
  try {
    const raw = Buffer.from(cursor, 'base64').toString('utf8');
    const parsed = JSON.parse(raw) as { f?: unknown };
    if (typeof parsed.f === 'string' && parsed.f.trim().length > 0) {
      return { fichaId: parsed.f.trim() };
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * Máscara segura de CPF (AD-12).
 * Formato padrão: '123.***.***-00' ou '***.***.***-**'.
 */
export function mascararCpfSeguro(cpf?: unknown): string {
  if (typeof cpf !== 'string') return '***.***.***-**';
  const limpo = cpf.replace(/\D/g, '');
  if (limpo.length !== 11) return '***.***.***-**';
  return `${limpo.slice(0, 3)}.***.***-${limpo.slice(9)}`;
}

/**
 * Validação rigorosa dos parâmetros de filtro para a consulta de auditoria.
 */
export function validarFiltrosConsultaAuditoria(dados: unknown): {
  filtros: FiltrosConsultaAuditoria;
  limite: number;
  cursorDecodificado: { timestampMs: number; commandId: string } | null;
} {
  if (dados === null || dados === undefined || typeof dados !== 'object') {
    return {
      filtros: {},
      limite: LIMITE_PADRAO_PAGINACAO,
      cursorDecodificado: null,
    };
  }

  const payload = dados as Record<string, unknown>;
  const filtros: FiltrosConsultaAuditoria = {};

  if (payload.igrejaId !== undefined) {
    if (typeof payload.igrejaId !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('igrejaId deve ser uma string.');
    }
    filtros.igrejaId = payload.igrejaId.trim();
  }

  if (payload.equipeId !== undefined) {
    if (typeof payload.equipeId !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('equipeId deve ser uma string.');
    }
    filtros.equipeId = payload.equipeId.trim();
  }

  if (payload.acao !== undefined) {
    if (typeof payload.acao !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('acao deve ser uma string.');
    }
    filtros.acao = payload.acao.trim().toUpperCase();
  }

  if (payload.atorUid !== undefined) {
    if (typeof payload.atorUid !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('atorUid deve ser uma string.');
    }
    filtros.atorUid = payload.atorUid.trim();
  }

  if (payload.entidadeTipo !== undefined) {
    if (typeof payload.entidadeTipo !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('entidadeTipo deve ser uma string.');
    }
    filtros.entidadeTipo = payload.entidadeTipo.trim().toUpperCase();
  }

  if (payload.entidadeId !== undefined) {
    if (typeof payload.entidadeId !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('entidadeId deve ser uma string.');
    }
    filtros.entidadeId = payload.entidadeId.trim();
  }

  if (payload.voluntarioId !== undefined) {
    if (typeof payload.voluntarioId !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('voluntarioId deve ser uma string.');
    }
    filtros.voluntarioId = payload.voluntarioId.trim();
  }

  if (payload.periodoInicio !== undefined) {
    if (typeof payload.periodoInicio !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('periodoInicio deve ser string ISO.');
    }
    const ms = Date.parse(payload.periodoInicio);
    if (isNaN(ms)) {
      throw new ConsultaAuditoriaInvalidaError('periodoInicio inválido.');
    }
    filtros.periodoInicio = new Date(ms).toISOString();
  }

  if (payload.periodoFim !== undefined) {
    if (typeof payload.periodoFim !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('periodoFim deve ser string ISO.');
    }
    const ms = Date.parse(payload.periodoFim);
    if (isNaN(ms)) {
      throw new ConsultaAuditoriaInvalidaError('periodoFim inválido.');
    }
    filtros.periodoFim = new Date(ms).toISOString();
  }

  let limite = LIMITE_PADRAO_PAGINACAO;
  if (payload.limite !== undefined) {
    const parsed = Number(payload.limite);
    if (isNaN(parsed) || !Number.isInteger(parsed) || parsed < 1 || parsed > LIMITE_MAXIMO_PAGINACAO) {
      throw new ConsultaAuditoriaInvalidaError(
        `limite deve ser um número inteiro entre 1 e ${LIMITE_MAXIMO_PAGINACAO}.`,
      );
    }
    limite = parsed;
    filtros.limite = parsed;
  }

  let cursorDecodificado: { timestampMs: number; commandId: string } | null = null;
  if (payload.cursor !== undefined) {
    if (typeof payload.cursor !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('cursor deve ser uma string.');
    }
    filtros.cursor = payload.cursor.trim();
    cursorDecodificado = decodificarCursorAuditoria(filtros.cursor);
  }

  return { filtros, limite, cursorDecodificado };
}

/**
 * Validação rigorosa dos parâmetros de filtro para a consulta de relatório operacional.
 */
export function validarFiltrosRelatorioOperacional(dados: unknown): {
  filtros: FiltrosRelatorioOperacional;
  limite: number;
  cursorDecodificado: { fichaId: string } | null;
} {
  if (dados === null || dados === undefined || typeof dados !== 'object') {
    return {
      filtros: {},
      limite: LIMITE_PADRAO_PAGINACAO,
      cursorDecodificado: null,
    };
  }

  const payload = dados as Record<string, unknown>;
  const filtros: FiltrosRelatorioOperacional = {};

  if (payload.igrejaId !== undefined) {
    if (typeof payload.igrejaId !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('igrejaId deve ser uma string.');
    }
    filtros.igrejaId = payload.igrejaId.trim();
  }

  if (payload.equipeId !== undefined) {
    if (typeof payload.equipeId !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('equipeId deve ser uma string.');
    }
    filtros.equipeId = payload.equipeId.trim();
  }

  if (payload.estado !== undefined) {
    if (typeof payload.estado !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('estado deve ser uma string.');
    }
    filtros.estado = payload.estado.trim().toUpperCase();
  }

  if (payload.ano !== undefined) {
    const parsedAno = Number(payload.ano);
    if (isNaN(parsedAno) || !Number.isInteger(parsedAno) || parsedAno < 2000 || parsedAno > 2100) {
      throw new ConsultaAuditoriaInvalidaError('ano deve ser número inteiro válido.');
    }
    filtros.ano = parsedAno;
  }

  if (payload.periodoInicio !== undefined) {
    if (typeof payload.periodoInicio !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('periodoInicio deve ser string ISO.');
    }
    const ms = Date.parse(payload.periodoInicio);
    if (isNaN(ms)) {
      throw new ConsultaAuditoriaInvalidaError('periodoInicio inválido.');
    }
    filtros.periodoInicio = new Date(ms).toISOString();
  }

  if (payload.periodoFim !== undefined) {
    if (typeof payload.periodoFim !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('periodoFim deve ser string ISO.');
    }
    const ms = Date.parse(payload.periodoFim);
    if (isNaN(ms)) {
      throw new ConsultaAuditoriaInvalidaError('periodoFim inválido.');
    }
    filtros.periodoFim = new Date(ms).toISOString();
  }

  if (payload.pastorId !== undefined) {
    if (typeof payload.pastorId !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('pastorId deve ser uma string.');
    }
    filtros.pastorId = payload.pastorId.trim();
  }

  if (payload.voluntarioId !== undefined) {
    if (typeof payload.voluntarioId !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('voluntarioId deve ser uma string.');
    }
    filtros.voluntarioId = payload.voluntarioId.trim();
  }

  let limite = LIMITE_PADRAO_PAGINACAO;
  if (payload.limite !== undefined) {
    const parsed = Number(payload.limite);
    if (isNaN(parsed) || !Number.isInteger(parsed) || parsed < 1 || parsed > LIMITE_MAXIMO_PAGINACAO) {
      throw new ConsultaAuditoriaInvalidaError(
        `limite deve ser um número inteiro entre 1 e ${LIMITE_MAXIMO_PAGINACAO}.`,
      );
    }
    limite = parsed;
    filtros.limite = parsed;
  }

  let cursorDecodificado: { fichaId: string } | null = null;
  if (payload.cursor !== undefined) {
    if (typeof payload.cursor !== 'string') {
      throw new ConsultaAuditoriaInvalidaError('cursor deve ser uma string.');
    }
    filtros.cursor = payload.cursor.trim();
    cursorDecodificado = decodificarCursorRelatorio(filtros.cursor);
  }

  return { filtros, limite, cursorDecodificado };
}
