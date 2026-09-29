import { describe, expect, it } from 'vitest';
import { validarRascunho } from '../src/domain/rascunho.js';

const valido = { commandId: 'a'.repeat(16), nomeCompleto: 'Ana da Silva', profissao: 'Professora', cpf: '529.982.247-25', igrejaId: 'igreja-abc' };
describe('contrato do rascunho', () => {
  it('aceita somente os dados permitidos e um CPF válido', () => expect(validarRascunho(valido).igrejaId).toBe('igreja-abc'));
  it('recusa CPF inválido e campos ausentes sem devolver os dados', () => {
    expect(() => validarRascunho({ ...valido, cpf: '111.111.111-11' })).toThrow('INVALID_ARGUMENT');
    expect(() => validarRascunho({ commandId: valido.commandId })).toThrow('INVALID_ARGUMENT');
  });
  it('recusa campos fora do contrato da callable', () => {
    expect(() => validarRascunho({ ...valido, papel: 'ADMIN' })).toThrow('INVALID_ARGUMENT');
  });
});
