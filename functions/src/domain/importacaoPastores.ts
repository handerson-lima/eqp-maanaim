import { createHash } from 'node:crypto';

/** Origem auditável de toda mutação feita pela carga inicial controlada. */
export const ORIGEM_SEED_INICIAL = 'seed-inicial-do-sistema';
/** Papel registrado no vínculo; a autoridade continua sendo o vínculo vigente (AD-2). */
export const PAPEL_PASTOR_LOCAL = 'PASTOR_LOCAL';

/** Uma linha crua da planilha local, ainda sem validação nem PII exposta. */
export type EntradaBruta = {
  codigoIgreja: unknown;
  nomePastor: unknown;
  email: unknown;
};

/** Linha validada; contém PII apenas em memória, nunca em recibo/auditoria/log. */
export type EntradaValidada = {
  codigoIgreja: string;
  nomeCompleto: string;
  email: string;
  emailNormalizado: string;
  nomeNormalizado: string;
  payloadHash: string;
};

export type StatusLinha = 'CRIADO' | 'JA_VIGENTE' | 'CRIARIA' | 'RECUSADO';

export type MotivoRecusa =
  | 'CODIGO_INVALIDO'
  | 'NOME_INVALIDO'
  | 'EMAIL_INVALIDO'
  | 'CODIGO_DUPLICADO'
  | 'IDENTIDADE_AMBIGUA'
  | 'IGREJA_INEXISTENTE'
  | 'IGREJA_INATIVA'
  | 'CONFLITO_VINCULO'
  | 'COMANDO_DIVERGENTE';

/** Resultado por linha, sem PII: apenas código de igreja, status e motivo. */
export type ResultadoLinha = {
  codigoIgreja: string | null;
  status: StatusLinha;
  motivo?: MotivoRecusa;
};

export type IgrejaResumo = {
  id: string;
  codigo: string;
  ativo: boolean;
  pastorLocalVigentePessoaId: string | null;
};

export type PessoaResumo = { id: string };

export type ContextoLinha = {
  commandId: string;
  correlacaoId: string;
  origem: string;
  agora: Date;
};

/**
 * Fronteira de persistência. O núcleo puro depende apenas destas operações,
 * permitindo exercitar a matriz I/O sem Firestore real.
 */
export type PortasImportacao = {
  buscarIgrejaPorCodigo(codigo: string): Promise<IgrejaResumo | null>;
  buscarPessoaPorEmail(emailNormalizado: string): Promise<PessoaResumo | null>;
  garantirIdentidade(
    entrada: EntradaValidada,
    contexto: ContextoLinha,
  ): Promise<PessoaResumo>;
  aplicarVinculo(
    entrada: EntradaValidada,
    pessoa: PessoaResumo,
    igreja: IgrejaResumo,
    contexto: ContextoLinha,
  ): Promise<'CRIADO' | 'JA_VIGENTE'>;
};

export class ConflitoVinculoError extends Error {
  constructor() {
    super('CONFLITO_VINCULO');
    this.name = 'ConflitoVinculoError';
  }
}

export class IgrejaInativaError extends Error {
  constructor() {
    super('IGREJA_INATIVA');
    this.name = 'IgrejaInativaError';
  }
}

export class ComandoDivergenteError extends Error {
  constructor() {
    super('COMANDO_DIVERGENTE');
    this.name = 'ComandoDivergenteError';
  }
}

export type RequisicaoImportacao = {
  commandId: string;
  correlacaoId: string;
  origem: string;
  modo: 'EXECUCAO' | 'SIMULACAO';
  agora: Date;
  entradas: EntradaBruta[];
};

export type ResultadoImportacao = {
  commandId: string;
  origem: string;
  modo: 'EXECUCAO' | 'SIMULACAO';
  status: 'COMPLETO';
  total: number;
  criados: number;
  jaVigentes: number;
  simulados: number;
  recusados: number;
  linhas: ResultadoLinha[];
};

type ItemValidacao =
  | { index: number; ok: true; entrada: EntradaValidada }
  | { index: number; ok: false; codigoIgreja: string | null; motivo: MotivoRecusa };

export type ResultadoValidacao = {
  itens: ItemValidacao[];
  validas: { index: number; entrada: EntradaValidada }[];
  recusadas: { index: number; codigoIgreja: string | null; motivo: MotivoRecusa }[];
};

const REGEX_CODIGO = /^(\d{6})(?:\s*-\s*(.*))?$/;
const REGEX_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const REGEX_COMMAND_ID = /^[A-Za-z0-9_-]{16,128}$/;
const REGEX_ORIGEM = /^[A-Za-z0-9_.:-]{1,64}$/;

/** Extrai o código String de uma célula no formato canônico "240001 - IGAPÓ". */
export function extrairCodigoIgreja(valor: unknown): string | null {
  if (typeof valor !== 'string') return null;
  const encontrado = valor.trim().match(REGEX_CODIGO);
  return encontrado ? encontrado[1] : null;
}

