import { describe, expect, it } from 'vitest';
import {
  AutoridadeInsuficienteError,
  ComandoDivergenteError,
  ConflitoVersaoError,
  MotivoObrigatorioLiderancaError,
  ParticipacaoJaTerminalError,
  ParticipacaoNaoEncontradaError,
  SolicitacaoInvalidaError,
  calcularPayloadHashCancelarParticipacao,
  validarCancelarParticipacao,
} from '../src/domain/cancelarParticipacao.js';
import { executarCancelarParticipacaoRepo } from '../src/repositories/cancelamento.js';
import { MENSAGEM_CANONICA_DECISAO_NEGATIVA } from '../src/domain/mensagens.js';

describe('Story 4.3: Domínio de Cancelar Participação', () => {
  it('valida payload correto e gera hash determinístico', () => {
    const entrada = validarCancelarParticipacao({
      commandId: 'cmd-cancelar-part-1',
      participacaoId: 'part-001',
      motivo: 'Motivo pessoal',
      expectedVersion: 2,
      correlationId: 'corr-001',
    });

    expect(entrada.commandId).toBe('cmd-cancelar-part-1');
    expect(entrada.participacaoId).toBe('part-001');
    expect(entrada.motivo).toBe('Motivo pessoal');
    expect(entrada.expectedVersion).toBe(2);
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it('calcula o mesmo hash para entradas equivalentes', () => {
    const hash1 = calcularPayloadHashCancelarParticipacao('part-001', 'Mudança de cidade');
    const hash2 = calcularPayloadHashCancelarParticipacao('part-001', 'Mudança de cidade');
    expect(hash1).toBe(hash2);
  });

  it('rejeita commandId ausente ou muito curto', () => {
    expect(() =>
      validarCancelarParticipacao({
        commandId: 'curto',
        participacaoId: 'part-001',
      }),
    ).toThrow(SolicitacaoInvalidaError);
  });

  it('rejeita participacaoId vazio ou ausente', () => {
    expect(() =>
      validarCancelarParticipacao({
        commandId: 'cmd-valido-123',
        participacaoId: '',
      }),
    ).toThrow(SolicitacaoInvalidaError);
  });
});

describe('Story 4.3: Repositório de Cancelar Participação', () => {
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
              if (col === 'participacoes') {
                const match = (cenario.participacoes ?? []).find((p) => p.id === docId);
                return { exists: !!match, id: docId, data: () => match };
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

  const baseEquipes = {
    [equipeSomId]: { nome: 'Som', responsavelVigentePessoaId: responsavelUid, ativo: true },
    [equipeLouvorId]: { nome: 'Louvor', responsavelVigentePessoaId: 'outro-resp', ativo: true },
  };

  it('permite o próprio titular cancelar uma de suas participações mantendo a ficha ATIVA se houver outra ativa', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      participacoes: [
        { id: 'part-som', fichaId: voluntarioUid, equipeId: equipeSomId, estado: 'ATIVA', versao: 1 },
        { id: 'part-louvor', fichaId: voluntarioUid, equipeId: equipeLouvorId, estado: 'ATIVA', versao: 1 },
      ],
      igrejas: baseIgrejas,
      equipes: baseEquipes,
    });

    const resultado = await executarCancelarParticipacaoRepo(
      db,
      { commandId: 'cmd-cancelar-001', uid: voluntarioUid },
      {
        commandId: 'cmd-cancelar-001',
        participacaoId: 'part-som',
        payloadHash: 'hash-001',
      },
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.estado).toBe('CANCELADA');
    expect(resultado.proximaAcao).toContain('cancelada pelo voluntário');
    expect(resultado.fichaEstado).toBe('ATIVA');

    const updatePart = db.__updates.find((u: any) => u.ref.id === 'part-som');
    expect(updatePart).toBeDefined();
    expect(updatePart.data.estado).toBe('CANCELADA');
    expect(updatePart.data.canceladoPorPapel).toBe('VOLUNTARIO');

    // A ficha NÃO deve ter sido alterada para INATIVA porque a equipe de Louvor continua ATIVA
    const updateFicha = db.__updates.find((u: any) => u.ref.col === 'fichas');
    expect(updateFicha).toBeUndefined();
  });

  it('transiciona a ficha para INATIVA quando a última participação ativa é cancelada (AD-11)', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      participacoes: [
        { id: 'part-som', fichaId: voluntarioUid, equipeId: equipeSomId, estado: 'ATIVA', versao: 1 },
        { id: 'part-louvor', fichaId: voluntarioUid, equipeId: equipeLouvorId, estado: 'CANCELADA', versao: 2 },
      ],
      igrejas: baseIgrejas,
      equipes: baseEquipes,
    });

    const resultado = await executarCancelarParticipacaoRepo(
      db,
      { commandId: 'cmd-cancelar-002', uid: voluntarioUid },
      {
        commandId: 'cmd-cancelar-002',
        participacaoId: 'part-som',
        payloadHash: 'hash-002',
      },
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.fichaEstado).toBe('INATIVA');

    const updateFicha = db.__updates.find((u: any) => u.ref.col === 'fichas');
    expect(updateFicha).toBeDefined();
    expect(updateFicha.data.estado).toBe('INATIVA');
  });

  it('permite Pastor Local vigente cancelar participação informando motivo obrigatório e aplica mensagem neutra canônica', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      participacoes: [
        { id: 'part-som', fichaId: voluntarioUid, equipeId: equipeSomId, estado: 'ATIVA', versao: 1 },
      ],
      igrejas: baseIgrejas,
      equipes: baseEquipes,
    });

    const resultado = await executarCancelarParticipacaoRepo(
      db,
      { commandId: 'cmd-cancelar-pastor', uid: pastorUid },
      {
        commandId: 'cmd-cancelar-pastor',
        participacaoId: 'part-som',
        motivo: 'Mudança de domicílio do membro',
        payloadHash: 'hash-pastor',
      },
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.estado).toBe('CANCELADA');
    // Sigilo Pastoral e Mensagem Neutra Canônica (AD-12, FR28)
    expect(resultado.proximaAcao).toBe(MENSAGEM_CANONICA_DECISAO_NEGATIVA);

    // Evidência grava o motivo interno
    const setEvidencia = db.__sets.find((s: any) => s.ref.col === 'evidenciasDecisao');
    expect(setEvidencia.data.motivoInterno).toBe('Mudança de domicílio do membro');
    expect(setEvidencia.data.papelAtor).toBe('PASTOR_LOCAL');

    // Auditoria não vaza motivo nem PII
    const setAuditoria = db.__sets.find((s: any) => s.ref.col === 'auditOutbox');
    expect(setAuditoria.data.motivoInterno).toBeUndefined();
    expect(setAuditoria.data.papelAtor).toBe('PASTOR_LOCAL');
  });

  it('exige motivo quando o cancelamento é realizado por liderança', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      participacoes: [
        { id: 'part-som', fichaId: voluntarioUid, equipeId: equipeSomId, estado: 'ATIVA', versao: 1 },
      ],
      igrejas: baseIgrejas,
      equipes: baseEquipes,
    });

    await expect(
      executarCancelarParticipacaoRepo(
        db,
        { commandId: 'cmd-cancelar-sem-motivo', uid: pastorUid },
        {
          commandId: 'cmd-cancelar-sem-motivo',
          participacaoId: 'part-som',
          motivo: '', // Vazio
          payloadHash: 'hash-sem-motivo',
        },
      ),
    ).rejects.toThrow(MotivoObrigatorioLiderancaError);
  });

  it('permite Responsável de Equipe vigente cancelar a participação de sua equipe', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      participacoes: [
        { id: 'part-som', fichaId: voluntarioUid, equipeId: equipeSomId, estado: 'ATIVA', versao: 1 },
      ],
      igrejas: baseIgrejas,
      equipes: baseEquipes,
    });

    const resultado = await executarCancelarParticipacaoRepo(
      db,
      { commandId: 'cmd-cancelar-resp', uid: responsavelUid },
      {
        commandId: 'cmd-cancelar-resp',
        participacaoId: 'part-som',
        motivo: 'Incompatibilidade de escala',
        payloadHash: 'hash-resp',
      },
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.proximaAcao).toBe(MENSAGEM_CANONICA_DECISAO_NEGATIVA);
  });

  it('rejeita Responsável de outra equipe ou usuário sem vínculo', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      participacoes: [
        { id: 'part-som', fichaId: voluntarioUid, equipeId: equipeSomId, estado: 'ATIVA', versao: 1 },
      ],
      igrejas: baseIgrejas,
      equipes: baseEquipes,
    });

    await expect(
      executarCancelarParticipacaoRepo(
        db,
        { commandId: 'cmd-cancelar-intruso', uid: intrusoUid },
        {
          commandId: 'cmd-cancelar-intruso',
          participacaoId: 'part-som',
          motivo: 'Tentativa não autorizada',
          payloadHash: 'hash-intruso',
        },
      ),
    ).rejects.toThrow(AutoridadeInsuficienteError);
  });

  it('permite Coordenador Geral cancelar qualquer participação', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      participacoes: [
        { id: 'part-som', fichaId: voluntarioUid, equipeId: equipeSomId, estado: 'ATIVA', versao: 1 },
      ],
      igrejas: baseIgrejas,
      equipes: baseEquipes,
      autoridades: {
        [coordenadorUid]: { ativa: true, papeis: ['COORDENADOR'], revisao: 1 },
      },
    });

    const resultado = await executarCancelarParticipacaoRepo(
      db,
      { commandId: 'cmd-coord', uid: coordenadorUid },
      {
        commandId: 'cmd-coord',
        participacaoId: 'part-som',
        motivo: 'Ajuste administrativo',
        payloadHash: 'hash-coord',
      },
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.proximaAcao).toBe(MENSAGEM_CANONICA_DECISAO_NEGATIVA);
  });

  it('rejeita cancelamento de participação já em estado terminal', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      participacoes: [
        { id: 'part-som', fichaId: voluntarioUid, equipeId: equipeSomId, estado: 'CANCELADA', versao: 2 },
      ],
      igrejas: baseIgrejas,
      equipes: baseEquipes,
    });

    await expect(
      executarCancelarParticipacaoRepo(
        db,
        { commandId: 'cmd-terminal', uid: voluntarioUid },
        {
          commandId: 'cmd-terminal',
          participacaoId: 'part-som',
          payloadHash: 'hash-terminal',
        },
      ),
    ).rejects.toThrow(ParticipacaoJaTerminalError);
  });

  it('rejeita comando se expectedVersion divergir', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      participacoes: [
        { id: 'part-som', fichaId: voluntarioUid, equipeId: equipeSomId, estado: 'ATIVA', versao: 2 },
      ],
      igrejas: baseIgrejas,
      equipes: baseEquipes,
    });

    await expect(
      executarCancelarParticipacaoRepo(
        db,
        { commandId: 'cmd-versao', uid: voluntarioUid },
        {
          commandId: 'cmd-versao',
          participacaoId: 'part-som',
          expectedVersion: 1, // Divergente
          payloadHash: 'hash-versao',
        },
      ),
    ).rejects.toThrow(ConflitoVersaoError);
  });

  it('retorna resultado idempotente em caso de reenvio com mesmo commandId e payloadHash', async () => {
    const db = criarMockDb({
      recibos: {
        'cmd-idemp-1': {
          payloadHash: 'hash-idemp-1',
          criadoEm: new Date().toISOString(),
          resultado: {
            participacaoId: 'part-som',
            estado: 'CANCELADA',
            proximaAcao: 'Participação cancelada pelo voluntário',
            fichaId: voluntarioUid,
            fichaEstado: 'ATIVA',
          },
        },
      },
    });

    const resultado = await executarCancelarParticipacaoRepo(
      db,
      { commandId: 'cmd-idemp-1', uid: voluntarioUid },
      {
        commandId: 'cmd-idemp-1',
        participacaoId: 'part-som',
        payloadHash: 'hash-idemp-1',
      },
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.repetido).toBe(true);
    expect(resultado.participacaoId).toBe('part-som');
  });

  it('rejeita reenvio se payloadHash divergir para o mesmo commandId', async () => {
    const db = criarMockDb({
      recibos: {
        'cmd-idemp-2': {
          payloadHash: 'hash-original',
        },
      },
    });

    await expect(
      executarCancelarParticipacaoRepo(
        db,
        { commandId: 'cmd-idemp-2', uid: voluntarioUid },
        {
          commandId: 'cmd-idemp-2',
          participacaoId: 'part-som',
          payloadHash: 'hash-diferente',
        },
      ),
    ).rejects.toThrow(ComandoDivergenteError);
  });
});
