import { describe, expect, it } from 'vitest';
import {
  ComandoDivergenteError,
  EquipeInvalidaError,
  EquipeJaSolicitadaError,
  FichaNaoAtivaError,
  FichaNaoEncontradaError,
  PermissaoNegadaError,
  SolicitacaoInvalidaError,
  TermoInvalidoError,
  calcularPayloadHashSolicitarEquipe,
  validarSolicitarEquipeAdicional,
} from '../src/domain/solicitarEquipeAdicional.js';
import { solicitarEquipeAdicionalRepo } from '../src/repositories/solicitarEquipeAdicional.js';
import { solicitarEquipeAdicional } from '../src/commands/solicitarEquipeAdicional.js';

describe('Story 4.2: Domínio de Solicitar Equipe Adicional', () => {
  it('valida payload correto e gera payloadHash determinístico', () => {
    const entrada = validarSolicitarEquipeAdicional({
      commandId: 'cmd-solicitar-123',
      equipeId: 'equipe-musica',
      correlationId: 'corr-001',
    });

    expect(entrada.commandId).toBe('cmd-solicitar-123');
    expect(entrada.equipeId).toBe('equipe-musica');
    expect(entrada.correlationId).toBe('corr-001');
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it('calcula o mesmo hash para entradas equivalentes', () => {
    const hash1 = calcularPayloadHashSolicitarEquipe('equipe-midia');
    const hash2 = calcularPayloadHashSolicitarEquipe('equipe-midia');
    expect(hash1).toBe(hash2);
  });

  it('rejeita commandId ausente ou com menos de 8 caracteres', () => {
    expect(() =>
      validarSolicitarEquipeAdicional({
        commandId: 'curto',
        equipeId: 'equipe-som',
      }),
    ).toThrow(SolicitacaoInvalidaError);

    expect(() =>
      validarSolicitarEquipeAdicional({
        commandId: '',
        equipeId: 'equipe-som',
      }),
    ).toThrow(SolicitacaoInvalidaError);
  });

  it('rejeita equipeId ausente ou vazio', () => {
    expect(() =>
      validarSolicitarEquipeAdicional({
        commandId: 'cmd-12345678',
        equipeId: '',
      }),
    ).toThrow(SolicitacaoInvalidaError);

    expect(() =>
      validarSolicitarEquipeAdicional({
        commandId: 'cmd-12345678',
      }),
    ).toThrow(SolicitacaoInvalidaError);
  });
});

describe('Story 4.2: Repositório de Solicitar Equipe Adicional', () => {
  const voluntarioUid = 'voluntario-ativo-01';
  const termoIdPadrao = 'termo-padrao';
  const versaoTermoVigente = 'versao-2026-v1';

  function criarMockDb(cenario: {
    ficha?: any;
    termos?: Record<string, any>;
    equipes?: Record<string, any>;
    participacoes?: Array<{ id: string; fichaId: string; equipeId: string; estado: string; data?: any }>;
    recibos?: Record<string, any>;
  }) {
    const sets: Array<{ ref: any; data: any }> = [];
    const updates: Array<{ ref: any; data: any }> = [];

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id?: string) => {
          const docId = id ?? `doc-auto-${Math.random().toString(36).substring(2, 9)}`;
          return {
            col,
            id: docId,
            get: async () => {
              if (col === 'fichas') {
                const d = cenario.ficha;
                return { exists: !!d, id: docId, data: () => d };
              }
              if (col === 'termos') {
                const d = cenario.termos?.[docId];
                return { exists: !!d, id: docId, data: () => d };
              }
              if (col === 'equipes') {
                const d = cenario.equipes?.[docId];
                return { exists: !!d, id: docId, data: () => d };
              }
              if (col === 'commands') {
                const d = cenario.recibos?.[docId];
                return { exists: !!d, id: docId, data: () => d };
              }
              return { exists: false, id: docId, data: () => undefined };
            },
          };
        },
        where: (field: string, op: string, val: any) => {
          const executar = async () => {
            if (col === 'participacoes') {
              const matches = (cenario.participacoes ?? []).filter((p) => {
                if (field === 'fichaId') return p.fichaId === val;
                return false;
              });
              return {
                docs: matches.map((m) => ({
                  id: m.id,
                  ref: { col, id: m.id },
                  data: () => ({
                    fichaId: m.fichaId,
                    equipeId: m.equipeId,
                    estado: m.estado,
                    ...(m.data ?? {}),
                  }),
                })),
              };
            }
            return { docs: [] };
          };
          return {
            get: executar,
            limit: (_n: number) => ({ get: executar }),
          };
        },
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => ref.get(),
          set: (ref: any, data: any) => {
            sets.push({ ref, data });
          },
          update: (ref: any, data: any) => {
            updates.push({ ref, data });
          },
        };
        return fn(tx);
      },
      __sets: sets,
      __updates: updates,
    };

    return mockDb;
  }

  const baseFichaAtiva = {
    nomeCompleto: 'Voluntário Ativo Teste',
    estado: 'ATIVA',
    versao: 3,
    termoAceito: {
      termoId: termoIdPadrao,
      versaoId: versaoTermoVigente,
    },
  };

  const baseTermos = {
    [termoIdPadrao]: {
      ativo: true,
      versaoVigenteId: versaoTermoVigente,
    },
  };

  const baseEquipes = {
    'equipe-recepcao': { ativo: true, nome: 'Recepção' },
    'equipe-som': { ativo: true, nome: 'Som e Mídia' },
    'equipe-louvor': { ativo: true, nome: 'Grupo de Louvor' },
    'equipe-inativa': { ativo: false, nome: 'Equipe Desativada' },
  };

  it('cria participação e ciclo de aprovação independentes quando dados são válidos', async () => {
    const mockDb = criarMockDb({
      ficha: baseFichaAtiva,
      termos: baseTermos,
      equipes: baseEquipes,
      participacoes: [
        {
          id: 'part-01',
          fichaId: voluntarioUid,
          equipeId: 'equipe-recepcao',
          estado: 'ATIVA',
          data: { nomeEquipe: 'Recepção' },
        },
      ],
    });

    const entrada = validarSolicitarEquipeAdicional({
      commandId: 'cmd-solicitar-novo-01',
      equipeId: 'equipe-som',
    });

    const resultado = await solicitarEquipeAdicionalRepo(
      mockDb,
      { commandId: entrada.commandId, uid: voluntarioUid },
      entrada,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.repetido).toBe(false);
    expect(resultado.equipeId).toBe('equipe-som');
    expect(resultado.nomeEquipe).toBe('Som e Mídia');
    expect(resultado.estado).toBe('AGUARDANDO_RESPONSAVEL_EQUIPE');
    expect(resultado.proximaAcao).toBe('Aguardando avaliação do Responsável de Equipe');
    expect(resultado.participacaoId).toBeTruthy();
    expect(resultado.cicloId).toContain(resultado.participacaoId);

    // Valida escritas na transação
    const partCriada = mockDb.__sets.find((s: any) => s.ref.col === 'participacoes');
    expect(partCriada).toBeTruthy();
    expect(partCriada.data.estado).toBe('AGUARDANDO_RESPONSAVEL_EQUIPE');
    expect(partCriada.data.equipeId).toBe('equipe-som');
    expect(partCriada.data.fichaId).toBe(voluntarioUid);

    const cicloCriado = mockDb.__sets.find((s: any) => s.ref.col === 'ciclos');
    expect(cicloCriado).toBeTruthy();
    expect(cicloCriado.data.estado).toBe('EM_APROVACAO');
    expect(cicloCriado.data.tipo).toBe('NOVA_EQUIPE');

    const recibo = mockDb.__sets.find((s: any) => s.ref.col === 'commands');
    expect(recibo).toBeTruthy();
    expect(recibo.data.estado).toBe('COMPLETO');

    const auditoria = mockDb.__sets.find((s: any) => s.ref.col === 'auditOutbox');
    expect(auditoria).toBeTruthy();
    expect(auditoria.data.action).toBe('SOLICITAR_EQUIPE_ADICIONAL');

    // Nenhuma participação pré-existente foi atualizada
    expect(mockDb.__updates).toHaveLength(0);
  });

  it('rejeita se a ficha não existir', async () => {
    const mockDb = criarMockDb({
      ficha: null,
      termos: baseTermos,
      equipes: baseEquipes,
    });

    const entrada = validarSolicitarEquipeAdicional({
      commandId: 'cmd-solicitar-novo-02',
      equipeId: 'equipe-som',
    });

    await expect(
      solicitarEquipeAdicionalRepo(mockDb, { commandId: entrada.commandId, uid: voluntarioUid }, entrada),
    ).rejects.toThrow(FichaNaoEncontradaError);
  });

  it('rejeita se a ficha não estiver no estado ATIVA', async () => {
    const mockDb = criarMockDb({
      ficha: { ...baseFichaAtiva, estado: 'RASCUNHO' },
      termos: baseTermos,
      equipes: baseEquipes,
    });

    const entrada = validarSolicitarEquipeAdicional({
      commandId: 'cmd-solicitar-novo-03',
      equipeId: 'equipe-som',
    });

    await expect(
      solicitarEquipeAdicionalRepo(mockDb, { commandId: entrada.commandId, uid: voluntarioUid }, entrada),
    ).rejects.toThrow(FichaNaoAtivaError);
  });

  it('rejeita se a equipe solicitada for inativa ou não existir', async () => {
    const mockDb = criarMockDb({
      ficha: baseFichaAtiva,
      termos: baseTermos,
      equipes: baseEquipes,
    });

    // Inativa
    const entradaInativa = validarSolicitarEquipeAdicional({
      commandId: 'cmd-solicitar-novo-04',
      equipeId: 'equipe-inativa',
    });
    await expect(
      solicitarEquipeAdicionalRepo(mockDb, { commandId: entradaInativa.commandId, uid: voluntarioUid }, entradaInativa),
    ).rejects.toThrow(EquipeInvalidaError);

    // Inexistente
    const entradaInexistente = validarSolicitarEquipeAdicional({
      commandId: 'cmd-solicitar-novo-05',
      equipeId: 'equipe-fantasma',
    });
    await expect(
      solicitarEquipeAdicionalRepo(mockDb, { commandId: entradaInexistente.commandId, uid: voluntarioUid }, entradaInexistente),
    ).rejects.toThrow(EquipeInvalidaError);
  });

  it('rejeita solicitação duplicada se o voluntário já possui participação ATIVA na equipe', async () => {
    const mockDb = criarMockDb({
      ficha: baseFichaAtiva,
      termos: baseTermos,
      equipes: baseEquipes,
      participacoes: [
        {
          id: 'part-01',
          fichaId: voluntarioUid,
          equipeId: 'equipe-recepcao',
          estado: 'ATIVA',
        },
      ],
    });

    const entrada = validarSolicitarEquipeAdicional({
      commandId: 'cmd-solicitar-dup-01',
      equipeId: 'equipe-recepcao',
    });

    await expect(
      solicitarEquipeAdicionalRepo(mockDb, { commandId: entrada.commandId, uid: voluntarioUid }, entrada),
    ).rejects.toThrow(EquipeJaSolicitadaError);
  });

  it('rejeita solicitação duplicada se a equipe já estiver em análise/tramitação', async () => {
    const mockDb = criarMockDb({
      ficha: baseFichaAtiva,
      termos: baseTermos,
      equipes: baseEquipes,
      participacoes: [
        {
          id: 'part-01',
          fichaId: voluntarioUid,
          equipeId: 'equipe-som',
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
        },
      ],
    });

    const entrada = validarSolicitarEquipeAdicional({
      commandId: 'cmd-solicitar-dup-02',
      equipeId: 'equipe-som',
    });

    await expect(
      solicitarEquipeAdicionalRepo(mockDb, { commandId: entrada.commandId, uid: voluntarioUid }, entrada),
    ).rejects.toThrow(EquipeJaSolicitadaError);
  });

  it('permite solicitar equipe caso a participação anterior esteja em estado terminal (REJEITADA ou CANCELADA)', async () => {
    const mockDb = criarMockDb({
      ficha: baseFichaAtiva,
      termos: baseTermos,
      equipes: baseEquipes,
      participacoes: [
        {
          id: 'part-antiga',
          fichaId: voluntarioUid,
          equipeId: 'equipe-som',
          estado: 'REJEITADA',
        },
      ],
    });

    const entrada = validarSolicitarEquipeAdicional({
      commandId: 'cmd-solicitar-rejeitada-01',
      equipeId: 'equipe-som',
    });

    const resultado = await solicitarEquipeAdicionalRepo(
      mockDb,
      { commandId: entrada.commandId, uid: voluntarioUid },
      entrada,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.estado).toBe('AGUARDANDO_RESPONSAVEL_EQUIPE');
  });

  it('retorna resultado idempotente em caso de repetição com mesmo commandId e payload', async () => {
    const entrada = validarSolicitarEquipeAdicional({
      commandId: 'cmd-repetido-01',
      equipeId: 'equipe-som',
    });

    const mockDb = criarMockDb({
      ficha: baseFichaAtiva,
      termos: baseTermos,
      equipes: baseEquipes,
      recibos: {
        'cmd-repetido-01': {
          uid: voluntarioUid,
          payloadHash: entrada.payloadHash,
          resultado: {
            participacaoId: 'part-original',
            cicloId: 'ciclo-original',
            equipeId: 'equipe-som',
            nomeEquipe: 'Som e Mídia',
            estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          },
          criadoEm: '2026-10-07T00:00:00.000Z',
        },
      },
    });

    const resultado = await solicitarEquipeAdicionalRepo(
      mockDb,
      { commandId: entrada.commandId, uid: voluntarioUid },
      entrada,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.repetido).toBe(true);
    expect(resultado.participacaoId).toBe('part-original');
  });

  it('rejeita com ComandoDivergenteError caso o mesmo commandId tenha payloadHash diferente', async () => {
    const entrada = validarSolicitarEquipeAdicional({
      commandId: 'cmd-divergente-01',
      equipeId: 'equipe-som',
    });

    const mockDb = criarMockDb({
      ficha: baseFichaAtiva,
      termos: baseTermos,
      equipes: baseEquipes,
      recibos: {
        'cmd-divergente-01': {
          uid: voluntarioUid,
          payloadHash: 'outro-hash-distinto',
          criadoEm: '2026-10-07T00:00:00.000Z',
        },
      },
    });

    await expect(
      solicitarEquipeAdicionalRepo(mockDb, { commandId: entrada.commandId, uid: voluntarioUid }, entrada),
    ).rejects.toThrow(ComandoDivergenteError);
  });
});

describe('Story 4.2: Endpoint Callable solicitarEquipeAdicional', () => {
  it('rejeita chamada não autenticada', async () => {
    const req: any = { auth: null, data: { commandId: 'cmd-12345678', equipeId: 'eq-1' } };
    await expect(solicitarEquipeAdicional.run(req)).rejects.toMatchObject({
      code: 'unauthenticated',
    });
  });

  it('rejeita se uid no payload divergir do uid autenticado', async () => {
    const req: any = {
      auth: { uid: 'user-01' },
      data: { commandId: 'cmd-12345678', equipeId: 'eq-1', uid: 'outro-user' },
    };
    await expect(solicitarEquipeAdicional.run(req)).rejects.toMatchObject({
      code: 'permission-denied',
    });
  });
});
