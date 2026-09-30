import { createHash } from 'node:crypto';
import { cpfValido, normalizarCpf } from './cpf.js';
import { normalizarNome } from './importacaoPastores.js';
import {
  PAPEIS_SISTEMA,
  ehPapelSistema,
  type PapelSistema,
} from './autoridadeAdministrativa.js';

const REGEX_COMMAND_ID = /^[A-Za-z0-9_-]{16,128}$/;
const REGEX_UID = /^[A-Za-z0-9_-]{1,128}$/;
const REGEX_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** Campos permitidos no comando de cadastro/atualização de pessoa. */
const CAMPOS_PESSOA = [
  'commandId',
  'correlationId',
  'uid',
  'nomeCompleto',
  'email',
  'coordenador',
  'cpf',
] as const;

/** Campos permitidos no comando de concessão/revogação de papel. */
const CAMPOS_PAPEIS = [
  'commandId',
  'correlationId',
  'alvoUid',
  'expectedVersion',
  'papel',
  'conceder',
] as const;

export type EntradaPessoa = {
  commandId: string;
  correlationId: string | null;
  uid: string | null;
  nomeCompleto: string;
  email: string;
  emailNormalizado: string;
  coordenador: boolean;
  /** CPF normalizado; somente presente quando `coordenador` é verdadeiro. */
  cpf: string | null;
  payloadHash: string;
};

export type EntradaPapeis = {
  commandId: string;
  correlationId: string | null;
  alvoUid: string;
  expectedVersion: number;
  papel: PapelSistema;
  conceder: boolean;
  payloadHash: string;
};

/** Projeção de leitura autorizada; sem CPF e sem qualquer PII sensível. */
export type PessoaResumo = {
  uid: string;
  nomeCompleto: string;
  email: string;
  papeis: PapelSistema[];
  versao: number;
  coordenador: boolean;
};

export type ContextoAtivo = {
  uid: string;
  papeis: PapelSistema[];
};

export type ResumoPessoas = {
  pessoas: PessoaResumo[];
  /** Conjunto efetivo do solicitante, exibido apenas como leitura na UI. */
  contexto: ContextoAtivo;
};

export class PessoaInvalidaError extends Error {
  constructor() {
    super('PESSOA_INVALIDA');
    this.name = 'PessoaInvalidaError';
  }
}

export class AlvoInexistenteError extends Error {
  constructor() {
    super('ALVO_INEXISTENTE');
    this.name = 'AlvoInexistenteError';
  }
}

