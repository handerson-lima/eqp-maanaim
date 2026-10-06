import { describe, expect, it } from 'vitest';
import {
  ComandoDivergenteError,
  DeclaracaoNaoInformadaError,
  EquipesNaoSelecionadasError,
  FichaNaoEditavelError,
  FichaNaoEncontradaError,
  PermissaoNegadaError,
  TERMO_ID_PADRAO,
  TermoInvalidoError,
  TermoNaoVigenteError,
  calcularPayloadHashAceite,
  validarAceitarTermoVigente,
} from '../src/domain/termos.js';
import {
  aceitarTermoVigenteRepo,
  obterHistoricoAceitesRepo,
} from '../src/repositories/termos.js';
import { aceitarTermoVigente } from '../src/commands/aceitarTermoVigente.js';
import { obterHistoricoAceites } from '../src/commands/obterHistoricoAceites.js';

describe('Story 2.3: Domínio de Aceite de Termo (termos.ts)', () => {
  const dadosValidos = {
    commandId: 'cmd-aceite-1234567890',
    versaoId: 'versao-v1-id',
    hashSha256: 'a'.repeat(64),
    declaracaoLidoEConcordo: true,
  };

  it('valida entrada correta com termoId padrão e gera payloadHash determinístico', () => {
    const entrada = validarAceitarTermoVigente(dadosValidos);
    expect(entrada.commandId).toBe(dadosValidos.commandId);
    expect(entrada.termoId).toBe(TERMO_ID_PADRAO);
    expect(entrada.versaoId).toBe(dadosValidos.versaoId);
    expect(entrada.hashSha256).toBe(dadosValidos.hashSha256);
    expect(entrada.declaracaoLidoEConcordo).toBe(true);
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it('permite customizar termoId explicitamente', () => {
    const entrada = validarAceitarTermoVigente({
      ...dadosValidos,
      termoId: 'termo-especial',
    });
    expect(entrada.termoId).toBe('termo-especial');
  });

  it('calcula o mesmo hash para entradas idênticas', () => {
    const hash1 = calcularPayloadHashAceite(dadosValidos);
    const hash2 = calcularPayloadHashAceite(dadosValidos);
    expect(hash1).toBe(hash2);
  });

  it('rejeita commandId ausente ou com menos de 16 caracteres', () => {
    expect(() =>
      validarAceitarTermoVigente({ ...dadosValidos, commandId: 'curto' }),
    ).toThrow(TermoInvalidoError);

    expect(() =>
      validarAceitarTermoVigente({ ...dadosValidos, commandId: '' }),
    ).toThrow(TermoInvalidoError);
  });

  it('rejeita versaoId ausente', () => {
    expect(() =>
      validarAceitarTermoVigente({ ...dadosValidos, versaoId: '' }),
    ).toThrow(TermoInvalidoError);
  });

  it('rejeita hashSha256 ausente ou menor que 32 caracteres', () => {
    expect(() =>
      validarAceitarTermoVigente({ ...dadosValidos, hashSha256: 'invalido' }),
    ).toThrow(TermoInvalidoError);
  });

  it('rejeita se declaracaoLidoEConcordo não for true', () => {
    expect(() =>
      validarAceitarTermoVigente({ ...dadosValidos, declaracaoLidoEConcordo: false }),
    ).toThrow(DeclaracaoNaoInformadaError);

    expect(() =>
      validarAceitarTermoVigente({ ...dadosValidos, declaracaoLidoEConcordo: undefined }),
    ).toThrow(DeclaracaoNaoInformadaError);
  });
});

describe('Story 2.3: Repositório de Aceite de Termo (termos.ts)', () => {
  const entradaValida = validarAceitarTermoVigente({
    commandId: 'cmd-aceite-1234567890',
    versaoId: 'versao-v1',
    hashSha256: 'b'.repeat(64),
    declaracaoLidoEConcordo: true,
  });

  const uid = 'uid-voluntario-123';

  it('falha com FichaNaoEncontradaError se a ficha permanente não existir', async () => {
    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'fichas') return { exists: false };
            return { exists: false };
          },
        };
        return fn(tx);
      },
    };

    await expect(
      aceitarTermoVigenteRepo(mockDb, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(FichaNaoEncontradaError);
  });

  it('falha com FichaNaoEditavelError se a ficha não estiver em RASCUNHO', async () => {
    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'fichas') {
              return {
                exists: true,
                data: () => ({ id: uid, estado: 'AGUARDANDO_PASTOR_LOCAL' }),
              };
            }
            return { exists: false };
          },
        };
        return fn(tx);
      },
    };

    await expect(
      aceitarTermoVigenteRepo(mockDb, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(FichaNaoEditavelError);
  });

  it('falha com EquipesNaoSelecionadasError se não houver equipes associadas à ficha no rascunho', async () => {
    let filtroCampo: string | null = null;
    let filtroValor: string | null = null;

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
        where: (field: string, op: string, value: any) => {
          filtroCampo = field;
          filtroValor = value;
          return { col, field, op, value, isQuery: true };
        },
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'fichas') return { exists: true, data: () => ({ id: uid, estado: 'RASCUNHO' }) };
            if (ref.col === 'participacoes') {
              // Verifica se filtrou de fato pelo uid correto
              if (ref.field === 'fichaId' && ref.value === uid) {
                return { empty: true, docs: [] };
              }
              return { empty: false, docs: [{ id: 'outra-ficha' }] };
            }
            return { exists: false };
          },
        };
        return fn(tx);
      },
    };

    await expect(
      aceitarTermoVigenteRepo(mockDb, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(EquipesNaoSelecionadasError);

    expect(filtroCampo).toBe('fichaId');
    expect(filtroValor).toBe(uid);
  });

  it('falha com TermoNaoVigenteError se o termo não estiver ativo ou não possuir versão vigente', async () => {
    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
        where: () => ({ get: async () => ({ empty: false, docs: [{ id: 'p1' }] }) }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'fichas') return { exists: true, data: () => ({ id: uid }) };
            if (ref.col === 'termos') return { exists: true, data: () => ({ ativo: false }) };
            return { exists: false };
          },
        };
        return fn(tx);
      },
    };

    await expect(
      aceitarTermoVigenteRepo(mockDb, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(TermoNaoVigenteError);
  });

  it('falha com TermoNaoVigenteError se o cliente enviar versaoId que não é a vigente', async () => {
    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
        where: () => ({ get: async () => ({ empty: false, docs: [{ id: 'p1' }] }) }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'fichas') return { exists: true, data: () => ({ id: uid }) };
            if (ref.col === 'termos') {
              return {
                exists: true,
                data: () => ({
                  ativo: true,
                  versaoVigenteId: 'versao-v2-diferente',
                  versaoVigenteNumero: 2,
                }),
              };
            }
            return { exists: false };
          },
        };
        return fn(tx);
      },
    };

    await expect(
      aceitarTermoVigenteRepo(mockDb, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(TermoNaoVigenteError);
  });

  it('falha com TermoNaoVigenteError se o hashSha256 divergir do hash oficial da versão vigente', async () => {
    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({
          col,
          id,
          collection: (sub: string) => ({
            doc: (subId: string) => ({ col: sub, id: subId }),
          }),
        }),
        where: () => ({ get: async () => ({ empty: false, docs: [{ id: 'p1' }] }) }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'fichas') return { exists: true, data: () => ({ id: uid }) };
            if (ref.col === 'termos') {
              return {
                exists: true,
                data: () => ({
                  ativo: true,
                  versaoVigenteId: 'versao-v1',
                  versaoVigenteNumero: 1,
                }),
              };
            }
            if (ref.col === 'versoes') {
              return {
                exists: true,
                data: () => ({
                  numeroVersao: 1,
                  hashSha256: 'outro-hash-oficial'.padEnd(64, '0'),
                  titulo: 'Termo Oficial',
                }),
              };
            }
            return { exists: false };
          },
        };
        return fn(tx);
      },
    };

    await expect(
      aceitarTermoVigenteRepo(mockDb, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(TermoNaoVigenteError);
  });

  it('persiste evidência imutável, atualiza projeção na ficha, recibo e auditoria', async () => {
    const operacoes: any[] = [];
    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({
          col,
          id,
          collection: (sub: string) => ({
            doc: (subId: string) => ({ col: sub, id: subId, parentId: id }),
          }),
        }),
        where: () => ({ get: async () => ({ empty: false, docs: [{ id: 'p1' }] }) }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'fichas') return { exists: true, data: () => ({ id: uid }) };
            if (ref.col === 'termos') {
              return {
                exists: true,
                data: () => ({
                  ativo: true,
                  versaoVigenteId: 'versao-v1',
                  versaoVigenteNumero: 1,
                }),
              };
            }
            if (ref.col === 'versoes') {
              return {
                exists: true,
                data: () => ({
                  numeroVersao: 1,
                  hashSha256: entradaValida.hashSha256,
                  titulo: 'Termo de Adesão ao Serviço Voluntário',
                }),
              };
            }
            return { exists: false };
          },
          set: (ref: any, data: any) => operacoes.push({ tipo: 'set', ref, data }),
          update: (ref: any, data: any) => operacoes.push({ tipo: 'update', ref, data }),
        };
        return fn(tx);
      },
    };

    const resultado = await aceitarTermoVigenteRepo(
      mockDb,
      { commandId: entradaValida.commandId, uid },
      entradaValida,
    );

    expect(resultado.repetido).toBe(false);
    expect(resultado.id).toBe('versao-v1');
    expect(resultado.versaoId).toBe('versao-v1');
    expect(resultado.numeroVersao).toBe(1);
    expect(resultado.hashSha256).toBe(entradaValida.hashSha256);
    expect(resultado.declaracaoLidoEConcordo).toBe(true);

    // Evidência de aceite imutável na subcoleção da ficha
    const aceiteOp = operacoes.find((o) => o.ref.col === 'aceites');
    expect(aceiteOp).toBeDefined();
    expect(aceiteOp.data.id).toBe('versao-v1');
    expect(aceiteOp.data.imutavel).toBe(true);

    // Atualização da projeção termoAceito na ficha
    const fichaOp = operacoes.find((o) => o.ref.col === 'fichas');
    expect(fichaOp).toBeDefined();
    expect(fichaOp.data.termoAceito.versaoId).toBe('versao-v1');

    // Recibo em commands
    const reciboOp = operacoes.find((o) => o.ref.col === 'commands');
    expect(reciboOp).toBeDefined();
    expect(reciboOp.data.action).toBe('ACEITAR_TERMO_VIGENTE');
    expect(reciboOp.data.estado).toBe('COMPLETO');

    // Auditoria em auditOutbox
    const auditOp = operacoes.find((o) => o.ref.col === 'auditOutbox');
    expect(auditOp).toBeDefined();
    expect(auditOp.data.action).toBe('ACEITE_TERMO_REGISTRADO');
  });

  it('retorna resultado idempotente para o mesmo commandId com payload idêntico', async () => {
    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') {
              return {
                exists: true,
                data: () => ({
                  uid,
                  action: 'ACEITAR_TERMO_VIGENTE',
                  estado: 'COMPLETO',
                  payloadHash: entradaValida.payloadHash,
                  aceiteId: 'versao-v1',
                  termoId: entradaValida.termoId,
                  versaoId: 'versao-v1',
                  numeroVersao: 1,
                  hashSha256: entradaValida.hashSha256,
                  titulo: 'Termo de Adesão',
                  criadoEm: new Date('2026-10-06T12:00:00Z'),
                }),
              };
            }
            return { exists: false };
          },
        };
        return fn(tx);
      },
    };

    const resultado = await aceitarTermoVigenteRepo(
      mockDb,
      { commandId: entradaValida.commandId, uid },
      entradaValida,
    );

    expect(resultado.repetido).toBe(true);
    expect(resultado.versaoId).toBe('versao-v1');
    expect(resultado.numeroVersao).toBe(1);
  });

  it('rejeita com ComandoDivergenteError se commandId já existir com payload diferente', async () => {
    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({ col, id }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') {
              return {
                exists: true,
                data: () => ({
                  uid,
                  payloadHash: 'hash-divergente-diferente',
                }),
              };
            }
            return { exists: false };
          },
        };
        return fn(tx);
      },
    };

    await expect(
      aceitarTermoVigenteRepo(mockDb, { commandId: entradaValida.commandId, uid }, entradaValida),
    ).rejects.toThrow(ComandoDivergenteError);
  });

  it('obterHistoricoAceitesRepo lista comprovantes ordenados por data', async () => {
    const docs = [
      {
        id: 'versao-v2',
        data: () => ({
          uid,
          fichaId: uid,
          termoId: TERMO_ID_PADRAO,
          versaoId: 'versao-v2',
          numeroVersao: 2,
          hashSha256: 'hash-v2'.padEnd(64, '0'),
          titulo: 'Termo v2',
          declaracaoLidoEConcordo: true,
          aceitoEm: new Date('2026-10-06T15:00:00Z'),
          commandId: 'cmd-2',
        }),
      },
      {
        id: 'versao-v1',
        data: () => ({
          uid,
          fichaId: uid,
          termoId: TERMO_ID_PADRAO,
          versaoId: 'versao-v1',
          numeroVersao: 1,
          hashSha256: 'hash-v1'.padEnd(64, '0'),
          titulo: 'Termo v1',
          declaracaoLidoEConcordo: true,
          aceitoEm: new Date('2026-10-01T10:00:00Z'),
          commandId: 'cmd-1',
        }),
      },
    ];

    const mockDb: any = {
      collection: () => ({
        doc: () => ({
          collection: () => ({
            orderBy: () => ({
              get: async () => ({ docs }),
            }),
          }),
        }),
      }),
    };

    const historico = await obterHistoricoAceitesRepo(mockDb, uid);
    expect(historico).toHaveLength(2);
    expect(historico[0].versaoId).toBe('versao-v2');
    expect(historico[0].numeroVersao).toBe(2);
    expect(historico[1].versaoId).toBe('versao-v1');
    expect(historico[1].numeroVersao).toBe(1);
  });
});

describe('Story 2.3: Callables aceitarTermoVigente e obterHistoricoAceites', () => {
  it('aceitarTermoVigente rejeita usuário não autenticado', async () => {
    const req: any = { auth: null, data: {} };
    await expect(aceitarTermoVigente.run(req)).rejects.toMatchObject({
      code: 'unauthenticated',
    });
  });

  it('aceitarTermoVigente rejeita personificação de outro voluntário', async () => {
    const req: any = {
      auth: { uid: 'user-1' },
      data: { uid: 'user-2' },
    };
    await expect(aceitarTermoVigente.run(req)).rejects.toMatchObject({
      code: 'permission-denied',
    });
  });

  it('obterHistoricoAceites rejeita usuário não autenticado', async () => {
    const req: any = { auth: null, data: {} };
    await expect(obterHistoricoAceites.run(req)).rejects.toMatchObject({
      code: 'unauthenticated',
    });
  });
});
