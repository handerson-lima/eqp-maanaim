import { describe, expect, it, vi } from 'vitest';
import { normalizarTelefone, TelefoneInvalidoError } from '../src/domain/telefone.js';
import { atualizarTelefoneRepo } from '../src/repositories/ficha.js';

describe('Domínio de Telefone (telefone.ts)', () => {
  it('valida e formata celular de 11 dígitos com 9 no início', () => {
    expect(normalizarTelefone('27999998888')).toBe('(27) 99999-8888');
    expect(normalizarTelefone('(27) 99999-8888')).toBe('(27) 99999-8888');
    expect(normalizarTelefone('11 9 8765 4321')).toBe('(11) 98765-4321');
  });

  it('valida e formata telefone fixo de 10 dígitos', () => {
    expect(normalizarTelefone('2733334444')).toBe('(27) 3333-4444');
    expect(normalizarTelefone('(27) 3333-4444')).toBe('(27) 3333-4444');
  });

  it('rejeita DDDs inexistentes no Brasil', () => {
    expect(() => normalizarTelefone('00999998888')).toThrow(TelefoneInvalidoError);
    expect(() => normalizarTelefone('05999998888')).toThrow(TelefoneInvalidoError);
    expect(() => normalizarTelefone('20999998888')).toThrow(TelefoneInvalidoError);
  });

  it('rejeita celular de 11 dígitos que não começa com 9 após o DDD', () => {
    expect(() => normalizarTelefone('27888887777')).toThrow(
      'Celular de 11 dígitos deve iniciar com 9 após o DDD.',
    );
  });

  it('rejeita tamanho incorreto (< 10 ou > 11 dígitos)', () => {
    expect(() => normalizarTelefone('279999')).toThrow(TelefoneInvalidoError);
    expect(() => normalizarTelefone('27999998888123')).toThrow(TelefoneInvalidoError);
  });

  it('rejeita entradas nulas ou não strings', () => {
    expect(() => normalizarTelefone(null)).toThrow(TelefoneInvalidoError);
    expect(() => normalizarTelefone(1234567890)).toThrow(TelefoneInvalidoError);
  });
});

describe('Repositório atualizarTelefoneRepo', () => {
  it('atualiza documento existente e grava evento de auditoria sem PII', async () => {
    const mockFichaDoc = {
      exists: true,
      data: () => ({ id: 'user-abc', nomeCompleto: 'Fulano' }),
    };

    const mockTx = {
      get: vi.fn().mockResolvedValue(mockFichaDoc),
      set: vi.fn(),
    };

    const mockDb = {
      collection: (col: string) => ({
        doc: (id?: string) => ({
          id: id ?? 'auto-id-123',
        }),
      }),
      runTransaction: vi.fn(async (cb: (tx: any) => Promise<any>) => {
        return cb(mockTx);
      }),
    };

    const res = await atualizarTelefoneRepo(mockDb as any, 'user-abc', '(27) 99999-8888');

    expect(res.telefone).toBe('(27) 99999-8888');
    expect(res.fichaId).toBe('user-abc');
    expect(mockTx.get).toHaveBeenCalled();
    // Verifica que gravou a atualização na ficha e no auditOutbox
    expect(mockTx.set).toHaveBeenCalledTimes(2);

    // Verifica que o evento de auditoria NÃO contém o telefone (AD-12)
    const auditCall = mockTx.set.mock.calls.find(
      (c: any) => c[1]?.action === 'TELEFONE_PERFIL_ATUALIZADO',
    );
    expect(auditCall).toBeDefined();
    expect(auditCall![1].camposAlterados).toEqual(['telefone']);
    expect(auditCall![1].actorUid).toBe('user-abc');
    expect(auditCall![1].telefone).toBeUndefined(); // strictly NO PII
  });

  it('cria documento se não existir e persiste telefone com estado RASCUNHO', async () => {
    const mockFichaDoc = {
      exists: false,
      data: () => null,
    };

    const mockTx = {
      get: vi.fn().mockResolvedValue(mockFichaDoc),
      set: vi.fn(),
    };

    const mockDb = {
      collection: (col: string) => ({
        doc: (id?: string) => ({
          id: id ?? 'auto-id-456',
        }),
      }),
      runTransaction: vi.fn(async (cb: (tx: any) => Promise<any>) => {
        return cb(mockTx);
      }),
    };

    const res = await atualizarTelefoneRepo(mockDb as any, 'novo-user', '(11) 98765-4321');

    expect(res.telefone).toBe('(11) 98765-4321');
    expect(res.fichaId).toBe('novo-user');
    expect(mockTx.set).toHaveBeenCalledTimes(2);

    const fichaSetCall = mockTx.set.mock.calls[0];
    expect(fichaSetCall[1].telefone).toBe('(11) 98765-4321');
    expect(fichaSetCall[1].estado).toBe('RASCUNHO');
  });
});
