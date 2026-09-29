import { describe, expect, it } from 'vitest';
import {
  NOME_CLAIM_ADMINISTRATIVA,
  PAPEL_ADMINISTRADOR,
  aplicarClaimAdministrativa,
  hashAlteracao,
  podeAdministrar,
} from '../src/domain/autoridadeAdministrativa.js';

describe('autoridade administrativa canônica', () => {
  it('só reconhece autoridade ativa emitida pelo backend', () => {
    expect(podeAdministrar({ ativa: true, papel: PAPEL_ADMINISTRADOR })).toBe(true);
    expect(podeAdministrar({ ativa: false, papel: PAPEL_ADMINISTRADOR })).toBe(false);
    expect(podeAdministrar({ ativa: true, papel: 'ADMINISTRADOR_CLIENTE' })).toBe(false);
  });

  it('preserva claims de outros domínios ao projetar a administração', () => {
    const existentes = { outroDominio: 'x', [NOME_CLAIM_ADMINISTRATIVA]: false };
    const concedida = aplicarClaimAdministrativa(existentes, true);
    expect(concedida.outroDominio).toBe('x');
    expect(concedida[NOME_CLAIM_ADMINISTRATIVA]).toBe(true);
    const revogada = aplicarClaimAdministrativa(existentes, false);
    expect(revogada.outroDominio).toBe('x');
    expect(revogada).not.toHaveProperty(NOME_CLAIM_ADMINISTRATIVA);
  });

  it('liga o recibo ao alvo e ao sentido sem persistir o UID', () => {
    const base = hashAlteracao({ alvoUid: 'uid-a', conceder: true });
    expect(base).toBe(hashAlteracao({ alvoUid: 'uid-a', conceder: true }));
    expect(base).not.toBe(hashAlteracao({ alvoUid: 'uid-b', conceder: true }));
    expect(base).not.toBe(hashAlteracao({ alvoUid: 'uid-a', conceder: false }));
    expect(base).not.toContain('uid-a');
  });
});
