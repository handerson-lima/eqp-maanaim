import { describe, expect, it } from 'vitest';
import {
  calcularPayloadHashManifestarRenovacao,
  ComandoDivergenteError,
  JanelaRenovacaoFechadaError,
  ParticipacaoNaoElegivelError,
  ParticipacaoNaoEncontradaError,
  PermissaoNegadaError,
  SolicitacaoInvalidaError,
  validarManifestarRenovacao,
} from '../src/domain/manifestarRenovacao.js';
import { executarManifestarRenovacaoRepo } from '../src/repositories/manifestarRenovacao.js';

describe('Story 5.2: Domínio de Manifestar Renovação', () => {
  it('valida payload com lista de manifestações e calcula hash SHA-256 determinístico', () => {
    const entrada = validarManifestarRenovacao({
      commandId: 'cmd-renovacao-001',
      manifestacoes: [
        {
          participacaoId: 'part-01',
          decisao: 'CONTINUAR',
          justificativa: 'Desejo prosseguir servindo',
        },
      ],
      correlationId: 'corr-001',
    });

    expect(entrada.commandId).toBe('cmd-renovacao-001');
    expect(entrada.correlationId).toBe('corr-001');
    expect(entrada.manifestacoes).toHaveLength(1);
    expect(entrada.manifestacoes[0].participacaoId).toBe('part-01');
    expect(entrada.manifestacoes[0].decisao).toBe('CONTINUAR');
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it('suporta payload com formato de item único', () => {
    const entrada = validarManifestarRenovacao({
      commandId: 'cmd-renovacao-002',
      participacaoId: 'part-02',
      decisao: 'NAO_CONTINUAR',
    });

    expect(entrada.manifestacoes).toHaveLength(1);
    expect(entrada.manifestacoes[0].participacaoId).toBe('part-02');
    expect(entrada.manifestacoes[0].decisao).toBe('NAO_CONTINUAR');
  });

  it('calcula o mesmo hash independentemente da ordem dos itens', () => {
    const hash1 = calcularPayloadHashManifestarRenovacao({
      commandId: 'cmd-hash-test',
      manifestacoes: [
        { participacaoId: 'part-a', decisao: 'CONTINUAR' },
        { participacaoId: 'part-b', decisao: 'NAO_CONTINUAR' },
      ],
    });
    const hash2 = calcularPayloadHashManifestarRenovacao({
      commandId: 'cmd-hash-test',
      manifestacoes: [
        { participacaoId: 'part-b', decisao: 'NAO_CONTINUAR' },
        { participacaoId: 'part-a', decisao: 'CONTINUAR' },
      ],
    });
    expect(hash1).toBe(hash2);
  });

  it('rejeita commandId com menos de 8 caracteres ou ausente', () => {
    expect(() =>
      validarManifestarRenovacao({
        commandId: 'curto',
        manifestacoes: [{ participacaoId: 'p1', decisao: 'CONTINUAR' }],
      }),
    ).toThrow(SolicitacaoInvalidaError);
  });

  it('rejeita se não houver manifestações informadas', () => {
    expect(() =>
      validarManifestarRenovacao({
        commandId: 'cmd-renov-001',
        manifestacoes: [],
      }),
    ).toThrow(SolicitacaoInvalidaError);
  });

  it('rejeita decisão com valor inválido', () => {
    expect(() =>
      validarManifestarRenovacao({
        commandId: 'cmd-renov-001',
        manifestacoes: [{ participacaoId: 'p1', decisao: 'TALVEZ' as any }],
      }),
    ).toThrow(SolicitacaoInvalidaError);
  });

  it('rejeita participacaoId duplicado na mesma requisição', () => {
    expect(() =>
      validarManifestarRenovacao({
        commandId: 'cmd-renov-001',
        manifestacoes: [
          { participacaoId: 'p1', decisao: 'CONTINUAR' },
          { participacaoId: 'p1', decisao: 'NAO_CONTINUAR' },
        ],
      }),
    ).toThrow(SolicitacaoInvalidaError);
  });
});

describe('Story 5.2: Repositório de Manifestar Renovação', () => {
  const voluntarioUid = 'user-voluntario-100';

  function criarMockDb(cenario: {
    ficha?: any;
    participacoes?: Record<string, any>;
    ciclos?: Record<string, any>;
    commands?: Record<string, any>;
  }) {
    const sets: Array<{ ref: any; data: any; options?: any }> = [];
    const updates: Array<{ ref: any; data: any }> = [];

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id?: string) => {
          const docId = id ?? `doc-auto-${Math.random().toString(36).substring(2, 9)}`;
          const docRef = {
            col,
            id: docId,
            collection: (subCol: string) => ({
              doc: (subId: string) => ({
                col: `${col}/${docId}/${subCol}`,
                id: subId,
                set: (data: any) =>
                  sets.push({ ref: { col: `${col}/${docId}/${subCol}`, id: subId }, data }),
              }),
            }),
            get: async () => {
              if (col === 'fichas') {
                const d = cenario.ficha;
                return { exists: !!d, id: docId, data: () => d };
              }
              if (col === 'participacoes') {
                const d = cenario.participacoes?.[docId];
                return { exists: !!d, id: docId, data: () => d };
              }
              if (col === 'ciclos') {
                const d = cenario.ciclos?.[docId];
                return { exists: !!d, id: docId, data: () => d };
              }
              if (col === 'commands') {
                const d = cenario.commands?.[docId];
                return { exists: !!d, id: docId, data: () => d };
              }
              return { exists: false, id: docId, data: () => undefined };
            },
            set: (data: any, options?: any) => sets.push({ ref: { col, id: docId }, data, options }),
            update: (data: any) => updates.push({ ref: { col, id: docId }, data }),
          };
          return docRef;
        },
      }),
      runTransaction: async (updateFunction: any) => {
        const tx: any = {
          get: async (ref: any) => ref.get(),
          set: (ref: any, data: any, options?: any) => sets.push({ ref, data, options }),
          update: (ref: any, data: any) => updates.push({ ref, data }),
        };
        return await updateFunction(tx);
      },
      __sets: sets,
      __updates: updates,
    };

    return mockDb;
  }

  it('manifesta CONTINUAR com sucesso: cria ciclo determinístico, atualiza participação e mantém ATIVA', async () => {
    const agora = new Date();
    // Vigência vence em 25 dias (dentro da janela de 60/30 dias)
    const vigenciaFim = new Date(agora.getTime() + 25 * 24 * 60 * 60 * 1000);
    const anoVigenciaEsperado = vigenciaFim.getUTCFullYear();

    const mockDb = criarMockDb({
      ficha: {
        id: voluntarioUid,
        nomeCompleto: 'Irmão Voluntário',
        igrejaId: 'igreja-central',
        estado: 'ATIVA',
      },
      participacoes: {
        'part-louvor': {
          id: 'part-louvor',
          fichaId: voluntarioUid,
          equipeId: 'eq-louvor',
          nomeEquipe: 'Louvor',
          estado: 'ATIVA',
          versao: 1,
          vigenciaInicio: new Date(agora.getTime() - 340 * 24 * 60 * 60 * 1000).toISOString(),
          vigenciaFim: vigenciaFim.toISOString(),
        },
      },
    });

    const entrada = validarManifestarRenovacao({
      commandId: 'cmd-manifestar-001',
      manifestacoes: [
        {
          participacaoId: 'part-louvor',
          decisao: 'CONTINUAR',
          justificativa: 'Quero continuar no louvor',
        },
      ],
    });

    const resultado = await executarManifestarRenovacaoRepo(
      mockDb,
      { commandId: entrada.commandId, uid: voluntarioUid },
      entrada,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.repetido).toBe(false);
    expect(resultado.itens).toHaveLength(1);
    expect(resultado.itens[0].decisao).toBe('CONTINUAR');
    expect(resultado.itens[0].cicloId).toBe(`ciclo_part-louvor_${anoVigenciaEsperado}`);
    expect(resultado.itens[0].estadoCiclo).toBe('AGUARDANDO_PASTOR_LOCAL');

    // Verifica que o ciclo determinístico foi criado sob a chave correta
    const cicloSet = mockDb.__sets.find((s: any) => s.ref.col === 'ciclos');
    expect(cicloSet).toBeDefined();
    expect(cicloSet.ref.id).toBe(`ciclo_part-louvor_${anoVigenciaEsperado}`);
    expect(cicloSet.data.tipo).toBe('RENOVACAO_ANUAL');
    expect(cicloSet.data.estado).toBe('AGUARDANDO_PASTOR_LOCAL');

    // Verifica que a participação foi atualizada com a intenção e cicloRenovacaoId, sem desativar a participação
    const partUpdate = mockDb.__updates.find((u: any) => u.ref.col === 'participacoes');
    expect(partUpdate).toBeDefined();
    expect(partUpdate.data.intencaoRenovacao).toBe('CONTINUAR');
    expect(partUpdate.data.cicloRenovacaoId).toBe(`ciclo_part-louvor_${anoVigenciaEsperado}`);
    expect(partUpdate.data.estado).toBeUndefined(); // estado NÃO deve ser alterado de ATIVA

    // Verifica auditoria e recibo
    const outboxSet = mockDb.__sets.find((s: any) => s.ref.col === 'auditOutbox');
    expect(outboxSet).toBeDefined();
    expect(outboxSet.data.tipo).toBe('MANIFESTACAO_RENOVACAO');

    const reciboSet = mockDb.__sets.find((s: any) => s.ref.col === 'commands');
    expect(reciboSet).toBeDefined();
    expect(reciboSet.data.status).toBe('COMPLETO');
  });

  it('manifesta NAO_CONTINUAR com sucesso: programa encerramento sem criar novo ciclo anual', async () => {
    const agora = new Date();
    const vigenciaFim = new Date(agora.getTime() + 15 * 24 * 60 * 60 * 1000);

    const mockDb = criarMockDb({
      ficha: {
        id: voluntarioUid,
        nomeCompleto: 'Irmão Voluntário',
        igrejaId: 'igreja-central',
        estado: 'ATIVA',
      },
      participacoes: {
        'part-transporte': {
          id: 'part-transporte',
          fichaId: voluntarioUid,
          equipeId: 'eq-transporte',
          nomeEquipe: 'Transporte',
          estado: 'ATIVA',
          versao: 2,
          vigenciaInicio: new Date(agora.getTime() - 350 * 24 * 60 * 60 * 1000).toISOString(),
          vigenciaFim: vigenciaFim.toISOString(),
        },
      },
    });

    const entrada = validarManifestarRenovacao({
      commandId: 'cmd-manifestar-002',
      manifestacoes: [
        {
          participacaoId: 'part-transporte',
          decisao: 'NAO_CONTINUAR',
        },
      ],
    });

    const resultado = await executarManifestarRenovacaoRepo(
      mockDb,
      { commandId: entrada.commandId, uid: voluntarioUid },
      entrada,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.itens[0].decisao).toBe('NAO_CONTINUAR');
    expect(resultado.itens[0].cicloId).toBeNull();

    // Ciclo novo não deve ter sido criado
    const cicloSet = mockDb.__sets.find((s: any) => s.ref.col === 'ciclos');
    expect(cicloSet).toBeUndefined();

    // Participação atualizada com intencaoRenovacao NAO_CONTINUAR
    const partUpdate = mockDb.__updates.find((u: any) => u.ref.col === 'participacoes');
    expect(partUpdate.data.intencaoRenovacao).toBe('NAO_CONTINUAR');
    expect(partUpdate.data.programadoEncerramentoEm).toBe(vigenciaFim.toISOString());
  });

  it('rejeita com JanelaRenovacaoFechadaError se faltarem mais de 60 dias para o vencimento', async () => {
    const agora = new Date();
    // Vence em 120 dias (fora da janela)
    const vigenciaFimLonge = new Date(agora.getTime() + 120 * 24 * 60 * 60 * 1000);

    const mockDb = criarMockDb({
      ficha: { id: voluntarioUid, estado: 'ATIVA' },
      participacoes: {
        'part-longe': {
          id: 'part-longe',
          fichaId: voluntarioUid,
          equipeId: 'eq-intercessao',
          estado: 'ATIVA',
          vigenciaFim: vigenciaFimLonge.toISOString(),
        },
      },
    });

    const entrada = validarManifestarRenovacao({
      commandId: 'cmd-renov-fechada',
      manifestacoes: [{ participacaoId: 'part-longe', decisao: 'CONTINUAR' }],
    });

    await expect(
      executarManifestarRenovacaoRepo(
        mockDb,
        { commandId: entrada.commandId, uid: voluntarioUid },
        entrada,
      ),
    ).rejects.toThrow(JanelaRenovacaoFechadaError);
  });

  it('rejeita com PermissaoNegadaError se o usuário tentar manifestar para participação de outro voluntário', async () => {
    const agora = new Date();
    const vigenciaFim = new Date(agora.getTime() + 20 * 24 * 60 * 60 * 1000);

    const mockDb = criarMockDb({
      ficha: { id: voluntarioUid, estado: 'ATIVA' },
      participacoes: {
        'part-alheia': {
          id: 'part-alheia',
          fichaId: 'outro-voluntario-999', // Não é o voluntarioUid
          equipeId: 'eq-louvor',
          estado: 'ATIVA',
          vigenciaFim: vigenciaFim.toISOString(),
        },
      },
    });

    const entrada = validarManifestarRenovacao({
      commandId: 'cmd-permissao-001',
      manifestacoes: [{ participacaoId: 'part-alheia', decisao: 'CONTINUAR' }],
    });

    await expect(
      executarManifestarRenovacaoRepo(
        mockDb,
        { commandId: entrada.commandId, uid: voluntarioUid },
        entrada,
      ),
    ).rejects.toThrow(PermissaoNegadaError);
  });

  it('rejeita com ParticipacaoNaoElegivelError se a participação não estiver ATIVA (ex: CANCELADA)', async () => {
    const agora = new Date();
    const vigenciaFim = new Date(agora.getTime() + 10 * 24 * 60 * 60 * 1000);

    const mockDb = criarMockDb({
      ficha: { id: voluntarioUid, estado: 'ATIVA' },
      participacoes: {
        'part-cancelada': {
          id: 'part-cancelada',
          fichaId: voluntarioUid,
          equipeId: 'eq-portaria',
          estado: 'CANCELADA', // Terminal
          vigenciaFim: vigenciaFim.toISOString(),
        },
      },
    });

    const entrada = validarManifestarRenovacao({
      commandId: 'cmd-terminal-001',
      manifestacoes: [{ participacaoId: 'part-cancelada', decisao: 'CONTINUAR' }],
    });

    await expect(
      executarManifestarRenovacaoRepo(
        mockDb,
        { commandId: entrada.commandId, uid: voluntarioUid },
        entrada,
      ),
    ).rejects.toThrow(ParticipacaoNaoElegivelError);
  });

  it('retorna resultado idempotente quando executado com mesmo commandId e mesmo payloadHash', async () => {
    const entrada = validarManifestarRenovacao({
      commandId: 'cmd-idempotente-001',
      manifestacoes: [{ participacaoId: 'part-01', decisao: 'CONTINUAR' }],
    });

    const mockDb = criarMockDb({
      ficha: { id: voluntarioUid },
      commands: {
        'cmd-idempotente-001': {
          uid: voluntarioUid,
          payloadHash: entrada.payloadHash,
          status: 'COMPLETO',
          criadoEm: '2026-10-07T12:00:00.000Z',
          resultado: {
            itens: [
              {
                participacaoId: 'part-01',
                equipeId: 'eq-01',
                nomeEquipe: 'Equipe 1',
                decisao: 'CONTINUAR',
                cicloId: 'ciclo_part-01_2027',
                anoVigencia: 2027,
                estadoCiclo: 'AGUARDANDO_PASTOR_LOCAL',
                proximaAcao: 'Aguardando avaliação do Pastor Local (Ciclo Anual)',
              },
            ],
          },
        },
      },
    });

    const resultado = await executarManifestarRenovacaoRepo(
      mockDb,
      { commandId: entrada.commandId, uid: voluntarioUid },
      entrada,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.repetido).toBe(true);
    expect(resultado.itens).toHaveLength(1);
    expect(resultado.itens[0].cicloId).toBe('ciclo_part-01_2027');
  });

  it('rejeita com ComandoDivergenteError se commandId for repetido com dados diferentes', async () => {
    const entrada = validarManifestarRenovacao({
      commandId: 'cmd-conflito-001',
      manifestacoes: [{ participacaoId: 'part-01', decisao: 'CONTINUAR' }],
    });

    const mockDb = criarMockDb({
      ficha: { id: voluntarioUid },
      commands: {
        'cmd-conflito-001': {
          uid: voluntarioUid,
          payloadHash: 'outro-hash-diferente',
        },
      },
    });

    await expect(
      executarManifestarRenovacaoRepo(
        mockDb,
        { commandId: entrada.commandId, uid: voluntarioUid },
        entrada,
      ),
    ).rejects.toThrow(ComandoDivergenteError);
  });
});
