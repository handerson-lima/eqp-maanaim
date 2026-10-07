import { describe, expect, it } from 'vitest';
import {
  montarRegistroAuditoriaImutavel,
  sanitizarDadoAuditoria,
  validarOrcamentoTransacional,
  validarParametrosReconciliacao,
  SolicitacaoReconciliacaoInvalidaError,
  LIMITE_MAXIMO_OPERACOES_TRANSACAO_FIRESTORE,
  LIMITE_MAXIMO_BYTES_TRANSACAO_FIRESTORE,
  type EntradaAuditOutbox,
} from '../src/domain/auditoria.js';
import {
  emitirAlertaOperacionalRepo,
  obterRegistroAuditoriaRepo,
  processarEntradaAuditOutboxRepo,
  reconciliarAuditoriaRepo,
} from '../src/repositories/auditoria.js';
import { reconciliarAuditoria } from '../src/commands/reconciliarAuditoria.js';

describe('Story 6.1: Domínio, Orçamento Transacional e Sanitização de Auditoria (AD-8, AD-12)', () => {
  it('valida orçamento transacional dentro dos limites do Firestore', () => {
    const resOk = validarOrcamentoTransacional(15, 1024);
    expect(resOk.valido).toBe(true);
    expect(resOk.motivo).toBeUndefined();

    const resTeto = validarOrcamentoTransacional(LIMITE_MAXIMO_OPERACOES_TRANSACAO_FIRESTORE, 1000);
    expect(resTeto.valido).toBe(true);
  });

  it('rejeita transação que exceda o teto de 500 operações (AD-8)', () => {
    const resExcedente = validarOrcamentoTransacional(501, 1024);
    expect(resExcedente.valido).toBe(false);
    expect(resExcedente.motivo).toContain('Orçamento transacional excedido');
    expect(resExcedente.motivo).toContain('501');
  });

  it('rejeita transação com zero operações ou bytes acima de 10MB', () => {
    const resZero = validarOrcamentoTransacional(0);
    expect(resZero.valido).toBe(false);

    const resBytes = validarOrcamentoTransacional(10, LIMITE_MAXIMO_BYTES_TRANSACAO_FIRESTORE + 1);
    expect(resBytes.valido).toBe(false);
    expect(resBytes.motivo).toContain('Tamanho estimado da transação');
  });

  it('sanitiza e mascara CPF em strings e metadados recursivos', () => {
    const entrada = {
      descricao: 'Decisão para o voluntário com CPF 123.456.789-00 aprovada.',
      listaCpfs: ['987.654.321-99', '11122233344'],
      aninhado: {
        cpfFormatado: '123.456.789-10',
        observacao: 'Nada sensível aqui',
      },
    };

    const sanitizado = sanitizarDadoAuditoria(entrada) as typeof entrada;
    expect(sanitizado.descricao).toBe('Decisão para o voluntário com CPF ***.***.***-** aprovada.');
    expect(sanitizado.listaCpfs[0]).toBe('***.***.***-**');
    expect(sanitizado.aninhado.cpfFormatado).toBe('***.***.***-**');
    expect(sanitizado.aninhado.observacao).toBe('Nada sensível aqui');
  });

  it('remove campos de senhas, tokens e chaves privadas da auditoria', () => {
    const entradaComSegredos = {
      id: 'cmd-1',
      token: 'jwt-super-secreto',
      refreshToken: 'refresh-1234',
      senha: 'minhaSenhaForte',
      password: 'password123',
      secret: 'chave-api',
      authorization: 'Bearer token-xyz',
      assinaturaPrivada: 'rsa-priv-key',
      motivo: 'APROVACAO_REGULAR',
      quantidadeEquipes: 2,
    };

    const resultado = sanitizarDadoAuditoria(entradaComSegredos) as Record<string, unknown>;
    expect(resultado.token).toBeUndefined();
    expect(resultado.refreshToken).toBeUndefined();
    expect(resultado.senha).toBeUndefined();
    expect(resultado.password).toBeUndefined();
    expect(resultado.secret).toBeUndefined();
    expect(resultado.authorization).toBeUndefined();
    expect(resultado.assinaturaPrivada).toBeUndefined();
    expect(resultado.motivo).toBe('APROVACAO_REGULAR');
    expect(resultado.quantidadeEquipes).toBe(2);
  });

  it('monta registro de auditoria imutável canônico com normalização e sanitização', () => {
    const outbox: EntradaAuditOutbox = {
      commandId: 'cmd-aprov-100',
      correlationId: 'corr-100',
      atorUid: 'user-pastor-1',
      acao: 'DECISAO_PASTORAL_REGISTRADA',
      entidades: [
        { tipo: 'ficha', id: 'vol-1' },
        { tipo: 'participacao', id: 'part-1' },
      ],
      antes: { estado: 'AGUARDANDO_PASTOR_LOCAL' },
      depois: { estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE' },
      metadados: {
        igrejaId: 'igreja-central',
        cpfVoluntario: '123.456.789-00',
        tokenSessao: 'tok-abc',
      },
      timestamp: '2026-10-07T12:00:00.000Z',
    };

    const agora = '2026-10-07T12:00:05.000Z';
    const reg = montarRegistroAuditoriaImutavel(outbox, agora);

    expect(reg.id).toBe('cmd-aprov-100');
    expect(reg.commandId).toBe('cmd-aprov-100');
    expect(reg.correlationId).toBe('corr-100');
    expect(reg.atorUid).toBe('user-pastor-1');
    expect(reg.acao).toBe('DECISAO_PASTORAL_REGISTRADA');
    expect(reg.entidades).toEqual([
      { tipo: 'FICHA', id: 'vol-1' },
      { tipo: 'PARTICIPACAO', id: 'part-1' },
    ]);
    expect(reg.antes).toEqual({ estado: 'AGUARDANDO_PASTOR_LOCAL' });
    expect(reg.depois).toEqual({ estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE' });
    expect(reg.metadados?.igrejaId).toBe('igreja-central');
    expect(reg.metadados?.cpfVoluntario).toBe('***.***.***-**');
    expect(reg.metadados?.tokenSessao).toBeUndefined();
    expect(reg.versaoSchema).toBe(1);
    expect(reg.sanitizado).toBe(true);
  });

  it('valida parâmetros da callable de reconciliação de auditoria', () => {
    expect(validarParametrosReconciliacao(null)).toEqual({ limite: 50 });
    expect(validarParametrosReconciliacao({})).toEqual({ limite: 50 });
    expect(validarParametrosReconciliacao({ limite: 100 })).toEqual({ limite: 100 });
    expect(() => validarParametrosReconciliacao({ limite: 0 })).toThrow(
      SolicitacaoReconciliacaoInvalidaError,
    );
    expect(() => validarParametrosReconciliacao({ limite: 201 })).toThrow(
      SolicitacaoReconciliacaoInvalidaError,
    );
    expect(() => validarParametrosReconciliacao({ limite: 'invalido' })).toThrow(
      SolicitacaoReconciliacaoInvalidaError,
    );
  });
});

// Helper de simulação de Firestore em memória para testes dos repositórios
function criarMockFirestoreAuditoria(dadosIniciais?: {
  auditOutbox?: Record<string, any>;
  auditoria?: Record<string, any>;
  commands?: Record<string, any>;
  alertasOperacionais?: Record<string, any>;
  autoridadesAdministrativas?: Record<string, any>;
  pessoas?: Record<string, any>;
}) {
  const auditOutbox: Record<string, any> = { ...(dadosIniciais?.auditOutbox ?? {}) };
  const auditoria: Record<string, any> = { ...(dadosIniciais?.auditoria ?? {}) };
  const commands: Record<string, any> = { ...(dadosIniciais?.commands ?? {}) };
  const alertasOperacionais: Record<string, any> = { ...(dadosIniciais?.alertasOperacionais ?? {}) };
  const autoridadesAdministrativas: Record<string, any> = {
    ...(dadosIniciais?.autoridadesAdministrativas ?? {}),
  };
  const pessoas: Record<string, any> = { ...(dadosIniciais?.pessoas ?? {}) };

  const getCol = (colName: string) => {
    if (colName === 'auditOutbox') return auditOutbox;
    if (colName === 'auditoria') return auditoria;
    if (colName === 'commands') return commands;
    if (colName === 'alertasOperacionais') return alertasOperacionais;
    if (colName === 'autoridadesAdministrativas') return autoridadesAdministrativas;
    if (colName === 'pessoas') return pessoas;
    return {};
  };

  const db: any = {
    collection: (colName: string) => ({
      doc: (docId: string) => ({
        id: docId,
        get: async () => {
          const col = getCol(colName);
          const data = col[docId];
          return {
            exists: !!data,
            id: docId,
            data: () => data,
          };
        },
        set: async (data: any, options?: { merge?: boolean }) => {
          const col = getCol(colName);
          if (options?.merge && col[docId]) {
            col[docId] = { ...col[docId], ...data };
          } else {
            col[docId] = { ...data };
          }
        },
        update: async (data: any) => {
          const col = getCol(colName);
          if (col[docId]) {
            col[docId] = { ...col[docId], ...data };
          }
        },
      }),
      limit: (limite: number) => ({
        get: async () => {
          const col = getCol(colName);
          const keys = Object.keys(col).slice(0, limite);
          return {
            size: keys.length,
            docs: keys.map((k) => ({
              id: k,
              data: () => col[k],
            })),
          };
        },
      }),
      where: (campo: string, op: string, valor: any) => ({
        limit: (limite: number) => ({
          get: async () => {
            const col = getCol(colName);
            const filtrados = Object.entries(col).filter(([_, v]) => {
              if (op === '==') return v[campo] === valor;
              if (op === '!=') return v[campo] !== valor;
              return true;
            });
            const docs = filtrados.slice(0, limite).map(([k, v]) => ({
              id: k,
              data: () => v,
            }));
            return { size: docs.length, docs };
          },
        }),
      }),
    }),
    runTransaction: async (updateFunction: (tx: any) => Promise<any>) => {
      const tx = {
        get: async (docRef: any) => docRef.get(),
        create: (docRef: any, data: any) => {
          const col = getCol(docRef.id ? 'auditoria' : 'auditoria'); // ref direta
          // DocRef do Firestore mock
          if (docRef.id) {
            auditoria[docRef.id] = { ...data };
          }
        },
        update: (docRef: any, data: any) => {
          if (docRef.id && commands[docRef.id]) {
            commands[docRef.id] = { ...commands[docRef.id], ...data };
          }
        },
        set: (docRef: any, data: any, options?: any) => {
          if (docRef.id) {
            if (options?.merge && auditOutbox[docRef.id]) {
              auditOutbox[docRef.id] = { ...auditOutbox[docRef.id], ...data };
            } else {
              auditOutbox[docRef.id] = { ...data };
            }
          }
        },
      };
      return updateFunction(tx);
    },
    _state: { auditOutbox, auditoria, commands, alertasOperacionais },
  };

  return db;
}

describe('Story 6.1: Repositório de Auditoria e Consumidor Idempotente de Outbox (AD-8, AD-10)', () => {
  it('materializa entrada de outbox em auditoria e atualiza recibo de comando para COMPLETO', async () => {
    const db = criarMockFirestoreAuditoria({
      auditOutbox: {
        'cmd-001': {
          commandId: 'cmd-001',
          atorUid: 'pastor-1',
          acao: 'DECISAO_PASTORAL_REGISTRADA',
          entidades: [{ tipo: 'FICHA', id: 'vol-1' }],
          depois: { estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE' },
          metadados: { decisao: 'FAVORAVEL' },
          processado: false,
        },
      },
      commands: {
        'cmd-001': {
          commandId: 'cmd-001',
          uid: 'pastor-1',
          acao: 'DECIDIR_FICHA_PASTOR_LOCAL',
          status: 'PENDENTE',
        },
      },
    });

    const resultado = await processarEntradaAuditOutboxRepo(db, 'cmd-001');

    expect(resultado.sucesso).toBe(true);
    expect(resultado.commandId).toBe('cmd-001');
    expect(resultado.jaProcessado).toBe(false);

    // Verifica que auditoria/:commandId foi materializada
    const auditSalva = db._state.auditoria['cmd-001'];
    expect(auditSalva).toBeDefined();
    expect(auditSalva.id).toBe('cmd-001');
    expect(auditSalva.acao).toBe('DECISAO_PASTORAL_REGISTRADA');
    expect(auditSalva.sanitizado).toBe(true);

    // Verifica que commands/:commandId foi concluído
    const cmdAtualizado = db._state.commands['cmd-001'];
    expect(cmdAtualizado.status).toBe('COMPLETO');
    expect(cmdAtualizado.auditoriaProcessada).toBe(true);
    expect(cmdAtualizado.auditoriaId).toBe('cmd-001');

    // Verifica que outbox foi marcado como processado
    const outboxAtualizado = db._state.auditOutbox['cmd-001'];
    expect(outboxAtualizado.processado).toBe(true);
  });

  it('garante idempotência estrita em múltiplas execuções do consumidor para o mesmo commandId', async () => {
    const db = criarMockFirestoreAuditoria({
      auditOutbox: {
        'cmd-002': {
          commandId: 'cmd-002',
          atorUid: 'resp-eqp-1',
          acao: 'DECISAO_RESPONSAVEL_EQUIPE',
          processado: true,
        },
      },
      auditoria: {
        'cmd-002': {
          id: 'cmd-002',
          commandId: 'cmd-002',
          acao: 'DECISAO_RESPONSAVEL_EQUIPE',
        },
      },
      commands: {
        'cmd-002': {
          commandId: 'cmd-002',
          status: 'COMPLETO',
        },
      },
    });

    const primeira = await processarEntradaAuditOutboxRepo(db, 'cmd-002');
    expect(primeira.sucesso).toBe(true);
    expect(primeira.jaProcessado).toBe(true);

    const segunda = await processarEntradaAuditOutboxRepo(db, 'cmd-002');
    expect(segunda.sucesso).toBe(true);
    expect(segunda.jaProcessado).toBe(true);
  });

  it('trata falha graciosa quando entrada de outbox não existe', async () => {
    const db = criarMockFirestoreAuditoria();
    const resultado = await processarEntradaAuditOutboxRepo(db, 'cmd-inexistente');

    expect(resultado.sucesso).toBe(false);
    expect(resultado.erro).toBe('ENTRADA_OUTBOX_NAO_ENCONTRADA');
  });

  it('emite alerta operacional após 3 falhas consecutivas de processamento', async () => {
    const db = criarMockFirestoreAuditoria({
      auditOutbox: {
        'cmd-com-falha': {
          commandId: 'cmd-com-falha',
          processado: false,
          tentativas: 2, // próxima será a 3ª
        },
      },
    });

    // Forçamos erro na transação
    db.runTransaction = async () => {
      throw new Error('Erro forçado de concorrência ou limite de writes');
    };

    const resultado = await processarEntradaAuditOutboxRepo(db, 'cmd-com-falha');
    expect(resultado.sucesso).toBe(false);

    // Verifica que alerta operacional foi emitido
    const alertas = db._state.alertasOperacionais;
    const alertaChave = 'ALERTA_OUTBOX_cmd-com-falha';
    expect(alertas[alertaChave]).toBeDefined();
    expect(alertas[alertaChave].tipo).toBe('OUTBOX_FALHA_PROCESSAMENTO');
    expect(alertas[alertaChave].severidade).toBe('ALTA');
    expect(alertas[alertaChave].detalhes.tentativas).toBe(3);
  });

  it('consulta registro de auditoria por commandId', async () => {
    const db = criarMockFirestoreAuditoria({
      auditoria: {
        'cmd-consulta-1': {
          id: 'cmd-consulta-1',
          commandId: 'cmd-consulta-1',
          acao: 'FICHA_ENVIADA_APROVACAO',
        },
      },
    });

    const encontrado = await obterRegistroAuditoriaRepo(db, 'cmd-consulta-1');
    expect(encontrado?.id).toBe('cmd-consulta-1');
    expect(encontrado?.acao).toBe('FICHA_ENVIADA_APROVACAO');

    const naoEncontrado = await obterRegistroAuditoriaRepo(db, 'cmd-inexistente');
    expect(naoEncontrado).toBeNull();
  });
});

describe('Story 6.1: Job de Reconciliação e Resiliência Operacional (AD-8, AD-10)', () => {
  it('reconcilia entradas pendentes de outbox com sucesso', async () => {
    const db = criarMockFirestoreAuditoria({
      auditOutbox: {
        'cmd-pendente-1': {
          commandId: 'cmd-pendente-1',
          atorUid: 'user-1',
          acao: 'TERMO_ACEITO',
          processado: false,
        },
        'cmd-pendente-2': {
          commandId: 'cmd-pendente-2',
          atorUid: 'user-2',
          acao: 'RASCUNHO_CRIADO',
          // sem campo processado
        },
        'cmd-ja-ok': {
          commandId: 'cmd-ja-ok',
          processado: true,
        },
      },
      commands: {
        'cmd-pendente-1': { status: 'PENDENTE' },
        'cmd-pendente-2': { status: 'PENDENTE' },
      },
    });

    const resumo = await reconciliarAuditoriaRepo(db, { limite: 50 });

    expect(resumo.pendentesEncontrados).toBe(2);
    expect(resumo.reconciliados).toBe(2);
    expect(resumo.falhas).toBe(0);
    expect(resumo.commandIdsProcessados).toContain('cmd-pendente-1');
    expect(resumo.commandIdsProcessados).toContain('cmd-pendente-2');
  });

  it('detecta comando órfão em PENDENTE sem entrada em auditOutbox e emite alerta operacional crítico', async () => {
    const db = criarMockFirestoreAuditoria({
      auditOutbox: {},
      commands: {
        'cmd-orfao-99': {
          commandId: 'cmd-orfao-99',
          uid: 'user-test',
          status: 'PENDENTE',
        },
      },
    });

    const resumo = await reconciliarAuditoriaRepo(db, { limite: 10 });

    expect(resumo.alertasEmitidos).toBe(1);
    const alerta = db._state.alertasOperacionais['ALERTA_COMANDO_ORFAO_cmd-orfao-99'];
    expect(alerta).toBeDefined();
    expect(alerta.tipo).toBe('COMANDO_ORFAO_SEM_OUTBOX');
    expect(alerta.severidade).toBe('CRITICA');
    expect(alerta.commandId).toBe('cmd-orfao-99');
  });
});

describe('Story 6.1: Callable de Reconciliação e Controle de Acesso', () => {
  it('rejeita chamadas não autenticadas na callable de reconciliação', async () => {
    const handler = (reconciliarAuditoria as any).run;
    expect(typeof handler).toBe('function');
    await expect(
      handler({ auth: null, data: { limite: 10 } }),
    ).rejects.toThrow('É necessário entrar na conta.');
  });
});
