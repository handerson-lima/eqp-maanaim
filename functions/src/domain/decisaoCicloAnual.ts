import { createHash } from 'node:crypto';

export const REGEX_COMMAND_ID = /^[A-Za-z0-9_-]{16,128}$/;
export const REGEX_ID = /^[A-Za-z0-9_-]{1,128}$/;

export const DECISOES_CICLO = ['APROVADO', 'DESFAVORAVEL'] as const;
export type TipoDecisaoCiclo = (typeof DECISOES_CICLO)[number];

export const MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA =
  'Procure o Pastor da igreja local para mais informações';

export class DecisaoInvalidaError extends Error {
  constructor(mensagem = 'Dados de decisão inválidos.') {
    super(mensagem);
    this.name = 'DecisaoInvalidaError';
  }
}

export class JustificativaObrigatoriaError extends Error {
  constructor(
    mensagem = 'Justificativa obrigatória para decisão negativa (mínimo de 5 caracteres).',
  ) {
    super(mensagem);
    this.name = 'JustificativaObrigatoriaError';
  }
}

export class CicloNaoEncontradoError extends Error {
  constructor(mensagem = 'Ciclo de renovação anual não encontrado.') {
    super(mensagem);
    this.name = 'CicloNaoEncontradoError';
  }
}

export class CicloNaoElegivelError extends Error {
  constructor(
    mensagem = 'O ciclo não está no estado esperado para esta etapa de deliberação.',
  ) {
    super(mensagem);
    this.name = 'CicloNaoElegivelError';
  }
}

export class ParticipacaoCicloNaoEncontradaError extends Error {
  constructor(mensagem = 'Participação vinculada ao ciclo não foi encontrada.') {
    super(mensagem);
    this.name = 'ParticipacaoCicloNaoEncontradaError';
  }
}

export class SemVinculoPastoralError extends Error {
  constructor(
    mensagem = 'O usuário não possui vínculo pastoral vigente ativo para a igreja do voluntário.',
  ) {
    super(mensagem);
    this.name = 'SemVinculoPastoralError';
  }
}

export class SemVinculoResponsavelEquipeError extends Error {
  constructor(
    mensagem = 'O usuário não possui vínculo de responsabilidade vigente ativo para a equipe do ciclo.',
  ) {
    super(mensagem);
    this.name = 'SemVinculoResponsavelEquipeError';
  }
}

export class SemAutoridadeCoordenadorError extends Error {
  constructor(
    mensagem = 'O usuário não possui autoridade de Coordenador Geral ou Administrador.',
  ) {
    super(mensagem);
    this.name = 'SemAutoridadeCoordenadorError';
  }
}

export class ReuniaoPastoresNaoConfirmadaError extends Error {
  constructor(
    mensagem = 'É obrigatório confirmar a deliberação na Reunião de Pastores para aprovar a renovação.',
  ) {
    super(mensagem);
    this.name = 'ReuniaoPastoresNaoConfirmadaError';
  }
}

export class ConflitoVersaoError extends Error {
  constructor(
    mensagem = 'Conflito de versão: o registro foi alterado concorrentemente.',
  ) {
    super(mensagem);
    this.name = 'ConflitoVersaoError';
  }
}

export class ComandoDivergenteError extends Error {
  constructor(
    mensagem = 'Operação já registrada com dados divergentes.',
  ) {
    super(mensagem);
    this.name = 'ComandoDivergenteError';
  }
}

export function normalizarDecisaoCiclo(valor: unknown): TipoDecisaoCiclo {
  if (typeof valor !== 'string') throw new DecisaoInvalidaError();
  const normalizado = valor.trim().toUpperCase();
  if (normalizado === 'APROVADO' || normalizado === 'APROVAR') {
    return 'APROVADO';
  }
  if (
    normalizado === 'DESFAVORAVEL' ||
    normalizado === 'DESFAVORÁVEL' ||
    normalizado === 'RECUSADO' ||
    normalizado === 'RECUSAR' ||
    normalizado === 'NEGATIVO'
  ) {
    return 'DESFAVORAVEL';
  }
  throw new DecisaoInvalidaError(
    `Decisão desconhecida: "${valor}". Esperado APROVADO ou DESFAVORAVEL.`,
  );
}

// -------------------------------------------------------------
// Etapa 1: Pastor Local
// -------------------------------------------------------------

export interface EntradaDecidirCicloAnualPastor {
  commandId: string;
  correlationId?: string;
  cicloId: string;
  decisao: TipoDecisaoCiclo;
  justificativa?: string;
  expectedVersion?: number;
  payloadHash: string;
}

export interface ResultadoDecidirCicloAnualPastor {
  sucesso: boolean;
  repetido: boolean;
  cicloId: string;
  decisao: TipoDecisaoCiclo;
  estadoCiclo: string;
  proximaAcao: string;
  decididoEm: string;
}

