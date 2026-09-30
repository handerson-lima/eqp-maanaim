import { describe, expect, it } from 'vitest';
import {
  NOME_CLAIM_ADMINISTRATIVA,
  NOME_CLAIM_COORDENADOR,
  PAPEL_ADMINISTRADOR,
  PAPEL_COORDENADOR,
  aplicarClaimsSistema,
  hashAlteracao,
  papeisEfetivos,
  podeAdministrar,
} from '../src/domain/autoridadeAdministrativa.js';

describe('autoridade administrativa canônica', () => {
  it('só reconhece autoridade ativa emitida pelo backend', () => {
    expect(podeAdministrar({ ativa: true, papel: PAPEL_ADMINISTRADOR })).toBe(true);
    expect(podeAdministrar({ ativa: false, papel: PAPEL_ADMINISTRADOR })).toBe(false);
    expect(podeAdministrar({ ativa: true, papel: 'ADMINISTRADOR_CLIENTE' })).toBe(false);
  });

  it('preserva claims de outros domínios ao projetar as claims de sistema', () => {
    const existentes = { outroDominio: 'x', [NOME_CLAIM_ADMINISTRATIVA]: false };
    const concedida = aplicarClaimsSistema(existentes, [PAPEL_ADMINISTRADOR]);
    expect(concedida.outroDominio).toBe('x');
    expect(concedida[NOME_CLAIM_ADMINISTRATIVA]).toBe(true);
    const revogada = aplicarClaimsSistema(existentes, []);
    expect(revogada.outroDominio).toBe('x');
    expect(revogada).not.toHaveProperty(NOME_CLAIM_ADMINISTRATIVA);
  });

  it('é retrocompatível com o papel singular e projeta uma claim por papel', () => {
    expect(podeAdministrar({ ativa: true, papel: PAPEL_ADMINISTRADOR })).toBe(true);
    expect(papeisEfetivos({ ativa: true, papel: PAPEL_ADMINISTRADOR })).toEqual([
      PAPEL_ADMINISTRADOR,
    ]);
    expect(podeAdministrar({ ativa: true, papeis: [PAPEL_ADMINISTRADOR] })).toBe(true);
    expect(podeAdministrar({ ativa: true, papeis: [PAPEL_COORDENADOR] })).toBe(false);
    const claims = aplicarClaimsSistema({}, [PAPEL_ADMINISTRADOR, PAPEL_COORDENADOR]);
    expect(claims[NOME_CLAIM_ADMINISTRATIVA]).toBe(true);
    expect(claims[NOME_CLAIM_COORDENADOR]).toBe(true);
  });

  it('faz o plural prevalecer quando os dois campos coexistem', () => {
    // O campo plural presente é a fonte, mesmo vazio: por isso todo writer
    // precisa convergir para `papeis` e remover o `papel` legado.
    expect(
      papeisEfetivos({ ativa: true, papeis: [], papel: PAPEL_ADMINISTRADOR }),
    ).toEqual([]);
    expect(
      papeisEfetivos({
        ativa: true,
        papeis: [PAPEL_COORDENADOR],
        papel: PAPEL_ADMINISTRADOR,
      }),
    ).toEqual([PAPEL_COORDENADOR]);
  });

  it('liga o recibo ao alvo, ao sentido e à versão sem persistir o UID', () => {
    const base = hashAlteracao({ alvoUid: 'uid-a', conceder: true, expectedVersion: 1 });
    expect(base).toBe(
      hashAlteracao({ alvoUid: 'uid-a', conceder: true, expectedVersion: 1 }),
    );
    expect(base).not.toBe(
      hashAlteracao({ alvoUid: 'uid-b', conceder: true, expectedVersion: 1 }),
    );
    expect(base).not.toBe(
      hashAlteracao({ alvoUid: 'uid-a', conceder: false, expectedVersion: 1 }),
    );
    expect(base).not.toBe(
      hashAlteracao({ alvoUid: 'uid-a', conceder: true, expectedVersion: 2 }),
    );
    expect(base).not.toContain('uid-a');
  });
});
