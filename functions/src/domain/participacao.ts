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

export { MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA } from './mensagens.js';

/**
 * Estados canônicos de uma participação. Novos estados (ex.: ciclo anual,
 * cancelamento, reativação) devem ser adicionados aqui para preservar a
 * validação em tempo de compilação.
 */
export type EstadoParticipacao =
  | 'RASCUNHO'
  | 'AGUARDANDO_PASTOR_LOCAL'
  | 'AGUARDANDO_RESPONSAVEL_EQUIPE'
  | 'AGUARDANDO_COORDENADOR'
  | 'ATIVA'
  | 'REJEITADA'
  | 'CANCELADA'
  | 'EXPIRADA'
  | 'INATIVA';

export const ESTADOS_PARTICIPACAO: readonly EstadoParticipacao[] = [
  'RASCUNHO',
  'AGUARDANDO_PASTOR_LOCAL',
  'AGUARDANDO_RESPONSAVEL_EQUIPE',
  'AGUARDANDO_COORDENADOR',
  'ATIVA',
  'REJEITADA',
  'CANCELADA',
  'EXPIRADA',
  'INATIVA',
];

/**
 * Estados terminais canônicos de uma participação (AD-11). Fonte única usada
 * pelo cancelamento e por qualquer fluxo que libere nova solicitação.
 */
export const ESTADOS_TERMINAIS_PARTICIPACAO: readonly string[] = [
  'REJEITADA',
  'CANCELADA',
  'EXPIRADA',
  'INATIVA',
];

export function normalizarEstadoParticipacao(valor: unknown): EstadoParticipacao {
  const estado = String(valor ?? '').trim().toUpperCase();
  return (ESTADOS_PARTICIPACAO as readonly string[]).includes(estado)
    ? (estado as EstadoParticipacao)
    : 'RASCUNHO';
}

export interface ParticipacaoRascunho {
  id: string;
  fichaId: string;
  equipeId: string;
  nomeEquipe: string;
  estado: EstadoParticipacao;
  versao: number;
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
