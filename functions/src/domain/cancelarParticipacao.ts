import { createHash } from 'node:crypto';

export class SolicitacaoInvalidaError extends Error {
  constructor(message = 'Dados de solicitação inválidos.') {
    super(message);
    this.name = 'SolicitacaoInvalidaError';
  }
}

export class ParticipacaoNaoEncontradaError extends Error {
  constructor(message = 'Participação não encontrada.') {
    super(message);
    this.name = 'ParticipacaoNaoEncontradaError';
  }
}

export class ParticipacaoJaTerminalError extends Error {
  constructor(message = 'Participação já se encontra em estado terminal.') {
    super(message);
    this.name = 'ParticipacaoJaTerminalError';
  }
}

export class AutoridadeInsuficienteError extends Error {
  constructor(message = 'Usuário não possui autoridade para cancelar esta participação.') {
    super(message);
    this.name = 'AutoridadeInsuficienteError';
  }
}

export class MotivoObrigatorioLiderancaError extends Error {
  constructor(message = 'Motivo é obrigatório para cancelamento realizado por liderança.') {
    super(message);
    this.name = 'MotivoObrigatorioLiderancaError';
  }
}

export class ComandoDivergenteError extends Error {
  constructor(message = 'Operação já registrada com dados divergentes.') {
    super(message);
    this.name = 'ComandoDivergenteError';
  }
}

export class ConflitoVersaoError extends Error {
  constructor(message = 'Versão da participação diverge da versão esperada.') {
    super(message);
    this.name = 'ConflitoVersaoError';
  }
}

export interface EntradaCancelarParticipacao {
  commandId: string;
  participacaoId: string;
  motivo?: string;
  expectedVersion?: number;
  correlationId?: string;
  payloadHash: string;
}

export interface ResultadoCancelarParticipacao {
  sucesso: boolean;
  repetido: boolean;
  participacaoId: string;
  estado: 'CANCELADA';
  proximaAcao: string;
  fichaId: string;
  fichaEstado: string;
  canceladoEm: string;
}

export function calcularPayloadHashCancelarParticipacao(
  participacaoId: string,
  motivo?: string,
): string {
  return createHash('sha256')
    .update(
      JSON.stringify({
        participacaoId: participacaoId.trim(),
        motivo: motivo?.trim() ?? '',
      }),
    )
    .digest('hex');
}

export function validarCancelarParticipacao(dados: unknown): EntradaCancelarParticipacao {
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
    !payload.participacaoId ||
    typeof payload.participacaoId !== 'string' ||
    !payload.participacaoId.trim()
  ) {
    throw new SolicitacaoInvalidaError('participacaoId é obrigatório.');
  }

  const motivo = typeof payload.motivo === 'string' ? payload.motivo.trim() : undefined;
  const expectedVersion =
    typeof payload.expectedVersion === 'number' && Number.isInteger(payload.expectedVersion)
      ? payload.expectedVersion
      : undefined;

  return {
    commandId: payload.commandId.trim(),
    participacaoId: payload.participacaoId.trim(),
    motivo,
    expectedVersion,
    correlationId:
      typeof payload.correlationId === 'string' ? payload.correlationId.trim() : undefined,
    payloadHash: calcularPayloadHashCancelarParticipacao(payload.participacaoId, motivo),
  };
}