export class PapelInvalidoError extends Error {
  constructor() {
    super('PAPEL_INVALIDO');
    this.name = 'PapelInvalidoError';
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

export class OperacaoInvalidaError extends Error {
  constructor() {
    super('OPERACAO_INVALIDA');
    this.name = 'OperacaoInvalidaError';
  }
}

export class UltimoAdminError extends Error {
  constructor() {
    super('ULTIMO_ADMIN');
    this.name = 'UltimoAdminError';
  }
}

export function validarCommandId(commandId: string): boolean {
  return REGEX_COMMAND_ID.test(commandId);
}

function texto(valor: unknown): string {
  return typeof valor === 'string' ? valor : '';
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

function chavesPermitidas(
  valor: Record<string, unknown>,
  permitidas: readonly string[],
): boolean {
  return Object.keys(valor).every((chave) => permitidas.includes(chave));
}

/** Valida o comando de pessoa; rejeita campos fora do contrato e CPF indevido. */
export function validarPessoa(value: unknown): EntradaPessoa {
  if (typeof value !== 'object' || value === null) throw new PessoaInvalidaError();
  const v = value as Record<string, unknown>;
  if (!chavesPermitidas(v, CAMPOS_PESSOA)) throw new PessoaInvalidaError();
  const commandId = texto(v.commandId);
  if (!validarCommandId(commandId)) throw new PessoaInvalidaError();
  const correlationId =
    v.correlationId === undefined ? null : texto(v.correlationId);
  if (correlationId !== null && !validarCommandId(correlationId)) {
    throw new PessoaInvalidaError();
  }
  const uid = v.uid === undefined || v.uid === null ? null : texto(v.uid);
  if (uid !== null && !REGEX_UID.test(uid)) throw new PessoaInvalidaError();

  const nomeCompleto = texto(v.nomeCompleto).trim();
  if (!nomeValido(nomeCompleto)) throw new PessoaInvalidaError();
  const email = texto(v.email).trim();
  if (!emailValido(email)) throw new PessoaInvalidaError();
  if (typeof v.coordenador !== 'boolean') throw new PessoaInvalidaError();
  const coordenador = v.coordenador;

  let cpf: string | null = null;
  if (coordenador) {
    if (v.cpf === undefined) throw new PessoaInvalidaError();
    const bruto = texto(v.cpf);
    if (!cpfValido(bruto)) throw new PessoaInvalidaError();
    cpf = normalizarCpf(bruto);
  } else if (v.cpf !== undefined) {
    throw new PessoaInvalidaError();
  }

  const entrada: EntradaPessoa = {
    commandId,
    correlationId,
    uid,
    nomeCompleto,
    email,
    emailNormalizado: email.toLowerCase(),
    coordenador,
    cpf,
    payloadHash: '',
  };
  entrada.payloadHash = hashPessoa(entrada);
  return entrada;
}

/** Valida o comando de papéis; o papel precisa pertencer ao catálogo de sistema. */
export function validarPapeis(value: unknown): EntradaPapeis {
  if (typeof value !== 'object' || value === null) throw new PapelInvalidoError();
  const v = value as Record<string, unknown>;
  if (!chavesPermitidas(v, CAMPOS_PAPEIS)) throw new PapelInvalidoError();
  const commandId = texto(v.commandId);
  if (!validarCommandId(commandId)) throw new PapelInvalidoError();
  const correlationId =
    v.correlationId === undefined ? null : texto(v.correlationId);
  if (correlationId !== null && !validarCommandId(correlationId)) {
    throw new PapelInvalidoError();
  }
  const alvoUid = texto(v.alvoUid);
  if (!REGEX_UID.test(alvoUid)) throw new PapelInvalidoError();
  if (
    typeof v.expectedVersion !== 'number' ||
    !Number.isInteger(v.expectedVersion) ||
    v.expectedVersion < 0
  ) {
    throw new PapelInvalidoError();
  }
  if (!ehPapelSistema(v.papel)) throw new PapelInvalidoError();
  if (typeof v.conceder !== 'boolean') throw new PapelInvalidoError();
  const entrada: EntradaPapeis = {
    commandId,
    correlationId,
    alvoUid,
    expectedVersion: v.expectedVersion,
    papel: v.papel,
    conceder: v.conceder,
    payloadHash: '',
  };
  entrada.payloadHash = hashPapeis(entrada);
  return entrada;
}

/** Liga o recibo ao conteúdo do cadastro sem persistir o UID do alvo. */
export function hashPessoa(entrada: EntradaPessoa): string {
  return createHash('sha256')
    .update(
      JSON.stringify({
        uid: entrada.uid ?? '',
        nomeCompleto: entrada.nomeCompleto,
        email: entrada.emailNormalizado,
        coordenador: entrada.coordenador,
        cpf: entrada.cpf ?? '',
      }),
    )
    .digest('hex');
}

/** Liga o recibo ao alvo, ao papel e ao sentido sem persistir o UID no recibo. */
export function hashPapeis(entrada: EntradaPapeis): string {
  return createHash('sha256')
    .update(
      JSON.stringify({
        alvoUid: entrada.alvoUid,
        papel: entrada.papel,
        conceder: entrada.conceder,
      }),
    )
    .digest('hex');
}

/** Pesquisa pessoas por nome (sem acento/caixa) ou e-mail (parcial). */
export function correspondeTermoPessoa(
  pessoa: { nomeCompleto: string; email: string },
  termo: string,
): boolean {
  const alvo = normalizarNome(termo);
  if (!alvo) return true;
  if (normalizarNome(pessoa.nomeCompleto).includes(alvo)) return true;
  return pessoa.email.toLowerCase().includes(termo.trim().toLowerCase());
}

/** Ordena alfabeticamente por nome; sem nome, mantém o uid como desempate. */
export function ordenarPessoas(pessoas: PessoaResumo[]): PessoaResumo[] {
  return [...pessoas].sort((a, b) => {
    const porNome = a.nomeCompleto.localeCompare(b.nomeCompleto, 'pt-BR', {
      sensitivity: 'base',
    });
    return porNome !== 0 ? porNome : a.uid.localeCompare(b.uid);
  });
}

export function pesquisarPessoas(
  pessoas: PessoaResumo[],
  termo: string,
): PessoaResumo[] {
  return ordenarPessoas(
    pessoas.filter((pessoa) => correspondeTermoPessoa(pessoa, termo)),
  );
}

/** Catálogo de papéis de sistema, reexposto para validação/migração. */
export { PAPEIS_SISTEMA };
