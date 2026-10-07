import { createHash } from 'node:crypto';
import { cpfValido, normalizarCpf } from './cpf.js';

export class CpfInvalidoError extends Error {
  constructor(message = 'CPF inválido') {
    super(message);
    this.name = 'CpfInvalidoError';
  }
}

export class IgrejaInvalidaError extends Error {
  constructor(message = 'Igreja inválida ou inativa') {
    super(message);
    this.name = 'IgrejaInvalidaError';
  }
}

export class ComandoDivergenteError extends Error {
  constructor(message = 'Operação já registrada com dados divergentes.') {
    super(message);
    this.name = 'ComandoDivergenteError';
  }
}

export class ConflitoVersaoError extends Error {
  constructor(message = 'A versão da ficha foi alterada concorrentemente.') {
    super(message);
    this.name = 'ConflitoVersaoError';
  }
}

export class FichaInvalidaError extends Error {
  constructor(message = 'Dados cadastrais inválidos.') {
    super(message);
    this.name = 'FichaInvalidaError';
  }
}

export interface TermoAceitoResumo {
  termoId: string;
  versaoId: string;
  numeroVersao: number;
  hashSha256: string;
  titulo?: string;
  aceitoEm: string;
  commandId: string;
}

export interface FichaPermanente {
  id: string; // uid do voluntário
  ownerUid: string;
  nomeCompleto: string;
  profissao: string;
  cpf: string; // normalizado (somente dígitos)
  igrejaId: string;
  estado: string; // 'RASCUNHO', etc.
  versao: number;
  termoAceito?: TermoAceitoResumo | null;
  proximaAcao?: string | null;
  mensagemVoluntario?: string | null;
  criadoEm?: string | null;
  atualizadoEm?: string | null;
}

export interface EntradaSalvarMinhaFicha {
  commandId: string;
  nomeCompleto: string;
  profissao: string;
  cpf: string; // normalizado (somente dígitos)
  igrejaId: string;
  expectedVersion?: number;
  payloadHash: string;
}

export interface DiffCampo {
  antes: unknown;
  depois: unknown;
}

export type DiffFicha = Record<string, DiffCampo>;

export const CAMPOS_OBRIGATORIOS_FICHA = [
  'nomeCompleto',
  'profissao',
  'cpf',
  'igrejaId',
] as const;

/**
 * Normaliza e calcula o hash SHA-256 do payload para garantir idempotência estrita.
 */
export function calcularPayloadHashFicha(dados: {
  nomeCompleto: string;
  profissao: string;
  cpf: string;
  igrejaId: string;
  expectedVersion?: number;
}): string {
  const normalizado = {
    nomeCompleto: dados.nomeCompleto.trim(),
    profissao: dados.profissao.trim(),
    cpf: normalizarCpf(dados.cpf),
    igrejaId: dados.igrejaId.trim(),
    expectedVersion: dados.expectedVersion ?? null,
  };
  return createHash('sha256').update(JSON.stringify(normalizado)).digest('hex');
}

/**
 * Valida a entrada da requisição de salvamento de ficha.
 * Lança CpfInvalidoError se o CPF for matematicamente inválido,
 * ou FichaInvalidaError para outros campos faltantes/inválidos.
 */
export function validarSalvarFicha(data: unknown): EntradaSalvarMinhaFicha {
  if (typeof data !== 'object' || data === null) {
    throw new FichaInvalidaError('Corpo da requisição inválido.');
  }

  const payload = data as Record<string, unknown>;

  const commandId =
    typeof payload.commandId === 'string' ? payload.commandId.trim() : '';
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(commandId)) {
    throw new FichaInvalidaError('Identificador de comando inválido.');
  }

  const nomeCompleto =
    typeof payload.nomeCompleto === 'string' ? payload.nomeCompleto.trim() : '';
  if (nomeCompleto.length < 3 || nomeCompleto.length > 160) {
    throw new FichaInvalidaError('Nome completo deve ter entre 3 e 160 caracteres.');
  }

  const profissao =
    typeof payload.profissao === 'string' ? payload.profissao.trim() : '';
  if (profissao.length < 2 || profissao.length > 120) {
    throw new FichaInvalidaError('Profissão deve ter entre 2 e 120 caracteres.');
  }

  const cpfRaw = typeof payload.cpf === 'string' ? payload.cpf : '';
  if (!cpfValido(cpfRaw)) {
    throw new CpfInvalidoError('CPF inválido');
  }
  const cpf = normalizarCpf(cpfRaw);

  const igrejaId =
    typeof payload.igrejaId === 'string' ? payload.igrejaId.trim() : '';
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(igrejaId)) {
    throw new FichaInvalidaError('Igreja inválida.');
  }

  let expectedVersion: number | undefined;
  if (payload.expectedVersion !== undefined && payload.expectedVersion !== null) {
    if (typeof payload.expectedVersion !== 'number' || payload.expectedVersion < 0) {
      throw new FichaInvalidaError('Versão esperada inválida.');
    }
    expectedVersion = payload.expectedVersion;
  }

  const payloadHash = calcularPayloadHashFicha({
    nomeCompleto,
    profissao,
    cpf,
    igrejaId,
    expectedVersion,
  });

  return {
    commandId,
    nomeCompleto,
    profissao,
    cpf,
    igrejaId,
    expectedVersion,
    payloadHash,
  };
}

/**
 * Retorna quais campos cadastrais obrigatórios ainda estão pendentes/inválidos.
 */
export function calcularCamposPendentes(dados: {
  nomeCompleto?: string | null;
  profissao?: string | null;
  cpf?: string | null;
  igrejaId?: string | null;
}): string[] {
  const pendencias: string[] = [];

  const nome = (dados.nomeCompleto ?? '').trim();
  if (nome.length < 3) {
    pendencias.push('nomeCompleto');
  }

  const prof = (dados.profissao ?? '').trim();
  if (prof.length < 2) {
    pendencias.push('profissao');
  }

  const cpf = (dados.cpf ?? '').trim();
  if (!cpfValido(cpf)) {
    pendencias.push('cpf');
  }

  const igreja = (dados.igrejaId ?? '').trim();
  if (igreja.length === 0) {
    pendencias.push('igrejaId');
  }

  return pendencias;
}

/**
 * Calcula o diferencial apenas dos campos cadastrais permitidos para inclusão na auditoria.
 */
export function calcularDiffFicha(
  anterior: Record<string, unknown> | null,
  novo: EntradaSalvarMinhaFicha,
): DiffFicha {
  const diff: DiffFicha = {};
  const camposAuditados: Array<keyof Pick<EntradaSalvarMinhaFicha, 'nomeCompleto' | 'profissao' | 'cpf' | 'igrejaId'>> = [
    'nomeCompleto',
    'profissao',
    'cpf',
    'igrejaId',
  ];

  for (const campo of camposAuditados) {
    const valorAntigo = anterior ? anterior[campo] : null;
    const valorNovo = novo[campo];
    if (valorAntigo !== valorNovo) {
      diff[campo] = {
        antes: valorAntigo ?? null,
        depois: valorNovo,
      };
    }
  }

  return diff;
}

/**
 * AD-12: auditoria e outbox nunca recebem valores cadastrais (nome, CPF, profissão).
 * Apenas os NOMES dos campos alterados são registrados.
 */
export function calcularCamposAlterados(
  anterior: Record<string, unknown> | null,
  novo: EntradaSalvarMinhaFicha,
): string[] {
  return Object.keys(calcularDiffFicha(anterior, novo));
}
