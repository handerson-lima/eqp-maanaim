import { describe, expect, it } from 'vitest';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  DadosIncompletosError,
  EnvioInvalidoError,
  EquipeInativaError,
  FichaNaoEncontradaError,
  FichaNaoRascunhoError,
  IgrejaInativaError,
  PermissaoNegadaError,
  SemParticipacoesError,
  TermoNaoAceitoError,
  calcularPayloadHashEnviarFicha,
  validarEnviarFicha,
} from '../src/domain/enviarFicha.js';
import { enviarFichaAprovacaoRepo } from '../src/repositories/enviarFicha.js';
import { enviarFichaAprovacao } from '../src/commands/enviarFichaAprovacao.js';

describe('Story 2.4: Domínio de Envio de Ficha (enviarFicha.ts)', () => {
  const dadosValidos = {
    commandId: 'cmd-envio-1234567890',
    expectedVersion: 1,
  };

  it('valida payload correto e gera hash determinístico', () => {
    const entrada = validarEnviarFicha(dadosValidos);
    expect(entrada.commandId).toBe('cmd-envio-1234567890');
    expect(entrada.expectedVersion).toBe(1);
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);

    const hashCalculado = calcularPayloadHashEnviarFicha({ expectedVersion: 1 });
    expect(entrada.payloadHash).toBe(hashCalculado);
  });

  it('rejeita payload inválido ou sem commandId de tamanho mínimo', () => {
    expect(() => validarEnviarFicha(null)).toThrow(EnvioInvalidoError);
    expect(() => validarEnviarFicha({ commandId: 'curto' })).toThrow(EnvioInvalidoError);
    expect(() => validarEnviarFicha({ commandId: '' })).toThrow(EnvioInvalidoError);
  });

  it('rejeita correlationId inválido ou expectedVersion negativo', () => {
    expect(() =>
      validarEnviarFicha({ ...dadosValidos, correlationId: '   ' }),
    ).toThrow(EnvioInvalidoError);

    expect(() =>
      validarEnviarFicha({ ...dadosValidos, expectedVersion: -1 }),
    ).toThrow(EnvioInvalidoError);
  });
});

