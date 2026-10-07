import { createHash } from 'node:crypto';

export class SolicitacaoInvalidaError extends Error {
  constructor(message = 'Dados de solicitação inválidos.') {
    super(message);
    this.name = 'SolicitacaoInvalidaError';
  }
}

export interface EntradaExpirarCiclos {
  commandId: string;
  correlationId?: string;
  agoraIso?: string;
  limite?: number;
  dryRun?: boolean;
  payloadHash: string;
}

export interface DetalheParticipacaoExpirada {
  participacaoId: string;
  fichaId: string;
  equipeId: string;
  cicloId?: string | null;
  fichaEstadoAnterior: string;
  fichaNovoEstado: string;
}

export interface ResultadoExpirarCiclos {
  sucesso: boolean;
  repetido: boolean;
  commandId: string;
  totalVerificadas: number;
  totalExpiradas: number;
  expiradas: DetalheParticipacaoExpirada[];
  processadoEm: string;
}

export function calcularPayloadHashExpirarCiclos(dados: {
  commandId: string;
  agoraIso?: string;
  limite?: number;
}): string {
  return createHash('sha256')
    .update(
      JSON.stringify({
        commandId: dados.commandId.trim(),
        agoraIso: dados.agoraIso?.trim() ?? '',
        limite: dados.limite ?? 100,
      }),
    )
    .digest('hex');
}

export function validarExpirarCiclos(dados: unknown): EntradaExpirarCiclos {
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

  const commandId = payload.commandId.trim();
  const agoraIso = typeof payload.agoraIso === 'string' ? payload.agoraIso.trim() : undefined;
  if (agoraIso !== undefined && agoraIso !== '' && Number.isNaN(Date.parse(agoraIso))) {
    throw new SolicitacaoInvalidaError('agoraIso inválido.');
  }
  const limite =
    typeof payload.limite === 'number' && Number.isInteger(payload.limite) && payload.limite > 0
      ? payload.limite
      : 100;
  const dryRun = Boolean(payload.dryRun);

  return {
    commandId,
    correlationId:
      typeof payload.correlationId === 'string' ? payload.correlationId.trim() : undefined,
    agoraIso,
    limite,
    dryRun,
    payloadHash: calcularPayloadHashExpirarCiclos({ commandId, agoraIso, limite }),
  };
}
