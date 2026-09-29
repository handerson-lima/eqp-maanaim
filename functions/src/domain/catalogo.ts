import { createHash } from 'node:crypto';
import { normalizarNome } from './importacaoPastores.js';

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
  nomeNormalizado: string;
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
  agora: Date;
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

export type ProblemaDataset = { motivo: string; referencia: string };

const REGEX_COMMAND_ID = /^[A-Za-z0-9_-]{16,128}$/;

export function validarCommandId(commandId: string): boolean {
  return REGEX_COMMAND_ID.test(commandId);
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
