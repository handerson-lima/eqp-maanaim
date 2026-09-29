import { describe, expect, it } from 'vitest';
import { hashRascunho, validarRascunho } from '../src/domain/rascunho.js';

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
  it('liga o recibo ao conteúdo e muda com qualquer campo do domínio', () => {
    const base = hashRascunho(valido);
    expect(base).toMatch(/^[0-9a-f]{64}$/);
    expect(hashRascunho({ ...valido })).toBe(base);
    expect(hashRascunho({ ...valido, nomeCompleto: 'Ana de Souza' })).not.toBe(base);
    expect(hashRascunho({ ...valido, profissao: 'Pedagoga' })).not.toBe(base);
    expect(hashRascunho({ ...valido, cpf: '529.982.247-26' })).not.toBe(base);
    expect(hashRascunho({ ...valido, igrejaId: 'outra' })).not.toBe(base);
    // Formatos equivalentes de CPF não divergem o hash.
    expect(hashRascunho({ ...valido, cpf: '52998224725' })).toBe(base);
  });
});