/** Remove o sufixo "| RN" da planilha antes de tratar o nome. */
export function removerSufixoRn(valor: string): string {
  return valor.replace(/\s*\|\s*RN\s*$/i, '').trim();
}

export function normalizarEmail(valor: string): string {
  return valor.trim().toLowerCase();
}

export function normalizarNome(valor: string): string {
  return valor
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toUpperCase()
    .replace(/\s+/g, ' ')
    .trim();
}

export function validarCommandId(commandId: string): boolean {
  return REGEX_COMMAND_ID.test(commandId);
}

/** Identificador opaco determinístico de uma linha, correlacionado ao comando. */
export function idDaLinha(commandId: string, codigoIgreja: string): string {
  return `${commandId}--${codigoIgreja}`;
}

function nomeValido(nome: string): boolean {
  return (
    nome.length >= 3 &&
    nome.length <= 160 &&
    /\p{L}/u.test(nome) &&
    !/[\u0000-\u001f\u007f]/.test(nome)
  );
}

function emailValido(email: string): boolean {
  return email.length <= 254 && REGEX_EMAIL.test(email);
}

function hashPayload(
  codigoIgreja: string,
  nomeNormalizado: string,
  emailNormalizado: string,
): string {
  return createHash('sha256')
    .update(JSON.stringify({ codigoIgreja, nomeNormalizado, emailNormalizado }))
    .digest('hex');
}

type Trabalho = {
  index: number;
  motivos: Set<MotivoRecusa>;
  codigoIgreja: string | null;
  nomeCompleto: string | null;
  email: string | null;
  emailNormalizado: string | null;
  nomeNormalizado: string | null;
  payloadHash: string | null;
};

/**
 * Valida todas as entradas antes de qualquer mutação. Ambiguidades de
 * identidade (código duplicado, mesmo e-mail com nomes divergentes ou mesmo
 * nome com e-mails divergentes) recusam as linhas envolvidas.
 */
export function validarEntradas(entradas: EntradaBruta[]): ResultadoValidacao {
  const trabalhos: Trabalho[] = entradas.map((entrada, index) => {
    const trabalho: Trabalho = {
      index,
      motivos: new Set<MotivoRecusa>(),
      codigoIgreja: null,
      nomeCompleto: null,
      email: null,
      emailNormalizado: null,
      nomeNormalizado: null,
      payloadHash: null,
    };
    const codigo = extrairCodigoIgreja(entrada.codigoIgreja);
    if (!codigo) trabalho.motivos.add('CODIGO_INVALIDO');
    else trabalho.codigoIgreja = codigo;

    const nome =
      typeof entrada.nomePastor === 'string'
        ? removerSufixoRn(entrada.nomePastor)
        : '';
    if (!nomeValido(nome)) trabalho.motivos.add('NOME_INVALIDO');
    else {
      trabalho.nomeCompleto = nome;
      trabalho.nomeNormalizado = normalizarNome(nome);
    }

    const email =
      typeof entrada.email === 'string' ? entrada.email.trim() : '';
    if (!emailValido(email)) trabalho.motivos.add('EMAIL_INVALIDO');
    else {
      trabalho.email = email;
      trabalho.emailNormalizado = normalizarEmail(email);
    }
    return trabalho;
  });

  const porCodigo = new Map<string, Trabalho[]>();
  for (const trabalho of trabalhos) {
    if (trabalho.motivos.size > 0 || !trabalho.codigoIgreja) continue;
    const grupo = porCodigo.get(trabalho.codigoIgreja) ?? [];
    grupo.push(trabalho);
    porCodigo.set(trabalho.codigoIgreja, grupo);
  }
  for (const grupo of porCodigo.values()) {
    if (grupo.length > 1) {
      for (const trabalho of grupo) trabalho.motivos.add('CODIGO_DUPLICADO');
    }
  }

  marcarIdentidadeAmbigua(trabalhos, (t) => t.emailNormalizado, (t) => t.nomeNormalizado);
  marcarIdentidadeAmbigua(trabalhos, (t) => t.nomeNormalizado, (t) => t.emailNormalizado);

  const itens: ItemValidacao[] = trabalhos.map((trabalho) => {
    if (trabalho.motivos.size > 0) {
      const motivo = [...trabalho.motivos][0];
      return {
        index: trabalho.index,
        ok: false,
        codigoIgreja: trabalho.codigoIgreja,
        motivo,
      };
    }
    const payloadHash = hashPayload(
      trabalho.codigoIgreja as string,
      trabalho.nomeNormalizado as string,
      trabalho.emailNormalizado as string,
    );
    return {
      index: trabalho.index,
      ok: true,
      entrada: {
        codigoIgreja: trabalho.codigoIgreja as string,
        nomeCompleto: trabalho.nomeCompleto as string,
        email: trabalho.email as string,
        emailNormalizado: trabalho.emailNormalizado as string,
        nomeNormalizado: trabalho.nomeNormalizado as string,
        payloadHash,
      },
    };
  });

  return {
    itens,
    validas: itens.filter(
      (item): item is Extract<ItemValidacao, { ok: true }> => item.ok,
    ),
    recusadas: itens.filter(
      (item): item is Extract<ItemValidacao, { ok: false }> => !item.ok,
    ),
  };
}