export function calcularPayloadHashCicloPastor(dados: {
  cicloId: string;
  decisao: TipoDecisaoCiclo;
  justificativa?: string;
  expectedVersion?: number;
}): string {
  const payload = [
    dados.cicloId,
    dados.decisao,
    dados.justificativa?.trim() ?? '',
    dados.expectedVersion ?? 0,
  ].join('|');
  return createHash('sha256').update(payload, 'utf8').digest('hex');
}

export function validarDecidirCicloAnualPastor(
  raw: unknown,
): EntradaDecidirCicloAnualPastor {
  if (!raw || typeof raw !== 'object') {
    throw new DecisaoInvalidaError('Corpo da requisição inválido.');
  }

  const dados = raw as Record<string, unknown>;

  const commandId = String(dados.commandId ?? '').trim();
  if (!REGEX_COMMAND_ID.test(commandId)) {
    throw new DecisaoInvalidaError(
      'commandId inválido (deve conter de 16 a 128 caracteres alfanuméricos/hífen/underline).',
    );
  }

  const cicloId = String(dados.cicloId ?? '').trim();
  if (!REGEX_ID.test(cicloId)) {
    throw new DecisaoInvalidaError('cicloId inválido.');
  }

  const decisao = normalizarDecisaoCiclo(dados.decisao);

  let justificativa: string | undefined;
  if (dados.justificativa !== undefined && dados.justificativa !== null) {
    const j = String(dados.justificativa).trim();
    if (j.length > 0) justificativa = j;
  }

  if (decisao === 'DESFAVORAVEL') {
    if (!justificativa || justificativa.length < 5) {
      throw new JustificativaObrigatoriaError();
    }
  }

  let expectedVersion: number | undefined;
  if (dados.expectedVersion !== undefined && dados.expectedVersion !== null) {
    const v = Number(dados.expectedVersion);
    if (!Number.isInteger(v) || v < 1) {
      throw new DecisaoInvalidaError('expectedVersion deve ser um inteiro positivo.');
    }
    expectedVersion = v;
  }

  const correlationId = dados.correlationId
    ? String(dados.correlationId).trim()
    : undefined;

  const payloadHash = calcularPayloadHashCicloPastor({
    cicloId,
    decisao,
    justificativa,
    expectedVersion,
  });

  return {
    commandId,
    correlationId,
    cicloId,
    decisao,
    justificativa,
    expectedVersion,
    payloadHash,
  };
}

// -------------------------------------------------------------
// Etapa 2: Responsável de Equipe
// -------------------------------------------------------------

export interface EntradaDecidirCicloAnualResponsavel {
  commandId: string;
  correlationId?: string;
  cicloId: string;
  decisao: TipoDecisaoCiclo;
  justificativa?: string;
  expectedVersion?: number;
  payloadHash: string;
}

export interface ResultadoDecidirCicloAnualResponsavel {
  sucesso: boolean;
  repetido: boolean;
  cicloId: string;
  decisao: TipoDecisaoCiclo;
  estadoCiclo: string;
  proximaAcao: string;
  decididoEm: string;
}

export function calcularPayloadHashCicloResponsavel(dados: {
  cicloId: string;
  decisao: TipoDecisaoCiclo;
  justificativa?: string;
  expectedVersion?: number;
}): string {
  const payload = [
    dados.cicloId,
    dados.decisao,
    dados.justificativa?.trim() ?? '',
    dados.expectedVersion ?? 0,
  ].join('|');
  return createHash('sha256').update(payload, 'utf8').digest('hex');
}

export function validarDecidirCicloAnualResponsavel(
  raw: unknown,
): EntradaDecidirCicloAnualResponsavel {
  if (!raw || typeof raw !== 'object') {
    throw new DecisaoInvalidaError('Corpo da requisição inválido.');
  }

  const dados = raw as Record<string, unknown>;

  const commandId = String(dados.commandId ?? '').trim();
  if (!REGEX_COMMAND_ID.test(commandId)) {
    throw new DecisaoInvalidaError(
      'commandId inválido (deve conter de 16 a 128 caracteres alfanuméricos/hífen/underline).',
    );
  }

  const cicloId = String(dados.cicloId ?? '').trim();
  if (!REGEX_ID.test(cicloId)) {
    throw new DecisaoInvalidaError('cicloId inválido.');
  }

  const decisao = normalizarDecisaoCiclo(dados.decisao);

  let justificativa: string | undefined;
  if (dados.justificativa !== undefined && dados.justificativa !== null) {
    const j = String(dados.justificativa).trim();
    if (j.length > 0) justificativa = j;
  }

  if (decisao === 'DESFAVORAVEL') {
    if (!justificativa || justificativa.length < 5) {
      throw new JustificativaObrigatoriaError();
    }
  }

  let expectedVersion: number | undefined;
  if (dados.expectedVersion !== undefined && dados.expectedVersion !== null) {
    const v = Number(dados.expectedVersion);
    if (!Number.isInteger(v) || v < 1) {
      throw new DecisaoInvalidaError('expectedVersion deve ser um inteiro positivo.');
    }
    expectedVersion = v;
  }

  const correlationId = dados.correlationId
    ? String(dados.correlationId).trim()
    : undefined;

  const payloadHash = calcularPayloadHashCicloResponsavel({
    cicloId,
    decisao,
    justificativa,
    expectedVersion,
  });

  return {
    commandId,
    correlationId,
    cicloId,
    decisao,
    justificativa,
    expectedVersion,
    payloadHash,
  };
}

