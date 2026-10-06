import { describe, expect, it } from 'vitest';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  DecisaoInvalidaError,
  FichaNaoAguardandoPastorError,
  FichaNaoEncontradaError,
  JustificativaObrigatoriaError,
  MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
  SemVinculoPastoralError,
  calcularPayloadHashDecisaoPastor,
  normalizarDecisao,
  validarDecidirFichaPastor,
} from '../src/domain/decisaoPastor.js';
import {
  decidirFichaPastorLocalRepo,
  obterFilaPastorLocalRepo,
} from '../src/repositories/decisaoPastor.js';
import { obterFilaPastorLocal } from '../src/commands/obterFilaPastorLocal.js';
import { decidirFichaPastorLocal } from '../src/commands/decidirFichaPastorLocal.js';

describe('Story 3.1: Domínio de Decisão do Pastor Local (decisaoPastor.ts)', () => {
  const dadosAprovacao = {
    commandId: 'cmd-decisao-pastor-12345',
    fichaId: 'ficha-voluntario-01',
    decisao: 'APROVADO',
    expectedVersion: 1,
  };

  it('normaliza decisões válidas (APROVADO, DESFAVORAVEL, RECUSADO, etc.)', () => {
    expect(normalizarDecisao('APROVADO')).toBe('APROVADO');
    expect(normalizarDecisao('aprovar')).toBe('APROVADO');
    expect(normalizarDecisao('DESFAVORAVEL')).toBe('DESFAVORAVEL');
    expect(normalizarDecisao('desfavorável')).toBe('DESFAVORAVEL');
    expect(normalizarDecisao('RECUSADO')).toBe('DESFAVORAVEL');
    expect(normalizarDecisao('recusar')).toBe('DESFAVORAVEL');
    expect(() => normalizarDecisao('OUTRO')).toThrow(DecisaoInvalidaError);
  });

  it('valida comando de aprovação e gera hash determinístico', () => {
    const entrada = validarDecidirFichaPastor(dadosAprovacao);
    expect(entrada.commandId).toBe('cmd-decisao-pastor-12345');
    expect(entrada.decisao).toBe('APROVADO');
    expect(entrada.expectedVersion).toBe(1);
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);

    const hashCalculado = calcularPayloadHashDecisaoPastor({
      fichaId: 'ficha-voluntario-01',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });
    expect(entrada.payloadHash).toBe(hashCalculado);
  });

  it('valida comando de decisão desfavorável com justificativa', () => {
    const entrada = validarDecidirFichaPastor({
      ...dadosAprovacao,
      decisao: 'DESFAVORAVEL',
      justificativa: 'Voluntário necessita de período de acompanhamento pastoral.',
    });
    expect(entrada.decisao).toBe('DESFAVORAVEL');
    expect(entrada.justificativa).toBe(
      'Voluntário necessita de período de acompanhamento pastoral.',
    );
  });

  it('rejeita decisão desfavorável sem justificativa ou menor que 5 caracteres', () => {
    expect(() =>
      validarDecidirFichaPastor({
        ...dadosAprovacao,
        decisao: 'DESFAVORAVEL',
      }),
    ).toThrow(JustificativaObrigatoriaError);

    expect(() =>
      validarDecidirFichaPastor({
        ...dadosAprovacao,
        decisao: 'DESFAVORAVEL',
        justificativa: 'abc',
      }),
    ).toThrow(JustificativaObrigatoriaError);
  });

  it('rejeita payload sem commandId válido ou com expectedVersion inválido', () => {
    expect(() =>
      validarDecidirFichaPastor({
        ...dadosAprovacao,
        commandId: 'curto',
      }),
    ).toThrow(DecisaoInvalidaError);

    expect(() =>
      validarDecidirFichaPastor({
        ...dadosAprovacao,
        expectedVersion: -1,
      }),
    ).toThrow(DecisaoInvalidaError);
  });
});

