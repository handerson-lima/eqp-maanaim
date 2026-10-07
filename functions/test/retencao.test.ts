import { describe, expect, it } from 'vitest';
import { ComandoDivergenteError } from '../src/domain/ficha.js';
import {
  DIAS_RASCUNHO_PADRAO,
  SolicitacaoRetencaoInvalidaError,
  calcularIndicadoresConformidade,
  calcularPayloadHashRetencao,
  fichaElegivelParaAnonimizacao,
  fichaElegivelParaExpurgo,
  normalizarDiasRascunho,
  validarRotinaRetencao,
} from '../src/domain/retencao.js';
import {
  consultarConformidadeRetencaoRepo,
  executarRotinaRetencaoRepo,
  obterConfiguracaoRetencao,
} from '../src/repositories/retencao.js';
import { executarRotinaRetencao } from '../src/commands/executarRotinaRetencao.js';

const AGORA = '2026-10-07T12:00:00.000Z';
const AGORA_MS = Date.parse(AGORA);

describe('Story 6.4: Domínio de Retenção e Elegibilidade (AD-12)', () => {
  it('valida a rotina com dryRun padrão e motivo padrão', () => {
    const entrada = validarRotinaRetencao({ commandId: 'cmd-retencao-001' });
    expect(entrada.commandId).toBe('cmd-retencao-001');
    expect(entrada.dryRun).toBe(true);
    expect(entrada.motivo).toBe('EXECUCAO_MANUAL');
    expect(entrada.limite).toBe(100);
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it('rejeita commandId, motivo, limite e agoraIso inválidos', () => {
    expect(() => validarRotinaRetencao({ commandId: 'curto' })).toThrow(
      SolicitacaoRetencaoInvalidaError,
    );
    expect(() =>
      validarRotinaRetencao({ commandId: 'cmd-retencao-001', motivo: 'INVENTADO' }),
    ).toThrow(SolicitacaoRetencaoInvalidaError);
    expect(() =>
      validarRotinaRetencao({ commandId: 'cmd-retencao-001', limite: 0 }),
    ).toThrow(SolicitacaoRetencaoInvalidaError);
    expect(() =>
      validarRotinaRetencao({ commandId: 'cmd-retencao-001', limite: 201 }),
    ).toThrow(SolicitacaoRetencaoInvalidaError);
    expect(() =>
      validarRotinaRetencao({ commandId: 'cmd-retencao-001', agoraIso: 'data-invalida' }),
    ).toThrow(SolicitacaoRetencaoInvalidaError);
  });

  it('normaliza diasRascunho para o intervalo 30–730 com padrão seguro', () => {
    expect(normalizarDiasRascunho(undefined)).toBe(DIAS_RASCUNHO_PADRAO);
    expect(normalizarDiasRascunho(10)).toBe(DIAS_RASCUNHO_PADRAO);
    expect(normalizarDiasRascunho(1000)).toBe(DIAS_RASCUNHO_PADRAO);
    expect(normalizarDiasRascunho(120)).toBe(120);
  });

  it('gera hash determinístico do payload lógico', () => {
    const a = calcularPayloadHashRetencao({
      commandId: 'cmd-retencao-001',
      motivo: 'ROTINA_AGENDADA',
      limite: 100,
    });
    const b = calcularPayloadHashRetencao({
      commandId: 'cmd-retencao-001',
      motivo: 'ROTINA_AGENDADA',
      limite: 100,
    });
    expect(a).toBe(b);
  });

  it('elegibilidade de anonimização: terminal + 5 anos', () => {
    const ficha = { estado: 'EXPIRADA', atualizadoEm: '2020-01-01T00:00:00.000Z' };
    const decisao = fichaElegivelParaAnonimizacao(ficha, [], {
      agoraMs: AGORA_MS,
      motivo: 'ROTINA_AGENDADA',
    });
    expect(decisao.elegivel).toBe(true);
    expect(decisao.retencaoAte).toBe('2025-01-01T00:00:00.000Z');
  });

  it('elegibilidade de anonimização: bloqueia participação ativa/pendente e estado não terminal', () => {
    const recente = { estado: 'EXPIRADA', atualizadoEm: '2026-01-01T00:00:00.000Z' };
    expect(
      fichaElegivelParaAnonimizacao(recente, [{ estado: 'ATIVA' }], {
        agoraMs: AGORA_MS,
        motivo: 'SOLICITACAO_TITULAR',
      }).elegivel,
    ).toBe(false);
    expect(
      fichaElegivelParaAnonimizacao({ estado: 'ATIVA', atualizadoEm: '2010-01-01' }, [], {
        agoraMs: AGORA_MS,
        motivo: 'ROTINA_AGENDADA',
      }).elegivel,
    ).toBe(false);
  });

  it('elegibilidade de anonimização: SOLICITACAO_TITULAR dispensa os 5 anos; repetição é no-op', () => {
    const recente = { estado: 'CANCELADA', atualizadoEm: '2026-09-01T00:00:00.000Z' };
    expect(
      fichaElegivelParaAnonimizacao(recente, [], {
        agoraMs: AGORA_MS,
        motivo: 'ROTINA_AGENDADA',
      }).elegivel,
    ).toBe(false);
    expect(
      fichaElegivelParaAnonimizacao(recente, [], {
        agoraMs: AGORA_MS,
        motivo: 'SOLICITACAO_TITULAR',
      }).elegivel,
    ).toBe(true);
    expect(
      fichaElegivelParaAnonimizacao(
        { ...recente, anonimizadaEm: AGORA },
        [],
        { agoraMs: AGORA_MS, motivo: 'SOLICITACAO_TITULAR' },
      ).motivoExclusao,
    ).toBe('JA_ANONIMIZADA');
  });

  it('elegibilidade de expurgo: rascunho abandonado sem aceite e com participações rascunho', () => {
    const antigo = '2020-01-01T00:00:00.000Z';
    const elegivel = fichaElegivelParaExpurgo(
      { estado: 'RASCUNHO', atualizadoEm: antigo },
      [{ estado: 'RASCUNHO' }],
      { agoraMs: AGORA_MS, diasRascunho: 180 },
    );
    expect(elegivel.elegivel).toBe(true);

    expect(
      fichaElegivelParaExpurgo(
        { estado: 'RASCUNHO', atualizadoEm: antigo, termoAceito: { termoId: 't1' } },
        [],
        { agoraMs: AGORA_MS, diasRascunho: 180 },
      ).motivoExclusao,
    ).toBe('TERMO_ACEITO');

    expect(
      fichaElegivelParaExpurgo(
        { estado: 'RASCUNHO', atualizadoEm: antigo },
        [{ estado: 'ATIVA' }],
        { agoraMs: AGORA_MS, diasRascunho: 180 },
      ).motivoExclusao,
    ).toBe('PARTICIPACAO_AVANCADA');

    expect(
      fichaElegivelParaExpurgo(
        { estado: 'RASCUNHO', atualizadoEm: '2026-09-01T00:00:00.000Z' },
        [],
        { agoraMs: AGORA_MS, diasRascunho: 180 },
      ).motivoExclusao,
    ).toBe('DENTRO_DO_PRAZO');
  });

  it('calcula indicadores de conformidade apenas como contagens', () => {
    const indicadores = calcularIndicadoresConformidade(
      [
        { estado: 'ATIVA' },
        { estado: 'EXPIRADA', atualizadoEm: '2020-01-01T00:00:00.000Z' },
        { estado: 'RASCUNHO', atualizadoEm: '2020-01-01T00:00:00.000Z' },
      ],
      [[], [], []],
      { agoraMs: AGORA_MS, diasRascunho: 180, expurgoAutomaticoHabilitado: false },
    );
    expect(indicadores.totalFichas).toBe(3);
    expect(indicadores.fichasAtivas).toBe(1);
    expect(indicadores.fichasElegiveisAnonimizacao).toBe(1);
    expect(indicadores.rascunhosElegiveisExpurgo).toBe(1);
    expect(indicadores.politicaId).toBe('AD-12_V1');
  });
});

function criarMockDb(cenario: {
  fichas?: Record<string, any>;
  participacoes?: Array<any>;
  commands?: Record<string, any>;
  configuracoes?: Record<string, any>;
}) {
  const fichas = { ...(cenario.fichas ?? {}) };
  const participacoes = [...(cenario.participacoes ?? [])];
  const commands = { ...(cenario.commands ?? {}) };
  const configuracoes = { ...(cenario.configuracoes ?? {}) };

  const updates: Array<{ col: string; id: string; data: any }> = [];
  const sets: Array<{ col: string; id: string; data: any }> = [];
  const deletes: Array<{ col: string; id: string }> = [];

  const fonte = (col: string) => {
    if (col === 'fichas') return Object.entries(fichas).map(([id, data]) => ({ id, data }));
    if (col === 'participacoes') return participacoes.map((p) => ({ id: p.id, data: p }));
    return [];
  };

  const combina = (item: any, condicoes: Array<[string, string, any]>) =>
    condicoes.every(([campo, op, valor]) => {
      if (op === '==') return item.data[campo] === valor;
      if (op === 'in') return Array.isArray(valor) && valor.includes(item.data[campo]);
      return true;
    });

  const queryBuilder = (col: string, condicoes: Array<[string, string, any]>) => {
    const q: any = {
      where: (campo: string, op: string, valor: any) =>
        queryBuilder(col, [...condicoes, [campo, op, valor]]),
      orderBy: () => q,
      limit: () => q,
      get: async () => {
        const docs = fonte(col)
          .filter((item) => combina(item, condicoes))
          .map((item) => ({
            id: item.id,
            ref: docRef(col, item.id),
            data: () => item.data,
          }));
        return { size: docs.length, docs, empty: docs.length === 0 };
      },
    };
    return q;
  };

  const docRef = (col: string, id: string) => ({
    col,
    id,
    get: async () => {
      if (col === 'commands') return { exists: !!commands[id], id, data: () => commands[id] };
      if (col === 'configuracoes') {
        return { exists: !!configuracoes[id], id, data: () => configuracoes[id] };
      }
      if (col === 'fichas') return { exists: !!fichas[id], id, data: () => fichas[id] };
      if (col === 'participacoes') {
        const d = participacoes.find((p) => p.id === id);
        return { exists: !!d, id, data: () => d };
      }
      return { exists: false, id, data: () => null };
    },
    create: async (data: any) => {
      if (col === 'commands' && commands[id]) {
        const erro: any = new Error('Já existe');
        erro.code = 'already-exists';
        throw erro;
      }
      sets.push({ col, id, data });
      if (col === 'commands') commands[id] = data;
    },
    set: async (data: any) => {
      sets.push({ col, id, data });
      if (col === 'commands') commands[id] = data;
    },
    update: async (data: any) => {
      updates.push({ col, id, data });
      if (col === 'fichas' && fichas[id]) fichas[id] = { ...fichas[id], ...data };
    },
  });

  const aplicarSet = (ref: any, data: any) => {
    sets.push({ col: ref.col, id: ref.id, data });
    if (ref.col === 'commands') commands[ref.id] = data;
  };
  const aplicarUpdate = (ref: any, data: any) => {
    updates.push({ col: ref.col, id: ref.id, data });
    if (ref.col === 'fichas' && fichas[ref.id]) fichas[ref.id] = { ...fichas[ref.id], ...data };
  };
  const aplicarDelete = (ref: any) => {
    deletes.push({ col: ref.col, id: ref.id });
    if (ref.col === 'fichas') delete fichas[ref.id];
    if (ref.col === 'participacoes') {
      const idx = participacoes.findIndex((p) => p.id === ref.id);
      if (idx !== -1) participacoes.splice(idx, 1);
    }
  };

  const mockDb: any = {
    collection: (col: string) => ({
      doc: (id: string) => docRef(col, id),
      where: (campo: string, op: string, valor: any) => queryBuilder(col, [[campo, op, valor]]),
      orderBy: () => queryBuilder(col, []),
      limit: () => queryBuilder(col, []),
      get: () => queryBuilder(col, []).get(),
    }),
    runTransaction: async (fn: any) => {
      const tx = {
        get: async (alvo: any) => {
          if (alvo && typeof alvo.get === 'function') return alvo.get();
          return { exists: false, data: () => null };
        },
        set: (ref: any, data: any) => aplicarSet(ref, data),
        update: (ref: any, data: any) => aplicarUpdate(ref, data),
        delete: (ref: any) => aplicarDelete(ref),
      };
      return fn(tx);
    },
    _updates: updates,
    _sets: sets,
    _deletes: deletes,
    _fichas: fichas,
    _commands: commands,
  };
  return mockDb;
}

describe('Story 6.4: Repositório da Rotina de Retenção (AD-12)', () => {
  function cenario() {
    return criarMockDb({
      fichas: {
        'ficha-anon': {
          id: 'ficha-anon',
          ownerUid: 'ficha-anon',
          estado: 'EXPIRADA',
          atualizadoEm: '2020-01-01T00:00:00.000Z',
          versao: 3,
          nomeCompleto: 'Maria Souza',
          cpf: '12345678900',
          profissao: 'Professora',
        },
        'ficha-rasc': {
          id: 'ficha-rasc',
          ownerUid: 'ficha-rasc',
          estado: 'RASCUNHO',
          atualizadoEm: '2020-01-01T00:00:00.000Z',
          versao: 1,
          nomeCompleto: 'João Rascunho',
          cpf: '98765432100',
          profissao: 'Pedreiro',
        },
        'ficha-recente': {
          id: 'ficha-recente',
          ownerUid: 'ficha-recente',
          estado: 'EXPIRADA',
          atualizadoEm: '2026-09-01T00:00:00.000Z',
          versao: 1,
        },
      },
      participacoes: [
        { id: 'part-rasc', fichaId: 'ficha-rasc', estado: 'RASCUNHO' },
      ],
      configuracoes: {
        retencao: { diasRascunho: 180, expurgoAutomaticoHabilitado: false },
      },
    });
  }

  it('dryRun projeta contagens e IDs sem gravar nada', async () => {
    const db = cenario();
    const entrada = validarRotinaRetencao({
      commandId: 'cmd-retencao-dry',
      agoraIso: AGORA,
      motivo: 'ROTINA_AGENDADA',
      dryRun: true,
    });
    const resultado = await executarRotinaRetencaoRepo(db, entrada);

    expect(resultado.dryRun).toBe(true);
    expect(resultado.totalAnonimizadas).toBe(1);
    expect(resultado.totalExpurgadas).toBe(1);
    expect(resultado.ignoradas).toBe(1);
    expect(resultado.itens.map((i) => i.fichaId).sort()).toEqual(['ficha-anon', 'ficha-rasc']);
    expect(db._updates.length).toBe(0);
    expect(db._sets.length).toBe(0);
    expect(db._deletes.length).toBe(0);
  });

  it('ficha com participação ativa não é anonimizada e é contabilizada como ignorada', async () => {
    const db = criarMockDb({
      fichas: {
        'ficha-com-vinculo': {
          id: 'ficha-com-vinculo',
          estado: 'EXPIRADA',
          atualizadoEm: '2010-01-01T00:00:00.000Z',
          versao: 2,
        },
      },
      participacoes: [{ id: 'part-ativa', fichaId: 'ficha-com-vinculo', estado: 'ATIVA' }],
    });
    const entrada = validarRotinaRetencao({
      commandId: 'cmd-retencao-ativa',
      agoraIso: AGORA,
      motivo: 'ROTINA_AGENDADA',
      dryRun: true,
    });
    const resultado = await executarRotinaRetencaoRepo(db, entrada);

    expect(resultado.totalAnonimizadas).toBe(0);
    expect(resultado.ignoradas).toBe(1);
    expect(db._updates.length).toBe(0);
    expect(db._deletes.length).toBe(0);
  });

  it('executa anonimização e expurgo auditando apenas IDs, estado e motivo', async () => {
    const db = cenario();
    const entrada = validarRotinaRetencao({
      commandId: 'cmd-retencao-exec',
      agoraIso: AGORA,
      motivo: 'ROTINA_AGENDADA',
      dryRun: false,
    });
    const resultado = await executarRotinaRetencaoRepo(db, {
      ...entrada,
      atorUid: 'uid-coordenador',
    });

    expect(resultado.totalAnonimizadas).toBe(1);
    expect(resultado.totalExpurgadas).toBe(1);

    const updateAnon = db._updates.find((u: any) => u.col === 'fichas' && u.id === 'ficha-anon');
    expect(updateAnon.data.nomeCompleto).toBe('Nome Anonimizado');
    expect(updateAnon.data.cpf).toBe('***.***.***-**');
    expect(updateAnon.data.profissao).toBe('');
    expect(updateAnon.data.anonimizadaEm).toBeDefined();
    expect(updateAnon.data.versao).toBe(4);
    expect(updateAnon.data.ownerUid).toBeUndefined();

    const deleteFicha = db._deletes.find((d: any) => d.col === 'fichas' && d.id === 'ficha-rasc');
    expect(deleteFicha).toBeDefined();
    const deletePart = db._deletes.find(
      (d: any) => d.col === 'participacoes' && d.id === 'part-rasc',
    );
    expect(deletePart).toBeDefined();

    const auditAnon = db._sets.find(
      (s: any) => s.col === 'auditOutbox' && s.id === 'cmd-retencao-exec__ficha-anon',
    );
    expect(auditAnon.data.acao).toBe('ANONIMIZAR_FICHA');
    expect(auditAnon.data.motivo).toBe('ROTINA_AGENDADA');
    expect(JSON.stringify(auditAnon.data)).not.toContain('Maria Souza');
    expect(JSON.stringify(auditAnon.data)).not.toContain('12345678900');

    const auditExpurgo = db._sets.find(
      (s: any) => s.col === 'auditOutbox' && s.id === 'cmd-retencao-exec__ficha-rasc',
    );
    expect(auditExpurgo.data.acao).toBe('EXPURGAR_RASCUNHO');

    const recibo = db._sets.find(
      (s: any) => s.col === 'commands' && s.id === 'cmd-retencao-exec',
    );
    expect(recibo).toBeDefined();
    expect(recibo.data.resultado.totalAnonimizadas).toBe(1);
  });

  it('é estritamente idempotente: repetir devolve recibo sem mutações', async () => {
    const db = cenario();
    const entrada = validarRotinaRetencao({
      commandId: 'cmd-retencao-repetido',
      agoraIso: AGORA,
      motivo: 'ROTINA_AGENDADA',
      dryRun: false,
    });
    db._commands['cmd-retencao-repetido'] = {
      commandId: 'cmd-retencao-repetido',
      payloadHash: entrada.payloadHash,
      resultado: {
        dryRun: false,
        totalAnalisadas: 3,
        totalAnonimizadas: 1,
        totalExpurgadas: 1,
        ignoradas: 1,
        itens: [{ fichaId: 'ficha-anon', acao: 'ANONIMIZAR' }],
        processadoEm: AGORA,
      },
    };

    const resultado = await executarRotinaRetencaoRepo(db, entrada);
    expect(resultado.repetido).toBe(true);
    expect(resultado.totalAnonimizadas).toBe(1);
    expect(db._updates.length).toBe(0);
    expect(db._deletes.length).toBe(0);
  });

  it('recusa recibo sem payloadHash (comando não relacionado) como divergente', async () => {
    const db = criarMockDb({
      commands: {
        'cmd-retencao-legado': {
          commandId: 'cmd-retencao-legado',
          resultado: { totalAnonimizadas: 0 },
        },
      },
    });
    const entrada = validarRotinaRetencao({
      commandId: 'cmd-retencao-legado',
      agoraIso: AGORA,
      motivo: 'ROTINA_AGENDADA',
      dryRun: false,
    });
    await expect(executarRotinaRetencaoRepo(db, entrada)).rejects.toThrow(
      ComandoDivergenteError,
    );
  });

  it('propaga falha de leitura da configuração em vez de rebaixar o prazo', async () => {
    const dbErro = {
      collection: () => ({
        doc: () => ({
          get: async () => {
            throw new Error('configuracao indisponivel');
          },
        }),
      }),
    } as any;
    await expect(obterConfiguracaoRetencao(dbErro)).rejects.toThrow(
      'configuracao indisponivel',
    );
  });

  it('recusa mesmo commandId com payload divergente', async () => {
    const db = criarMockDb({
      commands: {
        'cmd-retencao-divergente': {
          commandId: 'cmd-retencao-divergente',
          payloadHash: 'hash-antigo',
          resultado: { totalAnonimizadas: 0 },
        },
      },
    });
    const entrada = validarRotinaRetencao({
      commandId: 'cmd-retencao-divergente',
      agoraIso: AGORA,
      motivo: 'ROTINA_AGENDADA',
      dryRun: false,
    });
    await expect(executarRotinaRetencaoRepo(db, entrada)).rejects.toThrow(
      ComandoDivergenteError,
    );
  });

  it('modo somenteExpurgo ignora fichas terminais (job agendado)', async () => {
    const db = cenario();
    const entrada = validarRotinaRetencao({
      commandId: 'cmd-retencao-expurgo',
      agoraIso: AGORA,
      motivo: 'ROTINA_AGENDADA',
      dryRun: true,
    });
    const resultado = await executarRotinaRetencaoRepo(db, {
      ...entrada,
      somenteExpurgo: true,
    });
    expect(resultado.totalAnonimizadas).toBe(0);
    expect(resultado.totalExpurgadas).toBe(1);
    expect(resultado.itens.map((i) => i.acao)).toEqual(['EXPURGAR']);
  });

  it('auditoria do procedimento carrega metadados sem PII (motivo, política, retenção)', async () => {
    const db = cenario();
    const entrada = validarRotinaRetencao({
      commandId: 'cmd-retencao-meta',
      agoraIso: AGORA,
      motivo: 'ROTINA_AGENDADA',
      dryRun: false,
    });
    await executarRotinaRetencaoRepo(db, { ...entrada, atorUid: 'uid-coordenador' });

    const auditAnon = db._sets.find(
      (s: any) => s.col === 'auditOutbox' && s.id === 'cmd-retencao-meta__ficha-anon',
    );
    expect(auditAnon.data.metadados.motivo).toBe('ROTINA_AGENDADA');
    expect(auditAnon.data.metadados.politica).toBe('AD-12_V1');
    expect(auditAnon.data.retencaoAte).toBeDefined();
    expect(JSON.stringify(auditAnon.data)).not.toContain('Maria Souza');

    const auditExpurgo = db._sets.find(
      (s: any) => s.col === 'auditOutbox' && s.id === 'cmd-retencao-meta__ficha-rasc',
    );
    expect(auditExpurgo.data.depois.expurgada).toBe(true);
  });

  it('obterConfiguracaoRetencao aplica padrões seguros', async () => {
    const semConfig = criarMockDb({});
    const padrao = await obterConfiguracaoRetencao(semConfig);
    expect(padrao.diasRascunho).toBe(DIAS_RASCUNHO_PADRAO);
    expect(padrao.expurgoAutomaticoHabilitado).toBe(false);

    const comConfig = cenario();
    const config = await obterConfiguracaoRetencao(comConfig);
    expect(config.diasRascunho).toBe(180);
  });

  it('consultarConformidadeRetencaoRepo devolve somente contagens', async () => {
    const db = cenario();
    const indicadores = await consultarConformidadeRetencaoRepo(db, { agoraIso: AGORA });
    expect(indicadores.totalFichas).toBe(3);
    expect(indicadores.fichasElegiveisAnonimizacao).toBe(1);
    expect(indicadores.rascunhosElegiveisExpurgo).toBe(1);
    expect(JSON.stringify(indicadores)).not.toContain('Maria Souza');
  });
});

describe('Story 6.4: Callable executarRotinaRetencao', () => {
  it('rejeita chamadas não autenticadas', async () => {
    const callable: any = executarRotinaRetencao;
    await expect(
      callable.run({ auth: null, data: { commandId: 'cmd-retencao-auth' } }),
    ).rejects.toThrow('É necessário entrar na conta.');
  });
});
