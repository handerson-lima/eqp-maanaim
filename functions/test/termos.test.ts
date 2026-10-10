import { describe, expect, it } from 'vitest';
import {
  calcularHashConteudo,
  calcularPayloadHash,
  validarPublicarTermo,
  TermoInvalidoError,
  TIPO_TERMO_PADRAO,
  TERMO_ID_PADRAO,
  type EntradaPublicarTermo,
} from '../src/domain/termos.js';

describe('domínio de termos', () => {
  const base = {
    commandId: 'c'.repeat(32),
    correlationId: 'corr-1',
    titulo: 'Termo de Adesão ao Serviço Voluntário Maanaim',
    conteudo: 'Este é o conteúdo integral do termo de adesão ao serviço voluntário do Maanaim, com todas as cláusulas e compromissos.',
    expectedVersion: 0,
  };

  it('valida entrada correta com defaults canônicos', () => {
    const entrada = validarPublicarTermo(base);
    expect(entrada.termoId).toBe(TERMO_ID_PADRAO);
    expect(entrada.tipoTermo).toBe(TIPO_TERMO_PADRAO);
    expect(entrada.titulo).toBe(base.titulo);
    expect(entrada.conteudo).toBe(base.conteudo);
    expect(entrada.expectedVersion).toBe(0);
    expect(entrada.payloadHash).toHaveLength(64);
    expect(entrada.hashConteudo).toHaveLength(64);
  });

  it('calcula o mesmo hash SHA-256 para mesmo conteúdo normalizado', () => {
    const hash1 = calcularHashConteudo('Título', 'Conteúdo canônico longo para validação de teste');
    const hash2 = calcularHashConteudo('  Título  ', '  Conteúdo canônico longo para validação de teste  ');
    expect(hash1).toBe(hash2);
    expect(hash1).toMatch(/^[a-f0-9]{64}$/);
  });

  it('calcula hash diferente para conteúdos divergentes', () => {
    const hash1 = calcularHashConteudo('Título', 'Conteúdo canônico longo para validação de teste 1');
    const hash2 = calcularHashConteudo('Título', 'Conteúdo canônico longo para validação de teste 2');
    expect(hash1).not.toBe(hash2);
  });

  it('rejeita título curto ou vazio', () => {
    expect(() => validarPublicarTermo({ ...base, titulo: 'ab' })).toThrow(TermoInvalidoError);
    expect(() => validarPublicarTermo({ ...base, titulo: '' })).toThrow(TermoInvalidoError);
    expect(() => validarPublicarTermo({ ...base, titulo: '   ' })).toThrow(TermoInvalidoError);
  });

  it('rejeita conteúdo menor que 20 caracteres', () => {
    expect(() => validarPublicarTermo({ ...base, conteudo: 'curto' })).toThrow(TermoInvalidoError);
    expect(() => validarPublicarTermo({ ...base, conteudo: '' })).toThrow(TermoInvalidoError);
  });

  it('rejeita commandId inválido ou ausente', () => {
    expect(() => validarPublicarTermo({ ...base, commandId: '' })).toThrow(TermoInvalidoError);
    expect(() => validarPublicarTermo({ ...base, commandId: 'curto' })).toThrow(TermoInvalidoError);
  });

  it('aceita expectedVersion positivo para novas versões', () => {
    const entrada = validarPublicarTermo({ ...base, expectedVersion: 1 });
    expect(entrada.expectedVersion).toBe(1);
  });

  it('calcula payloadHash determinístico', () => {
    const e1 = validarPublicarTermo(base);
    const e2 = validarPublicarTermo(base);
    expect(e1.payloadHash).toBe(e2.payloadHash);
  });
});

