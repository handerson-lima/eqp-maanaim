import { describe, expect, it } from 'vitest';
import {
  ComandoDivergenteError,
  EquipeInvalidaError,
  EquipeJaEmAndamentoError,
  FichaNaoElegivelParaReativacaoError,
  FichaNaoEncontradaError,
  ParticipacaoNaoEncontradaError,
  ParticipacaoNaoTerminalError,
  PermissaoNegadaError,
  SolicitacaoReativacaoInvalidaError,
  TermoInvalidoError,
  calcularPayloadHashSolicitarReativacao,
  validarSolicitarReativacao,
} from '../src/domain/solicitarReativacao.js';
import { solicitarReativacaoRepo } from '../src/repositories/solicitarReativacao.js';
import { solicitarReativacao } from '../src/commands/solicitarReativacao.js';

describe('Story 4.4: Domínio de Solicitar Reativação', () => {
  it('valida payload correto e gera payloadHash determinístico', () => {
    const entrada = validarSolicitarReativacao({
      commandId: 'cmd-reativar-001',
      equipeId: 'eq-louvor',
      participacaoId: 'part-antiga-01',
      justificativa: 'Desejo voltar a servir nesta equipe',
      correlationId: 'corr-001',
    });

    expect(entrada.commandId).toBe('cmd-reativar-001');
    expect(entrada.equipeId).toBe('eq-louvor');
    expect(entrada.participacaoId).toBe('part-antiga-01');
    expect(entrada.justificativa).toBe('Desejo voltar a servir nesta equipe');
    expect(entrada.correlationId).toBe('corr-001');
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it('calcula o mesmo hash para entradas equivalentes', () => {
    const hash1 = calcularPayloadHashSolicitarReativacao({
      equipeId: 'eq-louvor',
      participacaoId: 'part-antiga-01',
      justificativa: 'Motivo A',
    });
    const hash2 = calcularPayloadHashSolicitarReativacao({
      equipeId: 'eq-louvor',
      participacaoId: 'part-antiga-01',
      justificativa: 'Motivo A',
    });
    expect(hash1).toBe(hash2);
  });

  it('rejeita commandId ausente ou com menos de 8 caracteres', () => {
    expect(() =>
      validarSolicitarReativacao({
        commandId: 'curto',
        equipeId: 'eq-louvor',
      }),
    ).toThrow(SolicitacaoReativacaoInvalidaError);

    expect(() =>
      validarSolicitarReativacao({
        commandId: '',
        equipeId: 'eq-louvor',
      }),
    ).toThrow(SolicitacaoReativacaoInvalidaError);
  });

  it('rejeita equipeId ausente ou vazio', () => {
    expect(() =>
      validarSolicitarReativacao({
        commandId: 'cmd-12345678',
        equipeId: '',
      }),
    ).toThrow(SolicitacaoReativacaoInvalidaError);

    expect(() =>
      validarSolicitarReativacao({
        commandId: 'cmd-12345678',
      }),
    ).toThrow(SolicitacaoReativacaoInvalidaError);
  });
});

describe('Story 4.4: Repositório de Solicitar Reativação', () => {
  const voluntarioUid = 'voluntario-inativo-01';
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
              if (col === 'participacoes') {
                const p = cenario.participacoes?.find((item) => item.id === docId);
                return { exists: !!p, id: docId, data: () => p?.data ?? p };
              }
              if (col === 'commands') {
                const d = cenario.recibos?.[docId];
                return { exists: !!d, id: docId, data: () => d };
              }
              return { exists: false, id: docId, data: () => undefined };
            },
            set: (data: any) => sets.push({ ref: { col, id: docId }, data }),
            update: (data: any) => updates.push({ ref: { col, id: docId }, data }),
          };
        },
        where: (campo: string, op: string, valor: any) => ({
          limit: () => ({
            get: async () => {
              if (col === 'participacoes') {
                const docs = (cenario.participacoes ?? [])
                  .filter((item: any) => (item.data ? item.data[campo] : item[campo]) === valor)
                  .map((item: any) => ({
                    id: item.id,
                    data: () => item.data ?? item,
                  }));
                return { docs, empty: docs.length === 0 };
              }
              return { docs: [], empty: true };
            },
          }),
        }),
      }),
      runTransaction: async (updateFunction: any) => {
        const tx: any = {
          get: async (ref: any) => ref.get(),
          set: (ref: any, data: any) => sets.push({ ref, data }),
          update: (ref: any, data: any) => updates.push({ ref, data }),
        };
        return await updateFunction(tx);
      },
      __sets: sets,
      __updates: updates,
    };

    return mockDb;
  }

  const fichaPadraoInativa = {
    estado: 'INATIVA',
    igrejaId: 'igreja-01',
    versao: 3,
    dadosPessoais: { nomeCompleto: 'Irmão Reativando' },
    termoAceito: {
      termoId: termoIdPadrao,
      versaoId: versaoTermoVigente,
    },
  };

  const termosValidos = {
    [termoIdPadrao]: {
      ativo: true,
      versaoVigenteId: versaoTermoVigente,
    },
  };

  const equipesValidas = {
    'eq-louvor': {
      nome: 'Equipe de Louvor',
      ativo: true,
    },
    'eq-midia': {
      nome: 'Equipe de Mídia',
      ativo: true,
    },
  };

  it('cria solicitação de reativação com sucesso preservando a anterior de forma append-only', async () => {
    const partAntigaId = 'part-antiga-cancelada';
    const mockDb = criarMockDb({
      ficha: fichaPadraoInativa,
      termos: termosValidos,
      equipes: equipesValidas,
      participacoes: [
        {
          id: partAntigaId,
          fichaId: voluntarioUid,
          equipeId: 'eq-louvor',
          estado: 'CANCELADA',
          data: {
            fichaId: voluntarioUid,
            equipeId: 'eq-louvor',
            estado: 'CANCELADA',
            ciclo: 'INICIAL',
            proximaAcao: 'Participação cancelada',
          },
        },
      ],
    });

    const entrada = validarSolicitarReativacao({
      commandId: 'cmd-reativar-100',
      equipeId: 'eq-louvor',
      participacaoId: partAntigaId,
      justificativa: 'Gostaria de retornar ao louvor',
    });

    const resultado = await solicitarReativacaoRepo(
      mockDb,
      {
        commandId: entrada.commandId,
        uid: voluntarioUid,
      },
      entrada,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.repetido).toBe(false);
    expect(resultado.estado).toBe('AGUARDANDO_PASTOR_LOCAL');
    expect(resultado.proximaAcao).toBe('Aguardando avaliação do Pastor Local');
    expect(resultado.participacaoAnteriorId).toBe(partAntigaId);

    // 1. Invariante: Participação anterior NUNCA é modificada (append-only)
    const updatePartAntiga = mockDb.__updates.find(
      (u: any) => u.ref.col === 'participacoes' && u.ref.id === partAntigaId,
    );
    expect(updatePartAntiga).toBeUndefined();

    // 2. Nova participação criada em AGUARDANDO_PASTOR_LOCAL
    const novaPartSet = mockDb.__sets.find(
      (s: any) =>
        s.ref.col === 'participacoes' &&
        s.ref.id === resultado.participacaoId,
    );
    expect(novaPartSet).toBeDefined();
    expect(novaPartSet.data.estado).toBe('AGUARDANDO_PASTOR_LOCAL');
    expect(novaPartSet.data.ciclo).toBe('REATIVACAO');
    expect(novaPartSet.data.participacaoAnteriorId).toBe(partAntigaId);

    // 3. Novo ciclo criado
    const novoCicloSet = mockDb.__sets.find(
      (s: any) => s.ref.col === 'ciclos' && s.ref.id === resultado.cicloId,
    );
    expect(novoCicloSet).toBeDefined();
    expect(novoCicloSet.data.tipo).toBe('REATIVACAO');
    expect(novoCicloSet.data.estado).toBe('EM_APROVACAO');
    expect(novoCicloSet.data.justificativa).toBe('Gostaria de retornar ao louvor');

    // 4. Projeção de fila do Pastor atualizada
    const filaSet = mockDb.__sets.find(
      (s: any) => s.ref.col === 'filaPendencias' && s.ref.id === voluntarioUid,
    );
    expect(filaSet).toBeDefined();
    expect(filaSet.data.estado).toBe('AGUARDANDO_PASTOR_LOCAL');
    expect(filaSet.data.equipes[0].reativacao).toBe(true);

    // 5. Evidência, Auditoria e Recibo gravados
    const evidenciaSet = mockDb.__sets.find(
      (s: any) => s.ref.col === 'evidenciasDecisao' && s.ref.id === entrada.commandId,
    );
    expect(evidenciaSet).toBeDefined();
    expect(evidenciaSet.data.etapa).toBe('SOLICITACAO_REATIVACAO');
    expect(evidenciaSet.data.decisao).toBe('SOLICITADO');

    const outboxSet = mockDb.__sets.find(
      (s: any) => s.ref.col === 'auditOutbox' && s.ref.id === entrada.commandId,
    );
    expect(outboxSet).toBeDefined();
    expect(outboxSet.data.action).toBe('SOLICITAR_REATIVACAO');

    const reciboSet = mockDb.__sets.find(
      (s: any) => s.ref.col === 'commands' && s.ref.id === entrada.commandId,
    );
    expect(reciboSet).toBeDefined();
    expect(reciboSet.data.estado).toBe('COMPLETO');
  });

  it('mantém a ficha ATIVA se o voluntário já mantiver outra participação ativa (AD-11)', async () => {
    const fichaAtiva = {
      ...fichaPadraoInativa,
      estado: 'ATIVA',
      versao: 5,
    };

    const mockDb = criarMockDb({
      ficha: fichaAtiva,
      termos: termosValidos,
      equipes: equipesValidas,
      participacoes: [
        {
          id: 'part-ativa-musica',
          fichaId: voluntarioUid,
          equipeId: 'eq-midia',
          estado: 'ATIVA',
          data: { fichaId: voluntarioUid, equipeId: 'eq-midia', estado: 'ATIVA' },
        },
        {
          id: 'part-cancelada-louvor',
          fichaId: voluntarioUid,
          equipeId: 'eq-louvor',
          estado: 'CANCELADA',
          data: { fichaId: voluntarioUid, equipeId: 'eq-louvor', estado: 'CANCELADA' },
        },
      ],
    });

    const entrada = validarSolicitarReativacao({
      commandId: 'cmd-reativar-200',
      equipeId: 'eq-louvor',
      participacaoId: 'part-cancelada-louvor',
    });

    const resultado = await solicitarReativacaoRepo(
      mockDb,
      {
        commandId: entrada.commandId,
        uid: voluntarioUid,
      },
      entrada,
    );

    expect(resultado.sucesso).toBe(true);

    // Ficha deve permanecer com estado ATIVA
    const updateFicha = mockDb.__updates.find(
      (u: any) => u.ref.col === 'fichas' && u.ref.id === voluntarioUid,
    );
    expect(updateFicha).toBeDefined();
    expect(updateFicha.data.estado).toBe('ATIVA');
  });

  it('rejeita reativação se a participação alvo não estiver em estado terminal', async () => {
    const mockDb = criarMockDb({
      ficha: fichaPadraoInativa,
      termos: termosValidos,
      equipes: equipesValidas,
      participacoes: [
        {
          id: 'part-em-andamento',
          fichaId: voluntarioUid,
          equipeId: 'eq-louvor',
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          data: {
            fichaId: voluntarioUid,
            equipeId: 'eq-louvor',
            estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          },
        },
      ],
    });

    const entrada = validarSolicitarReativacao({
      commandId: 'cmd-reativar-erro-1',
      equipeId: 'eq-louvor',
      participacaoId: 'part-em-andamento',
    });

    await expect(
      solicitarReativacaoRepo(
        mockDb,
        {
          commandId: entrada.commandId,
          uid: voluntarioUid,
        },
        entrada,
      ),
    ).rejects.toThrow(ParticipacaoNaoTerminalError);
  });

  it('rejeita se o voluntário já tiver ciclo não terminal em andamento na mesma equipe', async () => {
    const mockDb = criarMockDb({
      ficha: fichaPadraoInativa,
      termos: termosValidos,
      equipes: equipesValidas,
      participacoes: [
        {
          id: 'part-cancelada-antiga',
          fichaId: voluntarioUid,
          equipeId: 'eq-louvor',
          estado: 'CANCELADA',
          data: { fichaId: voluntarioUid, equipeId: 'eq-louvor', estado: 'CANCELADA' },
        },
        {
          id: 'part-nova-em-andamento',
          fichaId: voluntarioUid,
          equipeId: 'eq-louvor',
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          data: { fichaId: voluntarioUid, equipeId: 'eq-louvor', estado: 'AGUARDANDO_PASTOR_LOCAL' },
        },
      ],
    });

    const entrada = validarSolicitarReativacao({
      commandId: 'cmd-reativar-erro-2',
      equipeId: 'eq-louvor',
      participacaoId: 'part-cancelada-antiga',
    });

    await expect(
      solicitarReativacaoRepo(
        mockDb,
        {
          commandId: entrada.commandId,
          uid: voluntarioUid,
        },
        entrada,
      ),
    ).rejects.toThrow(EquipeJaEmAndamentoError);
  });

  it('rejeita se a participação pertencer a outro voluntário', async () => {
    const mockDb = criarMockDb({
      ficha: fichaPadraoInativa,
      termos: termosValidos,
      equipes: equipesValidas,
      participacoes: [
        {
          id: 'part-outro-usuario',
          fichaId: 'outro-voluntario',
          equipeId: 'eq-louvor',
          estado: 'CANCELADA',
          data: { fichaId: 'outro-voluntario', equipeId: 'eq-louvor', estado: 'CANCELADA' },
        },
      ],
    });

    const entrada = validarSolicitarReativacao({
      commandId: 'cmd-reativar-outro',
      equipeId: 'eq-louvor',
      participacaoId: 'part-outro-usuario',
    });

    await expect(
      solicitarReativacaoRepo(
        mockDb,
        {
          commandId: entrada.commandId,
          uid: voluntarioUid,
        },
        entrada,
      ),
    ).rejects.toThrow(PermissaoNegadaError);
  });

  it('retorna resultado idempotente em caso de reenvio idêntico', async () => {
    const entrada = validarSolicitarReativacao({
      commandId: 'cmd-idempotente-01',
      equipeId: 'eq-louvor',
      participacaoId: 'part-antiga-01',
    });

    const mockDb = criarMockDb({
      recibos: {
        'cmd-idempotente-01': {
          uid: voluntarioUid,
          payloadHash: entrada.payloadHash,
          criadoEm: '2026-10-07T10:00:00.000Z',
          resultado: {
            sucesso: true,
            participacaoId: 'part-gerada-123',
            participacaoAnteriorId: 'part-antiga-01',
            cicloId: 'ciclo-123',
            equipeId: 'eq-louvor',
            nomeEquipe: 'Equipe de Louvor',
            estado: 'AGUARDANDO_PASTOR_LOCAL',
            proximaAcao: 'Aguardando avaliação do Pastor Local',
          },
        },
      },
    });

    const resultado = await solicitarReativacaoRepo(
      mockDb,
      {
        commandId: entrada.commandId,
        uid: voluntarioUid,
      },
      entrada,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.repetido).toBe(true);
    expect(resultado.participacaoId).toBe('part-gerada-123');
  });

  it('lança ComandoDivergenteError se commandId for reutilizado com payload diferente', async () => {
    const entrada = validarSolicitarReativacao({
      commandId: 'cmd-divergente-01',
      equipeId: 'eq-louvor',
      participacaoId: 'part-antiga-01',
    });

    const mockDb = criarMockDb({
      recibos: {
        'cmd-divergente-01': {
          uid: voluntarioUid,
          payloadHash: 'hash-completamente-diferente',
        },
      },
    });

    await expect(
      solicitarReativacaoRepo(
        mockDb,
        {
          commandId: entrada.commandId,
          uid: voluntarioUid,
        },
        entrada,
      ),
    ).rejects.toThrow(ComandoDivergenteError);
  });
});

describe('Story 4.4: Callable Cloud Function solicitarReativacao', () => {
  it('rejeita chamadas não autenticadas', async () => {
    const callable: any = solicitarReativacao;
    await expect(
      callable.run({
        auth: null,
        data: {
          commandId: 'cmd-teste-auth',
          equipeId: 'eq-louvor',
        },
      }),
    ).rejects.toThrow('É necessário entrar na conta.');
  });

  it('rejeita tentativa de solicitar para outro usuário', async () => {
    const callable: any = solicitarReativacao;
    await expect(
      callable.run({
        auth: { uid: 'meu-uid' },
        data: {
          uid: 'outro-uid',
          commandId: 'cmd-teste-outro',
          equipeId: 'eq-louvor',
        },
      }),
    ).rejects.toThrow('Não é permitido solicitar reativação em nome de outro voluntário.');
  });
});
