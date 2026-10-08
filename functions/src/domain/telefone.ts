export class TelefoneInvalidoError extends Error {
  constructor(message = 'Número de telefone inválido.') {
    super(message);
    this.name = 'TelefoneInvalidoError';
  }
}

/**
 * Normaliza e valida um telefone no padrão brasileiro.
 * Aceita números com 10 dígitos (fixo: (XX) XXXX-XXXX) ou 11 dígitos (celular: (XX) 9XXXX-XXXX).
 * DDDs válidos no Brasil variam de 11 a 99 (primeiro dígito de 1 a 9, segundo dígito de 1 a 9).
 */
export function normalizarTelefone(valor: unknown): string {
  if (typeof valor !== 'string') {
    throw new TelefoneInvalidoError('Telefone deve ser informado.');
  }

  const digitos = valor.replace(/\D/g, '');

  if (digitos.length !== 10 && digitos.length !== 11) {
    throw new TelefoneInvalidoError('Telefone deve conter 10 ou 11 dígitos com DDD.');
  }

  const ddd = parseInt(digitos.slice(0, 2), 10);
  // Lista oficial de DDDs válidos no Brasil
  const dddValidos = new Set([
    11, 12, 13, 14, 15, 16, 17, 18, 19,
    21, 22, 24, 27, 28,
    31, 32, 33, 34, 35, 37, 38,
    41, 42, 43, 44, 45, 46, 47, 48, 49,
    51, 53, 54, 55,
    61, 62, 63, 64, 65, 66, 67, 68, 69,
    71, 73, 74, 75, 77, 79,
    81, 82, 83, 84, 85, 86, 87, 88, 89,
    91, 92, 93, 94, 95, 96, 97, 98, 99,
  ]);

  if (!dddValidos.has(ddd)) {
    throw new TelefoneInvalidoError('DDD inválido.');
  }

  if (digitos.length === 11) {
    // 3º dígito do celular no Brasil deve ser 9
    if (digitos[2] !== '9') {
      throw new TelefoneInvalidoError('Celular de 11 dígitos deve iniciar com 9 após o DDD.');
    }
    return `(${digitos.slice(0, 2)}) ${digitos.slice(2, 7)}-${digitos.slice(7)}`;
  } else {
    // Fixo: 10 dígitos. O primeiro dígito após DDD normalmente é de 2 a 8
    const primeiroDigito = parseInt(digitos[2], 10);
    if (primeiroDigito < 2 || primeiroDigito > 8) {
      throw new TelefoneInvalidoError('Telefone fixo inválido.');
    }
    return `(${digitos.slice(0, 2)}) ${digitos.slice(2, 6)}-${digitos.slice(6)}`;
  }
}