// -------------------------------------------------------------
// Etapa 3: Coordenador Geral
// -------------------------------------------------------------

export interface EntradaConcluirCicloAnualCoordenador {
  commandId: string;
  correlationId?: string;
  cicloId: string;
  decisao: TipoDecisaoCiclo;
  confirmouReuniaoPastores?: boolean;
  observacao?: string;
  justificativa?: string;
  expectedVersion?: number;
  payloadHash: string;
}

export interface ResultadoConcluirCicloAnualCoordenador {
  sucesso: boolean;
  repetido: boolean;
  cicloId: string;
  participacaoId: string;
  decisao: TipoDecisaoCiclo;
  estadoCiclo: string;
  vigenciaInicio?: string;
  vigenciaFim?: string;
  proximaAcao: string;
  decididoEm: string;
}

export function calcularPayloadHashCicloCoordenador(dados: {
  cicloId: string;
  decisao: TipoDecisaoCiclo;
  confirmouReuniaoPastores: boolean;
  observacao?: string;
  justificativa?: string;
  expectedVersion?: number;
}): string {
  const payload = [
    dados.cicloId,
    dados.decisao,
    dados.confirmouReuniaoPastores ? 'true' : 'false',
    dados.observacao?.trim() ?? '',
    dados.justificativa?.trim() ?? '',
    dados.expectedVersion ?? 0,
  ].join('|');
  return createHash('sha256').update(payload, 'utf8').digest('hex');
}

export function validarConcluirCicloAnualCoordenador(
  raw: unknown,
): EntradaConcluirCicloAnualCoordenador {
  if (!raw || typeof raw !== 'object') {
    throw new DecisaoInvalidaError('Corpo da requisição inválido.');
  }

  const dados = raw as Record<string, unknown>;

  const commandId = String(dados.commandId ?? '').trim();
  if (!REGEX_COMMAND_ID.test(commandId)) {
    throw new DecisaoInvalidaError(
      'commandId inválido (deve conter de 16 a 128 caracteres alfanuméricos/hífen/underline).',
    );
  }

  const cicloId = String(dados.cicloId ?? '').trim();
  if (!REGEX_ID.test(cicloId)) {
    throw new DecisaoInvalidaError('cicloId inválido.');
  }

  const decisao = normalizarDecisaoCiclo(dados.decisao);
  const confirmouReuniaoPastores = Boolean(dados.confirmouReuniaoPastores);

  if (decisao === 'APROVADO' && !confirmouReuniaoPastores) {
    throw new ReuniaoPastoresNaoConfirmadaError();
  }

  let observacao: string | undefined;
  if (dados.observacao !== undefined && dados.observacao !== null) {
    const obs = String(dados.observacao).trim();
    if (obs.length > 0) observacao = obs;
  }

  let justificativa: string | undefined;
  if (dados.justificativa !== undefined && dados.justificativa !== null) {
    const j = String(dados.justificativa).trim();
    if (j.length > 0) justificativa = j;
  }

  if (decisao === 'DESFAVORAVEL') {
    if (!justificativa || justificativa.length < 5) {
      throw new JustificativaObrigatoriaError();
    }
  }

  let expectedVersion: number | undefined;
  if (dados.expectedVersion !== undefined && dados.expectedVersion !== null) {
    const v = Number(dados.expectedVersion);
    if (!Number.isInteger(v) || v < 1) {
      throw new DecisaoInvalidaError('expectedVersion deve ser um inteiro positivo.');
    }
    expectedVersion = v;
  }

  const correlationId = dados.correlationId
    ? String(dados.correlationId).trim()
    : undefined;

  const payloadHash = calcularPayloadHashCicloCoordenador({
    cicloId,
    decisao,
    confirmouReuniaoPastores,
    observacao,
    justificativa,
    expectedVersion,
  });

  return {
    commandId,
    correlationId,
    cicloId,
    decisao,
    confirmouReuniaoPastores,
    observacao,
    justificativa,
    expectedVersion,
    payloadHash,
  };
}
