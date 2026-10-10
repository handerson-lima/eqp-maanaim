import { createHash } from 'node:crypto';
import { normalizarNome } from './importacaoPastores.js';
export { normalizarNome };

/** Versão do dataset canônico; incrementada sempre que o catálogo inicial muda. */
export const VERSAO_DATASET_CATALOGO = 1;

export const REGEX_CODIGO_IGREJA = /^\d{6}$/;

/** Uma igreja do dataset canônico, sem PII. */
export type ItemSeedIgreja = { codigo: string; nome: string };

/** Uma equipe do dataset canônico; responsáveis são geridos na Story 1.4. */
export type ItemSeedEquipe = { nome: string };

export type DatasetCatalogo = {
  versao: number;
  igrejas: ItemSeedIgreja[];
  equipes: ItemSeedEquipe[];
};

export type IgrejaCatalogo = {
  id: string;
  codigo: string;
  nome: string;
  ativo: boolean;
};

export type EquipeCatalogo = {
  id: string;
  nome: string;
  nomeNormalizado: string;
  ativo: boolean;
};

export type IgrejaCatalogoConsulta = IgrejaCatalogo & { rotulo: string };

export type ResumoCatalogo = {
  igrejas: IgrejaCatalogoConsulta[];
  equipes: EquipeCatalogo[];
};

export type ContextoSeedCatalogo = {
  commandId: string;
  correlacaoId: string;
  atorUid: string;
  origem: string;
};

export type ResultadoSemeadura = {
  repetido: boolean;
  datasetVersao: number;
  igrejasCriadas: number;
  equipesCriadas: number;
  totalIgrejas: number;
  totalEquipes: number;
};

export class ComandoDivergenteError extends Error {
  constructor() {
    super('COMANDO_DIVERGENTE');
    this.name = 'ComandoDivergenteError';
  }
}

export class SemAutoridadeError extends Error {
  constructor() {
    super('SEM_AUTORIDADE');
    this.name = 'SemAutoridadeError';
  }
}

export class DatasetInvalidoError extends Error {
  constructor(public readonly problemas: ProblemaDataset[]) {
    super('DATASET_INVALIDO');
    this.name = 'DatasetInvalidoError';
  }
}

export type TipoEntidadeCatalogo = 'IGREJA' | 'EQUIPE';

export type EntradaAlternarStatusIgreja = {
  commandId: string;
  igrejaId: string;
  ativo: boolean;
  correlationId?: string;
};

export type EntradaAlternarStatusEquipe = {
  commandId: string;
  equipeId: string;
  ativo: boolean;
  correlationId?: string;
};

export type ResultadoAlternarStatus = {
  repetido: boolean;
  id: string;
  ativo: boolean;
};

export class CodigoIgrejaDuplicadoError extends Error {
  constructor(public readonly codigo: string) {
    super(`CODIGO_IGREJA_DUPLICADO: ${codigo}`);
    this.name = 'CodigoIgrejaDuplicadoError';
  }
}

export class NomeEquipeDuplicadoError extends Error {
  constructor(public readonly nome: string) {
    super(`NOME_EQUIPE_DUPLICADO: ${nome}`);
    this.name = 'NomeEquipeDuplicadoError';
  }
}

export class ConflitoVersaoError extends Error {
  constructor(mensagem = 'Versão esperada diverge da versão atual.') {
    super(`CONFLITO_VERSAO: ${mensagem}`);
    this.name = 'ConflitoVersaoError';
  }
}

export type EntradaSalvarIgreja = {
  commandId: string;
  correlationId?: string;
  igrejaId?: string;
  codigo: string;
  nome: string;
  expectedVersion: number;
};

export type EntradaSalvarEquipe = {
  commandId: string;
  correlationId?: string;
  equipeId?: string;
  nome: string;
  expectedVersion: number;
};

export type ResultadoSalvarCatalogo = {
  id: string;
  repetido: boolean;
  versao: number;
};

export type ResponsavelResumo = {
  pessoaId: string;
  nome: string;
};

export type IgrejaAdmin = {
  id: string;
  codigo: string;
  nome: string;
  ativo: boolean;
  versao: number;
  rotulo: string;
  pastorLocal: ResponsavelResumo | null;
};

export type EquipeAdmin = {
  id: string;
  nome: string;
  nomeNormalizado: string;
  ativo: boolean;
  versao: number;
  responsavel: ResponsavelResumo | null;
};

