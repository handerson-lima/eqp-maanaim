import { describe, expect, it } from 'vitest';
import {
  ComandoDivergenteError,
  EquipeInvalidaError,
  FichaNaoEncontradaError,
  ParticipacaoInvalidaError,
  calcularPayloadHashParticipacoes,
  validarSalvarParticipacoes,
} from '../src/domain/participacao.js';
import {
  obterMinhasParticipacoesRepo,
  salvarParticipacoesRascunhoRepo,
} from '../src/repositories/participacao.js';
import { obterMinhasParticipacoes } from '../src/commands/obterMinhasParticipacoes.js';
import { salvarParticipacoesRascunho } from '../src/commands/salvarParticipacoesRascunho.js';

describe('Domínio de Participações em Rascunho (participacao.ts)', () => {
  const dadosValidos = {
    commandId: 'cmd-part-12345678',
    equipeIds: ['equipe-1', 'equipe-2'],
  };

  it('valida entrada correta, deduplica equipeIds e gera payloadHash determinístico', () => {
    const entrada = validarSalvarParticipacoes({
      commandId: 'cmd-part-12345678',
      equipeIds: ['equipe-2', 'equipe-1', 'equipe-2'],
    });

    expect(entrada.commandId).toBe('cmd-part-12345678');
    expect(entrada.equipeIds).toEqual(['equipe-2', 'equipe-1']);
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it('calcula o mesmo hash independentemente da ordem inicial ao passar pelos mesmos IDs', () => {
    const hash1 = calcularPayloadHashParticipacoes(['equipe-a', 'equipe-b']);
    const hash2 = calcularPayloadHashParticipacoes(['equipe-b', 'equipe-a']);
    expect(hash1).toBe(hash2);
  });

  it('rejeita commandId ausente ou com menos de 8 caracteres', () => {
    expect(() =>
      validarSalvarParticipacoes({ commandId: 'curto', equipeIds: ['eq-1'] }),
    ).toThrow(ParticipacaoInvalidaError);

    expect(() =>
      validarSalvarParticipacoes({ commandId: '', equipeIds: ['eq-1'] }),
    ).toThrow(ParticipacaoInvalidaError);
  });

  it('rejeita equipeIds se não for array ou se contiver itens vazios/inválidos', () => {
    expect(() =>
      validarSalvarParticipacoes({ commandId: 'cmd-12345678', equipeIds: 'nao-array' }),
    ).toThrow(ParticipacaoInvalidaError);

    expect(() =>
      validarSalvarParticipacoes({
        commandId: 'cmd-12345678',
        equipeIds: ['eq-1', '   ', 'eq-2'],
      }),
    ).toThrow(ParticipacaoInvalidaError);

    expect(() =>
      validarSalvarParticipacoes({
        commandId: 'cmd-12345678',
        equipeIds: ['eq-1', 123 as any],
      }),
    ).toThrow(ParticipacaoInvalidaError);
  });
});

describe('Repositório de Participações (participacao.ts)', () => {
  it('obterMinhasParticipacoesRepo retorna lista vazia quando voluntário não possui participações', async () => {
    const mockDb: any = {
      collection: (col: string) => ({
        where: (campo: string, op: string, valor: string) => ({
          get: async () => ({ docs: [] }),
        }),
      }),
    };

    const resultado = await obterMinhasParticipacoesRepo(mockDb, 'voluntario-sem-equipes');
    expect(resultado).toEqual([]);
  });

  it('obterMinhasParticipacoesRepo retorna participações ordenadas e mapeadas da ficha', async () => {
    const docs = [
      {
        id: 'part-1',
        data: () => ({
          fichaId: 'uid-voluntario-1',
          equipeId: 'eq-b',
          nomeEquipe: 'Recepção',
          estado: 'RASCUNHO',
          ciclo: 'INICIAL',
          proximaAcao: 'Aguardando envio da ficha',
        }),
      },
      {
        id: 'part-2',
        data: () => ({
          fichaId: 'uid-voluntario-1',
          equipeId: 'eq-a',
          nomeEquipe: 'Apoio',
          estado: 'RASCUNHO',
          ciclo: 'INICIAL',
          proximaAcao: 'Aguardando envio da ficha',
        }),
      },
    ];

    const mockDb: any = {
      collection: (col: string) => ({
        where: (campo: string, op: string, valor: string) => ({
          get: async () => ({ docs }),
        }),
      }),
    };

    const resultado = await obterMinhasParticipacoesRepo(mockDb, 'uid-voluntario-1');
    expect(resultado).toHaveLength(2);
    expect(resultado[0].nomeEquipe).toBe('Apoio');
    expect(resultado[1].nomeEquipe).toBe('Recepção');
    expect(resultado[0].estado).toBe('RASCUNHO');
    expect(resultado[0].ciclo).toBe('INICIAL');
  });

  it('salvarParticipacoesRascunhoRepo falha com FichaNaoEncontradaError se ficha permanente não existir', async () => {
    const entrada = validarSalvarParticipacoes({
      commandId: 'cmd-teste-sem-ficha',
      equipeIds: ['eq-1'],
    });

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
        where: () => ({ get: async () => ({ docs: [] }) }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'fichas') return { exists: false };
            return { exists: false };
          },
        };
        return fn(tx);
      },
    };

    await expect(
      salvarParticipacoesRascunhoRepo(
        mockDb,
        { commandId: entrada.commandId, uid: 'uid-sem-ficha' },
        entrada,
      ),
    ).rejects.toThrow(FichaNaoEncontradaError);
  });

  it('salvarParticipacoesRascunhoRepo falha com EquipeInvalidaError se equipe não existir ou estiver inativa', async () => {
    const entrada = validarSalvarParticipacoes({
      commandId: 'cmd-teste-eq-inativa',
      equipeIds: ['eq-inativa'],
    });

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
        where: () => ({ get: async () => ({ docs: [] }) }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'fichas') return { exists: true, data: () => ({ estado: 'RASCUNHO' }) };
            if (ref.col === 'equipes' && ref.id === 'eq-inativa') {
              return { exists: true, data: () => ({ ativo: false, nome: 'Inativa' }) };
            }
            return { exists: false };
          },
        };
        return fn(tx);
      },
    };

    await expect(
      salvarParticipacoesRascunhoRepo(
        mockDb,
        { commandId: entrada.commandId, uid: 'uid-vol' },
        entrada,
      ),
    ).rejects.toThrow(EquipeInvalidaError);
  });

  it('salvarParticipacoesRascunhoRepo cria participações, grava recibo e auditoria com equipes ativas', async () => {
    const setCalls: any[] = [];
    const deleteCalls: any[] = [];

    const entrada = validarSalvarParticipacoes({
      commandId: 'cmd-teste-salvar-eq',
      equipeIds: ['eq-1', 'eq-2'],
    });

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id?: string) => ({
          col,
          id: id ?? `id-gerado-${Math.random().toString(36).substring(2, 7)}`,
        }),
        where: () => ({
          get: async () => ({ docs: [] }),
        }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (target: any) => {
            if (target.col === 'commands') return { exists: false };
            if (target.col === 'fichas') return { exists: true, data: () => ({ estado: 'RASCUNHO' }) };
            if (target.col === 'equipes') {
              if (target.id === 'eq-1') return { exists: true, data: () => ({ ativo: true, nome: 'Cozinha' }) };
              if (target.id === 'eq-2') return { exists: true, data: () => ({ ativo: true, nome: 'Louvor' }) };
            }
            // query em participações
            return { docs: [] };
          },
          set: (ref: any, data: any) => {
            setCalls.push({ ref, data });
          },
          delete: (ref: any) => {
            deleteCalls.push(ref);
          },
        };
        return fn(tx);
      },
    };

    const resultado = await salvarParticipacoesRascunhoRepo(
      mockDb,
      { commandId: entrada.commandId, uid: 'uid-vol' },
      entrada,
    );

    expect(resultado.repetido).toBe(false);
    expect(resultado.participacoes).toHaveLength(2);
    expect(resultado.participacoes[0].nomeEquipe).toBe('Cozinha');
    expect(resultado.participacoes[1].nomeEquipe).toBe('Louvor');
    expect(resultado.participacoes[0].estado).toBe('RASCUNHO');
    expect(resultado.participacoes[0].ciclo).toBe('INICIAL');

    // Verifica gravação do recibo em commands e auditoria em auditOutbox
    const recibo = setCalls.find((c) => c.ref.col === 'commands');
    expect(recibo).toBeDefined();
    expect(recibo.data.action).toBe('SALVAR_PARTICIPACOES_RASCUNHO');
    expect(recibo.data.payloadHash).toBe(entrada.payloadHash);

    const auditoria = setCalls.find((c) => c.ref.col === 'auditOutbox');
    expect(auditoria).toBeDefined();
    expect(auditoria.data.action).toBe('PARTICIPACOES_RASCUNHO_SALVAS');
  });

  it('salvarParticipacoesRascunhoRepo remove equipe desmarcada sem tocar em participações ativas', async () => {
    const setCalls: any[] = [];
    const deleteCalls: any[] = [];

    // O voluntário agora seleciona apenas eq-2
    const entrada = validarSalvarParticipacoes({
      commandId: 'cmd-teste-remover-eq',
      equipeIds: ['eq-2'],
    });

    const participacaoRascunhoRemover = {
      id: 'part-rascunho-1',
      ref: { col: 'participacoes', id: 'part-rascunho-1' },
      data: () => ({
        fichaId: 'uid-vol',
        equipeId: 'eq-1',
        nomeEquipe: 'Cozinha',
        estado: 'RASCUNHO',
        ciclo: 'INICIAL',
      }),
    };

    const participacaoRascunhoManter = {
      id: 'part-rascunho-2',
      ref: { col: 'participacoes', id: 'part-rascunho-2' },
      data: () => ({
        fichaId: 'uid-vol',
        equipeId: 'eq-2',
        nomeEquipe: 'Louvor',
        estado: 'RASCUNHO',
        ciclo: 'INICIAL',
      }),
    };

    const participacaoAtivaHistorico = {
      id: 'part-ativa-99',
      ref: { col: 'participacoes', id: 'part-ativa-99' },
      data: () => ({
        fichaId: 'uid-vol',
        equipeId: 'eq-3',
        nomeEquipe: 'Intercessão',
        estado: 'ATIVA',
        ciclo: 'ANTERIOR',
      }),
    };

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id?: string) => ({
          col,
          id: id ?? `id-gerado-${Math.random().toString(36).substring(2, 7)}`,
        }),
        where: () => ({
          get: async () => ({ docs: [] }),
        }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (target: any) => {
            if (target.col === 'commands') return { exists: false };
            if (target.col === 'fichas') return { exists: true, data: () => ({ estado: 'RASCUNHO' }) };
            if (target.col === 'equipes') {
              if (target.id === 'eq-2') return { exists: true, data: () => ({ ativo: true, nome: 'Louvor' }) };
            }
            return {
              docs: [
                participacaoRascunhoRemover,
                participacaoRascunhoManter,
                participacaoAtivaHistorico,
              ],
            };
          },
          set: (ref: any, data: any) => {
            setCalls.push({ ref, data });
          },
          delete: (ref: any) => {
            deleteCalls.push(ref);
          },
        };
        return fn(tx);
      },
    };

    const resultado = await salvarParticipacoesRascunhoRepo(
      mockDb,
      { commandId: entrada.commandId, uid: 'uid-vol' },
      entrada,
    );

    // eq-1 em RASCUNHO deve ser deletada
    expect(deleteCalls).toHaveLength(1);
    expect(deleteCalls[0].id).toBe('part-rascunho-1');

    // A participação ATIVA nunca deve ser deletada
    expect(deleteCalls.some((c) => c.id === 'part-ativa-99')).toBe(false);

    // O resultado retornado reflete a mantida e a histórica preservada
    expect(resultado.participacoes.some((p) => p.equipeId === 'eq-2')).toBe(true);
    expect(resultado.participacoes.some((p) => p.equipeId === 'eq-1')).toBe(false);
  });

  it('salvarParticipacoesRascunhoRepo é idempotente com mesmo commandId e payload idêntico', async () => {
    const entrada = validarSalvarParticipacoes({
      commandId: 'cmd-teste-idempotencia',
      equipeIds: ['eq-1'],
    });

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
        where: () => ({
          get: async () => ({ docs: [] }),
        }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (target: any) => {
            if (target.col === 'commands') {
              return {
                exists: true,
                data: () => ({
                  uid: 'uid-vol',
                  payloadHash: entrada.payloadHash,
                  action: 'SALVAR_PARTICIPACOES_RASCUNHO',
                }),
              };
            }
            return {
              docs: [
                {
                  id: 'part-1',
                  data: () => ({
                    fichaId: 'uid-vol',
                    equipeId: 'eq-1',
                    nomeEquipe: 'Cozinha',
                    estado: 'RASCUNHO',
                    ciclo: 'INICIAL',
                    proximaAcao: 'Aguardando envio da ficha',
                  }),
                },
              ],
            };
          },
        };
        return fn(tx);
      },
    };

    const resultado = await salvarParticipacoesRascunhoRepo(
      mockDb,
      { commandId: entrada.commandId, uid: 'uid-vol' },
      entrada,
    );

    expect(resultado.repetido).toBe(true);
    expect(resultado.participacoes).toHaveLength(1);
    expect(resultado.participacoes[0].nomeEquipe).toBe('Cozinha');
  });

  it('salvarParticipacoesRascunhoRepo rejeita repetição com mesmo commandId mas payload divergente', async () => {
    const entrada = validarSalvarParticipacoes({
      commandId: 'cmd-teste-divergente',
      equipeIds: ['eq-1'],
    });

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (target: any) => {
            if (target.col === 'commands') {
              return {
                exists: true,
                data: () => ({
                  uid: 'uid-vol',
                  payloadHash: 'hash-completamente-diferente',
                  action: 'SALVAR_PARTICIPACOES_RASCUNHO',
                }),
              };
            }
            return { exists: false };
          },
        };
        return fn(tx);
      },
    };

    await expect(
      salvarParticipacoesRascunhoRepo(
        mockDb,
        { commandId: entrada.commandId, uid: 'uid-vol' },
        entrada,
      ),
    ).rejects.toThrow(ComandoDivergenteError);
  });
});