describe('Story 8.14: Repositório de Termos com U(V) e pendência operacional', () => {
  it('publica termo registrando snapshot U(V) com voluntários ativos e metadados imutáveis', async () => {
    const { publicarTermo } = await import('../src/repositories/termos.js');
    const entrada = validarPublicarTermo({
      commandId: 'cmd-publicar-1234567890',
      titulo: 'Termo Novo v1',
      conteudo: 'Conteúdo do termo com tamanho suficiente para aprovação.',
      expectedVersion: 0,
    });

    const operacoes: any[] = [];
    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id?: string) => ({
          col,
          id: id ?? 'id-auto-gerado',
          collection: (sub: string) => ({
            doc: (subId?: string) => ({ col: sub, id: subId ?? 'sub-auto-gerado' }),
          }),
        }),
        where: () => ({ isQuery: true }),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async (ref: any) => {
            if (ref.col === 'commands') return { exists: false };
            if (ref.col === 'autoridadesAdministrativas') {
              return { exists: true, data: () => ({ ativa: true, papel: 'ADMINISTRADOR' }) };
            }
            if (ref.col === 'termos') return { exists: false };
            if (ref.isQuery) {
              return {
                size: 3,
                docs: [{ id: 'f1' }, { id: 'f2' }, { id: 'f3' }],
              };
            }
            return { exists: false };
          },
          create: (ref: any, data: any) => operacoes.push({ tipo: 'create', ref, data }),
          set: (ref: any, data: any) => operacoes.push({ tipo: 'set', ref, data }),
          update: (ref: any, data: any) => operacoes.push({ tipo: 'update', ref, data }),
        };
        return fn(tx);
      },
    };

    const res = await publicarTermo(
      mockDb,
      {
        commandId: entrada.commandId,
        correlacaoId: 'corr-1',
        atorUid: 'admin-1',
        origem: 'teste',
      },
      entrada,
    );

    expect(res.repetido).toBe(false);
    expect(res.numeroVersao).toBe(1);
    expect(res.totalVoluntariosImpactados).toBe(3);

    // Valida que o snapshot U(V) foi persistido no create da versão
    const versaoOp = operacoes.find((o) => o.ref.col === 'versoes');
    expect(versaoOp).toBeDefined();
    expect(versaoOp.data.universoSnapshot).toBeDefined();
    expect(versaoOp.data.universoSnapshot.registrado).toBe(true);
    expect(versaoOp.data.universoSnapshot.totalAfetados).toBe(3);
    expect(versaoOp.data.universoSnapshot.fichasIds).toEqual(['f1', 'f2', 'f3']);
    expect(versaoOp.data.universoSnapshot.criterio).toBe('ESTADO_ATIVA_NA_PUBLICACAO');
  });

  it('consultarTermosRepo apura pendência operacional vigente e projeta aceites de U(V)', async () => {
    const { consultarTermosRepo } = await import('../src/repositories/termos.js');

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({
          col,
          id,
          get: async () => {
            if (col === 'autoridadesAdministrativas') {
              return { exists: true, data: () => ({ ativa: true, papel: 'ADMINISTRADOR' }) };
            }
            if (col === 'termos') {
              return {
                exists: true,
                id: 'termo-adesao-voluntariado',
                data: () => ({
                  tipoTermo: 'ADESAO_VOLUNTARIADO',
                  titulo: 'Termo Vigente',
                  versaoVigenteId: 'v-2',
                  versaoVigenteNumero: 2,
                  hashSha256: 'hash-v2',
                  totalVersoes: 2,
                  ativo: true,
                }),
              };
            }
            return { exists: false };
          },
          collection: (sub: string) => ({
            orderBy: () => ({
              get: async () => ({
                docs: [
                  {
                    id: 'v-2',
                    data: () => ({
                      numeroVersao: 2,
                      titulo: 'Termo v2',
                      conteudo: 'Conteúdo v2',
                      hashSha256: 'hash-v2',
                      publicadoEm: new Date('2026-10-10T12:00:00Z'),
                      universoSnapshot: {
                        registrado: true,
                        totalAfetados: 2,
                        fichasIds: ['vol-1', 'vol-2'],
                        criterio: 'ESTADO_ATIVA_NA_PUBLICACAO',
                      },
                    }),
                  },
                  {
                    id: 'v-1',
                    data: () => ({
                      numeroVersao: 1,
                      titulo: 'Termo v1 legado',
                      conteudo: 'Conteúdo v1 legado',
                      hashSha256: 'hash-v1',
                      publicadoEm: new Date('2026-09-01T12:00:00Z'),
                      // Legado: sem universoSnapshot
                    }),
                  },
                ],
              }),
            }),
            doc: (docId: string) => ({
              collection: (innerSub: string) => ({
                get: async () => {
                  if (docId === 'v-2') {
                    // vol-1 já aceitou v-2
                    return { docs: [{ id: 'vol-1' }] };
                  }
                  return { docs: [] };
                },
              }),
            }),
          }),
        }),
        where: (field: string, op: string, value: string) => ({
          get: async () => ({
            size: 3,
            docs: [
              { id: 'vol-1', data: () => ({ termoAceito: { versaoId: 'v-2' } }) },
              { id: 'vol-2', data: () => ({ termoAceito: { versaoId: 'v-1' } }) }, // Pendente na vigente
              { id: 'vol-3', data: () => ({ termoAceito: { versaoId: 'v-1' } }) }, // Pendente na vigente
            ],
          }),
        }),
      }),
    };

    const resultado = await consultarTermosRepo(mockDb, 'admin-uid');
    expect(resultado).not.toBeNull();
    expect(resultado!.versaoVigenteNumero).toBe(2);

    // Valida pendência operacional vigente
    expect(resultado!.pendenciaOperacional).toBeDefined();
    expect(resultado!.pendenciaOperacional!.totalAtivos).toBe(3);
    expect(resultado!.pendenciaOperacional!.pendentesVigente).toBe(2); // vol-2 e vol-3

    // Valida projeção da versão v2 com snapshot registrado
    const v2 = resultado!.versoes!.find((v) => v.numeroVersao === 2);
    expect(v2).toBeDefined();
    expect(v2!.universoSnapshot).toBeDefined();
    expect(v2!.universoSnapshot!.registrado).toBe(true);
    expect(v2!.universoSnapshot!.totalAfetados).toBe(2);
    expect(v2!.universoSnapshot!.aceitosCount).toBe(1); // vol-1
    expect(v2!.universoSnapshot!.pendentesCount).toBe(1); // vol-2

    // Valida versão legada v1: universo não registrado (não inventa zero!)
    const v1 = resultado!.versoes!.find((v) => v.numeroVersao === 1);
    expect(v1).toBeDefined();
    expect(v1!.universoSnapshot).toBeDefined();
    expect(v1!.universoSnapshot!.registrado).toBe(false);
  });
});