export type ResumoCatalogoAdmin = {
  igrejas: IgrejaAdmin[];
  equipes: EquipeAdmin[];
};

export class EntidadeInexistenteError extends Error {
  constructor(public readonly entidade: TipoEntidadeCatalogo, public readonly id: string) {
    super(`ENTIDADE_INEXISTENTE: ${entidade} ${id}`);
    this.name = 'EntidadeInexistenteError';
  }
}

export class EntradaInvalidaError extends Error {
  constructor(motivo: string) {
    super(`ENTRADA_INVALIDA: ${motivo}`);
    this.name = 'EntradaInvalidaError';
  }
}

export type ProblemaDataset = { motivo: string; referencia: string };

const REGEX_COMMAND_ID = /^[A-Za-z0-9_-]{16,128}$/;

export function validarCommandId(commandId: string): boolean {
  return REGEX_COMMAND_ID.test(commandId);
}

export function validarAlternarStatusIgreja(dados: unknown): EntradaAlternarStatusIgreja {
  if (!dados || typeof dados !== 'object') {
    throw new EntradaInvalidaError('Dados devem ser um objeto');
  }
  const d = dados as Record<string, unknown>;
  const commandId = typeof d.commandId === 'string' ? d.commandId.trim() : '';
  if (!validarCommandId(commandId)) {
    throw new EntradaInvalidaError('commandId inválido');
  }
  const igrejaId = typeof d.igrejaId === 'string' ? d.igrejaId.trim() : '';
  if (!igrejaId || igrejaId.length > 128) {
    throw new EntradaInvalidaError('igrejaId inválido');
  }
  if (typeof d.ativo !== 'boolean') {
    throw new EntradaInvalidaError('ativo deve ser booleano');
  }
  const correlationId =
    typeof d.correlationId === 'string' && d.correlationId.trim()
      ? d.correlationId.trim()
      : undefined;
  return {
    commandId,
    igrejaId,
    ativo: d.ativo,
    correlationId,
  };
}

export function validarAlternarStatusEquipe(dados: unknown): EntradaAlternarStatusEquipe {
  if (!dados || typeof dados !== 'object') {
    throw new EntradaInvalidaError('Dados devem ser um objeto');
  }
  const d = dados as Record<string, unknown>;
  const commandId = typeof d.commandId === 'string' ? d.commandId.trim() : '';
  if (!validarCommandId(commandId)) {
    throw new EntradaInvalidaError('commandId inválido');
  }
  const equipeId = typeof d.equipeId === 'string' ? d.equipeId.trim() : '';
  if (!equipeId || equipeId.length > 128) {
    throw new EntradaInvalidaError('equipeId inválido');
  }
  if (typeof d.ativo !== 'boolean') {
    throw new EntradaInvalidaError('ativo deve ser booleano');
  }
  const correlationId =
    typeof d.correlationId === 'string' && d.correlationId.trim()
      ? d.correlationId.trim()
      : undefined;
  return {
    commandId,
    equipeId,
    ativo: d.ativo,
    correlationId,
  };
}

export function hashAlternarStatus(
  tipo: TipoEntidadeCatalogo,
  id: string,
  ativo: boolean,
): string {
  return createHash('sha256').update(`${tipo}:${id}:${ativo ? 'ATIVO' : 'INATIVO'}`).digest('hex');
}

export function validarSalvarIgreja(dados: unknown): EntradaSalvarIgreja {
  if (!dados || typeof dados !== 'object') {
    throw new EntradaInvalidaError('Dados devem ser um objeto');
  }
  const d = dados as Record<string, unknown>;
  const commandId = typeof d.commandId === 'string' ? d.commandId.trim() : '';
  if (!validarCommandId(commandId)) {
    throw new EntradaInvalidaError('commandId inválido');
  }
  const igrejaId =
    typeof d.igrejaId === 'string' && d.igrejaId.trim()
      ? d.igrejaId.trim()
      : undefined;
  if (igrejaId && igrejaId.length > 128) {
    throw new EntradaInvalidaError('igrejaId inválido');
  }
  const codigo = typeof d.codigo === 'string' ? d.codigo.trim() : '';
  if (!REGEX_CODIGO_IGREJA.test(codigo)) {
    throw new EntradaInvalidaError('Código de igreja inválido (deve ter 6 dígitos numéricos)');
  }
  const nome = typeof d.nome === 'string' ? d.nome.trim() : '';
  if (!nomeValido(nome)) {
    throw new EntradaInvalidaError('Nome de igreja inválido (mínimo 3 e máximo 160 caracteres)');
  }
  const expectedVersion = typeof d.expectedVersion === 'number' ? d.expectedVersion : -1;
  if (!Number.isInteger(expectedVersion) || expectedVersion < 0) {
    throw new EntradaInvalidaError('expectedVersion deve ser um número inteiro maior ou igual a 0');
  }
  const correlationId =
    typeof d.correlationId === 'string' && d.correlationId.trim()
      ? d.correlationId.trim()
      : undefined;
  return {
    commandId,
    igrejaId,
    codigo,
    nome,
    expectedVersion,
    correlationId,
  };
}

