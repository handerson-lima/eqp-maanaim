export type CriarRascunhoInput = {
  commandId: string;
  nomeCompleto: string;
  profissao: string;
  cpf: string;
  igrejaId: string;
};

const cpfValido = (cpf: string): boolean => {
  const numeros = cpf.replace(/\D/g, '');
  if (!/^\d{11}$/.test(numeros) || /^(\d)\1{10}$/.test(numeros)) return false;
  const digito = (base: string, peso: number) => {
    const soma = [...base].reduce((total, n, i) => total + Number(n) * (peso - i), 0);
    const resto = (soma * 10) % 11;
    return resto === 10 ? 0 : resto;
  };
  return Number(numeros[9]) === digito(numeros.substring(0, 9), 10) &&
    Number(numeros[10]) === digito(numeros.substring(0, 10), 11);
};

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
