import { createHash } from 'node:crypto';
import { classificarVigencia } from './vigencia.js';

export type DecisaoRenovacao = 'CONTINUAR' | 'NAO_CONTINUAR';

export class SolicitacaoInvalidaError extends Error {
  constructor(message = 'Dados de solicitação de renovação inválidos.') {
    super(message);
    this.name = 'SolicitacaoInvalidaError';
  }
}

export class PermissaoNegadaError extends Error {
  constructor(message = 'Permissão negada para manifestar renovação desta participação.') {
    super(message);
    this.name = 'PermissaoNegadaError';
  }
}

export class ComandoDivergenteError extends Error {
  constructor(message = 'Comando já registrado com dados divergentes.') {
    super(message);
    this.name = 'ComandoDivergenteError';
  }
}

export class FichaNaoEncontradaError extends Error {
  constructor(message = 'Ficha cadastral não encontrada.') {
    super(message);
    this.name = 'FichaNaoEncontradaError';
  }
}

export class ParticipacaoNaoEncontradaError extends Error {
  constructor(message = 'Participação não encontrada.') {
    super(message);
    this.name = 'ParticipacaoNaoEncontradaError';
  }
}

export class ParticipacaoNaoElegivelError extends Error {
  constructor(message = 'Participação não está em situação elegível para renovação (deve estar ATIVA).') {
    super(message);
    this.name = 'ParticipacaoNaoElegivelError';
  }
}

export class JanelaRenovacaoFechadaError extends Error {
  constructor(message = 'A janela de renovação para esta equipe ainda não está aberta.') {
    super(message);
    this.name = 'JanelaRenovacaoFechadaError';
  }
}

export interface ItemManifestacaoRenovacao {
  participacaoId: string;
  decisao: DecisaoRenovacao;
  justificativa?: string;
}

export interface EntradaManifestarRenovacao {
  commandId: string;
  correlationId?: string;
  manifestacoes: ItemManifestacaoRenovacao[];
  payloadHash: string;
}

export interface DetalheResultadoRenovacaoItem {
  participacaoId: string;
  equipeId: string;
  nomeEquipe: string;
  decisao: DecisaoRenovacao;
  cicloId?: string | null;
  anoVigencia?: number | null;
  estadoCiclo?: string | null;
  proximaAcao: string;
}

export interface ResultadoManifestarRenovacao {
  sucesso: boolean;
  repetido: boolean;
  commandId: string;
  itens: DetalheResultadoRenovacaoItem[];
  processadoEm: string;
}

export function calcularPayloadHashManifestarRenovacao(dados: {
  commandId: string;
  manifestacoes: ItemManifestacaoRenovacao[];
}): string {
  const normalizadas = dados.manifestacoes.map((m) => ({
    participacaoId: m.participacaoId.trim(),
    decisao: m.decisao,
    justificativa: m.justificativa?.trim() ?? '',
  })).sort((a, b) => a.participacaoId.localeCompare(b.participacaoId));

  return createHash('sha256')
    .update(
      JSON.stringify({
        commandId: dados.commandId.trim(),
        manifestacoes: normalizadas,
      }),
    )
    .digest('hex');
}

export function validarManifestarRenovacao(dados: unknown): EntradaManifestarRenovacao {
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

  // Suporte a manifestacoes em lista ou item único legado ({ participacaoId, decisao })
  let rawLista: unknown[] = [];
  if (Array.isArray(payload.manifestacoes)) {
    rawLista = payload.manifestacoes;
  } else if (payload.participacaoId && payload.decisao) {
    rawLista = [
      {
        participacaoId: payload.participacaoId,
        decisao: payload.decisao,
        justificativa: payload.justificativa,
      },
    ];
  }

  if (rawLista.length === 0) {
    throw new SolicitacaoInvalidaError('Ao menos uma manifestação de equipe deve ser informada.');
  }

  const manifestacoes: ItemManifestacaoRenovacao[] = [];
  const idsVistos = new Set<string>();

  for (const item of rawLista) {
    if (!item || typeof item !== 'object') {
      throw new SolicitacaoInvalidaError('Item de manifestação inválido.');
    }
    const itemObj = item as Record<string, unknown>;
    const participacaoId = typeof itemObj.participacaoId === 'string' ? itemObj.participacaoId.trim() : '';
    if (!participacaoId) {
      throw new SolicitacaoInvalidaError('participacaoId é obrigatório em cada manifestação.');
    }
    if (idsVistos.has(participacaoId)) {
      throw new SolicitacaoInvalidaError(`participacaoId duplicado na mesma solicitação: ${participacaoId}`);
    }
    idsVistos.add(participacaoId);

    const decisaoStr = String(itemObj.decisao ?? '').trim().toUpperCase();
    if (decisaoStr !== 'CONTINUAR' && decisaoStr !== 'NAO_CONTINUAR') {
      throw new SolicitacaoInvalidaError("decisao deve ser 'CONTINUAR' ou 'NAO_CONTINUAR'.");
    }

    const justificativa =
      typeof itemObj.justificativa === 'string' && itemObj.justificativa.trim().length > 0
        ? itemObj.justificativa.trim()
        : undefined;

    manifestacoes.push({
      participacaoId,
      decisao: decisaoStr as DecisaoRenovacao,
      justificativa,
    });
  }

  const correlationId =
    typeof payload.correlationId === 'string' && payload.correlationId.trim().length > 0
      ? payload.correlationId.trim()
      : undefined;

  return {
    commandId,
    correlationId,
    manifestacoes,
    payloadHash: calcularPayloadHashManifestarRenovacao({ commandId, manifestacoes }),
  };
}

export { classificarVigencia };