export function validarSalvarEquipe(dados: unknown): EntradaSalvarEquipe {
  if (!dados || typeof dados !== 'object') {
    throw new EntradaInvalidaError('Dados devem ser um objeto');
  }
  const d = dados as Record<string, unknown>;
  const commandId = typeof d.commandId === 'string' ? d.commandId.trim() : '';
  if (!validarCommandId(commandId)) {
    throw new EntradaInvalidaError('commandId inválido');
  }
  const equipeId =
    typeof d.equipeId === 'string' && d.equipeId.trim()
      ? d.equipeId.trim()
      : undefined;
  if (equipeId && equipeId.length > 128) {
    throw new EntradaInvalidaError('equipeId inválido');
  }
  const nome = typeof d.nome === 'string' ? d.nome.trim() : '';
  if (!nomeValido(nome)) {
    throw new EntradaInvalidaError('Nome de equipe inválido (mínimo 3 e máximo 160 caracteres)');
  }
  const expectedVersion = typeof d.expectedVersion === 'number' ? d.expectedVersion : -1;
  if (!Number.isInteger(expectedVersion) || expectedVersion < 0) {
    throw new EntradaInvalidaError('expectedVersion deve ser um número inteiro maior ou igual a 0');
  }
  const correlationId =
    typeof d.correlationId === 'string' && d.correlationId.trim()
      ? d.correlationId.trim()
      : undefined;
  return {
    commandId,
    equipeId,
    nome,
    expectedVersion,
    correlationId,
  };
}

export function hashSalvarIgreja(entrada: EntradaSalvarIgreja): string {
  return createHash('sha256')
    .update(`SALVAR_IGREJA:${entrada.igrejaId ?? 'NOVA'}:${entrada.codigo}:${entrada.nome}:${entrada.expectedVersion}`)
    .digest('hex');
}

export function hashSalvarEquipe(entrada: EntradaSalvarEquipe): string {
  return createHash('sha256')
    .update(`SALVAR_EQUIPE:${entrada.equipeId ?? 'NOVA'}:${chaveEquipe(entrada.nome)}:${entrada.expectedVersion}`)
    .digest('hex');
}

function nomeValido(nome: string): boolean {
  return (
    nome.length >= 3 &&
    nome.length <= 160 &&
    /\p{L}/u.test(nome) &&
    !/[\u0000-\u001f\u007f]/.test(nome)
  );
}

/** Chave natural estável de uma igreja: o código String único. */
export function chaveIgreja(codigo: string): string {
  return codigo.trim();
}

/** Chave natural estável de uma equipe: o nome normalizado (sem acento/caixa). */
export function chaveEquipe(nome: string): string {
  return normalizarNome(nome);
}

function idOpaco(prefixo: string, chave: string): string {
  return `${prefixo}${createHash('sha256').update(chave).digest('hex').slice(0, 24)}`;
}

/** ID opaco e determinístico da igreja, ancorado ao código do seed. */
export function idIgrejaSeed(codigo: string): string {
  return idOpaco('ig_', `igreja:${chaveIgreja(codigo)}`);
}

/** ID opaco e determinístico da equipe, ancorado ao nome normalizado do seed. */
export function idEquipeSeed(nome: string): string {
  return idOpaco('eq_', `equipe:${chaveEquipe(nome)}`);
}

/**
 * Valida o dataset inteiro antes de qualquer mutação. Aponta apenas chaves não
 * pessoais (código/nome de catálogo) para não ecoar dados fora do escopo.
 */
