import { describe, expect, it } from 'vitest';
import {
  PAPEIS_SISTEMA,
  aplicarClaimsSistema,
  papeisEfetivos,
  possuiPapel,
} from '../src/domain/autoridadeAdministrativa.js';
import {
  hashPapeis,
  hashPessoa,
  pesquisarPessoas,
  validarPapeis,
  validarPessoa,
  type PessoaResumo,
} from '../src/domain/pessoas.js';
import { cpfValido, normalizarCpf } from '../src/domain/cpf.js';

const basePessoa = {
  commandId: 'a'.repeat(32),
  nomeCompleto: 'Ana da Silva',
  email: 'Ana.Silva@Exemplo.com',
  coordenador: false,
};

const basePapeis = {
  commandId: 'b'.repeat(32),
  alvoUid: 'uid-alvo-123',
  expectedVersion: 0,
  papel: 'COORDENADOR',
  conceder: true,
};

describe('validação de CPF compartilhada', () => {
  it('aceita CPF válido formatado ou não e rejeita inválidos', () => {
    expect(cpfValido('529.982.247-25')).toBe(true);
    expect(cpfValido('52998224725')).toBe(true);
    expect(cpfValido('111.111.111-11')).toBe(false);
    expect(cpfValido('123')).toBe(false);
    expect(normalizarCpf('529.982.247-25')).toBe('52998224725');
  });
});

describe('catálogo de papéis de sistema', () => {
  it('contém apenas ADMINISTRADOR e COORDENADOR', () => {
    expect(PAPEIS_SISTEMA).toEqual(['ADMINISTRADOR', 'COORDENADOR']);
  });

  it('lê o formato plural e é retrocompatível com o papel singular', () => {
    expect(
      papeisEfetivos({ ativa: true, papeis: ['ADMINISTRADOR', 'COORDENADOR'] }),
    ).toEqual(['ADMINISTRADOR', 'COORDENADOR']);
    expect(papeisEfetivos({ ativa: true, papel: 'ADMINISTRADOR' })).toEqual([
      'ADMINISTRADOR',
    ]);
    expect(papeisEfetivos({ ativa: false, papel: 'ADMINISTRADOR' })).toEqual([]);
    expect(papeisEfetivos(undefined)).toEqual([]);
  });

  it('ignora papéis fora do catálogo e duplicidades', () => {
    expect(
      papeisEfetivos({
        ativa: true,
        papeis: ['ADMINISTRADOR', 'ADMINISTRADOR', 'PASTOR_LOCAL'],
      }),
    ).toEqual(['ADMINISTRADOR']);
  });

  it('projeta uma claim por papel preservando domínios alheios', () => {
    const existentes = { outroDominio: 42, maanaimAdmin: true, maanaimCoordenador: true };
    const semCoordenador = aplicarClaimsSistema(existentes, ['ADMINISTRADOR']);
    expect(semCoordenador.outroDominio).toBe(42);
    expect(semCoordenador.maanaimAdmin).toBe(true);
    expect(semCoordenador).not.toHaveProperty('maanaimCoordenador');
    const ambos = aplicarClaimsSistema(existentes, ['ADMINISTRADOR', 'COORDENADOR']);
    expect(ambos.maanaimAdmin).toBe(true);
    expect(ambos.maanaimCoordenador).toBe(true);
    const nenhum = aplicarClaimsSistema(existentes, []);
    expect(nenhum.outroDominio).toBe(42);
    expect(nenhum).not.toHaveProperty('maanaimAdmin');
    expect(nenhum).not.toHaveProperty('maanaimCoordenador');
  });

  it('reconhece papel sem ampliar a administração', () => {
    expect(possuiPapel({ ativa: true, papeis: ['COORDENADOR'] }, 'ADMINISTRADOR')).toBe(false);
    expect(possuiPapel({ ativa: true, papeis: ['COORDENADOR'] }, 'COORDENADOR')).toBe(true);
  });
});

