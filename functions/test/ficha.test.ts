import { describe, expect, it, vi } from 'vitest';
import {
  CpfInvalidoError,
  FichaInvalidaError,
  IgrejaInvalidaError,
  ComandoDivergenteError,
  ConflitoVersaoError,
  calcularCamposPendentes,
  calcularDiffFicha,
  calcularPayloadHashFicha,
  validarSalvarFicha,
} from '../src/domain/ficha.js';
import {
  obterMinhaFichaRepo,
  salvarMinhaFichaRepo,
} from '../src/repositories/ficha.js';

describe('Domínio de Ficha Permanente (ficha.ts)', () => {
  const dadosValidos = {
    commandId: 'cmd-valid-1234567890',
    nomeCompleto: 'Manoel da Silva',
    profissao: 'Engenheiro de Software',
    cpf: '529.982.247-25',
    igrejaId: 'igreja-central-01',
    expectedVersion: 0,
  };

  it('valida entrada correta, normaliza CPF e gera payloadHash determinístico', () => {
    const entrada = validarSalvarFicha(dadosValidos);
    expect(entrada.commandId).toBe(dadosValidos.commandId);
    expect(entrada.nomeCompleto).toBe('Manoel da Silva');
    expect(entrada.profissao).toBe('Engenheiro de Software');
    expect(entrada.cpf).toBe('52998224725');
    expect(entrada.igrejaId).toBe('igreja-central-01');
    expect(entrada.expectedVersion).toBe(0);
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it('rejeita CPF matematicamente inválido com CpfInvalidoError', () => {
    expect(() =>
      validarSalvarFicha({
        ...dadosValidos,
        cpf: '111.111.111-11',
      }),
    ).toThrow(CpfInvalidoError);

    expect(() =>
      validarSalvarFicha({
        ...dadosValidos,
        cpf: '12345678900',
      }),
    ).toThrow(CpfInvalidoError);
  });

  it('rejeita campos obrigatórios ausentes ou com tamanho fora dos limites com FichaInvalidaError', () => {
    expect(() =>
      validarSalvarFicha({ ...dadosValidos, nomeCompleto: 'Jo' }),
    ).toThrow(FichaInvalidaError);

    expect(() =>
      validarSalvarFicha({ ...dadosValidos, profissao: 'A' }),
    ).toThrow(FichaInvalidaError);

    expect(() =>
      validarSalvarFicha({ ...dadosValidos, igrejaId: '' }),
    ).toThrow(FichaInvalidaError);

    expect(() =>
      validarSalvarFicha({ ...dadosValidos, commandId: 'curto' }),
    ).toThrow(FichaInvalidaError);

    expect(() =>
      validarSalvarFicha({ ...dadosValidos, expectedVersion: -1 }),
    ).toThrow(FichaInvalidaError);
  });

  it('calcula o mesmo hash para payloads com formatações idênticas', () => {
    const hash1 = calcularPayloadHashFicha({
      nomeCompleto: '  Manoel da Silva  ',
      profissao: ' Engenheiro ',
      cpf: '529.982.247-25',
      igrejaId: ' igreja-1 ',
    });
    const hash2 = calcularPayloadHashFicha({
      nomeCompleto: 'Manoel da Silva',
      profissao: 'Engenheiro',
      cpf: '52998224725',
      igrejaId: 'igreja-1',
    });
    expect(hash1).toBe(hash2);
  });

  it('identifica corretamente os campos obrigatórios pendentes', () => {
    // Todos preenchidos
    expect(
      calcularCamposPendentes({
        nomeCompleto: 'Manoel da Silva',
        profissao: 'Engenheiro',
        cpf: '52998224725',
        igrejaId: 'igreja-1',
      }),
    ).toEqual([]);

    // Campos vazios ou inválidos
    const pendencias = calcularCamposPendentes({
      nomeCompleto: '',
      profissao: '  ',
      cpf: 'invalido',
      igrejaId: '',
    });
    expect(pendencias).toContain('nomeCompleto');
    expect(pendencias).toContain('profissao');
    expect(pendencias).toContain('cpf');
    expect(pendencias).toContain('igrejaId');
  });

  it('calcula o diferencial (diff) de auditoria apenas para os campos cadastrais permitidos', () => {
    const entrada = validarSalvarFicha(dadosValidos);
    const anterior = {
      nomeCompleto: 'Manoel da Silva Antigo',
      profissao: 'Engenheiro de Software',
      cpf: '52998224725',
      igrejaId: 'igreja-antiga-02',
    };

    const diff = calcularDiffFicha(anterior, entrada);
    expect(Object.keys(diff)).toEqual(['nomeCompleto', 'igrejaId']);
    expect(diff.nomeCompleto).toEqual({
      antes: 'Manoel da Silva Antigo',
      depois: 'Manoel da Silva',
    });
    expect(diff.igrejaId).toEqual({
      antes: 'igreja-antiga-02',
      depois: 'igreja-central-01',
    });
    expect(diff.profissao).toBeUndefined();
    expect(diff.cpf).toBeUndefined();
  });
});

describe('Repositório de Ficha Permanente (ficha.ts)', () => {
  it('obterMinhaFichaRepo retorna null para ficha inexistente', async () => {
    const mockDb: any = {
      collection: () => ({
        doc: () => ({
          get: async () => ({ exists: false }),
        }),
      }),
    };

    const resultado = await obterMinhaFichaRepo(mockDb, 'uid-inexistente');
    expect(resultado).toBeNull();
  });

  it('obterMinhaFichaRepo retorna ficha mapeada quando existe', async () => {
    const mockDb: any = {
      collection: () => ({
        doc: (id: string) => ({
          get: async () => ({
            exists: true,
            id,
            data: () => ({
              ownerUid: id,
              nomeCompleto: 'Manoel da Silva',
              profissao: 'Marceneiro',
              cpf: '52998224725',
              igrejaId: 'ig-1',
              estado: 'RASCUNHO',
              versao: 1,
            }),
          }),
        }),
      }),
    };

    const resultado = await obterMinhaFichaRepo(mockDb, 'uid-voluntario-1');
    expect(resultado).not.toBeNull();
    expect(resultado?.nomeCompleto).toBe('Manoel da Silva');
    expect(resultado?.cpf).toBe('52998224725');
    expect(resultado?.estado).toBe('RASCUNHO');
    expect(resultado?.versao).toBe(1);
  });

  it('salvarMinhaFichaRepo salva rascunho com sucesso para nova ficha', async () => {
    const setCalls: any[] = [];
    const entrada = validarSalvarFicha({
      commandId: 'cmd-teste-salvar-001',
      nomeCompleto: 'Carlos Eduardo',
      profissao: 'Professor',
      cpf: '529.982.247-25',
      igrejaId: 'ig-central',
      expectedVersion: 0,
    });

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'igrejas') return { exists: true, data: () => ({ ativo: true }) };
            if (ref.col === 'fichas') return { exists: false };
            return { exists: false };
          },
          set: (ref: any, data: any) => {
            setCalls.push({ ref, data });
          },
        };
        return fn(tx);
      },
    };

    const resultado = await salvarMinhaFichaRepo(
      mockDb,
      { commandId: entrada.commandId, uid: 'uid-carlos' },
      entrada,
    );

    expect(resultado.repetido).toBe(false);
    expect(resultado.ficha.nomeCompleto).toBe('Carlos Eduardo');
    expect(resultado.ficha.versao).toBe(1);
    expect(resultado.ficha.estado).toBe('RASCUNHO');

    // Confirma que foram gravados ficha, recibo em commands e auditoria em auditOutbox
    const cols = setCalls.map((c) => c.ref.col);
    expect(cols).toContain('fichas');
    expect(cols).toContain('commands');
    expect(cols).toContain('auditOutbox');
  });

  it('salvarMinhaFichaRepo rejeita quando igreja é inativa ou inexistente', async () => {
    const entrada = validarSalvarFicha({
      commandId: 'cmd-teste-salvar-002',
      nomeCompleto: 'Carlos Eduardo',
      profissao: 'Professor',
      cpf: '529.982.247-25',
      igrejaId: 'ig-inativa',
      expectedVersion: 0,
    });

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'igrejas') return { exists: true, data: () => ({ ativo: false }) };
            if (ref.col === 'fichas') return { exists: false };
            return { exists: false };
          },
          set: () => {},
        };
        return fn(tx);
      },
    };

    await expect(
      salvarMinhaFichaRepo(
        mockDb,
        { commandId: entrada.commandId, uid: 'uid-carlos' },
        entrada,
      ),
    ).rejects.toThrow(IgrejaInvalidaError);
  });

  it('salvarMinhaFichaRepo rejeita conflito de concorrência se a versão divergir', async () => {
    const entrada = validarSalvarFicha({
      commandId: 'cmd-teste-salvar-003',
      nomeCompleto: 'Carlos Eduardo',
      profissao: 'Professor',
      cpf: '529.982.247-25',
      igrejaId: 'ig-central',
      expectedVersion: 1, // Espera versão 1
    });

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'igrejas') return { exists: true, data: () => ({ ativo: true }) };
            // Ficha já está na versão 2 no banco
            if (ref.col === 'fichas') return { exists: true, data: () => ({ versao: 2, estado: 'RASCUNHO' }) };
            return { exists: false };
          },
          set: () => {},
        };
        return fn(tx);
      },
    };

    await expect(
      salvarMinhaFichaRepo(
        mockDb,
        { commandId: entrada.commandId, uid: 'uid-carlos' },
        entrada,
      ),
    ).rejects.toThrow(ConflitoVersaoError);
  });

  it('salvarMinhaFichaRepo garante idempotência e rejeita payload divergente com mesmo commandId', async () => {
    const entrada = validarSalvarFicha({
      commandId: 'cmd-teste-salvar-004',
      nomeCompleto: 'Carlos Eduardo',
      profissao: 'Professor',
      cpf: '529.982.247-25',
      igrejaId: 'ig-central',
    });

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') {
              return {
                exists: true,
                data: () => ({
                  uid: 'uid-carlos',
                  payloadHash: 'outro-hash-divergente-12345',
                }),
              };
            }
            return { exists: false };
          },
          set: () => {},
        };
        return fn(tx);
      },
    };

    await expect(
      salvarMinhaFichaRepo(
        mockDb,
        { commandId: entrada.commandId, uid: 'uid-carlos' },
        entrada,
      ),
    ).rejects.toThrow(ComandoDivergenteError);
  });

  it('salvarMinhaFichaRepo em ficha com histórico preserva estado anterior e incrementa versão', async () => {
    const setCalls: any[] = [];
    const entrada = validarSalvarFicha({
      commandId: 'cmd-teste-salvar-005',
      nomeCompleto: 'Carlos Eduardo Silva',
      profissao: 'Professor Universitário',
      cpf: '529.982.247-25',
      igrejaId: 'ig-central',
      expectedVersion: 3,
    });

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'igrejas') return { exists: true, data: () => ({ ativo: true }) };
            // Ficha já com histórico (ex: SUBMETIDA)
            if (ref.col === 'fichas') {
              return {
                exists: true,
                id: 'uid-carlos',
                data: () => ({
                  versao: 3,
                  estado: 'SUBMETIDA',
                  nomeCompleto: 'Carlos Eduardo',
                  profissao: 'Professor',
                  cpf: '52998224725',
                  igrejaId: 'ig-central',
                }),
              };
            }
            return { exists: false };
          },
          set: (ref: any, data: any) => {
            setCalls.push({ ref, data });
          },
        };
        return fn(tx);
      },
    };

    const resultado = await salvarMinhaFichaRepo(
      mockDb,
      { commandId: entrada.commandId, uid: 'uid-carlos' },
      entrada,
    );

    expect(resultado.repetido).toBe(false);
    expect(resultado.ficha.estado).toBe('SUBMETIDA'); // Preserva estado!
    expect(resultado.ficha.versao).toBe(4); // versao 3 + 1

    const outboxSet = setCalls.find((c) => c.ref.col === 'auditOutbox');
    expect(outboxSet.data.action).toBe('FICHA_ATUALIZADA');
    expect(outboxSet.data.diff.nomeCompleto).toBeDefined();
  });
});
