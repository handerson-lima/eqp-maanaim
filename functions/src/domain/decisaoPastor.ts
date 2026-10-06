import { createHash } from 'node:crypto';

export const REGEX_COMMAND_ID = /^[A-Za-z0-9_-]{16,128}$/;
export const REGEX_ID = /^[A-Za-z0-9_-]{1,128}$/;

export const DECISOES_PASTORAIS = ['APROVADO', 'DESFAVORAVEL'] as const;
export type TipoDecisaoPastoral = (typeof DECISOES_PASTORAIS)[number];

export const MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA =
  'Procure o Pastor da igreja local para mais informações';

export class DecisaoInvalidaError extends Error {
  constructor(mensagem = 'Dados de decisão pastoral inválidos.') {
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

export class FichaNaoEncontradaError extends Error {
  constructor(mensagem = 'Ficha do voluntário não encontrada.') {
    super(mensagem);
    this.name = 'FichaNaoEncontradaError';
  }
}

export class FichaNaoAguardandoPastorError extends Error {
  constructor(
    mensagem = 'A ficha não está aguardando decisão do Pastor Local.',
  ) {
    super(mensagem);
    this.name = 'FichaNaoAguardandoPastorError';
  }
}

export class SemVinculoPastoralError extends Error {
  constructor(
    mensagem = 'O usuário não possui vínculo pastoral vigente ativo para a igreja da ficha.',
  ) {
    super(mensagem);
    this.name = 'SemVinculoPastoralError';
  }
}

export class ConflitoVersaoError extends Error {
  constructor(
    mensagem = 'Conflito de versão: a ficha foi alterada concorrentemente.',
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

export interface EntradaDecidirFichaPastorLocal {
  commandId: string;
  correlationId?: string;
  fichaId: string;
  decisao: TipoDecisaoPastoral;
  justificativa?: string;
  expectedVersion: number;
  payloadHash: string;
}

export interface ResultadoDecidirFichaPastorLocal {
  sucesso: boolean;
  repetido: boolean;
  decisao: TipoDecisaoPastoral;
  estado: string;
  versao: number;
  proximaAcao: string;
  decididoEm: string;
}

export interface ItemFilaPastorLocal {
  id: string;
  fichaId: string;
  voluntarioUid: string;
  voluntarioNome: string;
  igrejaId: string;
  nomeIgreja?: string;
  estado: string;
  proximaAcao: string;
  ano: number;
  equipes: Array<{ equipeId: string; nomeEquipe: string }>;
  enviadoEm: string;
}

export interface IgrejaEscopoPastor {
  id: string;
  nome: string;
  codigo?: string;
}

export interface ResultadoFilaPastorLocal {
  pendencias: ItemFilaPastorLocal[];
  igrejas: IgrejaEscopoPastor[];
}

export function normalizarDecisao(valor: unknown): TipoDecisaoPastoral {
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
    `Decisão pastoral desconhecida: "${valor}". Esperado APROVADO ou DESFAVORAVEL.`,
  );
}

export function calcularPayloadHashDecisaoPastor(dados: {
  fichaId: string;
  decisao: TipoDecisaoPastoral;
  justificativa?: string;
  expectedVersion: number;
}): string {
  const payloadNormalizado = JSON.stringify({
    fichaId: dados.fichaId,
    decisao: dados.decisao,
    justificativa: dados.justificativa?.trim() ?? '',
    expectedVersion: dados.expectedVersion,
  });
  return createHash('sha256').update(payloadNormalizado).digest('hex');
}

export function validarDecidirFichaPastor(
  payload: unknown,
): EntradaDecidirFichaPastorLocal {
  if (!payload || typeof payload !== 'object') {
    throw new DecisaoInvalidaError('Corpo da requisição ausente ou inválido.');
  }

  const p = payload as Record<string, unknown>;

  const commandId = String(p.commandId ?? '').trim();
  if (!REGEX_COMMAND_ID.test(commandId)) {
    throw new DecisaoInvalidaError(
      'commandId é obrigatório e deve ter entre 16 e 128 caracteres alfanuméricos.',
    );
  }

  let correlationId: string | undefined;
  if (p.correlationId !== undefined && p.correlationId !== null) {
    const corrStr = String(p.correlationId).trim();
    if (corrStr.length > 0) {
      if (!REGEX_COMMAND_ID.test(corrStr)) {
        throw new DecisaoInvalidaError('correlationId com formato inválido.');
      }
      correlationId = corrStr;
    }
  }

  const fichaId = String(p.fichaId ?? '').trim();
  if (!REGEX_ID.test(fichaId)) {
    throw new DecisaoInvalidaError('fichaId é obrigatório e possui formato inválido.');
  }

  const decisao = normalizarDecisao(p.decisao);

  let justificativa: string | undefined;
  if (p.justificativa !== undefined && p.justificativa !== null) {
    justificativa = String(p.justificativa).trim();
  }

  if (decisao === 'DESFAVORAVEL') {
    if (!justificativa || justificativa.length < 5) {
      throw new JustificativaObrigatoriaError();
    }
    if (justificativa.length > 500) {
      throw new DecisaoInvalidaError(
        'Justificativa não pode exceder 500 caracteres.',
      );
    }
  }

  if (
    p.expectedVersion === undefined ||
    p.expectedVersion === null ||
    typeof p.expectedVersion !== 'number' ||
    !Number.isInteger(p.expectedVersion) ||
    p.expectedVersion < 0
  ) {
    throw new DecisaoInvalidaError('expectedVersion deve ser um inteiro não-negativo.');
  }

  const expectedVersion = p.expectedVersion;

  const payloadHash = calcularPayloadHashDecisaoPastor({
    fichaId,
    decisao,
    justificativa,
    expectedVersion,
  });

  return {
    commandId,
    correlationId,
    fichaId,
    decisao,
    justificativa,
    expectedVersion,
    payloadHash,
  };
}
