import { createHash } from 'node:crypto';

export const TIPOS_ENTIDADE = ['IGREJA', 'EQUIPE'] as const;
export type TipoEntidade = (typeof TIPOS_ENTIDADE)[number];

export const ACOES_VINCULO = ['ATRIBUIR', 'SUBSTITUIR', 'ENCERRAR'] as const;
export type AcaoVinculo = (typeof ACOES_VINCULO)[number];

export const PAPEIS_VINCULO = ['PASTOR_LOCAL', 'PASTOR_EQUIPE'] as const;
export type PapelVinculo = (typeof PAPEIS_VINCULO)[number];

export const ESTADOS_VINCULO = ['VIGENTE', 'ENCERRADO'] as const;
export type EstadoVinculo = (typeof ESTADOS_VINCULO)[number];

/** Campos canônicos do par vigente conforme o tipo de entidade. */
export type CamposVigente = {
  colecao: 'igrejas' | 'equipes';
  colecaoVinculos: 'vinculosPastorIgreja' | 'vinculosPastorEquipe';
  pessoa: 'pastorLocalVigentePessoaId' | 'responsavelVigentePessoaId';
  vinculo: 'pastorLocalVigenteVinculoId' | 'responsavelVigenteVinculoId';
};

const REGEX_COMMAND_ID = /^[A-Za-z0-9_-]{16,128}$/;
const REGEX_ID = /^[A-Za-z0-9_-]{1,128}$/;
const REGEX_DATA = /^(\d{4})-(\d{2})-(\d{2})$/;

const CAMPOS_VINCULO = [
  'commandId',
  'correlationId',
  'tipoEntidade',
  'entidadeId',
  'acao',
  'pessoaId',
  'dataEfetiva',
  'justificativa',
  'expectedVersion',
] as const;

export type EntradaVinculo = {
  commandId: string;
  correlationId: string | null;
  tipoEntidade: TipoEntidade;
  entidadeId: string;
  acao: AcaoVinculo;
  /** Pessoa designada; ausente somente em ENCERRAR. */
  pessoaId: string | null;
  /** Data efetiva no formato `YYYY-MM-DD`, sempre UTC. */
  dataEfetiva: string;
  /** Data efetiva reduzida a milissegundos de meia-noite UTC. */
  dataEfetivaMs: number;
  justificativa: string | null;
  expectedVersion: number;
  payloadHash: string;
};

export type VigenteAtual = {
  vinculoId: string;
  pessoaId: string;
  /** Início do vínculo vigente; nulo quando o legado não gravou o timestamp. */
  inicioVigenciaMs: number | null;
};

export type EstadoEntidadeVinculo = {
  ativo: boolean;
  vigente: VigenteAtual | null;
  versaoVinculo: number;
};

/** Plano puro da transição: fechar o anterior e/ou criar o novo. */
export type PlanoVinculo = {
  encerrarVinculoId: string | null;
  fimVigenciaMs: number | null;
  criar: { pessoaId: string; inicioVigenciaMs: number } | null;
};

export type ResponsavelVinculo = { pessoaId: string; nome: string };

/** Evento histórico imutável, sem PII e sem e-mail. */
export type EventoHistoricoVinculo = {
  acao: AcaoVinculo;
  papel: PapelVinculo;
  estado: EstadoVinculo;
  atorUid: string;
  atorNome: string;
  inicioVigencia: string;
  fimVigencia: string | null;
  justificativa: string | null;
  encerradoPorUid: string | null;
};

export type EntidadeVinculoResumo = {
  id: string;
  tipoEntidade: TipoEntidade;
  rotulo: string;
  codigo: string | null;
  ativo: boolean;
  versaoVinculo: number;
  responsavel: ResponsavelVinculo | null;
  historico: EventoHistoricoVinculo[];
};

export type ResumoVinculos = {
  igrejas: EntidadeVinculoResumo[];
  equipes: EntidadeVinculoResumo[];
};

export class VinculoInvalidoError extends Error {
  constructor() {
    super('VINCULO_INVALIDO');
    this.name = 'VinculoInvalidoError';
  }
}

export class EntidadeInexistenteError extends Error {
  constructor() {
    super('ENTIDADE_INEXISTENTE');
    this.name = 'EntidadeInexistenteError';
  }
}

export class PessoaInexistenteError extends Error {
  constructor() {
    super('PESSOA_INEXISTENTE');
    this.name = 'PessoaInexistenteError';
  }
}

export class SemAutoridadeError extends Error {
  constructor() {
    super('SEM_AUTORIDADE');
    this.name = 'SemAutoridadeError';
  }
}

export class ComandoDivergenteError extends Error {
  constructor() {
    super('COMANDO_DIVERGENTE');
    this.name = 'ComandoDivergenteError';
  }
}