describe('Story 3.1: Repositório de Fila e Decisão do Pastor Local', () => {
  const pastorUid = 'pastor-uid-100';
  const outroPastorUid = 'pastor-uid-200';
  const igrejaDoPastorId = 'igreja-01';
  const outraIgrejaId = 'igreja-02';

  function criarMockDb(cenario: {
    igrejas?: Record<string, any>;
    vinculosIgreja?: Record<string, any>;
    pessoas?: Record<string, any>;
    fichas?: Record<string, any>;
    fila?: Record<string, any>;
    participacoes?: Array<{ id: string; fichaId: string; estado: string; data: any }>;
    recibos?: Record<string, any>;
  }) {
    const updates: Array<{ ref: any; data: any }> = [];
    const sets: Array<{ ref: any; data: any }> = [];
    const deletes: Array<{ ref: any }> = [];

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({
          col,
          id,
          get: async () => {
            if (col === 'igrejas') {
              const d = cenario.igrejas?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'vinculosPastorIgreja') {
              const d = cenario.vinculosIgreja?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'pessoas') {
              const d = cenario.pessoas?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'fichas') {
              const d = cenario.fichas?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'commands') {
              const d = cenario.recibos?.[id];
              return { exists: !!d, id, data: () => d };
            }
            return { exists: false, id, data: () => undefined };
          },
        }),
        where: (field1: string, op1: string, val1: any) => ({
          where: (field2: string, op2: string, val2: any) => ({
            get: async () => {
              if (col === 'filaPendencias') {
                const itens = Object.entries(cenario.fila ?? {})
                  .filter(([_, item]) => {
                    const match1 =
                      op1 === '=='
                        ? item[field1] === val1
                        : op1 === 'in'
                          ? Array.isArray(val1) && val1.includes(item[field1])
                          : false;
                    const match2 =
                      op2 === '=='
                        ? item[field2] === val2
                        : op2 === 'in'
                          ? Array.isArray(val2) && val2.includes(item[field2])
                          : false;
                    return match1 && match2;
                  })
                  .map(([id, item]) => ({
                    id,
                    data: () => item,
                  }));
                return { docs: itens };
              }
              return { docs: [] };
            },
          }),
          get: async () => {
            if (col === 'igrejas') {
              const docs = Object.entries(cenario.igrejas ?? {})
                .filter(([_, item]) => item[field1] === val1)
                .map(([id, item]) => ({ id, data: () => item }));
              return { docs };
            }
            if (col === 'vinculosPastorIgreja') {
              const docs = Object.entries(cenario.vinculosIgreja ?? {})
                .filter(([_, item]) => item[field1] === val1)
                .map(([id, item]) => ({ id, data: () => item }));
              return { docs };
            }
            if (col === 'participacoes') {
              const docs = (cenario.participacoes ?? [])
                .filter((p) => p.fichaId === val1)
                .map((p) => ({
                  id: p.id,
                  ref: { col: 'participacoes', id: p.id },
                  data: () => p.data,
                }));
              return { docs };
            }
            return { docs: [] };
          },
        }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (target: any) => {
            const col = target.col;
            const id = target.id;
            if (target.where) {
              return target.get();
            }
            if (col === 'commands') {
              const d = cenario.recibos?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'fichas') {
              const d = cenario.fichas?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'igrejas') {
              const d = cenario.igrejas?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'vinculosPastorIgreja') {
              const d = cenario.vinculosIgreja?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'pessoas') {
              const d = cenario.pessoas?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'participacoes') {
              const docs = (cenario.participacoes ?? [])
                .filter((p) => p.fichaId === target.val)
                .map((p) => ({
                  id: p.id,
                  ref: { col: 'participacoes', id: p.id },
                  data: () => p.data,
                }));
              return { docs };
            }
            return { exists: false, id, data: () => undefined };
          },
          set: (ref: any, data: any) => {
            sets.push({ ref, data });
          },
          update: (ref: any, data: any) => {
            updates.push({ ref, data });
          },
          delete: (ref: any) => {
            deletes.push({ ref });
          },
        };
        return await fn(tx);
      },
      _updates: updates,
      _sets: sets,
      _deletes: deletes,
    };

    return mockDb;
  }

  it('obterFilaPastorLocalRepo retorna somente pendências de igrejas sob responsabilidade vigente', async () => {
    const db = criarMockDb({
      igrejas: {
        [igrejaDoPastorId]: {
          nome: 'Igreja Central',
          pastorLocalVigentePessoaId: pastorUid,
          ativo: true,
        },
        [outraIgrejaId]: {
          nome: 'Igreja Norte',
          pastorLocalVigentePessoaId: outroPastorUid,
          ativo: true,
        },
      },
      fila: {
        'ficha-01': {
          fichaId: 'ficha-01',
          voluntarioUid: 'vol-01',
          voluntarioNome: 'Carlos Silva',
          igrejaId: igrejaDoPastorId,
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          proximaAcao: 'Aguardando avaliação do Pastor Local',
          ano: 2026,
          equipes: [{ equipeId: 'eq-01', nomeEquipe: 'Louvor' }],
          enviadoEm: new Date('2026-10-01T10:00:00Z'),
        },
        'ficha-02': {
          fichaId: 'ficha-02',
          voluntarioUid: 'vol-02',
          voluntarioNome: 'Maria Santos',
          igrejaId: outraIgrejaId,
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          proximaAcao: 'Aguardando avaliação do Pastor Local',
          ano: 2026,
          equipes: [{ equipeId: 'eq-02', nomeEquipe: 'Acolhimento' }],
          enviadoEm: new Date('2026-10-02T10:00:00Z'),
        },
      },
    });

    const resultado = await obterFilaPastorLocalRepo(db, pastorUid);
    expect(resultado.igrejas).toHaveLength(1);
    expect(resultado.igrejas[0].id).toBe(igrejaDoPastorId);
    expect(resultado.pendencias).toHaveLength(1);
    expect(resultado.pendencias[0].fichaId).toBe('ficha-01');
    expect(resultado.pendencias[0].voluntarioNome).toBe('Carlos Silva');
    expect(resultado.pendencias[0].nomeIgreja).toBe('Igreja Central');
  });

  it('obterFilaPastorLocalRepo retorna lista vazia quando usuário não possui igrejas vigentes', async () => {
    const db = criarMockDb({
      igrejas: {},
      fila: {},
    });

    const resultado = await obterFilaPastorLocalRepo(db, 'usuario-comum');
    expect(resultado.igrejas).toEqual([]);
    expect(resultado.pendencias).toEqual([]);
  });

  it('aprova ficha com sucesso, transiciona para AGUARDANDO_RESPONSAVEL_EQUIPE e gera evidência', async () => {
    const db = criarMockDb({
      igrejas: {
        [igrejaDoPastorId]: {
          nome: 'Igreja Central',
          pastorLocalVigentePessoaId: pastorUid,
          pastorLocalVigenteVinculoId: 'vinc-01',
          ativo: true,
        },
      },
      vinculosIgreja: {
        'vinc-01': {
          pessoaId: pastorUid,
          entidadeId: igrejaDoPastorId,
          estado: 'VIGENTE',
        },
      },
      pessoas: {
        [pastorUid]: { nomeCompleto: 'Pastor João' },
      },
      fichas: {
        'ficha-01': {
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          igrejaId: igrejaDoPastorId,
          versao: 1,
        },
      },
      participacoes: [
        {
          id: 'part-01',
          fichaId: 'ficha-01',
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          data: {
            estado: 'AGUARDANDO_PASTOR_LOCAL',
            equipeId: 'eq-01',
          },
        },
      ],
    });

    const entrada = validarDecidirFichaPastor({
      commandId: 'cmd-decisao-000000001',
      fichaId: 'ficha-01',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });

    const resultado = await decidirFichaPastorLocalRepo(
      db,
      { commandId: entrada.commandId, pastorUid },
      entrada,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.repetido).toBe(false);
    expect(resultado.estado).toBe('AGUARDANDO_RESPONSAVEL_EQUIPE');
    expect(resultado.versao).toBe(2);

    // Verifica que a ficha foi atualizada
    const updateFicha = db._updates.find((u: any) => u.ref.id === 'ficha-01');
    expect(updateFicha).toBeDefined();
    expect(updateFicha.data.estado).toBe('AGUARDANDO_RESPONSAVEL_EQUIPE');
    expect(updateFicha.data.versao).toBe(2);

    // Verifica que as participações foram atualizadas
    const updatePart = db._updates.find((u: any) => u.ref.id === 'part-01');
    expect(updatePart).toBeDefined();
    expect(updatePart.data.estado).toBe('AGUARDANDO_RESPONSAVEL_EQUIPE');

    // Verifica remoção da fila pastoral
    const deleteFila = db._deletes.find((d: any) => d.ref.id === 'ficha-01');
    expect(deleteFila).toBeDefined();

    // Verifica evidência imutável
    const setEvidencia = db._sets.find(
      (s: any) => s.ref.col === 'evidenciasDecisao' && s.ref.id === entrada.commandId,
    );
    expect(setEvidencia).toBeDefined();
    expect(setEvidencia.data.decisao).toBe('APROVADO');
    expect(setEvidencia.data.papel).toBe('PASTOR_LOCAL');
    expect(setEvidencia.data.atorNome).toBe('Pastor João');

    // Verifica recibo e auditoria
    const setRecibo = db._sets.find(
      (s: any) => s.ref.col === 'commands' && s.ref.id === entrada.commandId,
    );
    expect(setRecibo).toBeDefined();
    expect(setRecibo.data.status).toBe('COMPLETO');

    const setAuditoria = db._sets.find(
      (s: any) => s.ref.col === 'auditOutbox' && s.ref.id === entrada.commandId,
    );
    expect(setAuditoria).toBeDefined();
    expect(setAuditoria.data.depois.estado).toBe('AGUARDANDO_RESPONSAVEL_EQUIPE');
  });

  it('toma decisão desfavorável e define mensagem canônica invariante para o voluntário', async () => {
    const db = criarMockDb({
      igrejas: {
        [igrejaDoPastorId]: {
          nome: 'Igreja Central',
          pastorLocalVigentePessoaId: pastorUid,
          pastorLocalVigenteVinculoId: 'vinc-01',
          ativo: true,
        },
      },
      vinculosIgreja: {
        'vinc-01': {
          pessoaId: pastorUid,
          entidadeId: igrejaDoPastorId,
          estado: 'VIGENTE',
        },
      },
      pessoas: {
        [pastorUid]: { nomeCompleto: 'Pastor João' },
      },
      fichas: {
        'ficha-01': {
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          igrejaId: igrejaDoPastorId,
          versao: 1,
        },
      },
      participacoes: [
        {
          id: 'part-01',
          fichaId: 'ficha-01',
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          data: { estado: 'AGUARDANDO_PASTOR_LOCAL' },
        },
      ],
    });

    const entrada = validarDecidirFichaPastor({
      commandId: 'cmd-decisao-000000002',
      fichaId: 'ficha-01',
      decisao: 'DESFAVORAVEL',
      justificativa: 'Necessário período prévio de integração na comunidade local.',
      expectedVersion: 1,
    });

    const resultado = await decidirFichaPastorLocalRepo(
      db,
      { commandId: entrada.commandId, pastorUid },
      entrada,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.estado).toBe('REJEITADA');
    expect(resultado.proximaAcao).toBe(MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA);

    const updateFicha = db._updates.find((u: any) => u.ref.id === 'ficha-01');
    expect(updateFicha).toBeDefined();
    expect(updateFicha.data.estado).toBe('REJEITADA');
    expect(updateFicha.data.mensagemVoluntario).toBe(
      'Procure o Pastor da igreja local para mais informações',
    );
    expect(updateFicha.data.proximaAcao).toBe(
      'Procure o Pastor da igreja local para mais informações',
    );
  });

  it('rejeita decisão se o chamador não for o Pastor Local vigente da igreja da ficha', async () => {
    const db = criarMockDb({
      igrejas: {
        [igrejaDoPastorId]: {
          nome: 'Igreja Central',
          pastorLocalVigentePessoaId: outroPastorUid, // Outro pastor!
          ativo: true,
        },
      },
      fichas: {
        'ficha-01': {
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          igrejaId: igrejaDoPastorId,
          versao: 1,
        },
      },
    });

    const entrada = validarDecidirFichaPastor({
      commandId: 'cmd-decisao-000000003',
      fichaId: 'ficha-01',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });

    await expect(
      decidirFichaPastorLocalRepo(
        db,
        { commandId: entrada.commandId, pastorUid },
        entrada,
      ),
    ).rejects.toThrow(SemVinculoPastoralError);
  });

  it('rejeita decisão se expectedVersion divergir (concorrência)', async () => {
    const db = criarMockDb({
      igrejas: {
        [igrejaDoPastorId]: {
          pastorLocalVigentePessoaId: pastorUid,
          ativo: true,
        },
      },
      fichas: {
        'ficha-01': {
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          igrejaId: igrejaDoPastorId,
          versao: 2, // Versão no banco é 2, entrada traz 1
        },
      },
    });

    const entrada = validarDecidirFichaPastor({
      commandId: 'cmd-decisao-000000004',
      fichaId: 'ficha-01',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });

    await expect(
      decidirFichaPastorLocalRepo(
        db,
        { commandId: entrada.commandId, pastorUid },
        entrada,
      ),
    ).rejects.toThrow(ConflitoVersaoError);
  });

  it('rejeita decisão se a ficha não estiver em AGUARDANDO_PASTOR_LOCAL', async () => {
    const db = criarMockDb({
      igrejas: {
        [igrejaDoPastorId]: {
          pastorLocalVigentePessoaId: pastorUid,
          ativo: true,
        },
      },
      fichas: {
        'ficha-01': {
          estado: 'RASCUNHO',
          igrejaId: igrejaDoPastorId,
          versao: 1,
        },
      },
    });

    const entrada = validarDecidirFichaPastor({
      commandId: 'cmd-decisao-000000005',
      fichaId: 'ficha-01',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });

    await expect(
      decidirFichaPastorLocalRepo(
        db,
        { commandId: entrada.commandId, pastorUid },
        entrada,
      ),
    ).rejects.toThrow(FichaNaoAguardandoPastorError);
  });

  it('retorna resultado idempotente em repetição e rejeita comando divergente', async () => {
    const payloadHashOriginal = calcularPayloadHashDecisaoPastor({
      fichaId: 'ficha-01',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });

    const db = criarMockDb({
      recibos: {
        'cmd-decisao-repetido': {
          uid: pastorUid,
          payloadHash: payloadHashOriginal,
          resultado: {
            estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
            versao: 2,
            proximaAcao: 'Aguardando avaliação dos Responsáveis de Equipe',
          },
          criadoEm: new Date('2026-10-06T12:00:00Z'),
        },
      },
    });

    const entradaRepetida = validarDecidirFichaPastor({
      commandId: 'cmd-decisao-repetido',
      fichaId: 'ficha-01',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });

    const resIdempotente = await decidirFichaPastorLocalRepo(
      db,
      { commandId: entradaRepetida.commandId, pastorUid },
      entradaRepetida,
    );
    expect(resIdempotente.repetido).toBe(true);
    expect(resIdempotente.estado).toBe('AGUARDANDO_RESPONSAVEL_EQUIPE');

    // Com dados divergentes (ex: decisão diferente)
    const entradaDivergente = validarDecidirFichaPastor({
      commandId: 'cmd-decisao-repetido',
      fichaId: 'ficha-01',
      decisao: 'DESFAVORAVEL',
      justificativa: 'Outra justificativa divergente.',
      expectedVersion: 1,
    });

    await expect(
      decidirFichaPastorLocalRepo(
        db,
        { commandId: entradaDivergente.commandId, pastorUid },
        entradaDivergente,
      ),
    ).rejects.toThrow(ComandoDivergenteError);
  });
});

describe('Story 3.1: Cloud Functions Callables de Decisão Pastoral', () => {
  it('obterFilaPastorLocal rejeita chamada não autenticada', async () => {
    const callable: any = obterFilaPastorLocal;
    await expect(callable.run({ auth: null, data: {} })).rejects.toThrow(
      'É necessário entrar na conta.',
    );
  });

  it('decidirFichaPastorLocal rejeita chamada não autenticada', async () => {
    const callable: any = decidirFichaPastorLocal;
    await expect(callable.run({ auth: null, data: {} })).rejects.toThrow(
      'É necessário entrar na conta.',
    );
  });
});
