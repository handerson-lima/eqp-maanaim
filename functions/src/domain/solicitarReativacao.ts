import { createHash } from 'node:crypto';

export class SolicitacaoReativacaoInvalidaError extends Error {
  constructor(message = 'Dados de solicitação de reativação inválidos.') {
    super(message);
    this.name = 'SolicitacaoReativacaoInvalidaError';
  }
}

export class FichaNaoEncontradaError extends Error {
  constructor(message = 'Ficha permanente não encontrada.') {
    super(message);
    this.name = 'FichaNaoEncontradaError';
  }
}

export class FichaNaoElegivelParaReativacaoError extends Error {
  constructor(
    message = 'Apenas fichas ou participações em estado terminal (CANCELADA, INATIVA ou EXPIRADA) podem solicitar reativação.',
  ) {
    super(message);
    this.name = 'FichaNaoElegivelParaReativacaoError';
  }
}

export class ParticipacaoNaoTerminalError extends Error {
  constructor(
    message = 'A participação selecionada não se encontra em estado terminal (CANCELADA, INATIVA ou EXPIRADA).',
  ) {
    super(message);
    this.name = 'ParticipacaoNaoTerminalError';
  }
}

export class ParticipacaoNaoEncontradaError extends Error {
  constructor(message = 'Participação anterior não encontrada.') {
    super(message);
    this.name = 'ParticipacaoNaoEncontradaError';
  }
}

export class EquipeInvalidaError extends Error {
  constructor(message = 'A equipe selecionada está inativa ou não existe.') {
    super(message);
    this.name = 'EquipeInvalidaError';
  }
}

export class EquipeJaEmAndamentoError extends Error {
  constructor(
    message = 'Voluntário já possui participação ativa ou novo ciclo em andamento nesta equipe.',
  ) {
    super(message);
    this.name = 'EquipeJaEmAndamentoError';
  }
}

export class TermoInvalidoError extends Error {
  constructor(message = 'Termo de voluntariado inválido ou não vigente.') {
    super(message);
    this.name = 'TermoInvalidoError';
  }
}

export class PermissaoNegadaError extends Error {
  constructor(message = 'Não é permitido solicitar reativação em nome de outro voluntário.') {
    super(message);
    this.name = 'PermissaoNegadaError';
  }
}

export class ComandoDivergenteError extends Error {
  constructor(message = 'Operação de reativação já registrada com dados divergentes.') {
    super(message);
    this.name = 'ComandoDivergenteError';
  }
}

export interface EntradaSolicitarReativacao {
  commandId: string;
  equipeId: string;
  participacaoId?: string;
  justificativa?: string;
  correlationId?: string;
  payloadHash: string;
}

export interface ResultadoSolicitarReativacao {
  sucesso: boolean;
  repetido: boolean;
  participacaoId: string;
  participacaoAnteriorId?: string;
  cicloId: string;
  equipeId: string;
  nomeEquipe: string;
  estado: 'AGUARDANDO_PASTOR_LOCAL';
  proximaAcao: string;
  criadoEm: string;
}

export function calcularPayloadHashSolicitarReativacao(params: {
  equipeId: string;
  participacaoId?: string;
  justificativa?: string;
}): string {
  return createHash('sha256')
    .update(
      JSON.stringify({
        equipeId: params.equipeId.trim(),
        participacaoId: params.participacaoId?.trim() ?? '',
        justificativa: params.justificativa?.trim() ?? '',
      }),
    )
    .digest('hex');
}

export function validarSolicitarReativacao(dados: unknown): EntradaSolicitarReativacao {
  if (!dados || typeof dados !== 'object') {
    throw new SolicitacaoReativacaoInvalidaError('Corpo da requisição inválido.');
  }

  const payload = dados as Record<string, unknown>;

  if (
    !payload.commandId ||
    typeof payload.commandId !== 'string' ||
    payload.commandId.trim().length < 8
  ) {
    throw new SolicitacaoReativacaoInvalidaError(
      'commandId é obrigatório e deve ter no mínimo 8 caracteres.',
    );
  }

  if (
    !payload.equipeId ||
    typeof payload.equipeId !== 'string' ||
    payload.equipeId.trim().length === 0
  ) {
    throw new SolicitacaoReativacaoInvalidaError('equipeId é obrigatório.');
  }

  const participacaoId =
    typeof payload.participacaoId === 'string' && payload.participacaoId.trim().length > 0
      ? payload.participacaoId.trim()
      : undefined;

  const justificativa =
    typeof payload.justificativa === 'string' && payload.justificativa.trim().length > 0
      ? payload.justificativa.trim()
      : undefined;

  const correlationId =
    typeof payload.correlationId === 'string' && payload.correlationId.trim().length > 0
      ? payload.correlationId.trim()
      : undefined;

  const payloadHash = calcularPayloadHashSolicitarReativacao({
    equipeId: payload.equipeId,
    participacaoId,
    justificativa,
  });

  return {
    commandId: payload.commandId.trim(),
    equipeId: payload.equipeId.trim(),
    participacaoId,
    justificativa,
    correlationId,
    payloadHash,
  };
}
