import { createHash } from 'node:crypto';

import {
  AutoridadeInsuficienteError,
  ComandoDivergenteError,
  MotivoObrigatorioLiderancaError,
  SolicitacaoInvalidaError,
} from './cancelarParticipacao.js';

export {
  AutoridadeInsuficienteError,
  ComandoDivergenteError,
  MotivoObrigatorioLiderancaError,
  SolicitacaoInvalidaError,
};

export class FichaNaoEncontradaError extends Error {
  constructor(message = 'Ficha de voluntariado não encontrada.') {
    super(message);
    this.name = 'FichaNaoEncontradaError';
  }
}

export class FichaJaTerminalError extends Error {
  constructor(message = 'Ficha de voluntariado já se encontra em estado terminal.') {
    super(message);
    this.name = 'FichaJaTerminalError';
  }
}

export interface EntradaCancelarVoluntariado {
  commandId: string;
  fichaId: string;
  motivo?: string;
  correlationId?: string;
  payloadHash: string;
}

export interface ResultadoCancelarVoluntariado {
  sucesso: boolean;
  repetido: boolean;
  fichaId: string;
  estado: 'CANCELADA';
  participacoesAfetadas: string[];
  canceladoEm: string;
}

export function calcularPayloadHashCancelarVoluntariado(
  fichaId: string,
  motivo?: string,
): string {
  return createHash('sha256')
    .update(
      JSON.stringify({
        fichaId: fichaId.trim(),
        motivo: motivo?.trim() ?? '',
      }),
    )
    .digest('hex');
}

export function validarCancelarVoluntariado(dados: unknown): EntradaCancelarVoluntariado {
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
    !payload.fichaId ||
    typeof payload.fichaId !== 'string' ||
    !payload.fichaId.trim()
  ) {
    throw new SolicitacaoInvalidaError('fichaId é obrigatório.');
  }

  const motivo = typeof payload.motivo === 'string' ? payload.motivo.trim() : undefined;

  return {
    commandId: payload.commandId.trim(),
    fichaId: payload.fichaId.trim(),
    motivo,
    correlationId:
      typeof payload.correlationId === 'string' ? payload.correlationId.trim() : undefined,
    payloadHash: calcularPayloadHashCancelarVoluntariado(payload.fichaId, motivo),
  };
}