export function validarDataset(dataset: DatasetCatalogo): ProblemaDataset[] {
  const problemas: ProblemaDataset[] = [];
  if (dataset.igrejas.length === 0) {
    problemas.push({ motivo: 'DATASET_VAZIO', referencia: 'igrejas' });
  }
  if (dataset.equipes.length === 0) {
    problemas.push({ motivo: 'DATASET_VAZIO', referencia: 'equipes' });
  }

  const codigos = new Set<string>();
  for (const igreja of dataset.igrejas) {
    if (!REGEX_CODIGO_IGREJA.test(igreja.codigo)) {
      problemas.push({ motivo: 'CODIGO_INVALIDO', referencia: igreja.codigo });
      continue;
    }
    if (codigos.has(igreja.codigo)) {
      problemas.push({ motivo: 'CODIGO_DUPLICADO', referencia: igreja.codigo });
    }
    codigos.add(igreja.codigo);
    if (!nomeValido(igreja.nome)) {
      problemas.push({ motivo: 'NOME_INVALIDO', referencia: igreja.codigo });
    }
  }

  const nomes = new Set<string>();
  for (const equipe of dataset.equipes) {
    const chave = chaveEquipe(equipe.nome);
    if (!nomeValido(equipe.nome)) {
      problemas.push({ motivo: 'NOME_INVALIDO', referencia: chave });
      continue;
    }
    if (nomes.has(chave)) {
      problemas.push({ motivo: 'NOME_DUPLICADO', referencia: chave });
    }
    nomes.add(chave);
  }
  return problemas;
}

/** Vincula recibo e auditoria ao conteúdo canônico do dataset. */
export function hashDataset(dataset: DatasetCatalogo): string {
  const canonico = JSON.stringify({
    versao: dataset.versao,
    igrejas: dataset.igrejas.map((igreja) => ({
      codigo: igreja.codigo,
      nome: igreja.nome,
    })),
    equipes: dataset.equipes.map((equipe) => ({ nome: equipe.nome })),
  });
  return createHash('sha256').update(canonico).digest('hex');
}

/** Planeja apenas os registros ausentes; existentes jamais são alterados. */
export function igrejasAusentes(
  dataset: DatasetCatalogo,
  existentes: IgrejaCatalogo[],
): ItemSeedIgreja[] {
  const chaves = new Set(existentes.map((igreja) => chaveIgreja(igreja.codigo)));
  const ids = new Set(existentes.map((igreja) => igreja.id));
  return dataset.igrejas.filter(
    (item) =>
      !chaves.has(chaveIgreja(item.codigo)) && !ids.has(idIgrejaSeed(item.codigo)),
  );
}

export function equipesAusentes(
  dataset: DatasetCatalogo,
  existentes: EquipeCatalogo[],
): ItemSeedEquipe[] {
  const chaves = new Set(existentes.map((equipe) => chaveEquipe(equipe.nome)));
  const ids = new Set(existentes.map((equipe) => equipe.id));
  return dataset.equipes.filter(
    (item) => !chaves.has(chaveEquipe(item.nome)) && !ids.has(idEquipeSeed(item.nome)),
  );
}

function compararPorNome(a: { nome: string }, b: { nome: string }): number {
  return a.nome.localeCompare(b.nome, 'pt-BR', { sensitivity: 'base' });
}

export function ordenarPorNome<T extends { nome: string }>(itens: T[]): T[] {
  return [...itens].sort(compararPorNome);
}

export function rotuloIgreja(igreja: { nome: string; codigo: string }): string {
  return `${igreja.nome} - ${igreja.codigo}`;
}

/** Pesquisa por nome (sem acento/caixa) ou código (exato/parcial). */
export function correspondePesquisa(
  item: { nome: string; codigo?: string },
  termo: string,
): boolean {
  const alvo = normalizarNome(termo);
  if (!alvo) return true;
  if (normalizarNome(item.nome).includes(alvo)) return true;
  return (item.codigo ?? '').includes(termo.trim());
}

export function pesquisarIgrejas(
  igrejas: IgrejaCatalogo[],
  termo: string,
): IgrejaCatalogo[] {
  return ordenarPorNome(igrejas.filter((igreja) => correspondePesquisa(igreja, termo)));
}

export function pesquisarEquipes(
  equipes: EquipeCatalogo[],
  termo: string,
): EquipeCatalogo[] {
  return ordenarPorNome(equipes.filter((equipe) => correspondePesquisa(equipe, termo)));
}
