import { createHash } from 'node:crypto';

export const REGEX_COMMAND_ID = /^[A-Za-z0-9_-]{16,128}$/;
export const REGEX_ID = /^[A-Za-z0-9_-]{1,128}$/;

export const DECISOES_EQUIPE = ['APROVADO', 'DESFAVORAVEL'] as const;
export type TipoDecisaoEquipe = (typeof DECISOES_EQUIPE)[number];

export const MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA =
  'Procure o Pastor da igreja local para mais informações';

export class DecisaoInvalidaError extends Error {
  constructor(mensagem = 'Dados de decisão do responsável de equipe inválidos.') {
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

export class ParticipacaoNaoEncontradaError extends Error {
  constructor(mensagem = 'Participação de equipe não encontrada.') {
    super(mensagem);
    this.name = 'ParticipacaoNaoEncontradaError';
  }
}

export class ParticipacaoNaoAguardandoResponsavelError extends Error {
  constructor(
    mensagem = 'A participação não está aguardando decisão do Responsável de Equipe.',
  ) {
    super(mensagem);
    this.name = 'ParticipacaoNaoAguardandoResponsavelError';
  }
}

export class SemVinculoResponsavelEquipeError extends Error {
  constructor(
    mensagem = 'O usuário não possui vínculo de responsabilidade vigente ativo para a equipe solicitada.',
  ) {
    super(mensagem);
    this.name = 'SemVinculoResponsavelEquipeError';
  }
}

export class ConflitoVersaoError extends Error {
  constructor(
    mensagem = 'Conflito de versão: a participação foi alterada concorrentemente.',
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

export interface EntradaDecidirParticipacaoResponsavelEquipe {
  commandId: string;
  correlationId?: string;
  participacaoId: string;
  decisao: TipoDecisaoEquipe;
  justificativa?: string;
  expectedVersion: number;
  payloadHash: string;
}

export interface ResultadoDecidirParticipacaoResponsavelEquipe {
  sucesso: boolean;
  repetido: boolean;
  participacaoId: string;
  decisao: TipoDecisaoEquipe;
  estado: string;
  versao: number;
  proximaAcao: string;
  decididoEm: string;
}

export interface ItemFilaResponsavelEquipe {
  participacaoId: string;
  fichaId: string;
  voluntarioUid: string;
  voluntarioNome: string;
  igrejaId: string;
  nomeIgreja?: string;
  equipeId: string;
  nomeEquipe: string;
  estado: string;
  proximaAcao: string;
  versao: number;
  enviadoEm: string;
}

export interface EquipeEscopoResponsavel {
  id: string;
  nome: string;
}

export interface ResultadoFilaResponsavelEquipe {
  pendencias: ItemFilaResponsavelEquipe[];
  equipes: EquipeEscopoResponsavel[];
}

export function normalizarDecisao(valor: unknown): TipoDecisaoEquipe {
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
    `Decisão de equipe desconhecida: "${valor}". Esperado APROVADO ou DESFAVORAVEL.`,
  );
}

export function calcularPayloadHashDecisaoResponsavel(dados: {
  participacaoId: string;
  decisao: TipoDecisaoEquipe;
  justificativa?: string;
  expectedVersion: number;
}): string {
  const payloadNormalizado = JSON.stringify({
    participacaoId: dados.participacaoId,
    decisao: dados.decisao,
    justificativa: dados.justificativa?.trim() ?? '',
    expectedVersion: dados.expectedVersion,
  });
  return createHash('sha256').update(payloadNormalizado).digest('hex');
}

export function validarDecidirParticipacaoResponsavel(
  payload: unknown,
): EntradaDecidirParticipacaoResponsavelEquipe {
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

  const participacaoId = String(p.participacaoId ?? '').trim();
  if (!REGEX_ID.test(participacaoId)) {
    throw new DecisaoInvalidaError('participacaoId é obrigatório e possui formato inválido.');
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

  const payloadHash = calcularPayloadHashDecisaoResponsavel({
    participacaoId,
    decisao,
    justificativa,
    expectedVersion,
  });

  return {
    commandId,
    correlationId,
    participacaoId,
    decisao,
    justificativa,
    expectedVersion,
    payloadHash,
  };
}
