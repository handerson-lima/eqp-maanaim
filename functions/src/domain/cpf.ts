/** Normaliza o CPF para o formato persistido (somente dígitos). */
export function normalizarCpf(cpf: string): string {
  return cpf.replace(/\D/g, '');
}

/** Valida um CPF pelos dígitos verificadores, sem depender de formatação. */
export function cpfValido(cpf: string): boolean {
  const numeros = normalizarCpf(cpf);
  if (!/^\d{11}$/.test(numeros) || /^(\d)\1{10}$/.test(numeros)) return false;
  const digito = (base: string, peso: number) => {
    const soma = [...base].reduce(
      (total, n, i) => total + Number(n) * (peso - i),
      0,
    );
    const resto = (soma * 10) % 11;
    return resto === 10 ? 0 : resto;
  };
  return (
    Number(numeros[9]) === digito(numeros.substring(0, 9), 10) &&
    Number(numeros[10]) === digito(numeros.substring(0, 10), 11)
  );
}
