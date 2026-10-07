import { createHash } from 'node:crypto';

export const REGEX_COMMAND_ID = /^[A-Za-z0-9_-]{16,128}$/;
export const REGEX_ID = /^[A-Za-z0-9_-]{1,128}$/;

export const DECISOES_COORDENADOR = ['APROVADO', 'DESFAVORAVEL'] as const;
export type TipoDecisaoCoordenador = (typeof DECISOES_COORDENADOR)[number];

export const MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA =
  'Procure o Pastor da igreja local para mais informações';

export class DecisaoInvalidaError extends Error {
  constructor(mensagem = 'Dados de decisão do coordenador inválidos.') {
    super(mensagem);
    this.name = 'DecisaoInvalidaError';
  }
}

export class ReuniaoPastoresNaoConfirmadaError extends Error {
  constructor(
    mensagem = 'É obrigatório confirmar a verificação na Reunião de Pastores para ativar o voluntariado.',
  ) {
    super(mensagem);
    this.name = 'ReuniaoPastoresNaoConfirmadaError';
  }
}

export class JustificativaObrigatoriaError extends Error {
  constructor(
    mensagem = 'Justificativa obrigatória para decisão desfavorável (mínimo de 5 caracteres).',
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

export class FichaNaoAguardandoCoordenadorError extends Error {
  constructor(
    mensagem = 'A solicitação não possui participações aguardando conclusão do Coordenador.',
  ) {
    super(mensagem);
    this.name = 'FichaNaoAguardandoCoordenadorError';
  }
}

export class SemAutoridadeCoordenadorError extends Error {
  constructor(
    mensagem = 'O usuário não possui autoridade de Coordenador Geral.',
  ) {
    super(mensagem);
    this.name = 'SemAutoridadeCoordenadorError';
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
  constructor(mensagem = 'Operação já registrada com dados divergentes.') {
    super(mensagem);
    this.name = 'ComandoDivergenteError';
  }
}

export interface EntradaDecidirAtivacaoCoordenador {
  commandId: string;
  correlationId?: string;
  fichaId: string;
  decisao: TipoDecisaoCoordenador;
  confirmouReuniaoPastores: boolean;
  observacao?: string;
  expectedVersion: number;
  payloadHash: string;
}

export interface ResultadoDecidirAtivacaoCoordenador {
  sucesso: boolean;
  repetido: boolean;
  fichaId: string;
  decisao: TipoDecisaoCoordenador;
  estadoFicha: string;
  versaoFicha: number;
  participacoesAtivadas: string[];
  participacoesRejeitadas: string[];
  vigenciaInicio?: string;
  vigenciaFim?: string;
  decididoEm: string;
}

export interface ParticipacaoFilaCoordenador {
  participacaoId: string;
  equipeId: string;
  nomeEquipe: string;
  estado: string;
  proximaAcao: string;
  responsavelNome?: string;
  responsavelDecididoEm?: string;
  justificativaResponsavel?: string;
  elegivelAtivacao: boolean;
}

export interface ItemFilaCoordenador {
  fichaId: string;
  voluntarioUid: string;
  voluntarioNome: string;
  profissao: string;
  cpfMascarado: string;
  igrejaId: string;
  nomeIgreja: string;
  versaoFicha: number;
  enviadoEm: string;
  pastorLocalNome?: string;
  pastorLocalDecididoEm?: string;
  participacoes: ParticipacaoFilaCoordenador[];
}

export interface ResultadoFilaCoordenador {
  pendencias: ItemFilaCoordenador[];
}

export function normalizarDecisaoCoordenador(valor: unknown): TipoDecisaoCoordenador {
  if (typeof valor !== 'string') throw new DecisaoInvalidaError();
  const normalizado = valor.trim().toUpperCase();
  if (normalizado === 'APROVADO' || normalizado === 'DESFAVORAVEL') {
    return normalizado;
  }
  throw new DecisaoInvalidaError(
    `Decisão do coordenador desconhecida: "${valor}". Esperado APROVADO ou DESFAVORAVEL.`,
  );
}

export function calcularPayloadHashDecisaoCoordenador(dados: {
  fichaId: string;
  decisao: TipoDecisaoCoordenador;
  confirmouReuniaoPastores: boolean;
  observacao?: string;
  expectedVersion: number;
}): string {
  const payloadNormalizado = JSON.stringify({
    fichaId: dados.fichaId,
    decisao: dados.decisao,
    confirmouReuniaoPastores: dados.confirmouReuniaoPastores,
    observacao: dados.observacao?.trim() ?? '',
    expectedVersion: dados.expectedVersion,
  });
  return createHash('sha256').update(payloadNormalizado).digest('hex');
}

export function validarDecidirAtivacaoCoordenador(
  payload: unknown,
): EntradaDecidirAtivacaoCoordenador {
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

  const decisao = normalizarDecisaoCoordenador(p.decisao);
  const confirmouReuniaoPastores = p.confirmouReuniaoPastores === true;

  if (decisao === 'APROVADO' && !confirmouReuniaoPastores) {
    throw new ReuniaoPastoresNaoConfirmadaError();
  }

  let observacao: string | undefined;
  if (p.observacao !== undefined && p.observacao !== null) {
    observacao = String(p.observacao).trim();
  }

  if (observacao && observacao.length > 500) {
    throw new DecisaoInvalidaError(
      'Observação/justificativa não pode exceder 500 caracteres.',
    );
  }

  if (decisao === 'DESFAVORAVEL') {
    if (!observacao || observacao.length < 5) {
      throw new JustificativaObrigatoriaError();
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

  const payloadHash = calcularPayloadHashDecisaoCoordenador({
    fichaId,
    decisao,
    confirmouReuniaoPastores,
    observacao,
    expectedVersion,
  });

  return {
    commandId,
    correlationId,
    fichaId,
    decisao,
    confirmouReuniaoPastores,
    observacao,
    expectedVersion,
    payloadHash,
  };
}