describe('contrato do cadastro de pessoa', () => {
  it('aceita apenas os campos permitidos e normaliza o e-mail', () => {
    const entrada = validarPessoa(basePessoa);
    expect(entrada.emailNormalizado).toBe('ana.silva@exemplo.com');
    expect(entrada.uid).toBeNull();
    expect(entrada.coordenador).toBe(false);
    expect(entrada.cpf).toBeNull();
    expect(entrada.payloadHash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('exige CPF válido apenas para o Coordenador e o mantém normalizado', () => {
    const coordenador = validarPessoa({
      ...basePessoa,
      coordenador: true,
      cpf: '529.982.247-25',
    });
    expect(coordenador.cpf).toBe('52998224725');
    expect(() =>
      validarPessoa({ ...basePessoa, coordenador: true, cpf: '111.111.111-11' }),
    ).toThrow('PESSOA_INVALIDA');
    expect(() => validarPessoa({ ...basePessoa, coordenador: true })).toThrow(
      'PESSOA_INVALIDA',
    );
    expect(() => validarPessoa({ ...basePessoa, cpf: '529.982.247-25' })).toThrow(
      'PESSOA_INVALIDA',
    );
  });

  it('recusa campos fora do contrato, nome e e-mail inválidos', () => {
    expect(() => validarPessoa({ ...basePessoa, papel: 'ADMIN' })).toThrow(
      'PESSOA_INVALIDA',
    );
    expect(() => validarPessoa({ ...basePessoa, nomeCompleto: 'A' })).toThrow(
      'PESSOA_INVALIDA',
    );
    expect(() => validarPessoa({ ...basePessoa, email: 'sem-arroba' })).toThrow(
      'PESSOA_INVALIDA',
    );
    expect(() => validarPessoa({ ...basePessoa, commandId: 'curto' })).toThrow(
      'PESSOA_INVALIDA',
    );
  });

  it('liga o recibo ao conteúdo sem persistir o UID do alvo', () => {
    const comUid = validarPessoa({ ...basePessoa, uid: 'uid-secreto-123' });
    const base = comUid.payloadHash;
    expect(hashPessoa(comUid)).toBe(base);
    expect(base).not.toContain('uid-secreto-123');
    expect(
      hashPessoa(validarPessoa({ ...basePessoa, uid: 'uid-secreto-456' })),
    ).not.toBe(base);
    expect(
      hashPessoa(validarPessoa({ ...basePessoa, nomeCompleto: 'Ana de Souza' })),
    ).not.toBe(base);
  });
});

describe('contrato de papéis', () => {
  it('aceita apenas papéis do catálogo e versão inteira não negativa', () => {
    expect(validarPapeis(basePapeis).papel).toBe('COORDENADOR');
    expect(() => validarPapeis({ ...basePapeis, papel: 'PASTOR_LOCAL' })).toThrow(
      'PAPEL_INVALIDO',
    );
    expect(() => validarPapeis({ ...basePapeis, expectedVersion: 1.5 })).toThrow(
      'PAPEL_INVALIDO',
    );
    expect(() => validarPapeis({ ...basePapeis, expectedVersion: -1 })).toThrow(
      'PAPEL_INVALIDO',
    );
    expect(() => validarPapeis({ ...basePapeis, conceder: 'sim' })).toThrow(
      'PAPEL_INVALIDO',
    );
    expect(() => validarPapeis({ ...basePapeis, extra: true })).toThrow(
      'PAPEL_INVALIDO',
    );
  });

  it('liga o recibo ao alvo, papel e sentido sem persistir o UID', () => {
    const base = validarPapeis(basePapeis).payloadHash;
    expect(hashPapeis(validarPapeis(basePapeis))).toBe(base);
    expect(base).not.toContain(basePapeis.alvoUid);
    expect(
      hashPapeis(validarPapeis({ ...basePapeis, conceder: false })),
    ).not.toBe(base);
    expect(
      hashPapeis(
        validarPapeis({ ...basePapeis, papel: 'ADMINISTRADOR' }),
      ),
    ).not.toBe(base);
  });
});

describe('pesquisa de pessoas', () => {
  const pessoas: PessoaResumo[] = [
    {
      uid: '1',
      nomeCompleto: 'João Batista',
      email: 'joao@exemplo.com',
      papeis: [],
      versao: 0,
      coordenador: false,
    },
    {
      uid: '2',
      nomeCompleto: 'Ana Lima',
      email: 'ana@exemplo.com',
      papeis: [],
      versao: 0,
      coordenador: false,
    },
  ];

  it('ordena por nome e pesquisa sem acento', () => {
    expect(pesquisarPessoas(pessoas, 'joao').map((p) => p.uid)).toEqual(['1']);
    expect(pesquisarPessoas(pessoas, '').map((p) => p.uid)).toEqual(['2', '1']);
    expect(pesquisarPessoas(pessoas, 'ana@').map((p) => p.uid)).toEqual(['2']);
  });
});
