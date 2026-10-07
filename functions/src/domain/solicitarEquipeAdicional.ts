import { createHash } from 'node:crypto';

export class SolicitacaoInvalidaError extends Error {
  constructor(message = 'Dados de solicitação inválidos.') {
    super(message);
    this.name = 'SolicitacaoInvalidaError';
  }
}

export class FichaNaoEncontradaError extends Error {
  constructor(message = 'Ficha permanente não encontrada.') {
    super(message);
    this.name = 'FichaNaoEncontradaError';
  }
}

export class FichaNaoAtivaError extends Error {
  constructor(message = 'Apenas voluntários com ficha ativa podem solicitar equipes adicionais.') {
    super(message);
    this.name = 'FichaNaoAtivaError';
  }
}

export class TermoInvalidoError extends Error {
  constructor(message = 'Termo de adesão inválido ou não vigente.') {
    super(message);
    this.name = 'TermoInvalidoError';
  }
}

export class EquipeInvalidaError extends Error {
  constructor(message = 'A equipe selecionada está inativa ou não existe.') {
    super(message);
    this.name = 'EquipeInvalidaError';
  }
}

export class EquipeJaSolicitadaError extends Error {
  constructor(message = 'Voluntário já possui participação ativa ou solicitação em andamento nesta equipe.') {
    super(message);
    this.name = 'EquipeJaSolicitadaError';
  }
}

export class ComandoDivergenteError extends Error {
  constructor(message = 'Operação já registrada com dados divergentes.') {
    super(message);
    this.name = 'ComandoDivergenteError';
  }
}

export class PermissaoNegadaError extends Error {
  constructor(message = 'Não é permitido solicitar equipe em nome de outro voluntário.') {
    super(message);
    this.name = 'PermissaoNegadaError';
  }
}

export interface EntradaSolicitarEquipeAdicional {
  commandId: string;
  equipeId: string;
  correlationId?: string;
  payloadHash: string;
}

export interface ResultadoSolicitarEquipeAdicional {
  sucesso: boolean;
  repetido: boolean;
  participacaoId: string;
  cicloId: string;
  equipeId: string;
  nomeEquipe: string;
  estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE';
  proximaAcao: string;
  criadoEm: string;
}

export function calcularPayloadHashSolicitarEquipe(equipeId: string): string {
  return createHash('sha256')
    .update(JSON.stringify({ equipeId: equipeId.trim() }))
    .digest('hex');
}

export function validarSolicitarEquipeAdicional(dados: unknown): EntradaSolicitarEquipeAdicional {
  if (!dados || typeof dados !== 'object') {
    throw new SolicitacaoInvalidaError('Corpo da requisição inválido.');
  }

  const payload = dados as Record<string, unknown>;

  if (
    !payload.commandId ||
    typeof payload.commandId !== 'string' ||
    payload.commandId.trim().length < 8
  ) {
    throw new SolicitacaoInvalidaError('commandId é obrigatório e deve ter no mínimo 8 caracteres.');
  }

  if (
    !payload.equipeId ||
    typeof payload.equipeId !== 'string' ||
    payload.equipeId.trim().length === 0
  ) {
    throw new SolicitacaoInvalidaError('equipeId é obrigatório.');
  }

  const correlationId =
    typeof payload.correlationId === 'string' && payload.correlationId.trim().length > 0
      ? payload.correlationId.trim()
      : undefined;

  const equipeId = payload.equipeId.trim();
  const payloadHash = calcularPayloadHashSolicitarEquipe(equipeId);

  return {
    commandId: payload.commandId.trim(),
    equipeId,
    correlationId,
    payloadHash,
  };
}