export class ConflitoVersaoError extends Error {
  constructor() {
    super('CONFLITO_VERSAO');
    this.name = 'ConflitoVersaoError';
  }
}

export class DataInvalidaError extends Error {
  constructor() {
    super('DATA_INVALIDA');
    this.name = 'DataInvalidaError';
  }
}

export class SobreposicaoError extends Error {
  constructor() {
    super('SOBREPOSICAO');
    this.name = 'SobreposicaoError';
  }
}

export class VigenteExistenteError extends Error {
  constructor() {
    super('VIGENTE_EXISTENTE');
    this.name = 'VigenteExistenteError';
  }
}

export class VinculoInexistenteError extends Error {
  constructor() {
    super('VINCULO_INEXISTENTE');
    this.name = 'VinculoInexistenteError';
  }
}

export class OperacaoInvalidaError extends Error {
  constructor() {
    super('OPERACAO_INVALIDA');
    this.name = 'OperacaoInvalidaError';
  }
}

export function ehTipoEntidade(valor: unknown): valor is TipoEntidade {
  return typeof valor === 'string' && (TIPOS_ENTIDADE as readonly string[]).includes(valor);
}

export function ehAcaoVinculo(valor: unknown): valor is AcaoVinculo {
  return typeof valor === 'string' && (ACOES_VINCULO as readonly string[]).includes(valor);
}

export function validarCommandId(commandId: string): boolean {
  return REGEX_COMMAND_ID.test(commandId);
}

/** Papel de vínculo canônico de cada tipo de entidade. */
export function papelDoTipo(tipo: TipoEntidade): PapelVinculo {
  return tipo === 'IGREJA' ? 'PASTOR_LOCAL' : 'PASTOR_EQUIPE';
}

/** Campos de ponteiro vigente no documento canônico da entidade. */
export function camposVigente(tipo: TipoEntidade): CamposVigente {
  return tipo === 'IGREJA'
    ? {
        colecao: 'igrejas',
        colecaoVinculos: 'vinculosPastorIgreja',
        pessoa: 'pastorLocalVigentePessoaId',
        vinculo: 'pastorLocalVigenteVinculoId',
      }
    : {
        colecao: 'equipes',
        colecaoVinculos: 'vinculosPastorEquipe',
        pessoa: 'responsavelVigentePessoaId',
        vinculo: 'responsavelVigenteVinculoId',
      };
}

function texto(valor: unknown): string {
  return typeof valor === 'string' ? valor : '';
}

function chavesPermitidas(
  valor: Record<string, unknown>,
  permitidas: readonly string[],
): boolean {
  return Object.keys(valor).every((chave) => permitidas.includes(chave));
}

/** Converte `YYYY-MM-DD` em meia-noite UTC; retorna nulo se a data não existir. */
export function dataEfetivaEmMs(valor: string): number | null {
  const encontrado = valor.match(REGEX_DATA);
  if (!encontrado) return null;
  const ano = Number(encontrado[1]);
  const mes = Number(encontrado[2]);
  const dia = Number(encontrado[3]);
  if (ano < 2000 || ano > 2100) return null;
  const ms = Date.UTC(ano, mes - 1, dia);
  const data = new Date(ms);
  if (
    data.getUTCFullYear() !== ano ||
    data.getUTCMonth() !== mes - 1 ||
    data.getUTCDate() !== dia
  ) {
    return null;
  }
  return ms;
}

function justificativaValida(valor: string): boolean {
  return valor.length <= 500 && !/[\u0000-\u001f\u007f]/.test(valor);
}

