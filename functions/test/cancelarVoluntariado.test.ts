import { describe, expect, it } from 'vitest';
import {
  AutoridadeInsuficienteError,
  ComandoDivergenteError,
  FichaJaTerminalError,
  FichaNaoEncontradaError,
  MotivoObrigatorioLiderancaError,
  SolicitacaoInvalidaError,
  calcularPayloadHashCancelarVoluntariado,
  validarCancelarVoluntariado,
} from '../src/domain/cancelarVoluntariado.js';
import { executarCancelarVoluntariadoRepo } from '../src/repositories/cancelamento.js';
import { MENSAGEM_CANONICA_DECISAO_NEGATIVA } from '../src/domain/mensagens.js';

describe('Story 4.3: Domínio de Cancelar Voluntariado', () => {
  it('valida payload correto e gera hash determinístico', () => {
    const entrada = validarCancelarVoluntariado({
      commandId: 'cmd-cancelar-vol-1',
      fichaId: 'ficha-001',
      motivo: 'Motivo pessoal geral',
      correlationId: 'corr-001',
    });

    expect(entrada.commandId).toBe('cmd-cancelar-vol-1');
    expect(entrada.fichaId).toBe('ficha-001');
    expect(entrada.motivo).toBe('Motivo pessoal geral');
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it('calcula o mesmo hash para entradas equivalentes', () => {
    const hash1 = calcularPayloadHashCancelarVoluntariado('ficha-001', 'Encerramento geral');
    const hash2 = calcularPayloadHashCancelarVoluntariado('ficha-001', 'Encerramento geral');
    expect(hash1).toBe(hash2);
  });

  it('rejeita commandId ausente ou muito curto', () => {
    expect(() =>
      validarCancelarVoluntariado({
        commandId: 'curto',
        fichaId: 'ficha-001',
      }),
    ).toThrow(SolicitacaoInvalidaError);
  });

  it('rejeita fichaId vazio ou ausente', () => {
    expect(() =>
      validarCancelarVoluntariado({
        commandId: 'cmd-valido-123',
        fichaId: '',
      }),
    ).toThrow(SolicitacaoInvalidaError);
  });
});

describe('Story 4.3: Repositório de Cancelar Voluntariado', () => {
  const voluntarioUid = 'voluntario-01';
  const pastorUid = 'pastor-01';
  const responsavelUid = 'responsavel-01';
  const coordenadorUid = 'coordenador-01';
  const intrusoUid = 'intruso-01';

  const igrejaId = 'igreja-central';
  const equipeSomId = 'equipe-som';
  const equipeLouvorId = 'equipe-louvor';

  function criarMockDb(cenario: {
    ficha?: any;
    participacoes?: Array<{ id: string; fichaId: string; equipeId: string; estado: string; versao?: number; data?: any }>;
    ciclos?: Record<string, any>;
    igrejas?: Record<string, any>;
    equipes?: Record<string, any>;
    autoridades?: Record<string, any>;
    vinculos?: Array<any>;
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
              if (col === 'ciclos') {
                const d = cenario.ciclos?.[docId];
                return { exists: !!d, id: docId, data: () => d };
              }
              if (col === 'igrejas') {
                const d = cenario.igrejas?.[docId];
                return { exists: !!d, id: docId, data: () => d };
              }
              if (col === 'equipes') {
                const d = cenario.equipes?.[docId];
                return { exists: !!d, id: docId, data: () => d };
              }
              if (col === 'autoridadesAdministrativas') {
                const d = cenario.autoridades?.[docId];
                return { exists: !!d, id: docId, data: () => d };
              }
              if (col === 'pessoas') {
                const d = cenario.autoridades?.[docId];
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
        where: (field1: string, op1: string, val1: any) => {
          const filtros = [{ field: field1, op: op1, val: val1 }];
          const queryObj: any = {
            where: (field2: string, op2: string, val2: any) => {
              filtros.push({ field: field2, op: op2, val: val2 });
              return queryObj;
            },
            get: async () => {
              if (col === 'participacoes') {
                const matches = (cenario.participacoes ?? []).filter((p) => {
                  return filtros.every((f) => {
                    if (f.field === 'fichaId') return p.fichaId === f.val;
                    if (f.field === 'estado') return p.estado === f.val;
                    return true;
                  });
                });
                return {
                  docs: matches.map((m) => ({
                    id: m.id,
                    ref: { col, id: m.id },
                    data: () => m,
                  })),
                };
              }
              if (col === 'vinculosPastorEquipe') {
                const matches = (cenario.vinculos ?? []).filter((v) => {
                  return filtros.every((f) => {
                    if (f.field === 'pessoaId') return v.pessoaId === f.val;
                    if (f.field === 'entidadeId') return v.entidadeId === f.val;
                    if (f.field === 'estado') return v.estado === f.val;
                    if (f.field === 'tipo') return v.tipo === f.val;
                    return true;
                  });
                });
                return {
                  empty: matches.length === 0,
                  docs: matches.map((m) => ({
                    id: m.id ?? 'v-id',
                    data: () => m,
                  })),
                };
              }
              return { empty: true, docs: [] };
            },
            limit: () => queryObj,
          };
          return queryObj;
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

  const baseFicha = {
    nomeCompleto: 'Irmão Voluntário',
    igrejaId,
    estado: 'ATIVA',
  };

  const baseIgrejas = {
    [igrejaId]: { nome: 'Igreja Central', pastorLocalVigentePessoaId: pastorUid, ativo: true },
  };

  it('permite o titular cancelar seu voluntariado, cancelando todas as participações não terminais e a ficha', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      participacoes: [
        { id: 'part-som', fichaId: voluntarioUid, equipeId: equipeSomId, estado: 'ATIVA', versao: 1 },
        { id: 'part-louvor', fichaId: voluntarioUid, equipeId: equipeLouvorId, estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE', versao: 1 },
        { id: 'part-antiga', fichaId: voluntarioUid, equipeId: 'equipe-antiga', estado: 'REJEITADA', versao: 1 },
      ],
      igrejas: baseIgrejas,
    });

    const resultado = await executarCancelarVoluntariadoRepo(
      db,
      { commandId: 'cmd-cancelar-vol-01', uid: voluntarioUid },
      {
        commandId: 'cmd-cancelar-vol-01',
        fichaId: voluntarioUid,
        payloadHash: 'hash-vol-01',
      },
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.estado).toBe('CANCELADA');
    expect(resultado.participacoesAfetadas).toEqual(['part-som', 'part-louvor']);

    const updateFicha = db.__updates.find((u: any) => u.ref.col === 'fichas');
    expect(updateFicha).toBeDefined();
    expect(updateFicha.data.estado).toBe('CANCELADA');
    expect(updateFicha.data.canceladoPorPapel).toBe('VOLUNTARIO');

    const updateSom = db.__updates.find((u: any) => u.ref.id === 'part-som');
    expect(updateSom.data.estado).toBe('CANCELADA');

    const updateLouvor = db.__updates.find((u: any) => u.ref.id === 'part-louvor');
    expect(updateLouvor.data.estado).toBe('CANCELADA');

    // A participação que já era terminal não deve ser alterada
    const updateAntiga = db.__updates.find((u: any) => u.ref.id === 'part-antiga');
    expect(updateAntiga).toBeUndefined();
  });

  it('permite Pastor Local vigente cancelar voluntariado com motivo e aplica mensagem neutra canônica', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      participacoes: [
        { id: 'part-som', fichaId: voluntarioUid, equipeId: equipeSomId, estado: 'ATIVA', versao: 1 },
      ],
      igrejas: baseIgrejas,
    });

    const resultado = await executarCancelarVoluntariadoRepo(
      db,
      { commandId: 'cmd-vol-pastor', uid: pastorUid },
      {
        commandId: 'cmd-vol-pastor',
        fichaId: voluntarioUid,
        motivo: 'Transferência eclesiástica confirmada',
        payloadHash: 'hash-vol-pastor',
      },
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.estado).toBe('CANCELADA');

    const updateFicha = db.__updates.find((u: any) => u.ref.col === 'fichas');
    expect(updateFicha.data.proximaAcao).toBe(MENSAGEM_CANONICA_DECISAO_NEGATIVA);

    const updatePart = db.__updates.find((u: any) => u.ref.id === 'part-som');
    expect(updatePart.data.proximaAcao).toBe(MENSAGEM_CANONICA_DECISAO_NEGATIVA);

    const setEvidencia = db.__sets.find((s: any) => s.ref.col === 'evidenciasDecisao');
    expect(setEvidencia.data.motivoInterno).toBe('Transferência eclesiástica confirmada');
    expect(setEvidencia.data.papelAtor).toBe('PASTOR_LOCAL');
  });

  it('bloqueia estritamente Responsável de Equipe ao tentar cancelar toda a ficha (AD-11)', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      participacoes: [
        { id: 'part-som', fichaId: voluntarioUid, equipeId: equipeSomId, estado: 'ATIVA', versao: 1 },
      ],
      igrejas: baseIgrejas,
      vinculos: [
        {
          pessoaId: responsavelUid,
          entidadeId: equipeSomId,
          tipo: 'EQUIPE',
          estado: 'VIGENTE',
        },
      ],
    });

    await expect(
      executarCancelarVoluntariadoRepo(
        db,
        { commandId: 'cmd-vol-resp-bloqueado', uid: responsavelUid },
        {
          commandId: 'cmd-vol-resp-bloqueado',
          fichaId: voluntarioUid,
          motivo: 'Tentando cancelar a ficha inteira',
          payloadHash: 'hash-vol-resp',
        },
      ),
    ).rejects.toThrow(AutoridadeInsuficienteError);
  });

  it('permite Coordenador Geral cancelar toda a ficha com motivo', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      participacoes: [
        { id: 'part-som', fichaId: voluntarioUid, equipeId: equipeSomId, estado: 'ATIVA', versao: 1 },
      ],
      igrejas: baseIgrejas,
      autoridades: {
        [coordenadorUid]: { ativa: true, papeis: ['COORDENADOR'], revisao: 1 },
      },
    });

    const resultado = await executarCancelarVoluntariadoRepo(
      db,
      { commandId: 'cmd-vol-coord', uid: coordenadorUid },
      {
        commandId: 'cmd-vol-coord',
        fichaId: voluntarioUid,
        motivo: 'Decisão da Coordenação Geral',
        payloadHash: 'hash-vol-coord',
      },
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.estado).toBe('CANCELADA');
  });

  it('rejeita cancelamento de ficha inexistente', async () => {
    const db = criarMockDb({});

    await expect(
      executarCancelarVoluntariadoRepo(
        db,
        { commandId: 'cmd-inexistente', uid: voluntarioUid },
        {
          commandId: 'cmd-inexistente',
          fichaId: 'inexistente',
          payloadHash: 'hash-inexistente',
        },
      ),
    ).rejects.toThrow(FichaNaoEncontradaError);
  });

  it('rejeita cancelamento de ficha já em estado CANCELADA', async () => {
    const db = criarMockDb({
      ficha: {
        ...baseFicha,
        estado: 'CANCELADA',
      },
    });

    await expect(
      executarCancelarVoluntariadoRepo(
        db,
        { commandId: 'cmd-ja-cancelada', uid: voluntarioUid },
        {
          commandId: 'cmd-ja-cancelada',
          fichaId: voluntarioUid,
          payloadHash: 'hash-ja-cancelada',
        },
      ),
    ).rejects.toThrow(FichaJaTerminalError);
  });
});