function marcarIdentidadeAmbigua(
  trabalhos: Trabalho[],
  chave: (t: Trabalho) => string | null,
  valor: (t: Trabalho) => string | null,
): void {
  const grupos = new Map<string, Trabalho[]>();
  for (const trabalho of trabalhos) {
    if (trabalho.motivos.size > 0) continue;
    const k = chave(trabalho);
    if (!k) continue;
    const grupo = grupos.get(k) ?? [];
    grupo.push(trabalho);
    grupos.set(k, grupo);
  }
  for (const grupo of grupos.values()) {
    const valores = new Set(grupo.map(valor));
    if (valores.size > 1) {
      for (const trabalho of grupo) trabalho.motivos.add('IDENTIDADE_AMBIGUA');
    }
  }
}

function recusada(codigoIgreja: string, motivo: MotivoRecusa): ResultadoLinha {
  return { codigoIgreja, status: 'RECUSADO', motivo };
}

async function processarEntrada(
  entrada: EntradaValidada,
  modo: RequisicaoImportacao['modo'],
  contexto: ContextoLinha,
  portas: PortasImportacao,
): Promise<ResultadoLinha> {
  const igreja = await portas.buscarIgrejaPorCodigo(entrada.codigoIgreja);
  if (!igreja) return recusada(entrada.codigoIgreja, 'IGREJA_INEXISTENTE');
  if (!igreja.ativo) return recusada(entrada.codigoIgreja, 'IGREJA_INATIVA');

  const pessoa = await portas.buscarPessoaPorEmail(entrada.emailNormalizado);
  if (igreja.pastorLocalVigentePessoaId) {
    if (pessoa && pessoa.id === igreja.pastorLocalVigentePessoaId) {
      return { codigoIgreja: entrada.codigoIgreja, status: 'JA_VIGENTE' };
    }
    return recusada(entrada.codigoIgreja, 'CONFLITO_VINCULO');
  }
  if (modo === 'SIMULACAO') {
    return { codigoIgreja: entrada.codigoIgreja, status: 'CRIARIA' };
  }

  const identidade =
    pessoa ?? (await portas.garantirIdentidade(entrada, contexto));
  try {
    const status = await portas.aplicarVinculo(
      entrada,
      identidade,
      igreja,
      contexto,
    );
    return { codigoIgreja: entrada.codigoIgreja, status };
  } catch (erro) {
    if (erro instanceof ConflitoVinculoError) {
      return recusada(entrada.codigoIgreja, 'CONFLITO_VINCULO');
    }
    if (erro instanceof IgrejaInativaError) {
      return recusada(entrada.codigoIgreja, 'IGREJA_INATIVA');
    }
    if (erro instanceof ComandoDivergenteError) {
      return recusada(entrada.codigoIgreja, 'COMANDO_DIVERGENTE');
    }
    throw erro;
  }
}

/**
 * Carga inicial idempotente. Cada linha é atômica: uma falha não grava vínculo
 * parcial nem impede as demais linhas válidas de serem processadas.
 */
export async function importarPastoresIniciais(
  requisicao: RequisicaoImportacao,
  portas: PortasImportacao,
): Promise<ResultadoImportacao> {
  if (!validarCommandId(requisicao.commandId)) {
    throw new Error('COMANDO_INVALIDO');
  }
  if (!REGEX_ORIGEM.test(requisicao.origem)) {
    throw new Error('ORIGEM_INVALIDA');
  }
  const validacao = validarEntradas(requisicao.entradas);
  const contexto: ContextoLinha = {
    commandId: requisicao.commandId,
    correlacaoId: requisicao.correlacaoId,
    origem: requisicao.origem,
    agora: requisicao.agora,
  };
  const linhas: ResultadoLinha[] = new Array(requisicao.entradas.length);
  for (const item of validacao.recusadas) {
    linhas[item.index] = {
      codigoIgreja: item.codigoIgreja,
      status: 'RECUSADO',
      motivo: item.motivo,
    };
  }
  for (const item of validacao.validas) {
    linhas[item.index] = await processarEntrada(
      item.entrada,
      requisicao.modo,
      contexto,
      portas,
    );
  }

  const contar = (status: StatusLinha) =>
    linhas.filter((linha) => linha.status === status).length;
  return {
    commandId: requisicao.commandId,
    origem: requisicao.origem,
    modo: requisicao.modo,
    status: 'COMPLETO',
    total: linhas.length,
    criados: contar('CRIADO'),
    jaVigentes: contar('JA_VIGENTE'),
    simulados: contar('CRIARIA'),
    recusados: contar('RECUSADO'),
    linhas,
  };
}