/** Valida o comando de vínculo; rejeita campos fora do contrato e erro de tipo. */
export function validarVinculo(value: unknown): EntradaVinculo {
  if (typeof value !== 'object' || value === null) throw new VinculoInvalidoError();
  const v = value as Record<string, unknown>;
  if (!chavesPermitidas(v, CAMPOS_VINCULO)) throw new VinculoInvalidoError();

  const commandId = texto(v.commandId);
  if (!validarCommandId(commandId)) throw new VinculoInvalidoError();
  const correlationId =
    v.correlationId === undefined || v.correlationId === null
      ? null
      : texto(v.correlationId);
  if (correlationId !== null && !validarCommandId(correlationId)) {
    throw new VinculoInvalidoError();
  }
  if (!ehTipoEntidade(v.tipoEntidade)) throw new VinculoInvalidoError();
  const entidadeId = texto(v.entidadeId);
  if (!REGEX_ID.test(entidadeId)) throw new VinculoInvalidoError();
  if (!ehAcaoVinculo(v.acao)) throw new VinculoInvalidoError();
  const acao = v.acao;

  let pessoaId: string | null = null;
  if (acao === 'ENCERRAR') {
    if (v.pessoaId !== undefined && v.pessoaId !== null) throw new VinculoInvalidoError();
  } else {
    pessoaId = texto(v.pessoaId);
    if (!REGEX_ID.test(pessoaId)) throw new VinculoInvalidoError();
  }

  const dataEfetiva = texto(v.dataEfetiva);
  const dataEfetivaMs = dataEfetivaEmMs(dataEfetiva);
  if (dataEfetivaMs === null) throw new VinculoInvalidoError();

  const justificativa =
    v.justificativa === undefined || v.justificativa === null
      ? null
      : texto(v.justificativa).trim();
  if (justificativa !== null && !justificativaValida(justificativa)) {
    throw new VinculoInvalidoError();
  }

  if (
    typeof v.expectedVersion !== 'number' ||
    !Number.isInteger(v.expectedVersion) ||
    v.expectedVersion < 0
  ) {
    throw new VinculoInvalidoError();
  }

  const entrada: EntradaVinculo = {
    commandId,
    correlationId,
    tipoEntidade: v.tipoEntidade,
    entidadeId,
    acao,
    pessoaId,
    dataEfetiva,
    dataEfetivaMs,
    justificativa: justificativa === '' ? null : justificativa,
    expectedVersion: v.expectedVersion,
    payloadHash: '',
  };
  entrada.payloadHash = hashVinculo(entrada);
  return entrada;
}

/**
 * Liga o recibo ao conteúdo do comando sem persistir PII: IDs opacos, a ação, a
 * data efetiva e a justificativa entram no hash. A justificativa é vinculada
 * para que um replay divergente não devolva o recibo de outro payload.
 */
export function hashVinculo(entrada: EntradaVinculo): string {
  return createHash('sha256')
    .update(
      JSON.stringify({
        tipoEntidade: entrada.tipoEntidade,
        entidadeId: entrada.entidadeId,
        acao: entrada.acao,
        pessoaId: entrada.pessoaId ?? '',
        dataEfetivaMs: entrada.dataEfetivaMs,
        justificativa: entrada.justificativa ?? '',
        correlationId: entrada.correlationId ?? '',
        expectedVersion: entrada.expectedVersion,
      }),
    )
    .digest('hex');
}

function validarIntervalo(dataEfetivaMs: number, vigente: VigenteAtual): void {
  // O intervalo é semiaberto [inicio, fim); encerrar antes do início criaria
  // sobreposição/intervalo inválido.
  if (vigente.inicioVigenciaMs !== null && dataEfetivaMs < vigente.inicioVigenciaMs) {
    throw new SobreposicaoError();
  }
}

/**
 * Planeja a transição temporal sem tocar em Firestore. Garante exatamente um
 * responsável vigente, sem sobreposição e sem data futura.
 */
export function planejarVinculo(
  entrada: EntradaVinculo,
  entidade: EstadoEntidadeVinculo,
  agoraMs: number,
): PlanoVinculo {
  if (!entidade.ativo) throw new EntidadeInexistenteError();
  if (entidade.versaoVinculo !== entrada.expectedVersion) {
    throw new ConflitoVersaoError();
  }
  // A data efetiva é escolhida pelo administrador e nunca pode ser futura.
  if (entrada.dataEfetivaMs > agoraMs) throw new DataInvalidaError();

  const vigente = entidade.vigente;

  if (entrada.acao === 'ENCERRAR') {
    if (!vigente) throw new VinculoInexistenteError();
    validarIntervalo(entrada.dataEfetivaMs, vigente);
    return {
      encerrarVinculoId: vigente.vinculoId,
      fimVigenciaMs: entrada.dataEfetivaMs,
      criar: null,
    };
  }

  const pessoaId = entrada.pessoaId;
  if (!pessoaId) throw new VinculoInvalidoError();

  if (entrada.acao === 'ATRIBUIR') {
    if (vigente) {
      if (vigente.pessoaId === pessoaId) throw new OperacaoInvalidaError();
      throw new VigenteExistenteError();
    }
    return {
      encerrarVinculoId: null,
      fimVigenciaMs: null,
      criar: { pessoaId, inicioVigenciaMs: entrada.dataEfetivaMs },
    };
  }

  // SUBSTITUIR
  if (!vigente) throw new VinculoInexistenteError();
  if (vigente.pessoaId === pessoaId) throw new OperacaoInvalidaError();
  validarIntervalo(entrada.dataEfetivaMs, vigente);
  return {
    encerrarVinculoId: vigente.vinculoId,
    fimVigenciaMs: entrada.dataEfetivaMs,
    criar: { pessoaId, inicioVigenciaMs: entrada.dataEfetivaMs },
  };
}