describe('Story 2.4: Repositório de Envio de Ficha (enviarFicha.ts)', () => {
  const uid = 'uid-voluntario-999';
  const entradaValida = validarEnviarFicha({
    commandId: 'cmd-envio-1234567890',
    expectedVersion: 2,
  });

  // CPF válido para testes: 52998224725
  const cpfValidoExemplo = '52998224725';

  function criarMockDb(cenario: {
    recibo?: any;
    ficha?: any;
    termo?: any;
    participacoes?: any[];
    equipes?: Record<string, any>;
    igrejas?: Record<string, any>;
  }) {
    const updates: Array<{ ref: any; data: any }> = [];
    const sets: Array<{ ref: any; data: any }> = [];
    const creates: Array<{ ref: any; data: any }> = [];

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id, ref: { col, id } }),
        where: (field: string, op: string, val: any) => ({
          col,
          field,
          val,
        }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (target: any) => {
            // Se for consulta where em participacoes
            if (target.col === 'participacoes' && target.field === 'fichaId') {
              const parts = cenario.participacoes ?? [];
              return {
                empty: parts.length === 0,
                docs: parts.map((p, idx) => ({
                  id: p.id ?? `part-${idx}`,
                  ref: { col: 'participacoes', id: p.id ?? `part-${idx}` },
                  data: () => p,
                })),
              };
            }

            const col = target.col;
            const id = target.id;

            if (col === 'commands') {
              return cenario.recibo
                ? { exists: true, data: () => cenario.recibo }
                : { exists: false, data: () => null };
            }

            if (col === 'fichas') {
              return cenario.ficha
                ? { exists: true, data: () => cenario.ficha }
                : { exists: false, data: () => null };
            }

            if (col === 'termos') {
              return cenario.termo
                ? { exists: true, data: () => cenario.termo }
                : { exists: false, data: () => null };
            }

            if (col === 'equipes') {
              const eq = cenario.equipes?.[id];
              return eq
                ? { exists: true, data: () => eq }
                : { exists: false, data: () => null };
            }

            if (col === 'igrejas') {
              const ig = cenario.igrejas?.[id];
              return ig
                ? { exists: true, data: () => ig }
                : { exists: false, data: () => null };
            }

            return { exists: false, data: () => null };
          },
          update: (ref: any, data: any) => {
            updates.push({ ref, data });
          },
          set: (ref: any, data: any) => {
            sets.push({ ref, data });
          },
          create: (ref: any, data: any) => {
            creates.push({ ref, data });
          },
        };

        const res = await fn(tx);
        return res;
      },
      _updates: updates,
      _sets: sets,
      _creates: creates,
    };

    return mockDb;
  }

  const baseFicha = {
    nomeCompleto: 'Voluntário da Silva',
    profissao: 'Engenheiro',
    cpf: cpfValidoExemplo,
    igrejaId: 'igreja-central',
    estado: 'RASCUNHO',
    versao: 2,
    termoAceito: {
      termoId: 'adesao-voluntariado',
      versaoId: 'versao-v1',
      hashSha256: 'a'.repeat(64),
    },
  };

  const baseTermo = {
    ativo: true,
    versaoVigenteId: 'versao-v1',
    hashSha256: 'a'.repeat(64),
  };

  const baseParticipacoes = [
    { id: 'part-1', equipeId: 'equipe-musica', nomeEquipe: 'Música', estado: 'RASCUNHO' },
  ];

  const baseEquipes = {
    'equipe-musica': { ativo: true, nome: 'Música' },
  };

  const baseIgrejas = {
    'igreja-central': {
      ativo: true,
      nome: 'Igreja Central',
      pastorLocalVigentePessoaId: 'pastor-joao',
    },
  };

  it('falha se a ficha não existir', async () => {
    const db = criarMockDb({ ficha: null });
    await expect(
      enviarFichaAprovacaoRepo(db, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(FichaNaoEncontradaError);
  });

  it('falha se a ficha não estiver em RASCUNHO', async () => {
    const db = criarMockDb({
      ficha: { ...baseFicha, estado: 'AGUARDANDO_PASTOR_LOCAL' },
    });
    await expect(
      enviarFichaAprovacaoRepo(db, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(FichaNaoRascunhoError);
  });

  it('falha se houver conflito de versão da ficha', async () => {
    const db = criarMockDb({
      ficha: { ...baseFicha, versao: 3 }, // esperado era 2
    });
    await expect(
      enviarFichaAprovacaoRepo(db, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(ConflitoVersaoError);
  });

  it('falha se campos obrigatórios da ficha estiverem incompletos ou CPF inválido', async () => {
    const db1 = criarMockDb({
      ficha: { ...baseFicha, nomeCompleto: 'AB' },
    });
    await expect(
      enviarFichaAprovacaoRepo(db1, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(DadosIncompletosError);

    const db2 = criarMockDb({
      ficha: { ...baseFicha, cpf: '11111111111' }, // CPF inválido
    });
    await expect(
      enviarFichaAprovacaoRepo(db2, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(DadosIncompletosError);
  });

  it('falha se o termo vigente não tiver sido aceito ou divergir da versão ativa', async () => {
    const db1 = criarMockDb({
      ficha: { ...baseFicha, termoAceito: null },
    });
    await expect(
      enviarFichaAprovacaoRepo(db1, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(TermoNaoAceitoError);

    // Termo no catálogo com versão vigente diferente
    const db2 = criarMockDb({
      ficha: baseFicha,
      termo: { ...baseTermo, versaoVigenteId: 'versao-v2' },
    });
    await expect(
      enviarFichaAprovacaoRepo(db2, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(TermoNaoAceitoError);
  });

  it('falha se não houver participações cadastradas', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      termo: baseTermo,
      participacoes: [],
    });
    await expect(
      enviarFichaAprovacaoRepo(db, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(SemParticipacoesError);
  });

  it('falha se alguma equipe selecionada estiver inativa no catálogo', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      termo: baseTermo,
      participacoes: baseParticipacoes,
      equipes: {
        'equipe-musica': { ativo: false, nome: 'Música' },
      },
    });
    await expect(
      enviarFichaAprovacaoRepo(db, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(EquipeInativaError);
  });

  it('falha se a igreja estiver inativa ou inexistente', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      termo: baseTermo,
      participacoes: baseParticipacoes,
      equipes: baseEquipes,
      igrejas: {
        'igreja-central': { ativo: false, nome: 'Igreja Central' },
      },
    });
    await expect(
      enviarFichaAprovacaoRepo(db, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(IgrejaInativaError);
  });

  it('envia com sucesso, transiciona agregados, projeta fila, cria recibo e auditoria', async () => {
    const db = criarMockDb({
      ficha: baseFicha,
      termo: baseTermo,
      participacoes: baseParticipacoes,
      equipes: baseEquipes,
      igrejas: baseIgrejas,
    });

    const resultado = await enviarFichaAprovacaoRepo(
      db,
      { commandId: entradaValida.commandId, uid },
      entradaValida,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.repetido).toBe(false);
    expect(resultado.estado).toBe('AGUARDANDO_PASTOR_LOCAL');
    expect(resultado.versao).toBe(3); // 2 + 1
    expect(resultado.proximaAcao).toBe('Aguardando avaliação do Pastor Local');
    expect(resultado.igrejaId).toBe('igreja-central');

    // Verifica update da ficha
    const updateFicha = db._updates.find((u: any) => u.ref.col === 'fichas');
    expect(updateFicha).toBeDefined();
    expect(updateFicha.data.estado).toBe('AGUARDANDO_PASTOR_LOCAL');
    expect(updateFicha.data.versao).toBe(3);

    // Verifica update da participação
    const updatePart = db._updates.find((u: any) => u.ref.col === 'participacoes');
    expect(updatePart).toBeDefined();
    expect(updatePart.data.estado).toBe('AGUARDANDO_PASTOR_LOCAL');

    // Verifica projeção da fila
    const setFila = db._sets.find((s: any) => s.ref.col === 'filaPendencias');
    expect(setFila).toBeDefined();
    expect(setFila.data.igrejaId).toBe('igreja-central');
    expect(setFila.data.pastorLocalPessoaId).toBe('pastor-joao');
    expect(setFila.data.estado).toBe('AGUARDANDO_PASTOR_LOCAL');
    expect(setFila.data.equipes).toEqual([
      { equipeId: 'equipe-musica', nomeEquipe: 'Música' },
    ]);

    // Verifica recibo em commands
    const createRecibo = db._creates.find((c: any) => c.ref.col === 'commands');
    expect(createRecibo).toBeDefined();
    expect(createRecibo.data.acao).toBe('ENVIAR_FICHA_APROVACAO');
    expect(createRecibo.data.status).toBe('COMPLETO');

    // Verifica outbox de auditoria sem PII
    const createAuditoria = db._creates.find((c: any) => c.ref.col === 'auditOutbox');
    expect(createAuditoria).toBeDefined();
    expect(createAuditoria.data.acao).toBe('FICHA_ENVIADA_APROVACAO');
    expect(createAuditoria.data.antes).toEqual({ estado: 'RASCUNHO' });
    expect(createAuditoria.data.depois).toEqual({ estado: 'AGUARDANDO_PASTOR_LOCAL' });
    expect(createAuditoria.data).not.toHaveProperty('cpf');
    expect(createAuditoria.data).not.toHaveProperty('nomeCompleto');
  });

  it('garante idempotência estrita ao reenviar com o mesmo commandId e payloadHash', async () => {
    const db = criarMockDb({
      recibo: {
        uid,
        payloadHash: entradaValida.payloadHash,
        resultado: {
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          versao: 3,
          proximaAcao: 'Aguardando avaliação do Pastor Local',
          igrejaId: 'igreja-central',
        },
        criadoEm: '2026-10-06T12:00:00Z',
      },
    });

    const resultado = await enviarFichaAprovacaoRepo(
      db,
      { commandId: entradaValida.commandId, uid },
      entradaValida,
    );

    expect(resultado.repetido).toBe(true);
    expect(resultado.estado).toBe('AGUARDANDO_PASTOR_LOCAL');
    expect(resultado.versao).toBe(3);
    expect(db._updates.length).toBe(0);
    expect(db._creates.length).toBe(0);
  });

  it('rejeita reenvio com dados divergentes no mesmo commandId', async () => {
    const db = criarMockDb({
      recibo: {
        uid,
        payloadHash: 'hash-completamente-diferente',
      },
    });

    await expect(
      enviarFichaAprovacaoRepo(db, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(ComandoDivergenteError);
  });

  it('rejeita reenvio de commandId pertencente a outro voluntário', async () => {
    const db = criarMockDb({
      recibo: {
        uid: 'outro-voluntario',
        payloadHash: entradaValida.payloadHash,
      },
    });

    await expect(
      enviarFichaAprovacaoRepo(db, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(PermissaoNegadaError);
  });
});

describe('Story 2.4: Callable enviarFichaAprovacao', () => {
  it('rejeita chamadas não autenticadas', async () => {
    await expect(
      (enviarFichaAprovacao as any).run({
        auth: null,
        data: { commandId: 'cmd-envio-1234567890' },
      }),
    ).rejects.toThrow('É necessário entrar na conta.');
  });

  it('rejeita chamadas em nome de outro voluntário', async () => {
    await expect(
      (enviarFichaAprovacao as any).run({
        auth: { uid: 'voluntario-a' },
        data: { commandId: 'cmd-envio-1234567890', uid: 'voluntario-b' },
      }),
    ).rejects.toThrow('Não é permitido enviar a ficha em nome de outro voluntário.');
  });
});
