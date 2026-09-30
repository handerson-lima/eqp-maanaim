import { createHash } from 'node:crypto';
import { cpfValido, normalizarCpf } from './cpf.js';

export type CriarRascunhoInput = {
  commandId: string;
  nomeCompleto: string;
  profissao: string;
  cpf: string;
  igrejaId: string;
};

/** Liga um comando ao conteúdo: mesmo commandId com dados diferentes é recusado. */
export function hashRascunho(input: CriarRascunhoInput): string {
  // Normaliza o CPF como é persistido, para que formatos equivalentes não
  // produzam hashes divergentes.
  const cpf = normalizarCpf(input.cpf);
  return createHash('sha256')
    .update(JSON.stringify({ nomeCompleto: input.nomeCompleto, profissao: input.profissao, cpf, igrejaId: input.igrejaId }))
    .digest('hex');
}

export function validarRascunho(value: unknown): CriarRascunhoInput {
  if (typeof value !== 'object' || value === null) throw new Error('INVALID_ARGUMENT');
  const v = value as Record<string, unknown>;
  const campos = ['commandId', 'nomeCompleto', 'profissao', 'cpf', 'igrejaId'];
  if (Object.keys(v).length !== campos.length || !Object.keys(v).every((campo) => campos.includes(campo)) ||
      !campos.every((campo) => typeof v[campo] === 'string')) throw new Error('INVALID_ARGUMENT');
  const input = Object.fromEntries(campos.map((campo) => [campo, (v[campo] as string).trim()])) as CriarRascunhoInput;
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(input.commandId) || input.nomeCompleto.length < 3 ||
      input.nomeCompleto.length > 160 || input.profissao.length < 2 || input.profissao.length > 120 ||
      !cpfValido(input.cpf) || !/^[A-Za-z0-9_-]{1,128}$/.test(input.igrejaId)) throw new Error('INVALID_ARGUMENT');
  return input;
}
