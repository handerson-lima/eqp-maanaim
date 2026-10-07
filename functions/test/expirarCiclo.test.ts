import { describe, expect, it } from 'vitest';
import {
  SolicitacaoInvalidaError,
  validarExpirarCiclos,
} from '../src/domain/expirarCiclo.js';
import { executarExpirarCiclosRepo } from '../src/repositories/expirarCiclo.js';
import { expirarCiclosVencidos } from '../src/commands/expirarCiclo.js';
import { ComandoDivergenteError } from '../src/domain/participacao.js';

describe('Story 5.1: Domínio e Validação de Expirar Ciclos', () => {
  it('valida entrada correta com commandId válido e limite', () => {
    const entrada = validarExpirarCiclos({
      commandId: 'cmd-job-expirar-001',
      agoraIso: '2026-10-07T00:00:00.000Z',
      limite: 50,
      correlationId: 'corr-job-1',
    });

    expect(entrada.commandId).toBe('cmd-job-expirar-001');
    expect(entrada.agoraIso).toBe('2026-10-07T00:00:00.000Z');
    expect(entrada.limite).toBe(50);
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it('rejeita commandId com menos de 8 caracteres ou ausente', () => {
    expect(() =>
      validarExpirarCiclos({
        commandId: 'curto',
      }),
    ).toThrow(SolicitacaoInvalidaError);
  });

  it('rejeita agoraIso inválido', () => {
    expect(() =>
      validarExpirarCiclos({
        commandId: 'cmd-job-expirar-001',
        agoraIso: 'data-invalida',
      }),
    ).toThrow(SolicitacaoInvalidaError);
  });
});

function toMillis(valor: any): number {
  if (valor === null || valor === undefined) return NaN;
  if (valor instanceof Date) return valor.getTime();
  if (typeof valor === 'number') return valor;
  if (typeof valor === 'string') return Date.parse(valor);
  if (typeof valor.toMillis === 'function') return valor.toMillis();
  if (typeof valor.toDate === 'function') return valor.toDate().getTime();
  return NaN;
}

function criarMockDb(cenario: {
  fichas?: Record<string, any>;
  participacoes?: Array<any>;
  ciclos?: Record<string, any>;
  recibos?: Record<string, any>;
  configuracoes?: Record<string, any>;
}) {
  const fichas = { ...(cenario.fichas ?? {}) };
  const participacoes = [...(cenario.participacoes ?? [])];
  const ciclos = { ...(cenario.ciclos ?? {}) };
  const recibos = { ...(cenario.recibos ?? {}) };
  const configuracoes = { ...(cenario.configuracoes ?? {}) };

  const updates: Array<{ col: string; id: string; data: any }> = [];
  const sets: Array<{ col: string; id: string; data: any }> = [];

  const combina = (p: any, condicoes: Array<[string, string, any]>) =>
    condicoes.every(([campo, op, valor]) => {
      if (op === '==') return p[campo] === valor;
      if (op === '<=') return toMillis(p[campo]) <= toMillis(valor);
      if (op === '<') return toMillis(p[campo]) < toMillis(valor);
      if (op === '>=') return toMillis(p[campo]) >= toMillis(valor);
      return false;
    });

  const queryBuilder = (condicoes: Array<[string, string, any]>) => {
    const q: any = {
      where: (campo: string, op: string, valor: any) =>
        queryBuilder([...condicoes, [campo, op, valor]]),
      orderBy: () => q,
      limit: () => q,
      get: async () => {
        const filtrados = participacoes.filter((p) => combina(p, condicoes));
        return {
          size: filtrados.length,
          docs: filtrados.map((p) => ({ id: p.id, data: () => p })),
        };
      },
    };
    return q;
  };

  const docRef = (col: string, id: string) => ({
    col,
    id,
    get: async () => {
      if (col === 'commands') {
        const d = recibos[id];
        return { exists: !!d, id, data: () => d };
      }
      if (col === 'fichas') {
        const d = fichas[id];
        return { exists: !!d, id, data: () => d };
      }
      if (col === 'participacoes') {
        const d = participacoes.find((p) => p.id === id);
        return { exists: !!d, id, data: () => d };
      }
      if (col === 'ciclos') {
        const d = ciclos[id];
        return { exists: !!d, id, data: () => d };
      }
      if (col === 'configuracoes') {
        const d = configuracoes[id];
        return { exists: !!d, id, data: () => d };
      }
      return { exists: false, id, data: () => null };
    },
    create: async (data: any) => {
      if (col === 'commands' && recibos[id]) {
        const erro: any = new Error('Já existe');
        erro.code = 'already-exists';
        throw erro;
      }
      sets.push({ col, id, data });
      if (col === 'commands') recibos[id] = data;
    },
    set: async (data: any) => {
      sets.push({ col, id, data });
      if (col === 'commands') recibos[id] = data;
    },
    update: async (data: any) => {
      updates.push({ col, id, data });
      if (col === 'fichas' && fichas[id]) fichas[id] = { ...fichas[id], ...data };
      if (col === 'participacoes') {
        const idx = participacoes.findIndex((p) => p.id === id);
        if (idx !== -1) participacoes[idx] = { ...participacoes[idx], ...data };
      }
      if (col === 'ciclos' && ciclos[id]) ciclos[id] = { ...ciclos[id], ...data };
    },
    collection: (subCol: string) => ({
      doc: (subId: string) => ({
        set: async (subData: any) => {
          sets.push({ col: `${col}/${id}/${subCol}`, id: subId, data: subData });
        },
      }),
    }),
  });

  const mockDb: any = {
    collection: (col: string) => ({
      doc: (id: string) => docRef(col, id),
      where: (campo: string, op: string, valor: any) => queryBuilder([[campo, op, valor]]),
    }),
    runTransaction: async (fn: any) => {
      const tx = {
        get: async (ref: any) => {
          if (typeof ref.get === 'function') return await ref.get();
          if (ref.col) return await docRef(ref.col, ref.id).get();
          return { exists: false, id: ref.id, data: () => null };
        },
        update: (ref: any, data: any) => {
          updates.push({ col: ref.col, id: ref.id, data });
          if (ref.col === 'fichas' && fichas[ref.id]) {
            fichas[ref.id] = { ...fichas[ref.id], ...data };
          }
          if (ref.col === 'participacoes') {
            const idx = participacoes.findIndex((p) => p.id === ref.id);
            if (idx !== -1) participacoes[idx] = { ...participacoes[idx], ...data };
          }
          if (ref.col === 'ciclos' && ciclos[ref.id]) {
            ciclos[ref.id] = { ...ciclos[ref.id], ...data };
          }
        },
        set: (ref: any, data: any) => {
          sets.push({ col: ref.col, id: ref.id, data });
        },
      };
      return await fn(tx);
    },
    _updates: updates,
    _sets: sets,
  };

  return mockDb;
}

describe('Story 5.1: Repositório e Job Idempotente de Expiração (AD-10 / AD-11 / AD-12)', () => {
  it('expira participações ativas vencidas e reduz ficha para EXPIRADA quando todas expiram (AD-11)', async () => {
    const agoraIso = '2026-10-07T12:00:00.000Z';
    const vencimentoPassado = '2026-10-01T12:00:00.000Z';

    const db = criarMockDb({
      fichas: {
        'ficha-01': {
          id: 'ficha-01',
          estado: 'ATIVA',
          nomeCompleto: 'Voluntário Expirando',
        },
      },
      participacoes: [
        {
          id: 'part-01',
          fichaId: 'ficha-01',
          equipeId: 'eq-louvor',
          estado: 'ATIVA',
          versao: 1,
          cicloAtualId: 'ciclo-01',
          vigenciaFim: vencimentoPassado,
        },
      ],
      ciclos: {
        'ciclo-01': {
          id: 'ciclo-01',
          estado: 'ATIVO',
          anoVigencia: 2025,
        },
      },
    });

    const entrada = validarExpirarCiclos({
      commandId: 'cmd-job-expirar-001',
      agoraIso,
    });

    const resultado = await executarExpirarCiclosRepo(db, entrada);

    expect(resultado.sucesso).toBe(true);
    expect(resultado.totalExpiradas).toBe(1);
    expect(resultado.expiradas[0].participacaoId).toBe('part-01');
    expect(resultado.expiradas[0].fichaNovoEstado).toBe('EXPIRADA');

    const partUpdate = db._updates.find((u: any) => u.col === 'participacoes' && u.id === 'part-01');
    expect(partUpdate).toBeDefined();
    expect(partUpdate.data.estado).toBe('EXPIRADA');
    expect(partUpdate.data.versao).toBe(2);

    const cicloUpdate = db._updates.find((u: any) => u.col === 'ciclos' && u.id === 'ciclo-01');
    expect(cicloUpdate).toBeDefined();
    expect(cicloUpdate.data.estado).toBe('EXPIRADA');

    const fichaUpdate = db._updates.find((u: any) => u.col === 'fichas' && u.id === 'ficha-01');
    expect(fichaUpdate).toBeDefined();
    expect(fichaUpdate.data.estado).toBe('EXPIRADA');

    const auditSet = db._sets.find((s: any) => s.col === 'auditOutbox');
    expect(auditSet).toBeDefined();
    expect(auditSet.data.acao).toBe('EXPIRAR_CICLO_ANUAL');
    expect(auditSet.data.ator.papel).toBe('SISTEMA');
    expect(auditSet.data.antes.estadoParticipacao).toBe('ATIVA');
    expect(auditSet.data.depois.estadoParticipacao).toBe('EXPIRADA');
  });

  it('mantém a ficha ATIVA se houver outra participação com vigência não vencida (AD-11)', async () => {
    const agoraIso = '2026-10-07T12:00:00.000Z';
    const vencimentoPassado = '2026-10-01T12:00:00.000Z';
    const vencimentoFuturo = '2026-12-01T12:00:00.000Z';

    const db = criarMockDb({
      fichas: {
        'ficha-02': {
          id: 'ficha-02',
          estado: 'ATIVA',
          nomeCompleto: 'Voluntário com Múltiplas Equipes',
        },
      },
      participacoes: [
        {
          id: 'part-vencida',
          fichaId: 'ficha-02',
          equipeId: 'eq-louvor',
          estado: 'ATIVA',
          versao: 1,
          cicloAtualId: 'ciclo-vencido',
          vigenciaFim: vencimentoPassado,
        },
        {
          id: 'part-valida',
          fichaId: 'ficha-02',
          equipeId: 'eq-som',
          estado: 'ATIVA',
          versao: 1,
          cicloAtualId: 'ciclo-valido',
          vigenciaFim: vencimentoFuturo,
        },
      ],
      ciclos: {
        'ciclo-vencido': { id: 'ciclo-vencido', estado: 'ATIVO' },
        'ciclo-valido': { id: 'ciclo-valido', estado: 'ATIVO' },
      },
    });

    const entrada = validarExpirarCiclos({
      commandId: 'cmd-job-expirar-002',
      agoraIso,
    });

    const resultado = await executarExpirarCiclosRepo(db, entrada);

    expect(resultado.sucesso).toBe(true);
    expect(resultado.totalExpiradas).toBe(1);
    expect(resultado.expiradas[0].participacaoId).toBe('part-vencida');
    expect(resultado.expiradas[0].fichaNovoEstado).toBe('ATIVA');

    const fichaUpdate = db._updates.find((u: any) => u.col === 'fichas' && u.id === 'ficha-02');
    expect(fichaUpdate).toBeUndefined();
  });

  it('marca a participação como INATIVA quando o voluntário escolheu não continuar (AD-11)', async () => {
    const agoraIso = '2026-10-07T12:00:00.000Z';
    const vencimentoPassado = '2026-10-01T12:00:00.000Z';

    const db = criarMockDb({
      fichas: { 'ficha-03': { id: 'ficha-03', estado: 'ATIVA' } },
      participacoes: [
        {
          id: 'part-nao-continuar',
          fichaId: 'ficha-03',
          equipeId: 'eq-som',
          estado: 'ATIVA',
          versao: 1,
          vigenciaFim: vencimentoPassado,
          intencaoRenovacao: 'NAO_CONTINUAR',
          programadoEncerramentoEm: vencimentoPassado,
        },
      ],
    });

    const resultado = await executarExpirarCiclosRepo(
      db,
      validarExpirarCiclos({ commandId: 'cmd-job-expirar-003', agoraIso }),
    );

    expect(resultado.totalExpiradas).toBe(1);
    const partUpdate = db._updates.find(
      (u: any) => u.col === 'participacoes' && u.id === 'part-nao-continuar',
    );
    expect(partUpdate.data.estado).toBe('INATIVA');
    expect(resultado.expiradas[0].fichaNovoEstado).toBe('INATIVA');
  });

  it('mantém a ficha AGUARDANDO_COORDENADOR quando há participação pendente (AD-11)', async () => {
    const agoraIso = '2026-10-07T12:00:00.000Z';
    const vencimentoPassado = '2026-10-01T12:00:00.000Z';

    const db = criarMockDb({
      fichas: { 'ficha-04': { id: 'ficha-04', estado: 'ATIVA' } },
      participacoes: [
        {
          id: 'part-vencida-04',
          fichaId: 'ficha-04',
          equipeId: 'eq-louvor',
          estado: 'ATIVA',
          versao: 1,
          vigenciaFim: vencimentoPassado,
        },
        {
          id: 'part-pendente-04',
          fichaId: 'ficha-04',
          equipeId: 'eq-som',
          estado: 'AGUARDANDO_COORDENADOR',
          versao: 1,
        },
      ],
    });

    const resultado = await executarExpirarCiclosRepo(
      db,
      validarExpirarCiclos({ commandId: 'cmd-job-expirar-004', agoraIso }),
    );

    expect(resultado.expiradas[0].fichaNovoEstado).toBe('AGUARDANDO_COORDENADOR');
    const fichaUpdate = db._updates.find((u: any) => u.col === 'fichas' && u.id === 'ficha-04');
    expect(fichaUpdate.data.estado).toBe('AGUARDANDO_COORDENADOR');
  });

  it('dryRun projeta expirações sem mutar estado nem gravar recibo', async () => {
    const agoraIso = '2026-10-07T12:00:00.000Z';
    const vencimentoPassado = '2026-10-01T12:00:00.000Z';

    const db = criarMockDb({
      fichas: { 'ficha-05': { id: 'ficha-05', estado: 'ATIVA' } },
      participacoes: [
        {
          id: 'part-dry-05',
          fichaId: 'ficha-05',
          equipeId: 'eq-louvor',
          estado: 'ATIVA',
          versao: 1,
          vigenciaFim: vencimentoPassado,
        },
      ],
    });

    const resultado = await executarExpirarCiclosRepo(
      db,
      validarExpirarCiclos({ commandId: 'cmd-job-dry-005', agoraIso, dryRun: true }),
    );

    expect(resultado.totalExpiradas).toBe(0);
    expect(resultado.expiradas).toHaveLength(1);
    expect(db._updates.length).toBe(0);
    expect(db._sets.length).toBe(0);
  });

  it('recusa mesmo commandId com payload divergente (AD-10)', async () => {
    const db = criarMockDb({
      recibos: {
        'cmd-job-divergente': {
          commandId: 'cmd-job-divergente',
          payloadHash: 'hash-antigo',
          resultado: { totalVerificadas: 0, totalExpiradas: 0, expiradas: [] },
        },
      },
    });

    await expect(
      executarExpirarCiclosRepo(
        db,
        validarExpirarCiclos({ commandId: 'cmd-job-divergente', agoraIso: '2026-10-07T12:00:00.000Z' }),
      ),
    ).rejects.toThrow(ComandoDivergenteError);
  });

  it('é estritamente idempotente: repetição do commandId retorna recibo sem mutações repetidas (AD-10)', async () => {
    const agoraIso = '2026-10-07T12:00:00.000Z';

    const db = criarMockDb({
      recibos: {
        'cmd-job-repetido': {
          commandId: 'cmd-job-repetido',
          tipo: 'EXPIRAR_CICLOS_VENCIDOS',
          estado: 'COMPLETO',
          resultado: {
            totalVerificadas: 5,
            totalExpiradas: 2,
            expiradas: [{ participacaoId: 'part-p1' }, { participacaoId: 'part-p2' }],
            processadoEm: agoraIso,
          },
          criadoEm: agoraIso,
        },
      },
    });

    const entrada = validarExpirarCiclos({
      commandId: 'cmd-job-repetido',
      agoraIso,
    });

    const resultado = await executarExpirarCiclosRepo(db, entrada);

    expect(resultado.repetido).toBe(true);
    expect(resultado.totalExpiradas).toBe(2);
    expect(db._updates.length).toBe(0);
  });
});

describe('Story 5.1: Callable Cloud Function expirarCiclosVencidos', () => {
  it('rejeita chamadas não autenticadas', async () => {
    const callable: any = expirarCiclosVencidos;
    await expect(
      callable.run({
        auth: null,
        data: { commandId: 'cmd-teste-auth' },
      }),
    ).rejects.toThrow('É necessário entrar na conta.');
  });
});
