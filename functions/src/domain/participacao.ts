import { createHash } from 'node:crypto';

export class EquipeInvalidaError extends Error {
  constructor(message = 'Equipe inválida ou inativa') {
    super(message);
    this.name = 'EquipeInvalidaError';
  }
}

export class FichaNaoEncontradaError extends Error {
  constructor(message = 'Ficha permanente não encontrada') {
    super(message);
    this.name = 'FichaNaoEncontradaError';
  }
}

export class ComandoDivergenteError extends Error {
  constructor(message = 'Operação já registrada com dados divergentes.') {
    super(message);
    this.name = 'ComandoDivergenteError';
  }
}

export class ParticipacaoInvalidaError extends Error {
  constructor(message = 'Dados de participação inválidos.') {
    super(message);
    this.name = 'ParticipacaoInvalidaError';
  }
}

export const MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA =
  'Procure o Pastor da igreja local para mais informações';

export interface ParticipacaoRascunho {
  id: string;
  fichaId: string;
  equipeId: string;
  nomeEquipe: string;
  estado: string;
  ciclo: string;
  proximaAcao: string;
  vigenciaInicio?: string | null;
  vigenciaFim?: string | null;
  cicloAtualId?: string | null;
  criadoEm?: string | null;
  atualizadoEm?: string | null;
}


export interface EntradaSalvarParticipacoesRascunho {
  commandId: string;
  equipeIds: string[];
  payloadHash: string;
}

export function calcularPayloadHashParticipacoes(equipeIds: string[]): string {
  const normalizados = Array.from(new Set(equipeIds.map((id) => id.trim()))).sort();
  return createHash('sha256').update(JSON.stringify(normalizados)).digest('hex');
}

export function validarSalvarParticipacoes(dados: unknown): EntradaSalvarParticipacoesRascunho {
  if (!dados || typeof dados !== 'object') {
    throw new ParticipacaoInvalidaError('Corpo da requisição inválido.');
  }

  const payload = dados as Record<string, unknown>;

  if (
    !payload.commandId ||
    typeof payload.commandId !== 'string' ||
    payload.commandId.trim().length < 8
  ) {
    throw new ParticipacaoInvalidaError('commandId é obrigatório e deve ter no mínimo 8 caracteres.');
  }

  if (!Array.isArray(payload.equipeIds)) {
    throw new ParticipacaoInvalidaError('equipeIds deve ser uma lista de IDs de equipes.');
  }

  const equipeIds: string[] = [];
  for (const item of payload.equipeIds) {
    if (typeof item !== 'string' || item.trim().length === 0) {
      throw new ParticipacaoInvalidaError('ID de equipe inválido na lista.');
    }
    equipeIds.push(item.trim());
  }

  const equipeIdsUnicos = Array.from(new Set(equipeIds));
  const payloadHash = calcularPayloadHashParticipacoes(equipeIdsUnicos);

  return {
    commandId: payload.commandId.trim(),
    equipeIds: equipeIdsUnicos,
    payloadHash,
  };
}