describe('Callables de Participações (obterMinhasParticipacoes e salvarParticipacoesRascunho)', () => {
  it('obterMinhasParticipacoes rejeita requisição não autenticada', async () => {
    await expect(
      obterMinhasParticipacoes.run({
        auth: undefined,
        data: {},
      } as any),
    ).rejects.toThrow('É necessário entrar na conta.');
  });

  it('obterMinhasParticipacoes rejeita tentativa de consulta de UID de outro voluntário com permission-denied', async () => {
    await expect(
      obterMinhasParticipacoes.run({
        auth: { uid: 'voluntario-proprio' },
        data: { uid: 'outro-voluntario' },
      } as any),
    ).rejects.toThrow('Não é permitido consultar as participações de outro voluntário.');
  });

  it('salvarParticipacoesRascunho rejeita requisição não autenticada', async () => {
    await expect(
      salvarParticipacoesRascunho.run({
        auth: undefined,
        data: { commandId: 'cmd-teste-123', equipeIds: ['eq-1'] },
      } as any),
    ).rejects.toThrow('É necessário entrar na conta.');
  });

  it('salvarParticipacoesRascunho rejeita tentativa de adulterar UID de outro voluntário com permission-denied', async () => {
    await expect(
      salvarParticipacoesRascunho.run({
        auth: { uid: 'voluntario-proprio' },
        data: { uid: 'outro-voluntario', commandId: 'cmd-teste-123', equipeIds: ['eq-1'] },
      } as any),
    ).rejects.toThrow('Não é permitido alterar as participações de outro voluntário.');
  });
});
