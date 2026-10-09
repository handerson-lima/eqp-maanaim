import { describe, expect, it } from 'vitest';
import { derivarCapacidades } from '../src/domain/contextoAcesso.js';
import { obterContextoAcessoRepo } from '../src/repositories/contextoAcesso.js';

describe('Story 8.3: Domínio de Contexto de Acesso e Capacidades', () => {
  it('garante que voluntário simples possui apenas capacidade de voluntário', () => {
    const caps = derivarCapacidades({
      ehAdmin: false,
      ehCoord: false,
      temIgrejas: false,
      temEquipes: false,
    });
    expect(caps).toEqual(['voluntario']);
  });

  it('adiciona pastor_local quando o usuário possui igrejas sob seu pastoreio', () => {
    const caps = derivarCapacidades({
      ehAdmin: false,
      ehCoord: false,
      temIgrejas: true,
      temEquipes: false,
    });
    expect(caps).toContain('voluntario');
    expect(caps).toContain('pastor_local');
    expect(caps).not.toContain('responsavel_equipe');
  });

  it('adiciona responsavel_equipe quando o usuário possui equipes sob sua responsabilidade', () => {
    const caps = derivarCapacidades({
      ehAdmin: false,
      ehCoord: false,
      temIgrejas: false,
      temEquipes: true,
    });
    expect(caps).toContain('voluntario');
    expect(caps).toContain('responsavel_equipe');
    expect(caps).not.toContain('pastor_local');
  });

  it('suporta vínculos simultâneos de Pastor Local E Responsável de Equipe', () => {
    const caps = derivarCapacidades({
      ehAdmin: false,
      ehCoord: false,
      temIgrejas: true,
      temEquipes: true,
    });
    expect(caps).toContain('voluntario');
    expect(caps).toContain('pastor_local');
    expect(caps).toContain('responsavel_equipe');
    expect(caps).not.toContain('administrador');
  });

  it('suporta coordenador e administrador', () => {
    const caps = derivarCapacidades({
      ehAdmin: true,
      ehCoord: true,
      temIgrejas: false,
      temEquipes: false,
    });
    expect(caps).toContain('voluntario');
    expect(caps).toContain('coordenador');
    expect(caps).toContain('administrador');
  });
});

describe('Story 8.3: Repositório obterContextoAcessoRepo', () => {
  function criarMockDb(dados: {
    autoridadesAdministrativas?: Record<string, any>;
    igrejas?: Record<string, any>;
    equipes?: Record<string, any>;
    vinculosPastorIgreja?: Record<string, any>;
    vinculosResponsavelEquipe?: Record<string, any>;
    fichas?: Record<string, any>;
  }) {
    return {
      collection: (colName: string) => ({
        doc: (id: string) => ({
          get: async () => {
            const mapa = (dados as any)[colName] || {};
            const docData = mapa[id];
            return {
              id,
              exists: !!docData,
              data: () => docData,
            };
          },
        }),
        where: (campo: string, op: string, valor: any) => {
          const criarQuery = (filtros: Array<{ campo: string; op: string; valor: any }>) => ({
            where: (c: string, o: string, v: any) =>
              criarQuery([...filtros, { campo: c, op: o, valor: v }]),
            get: async () => {
              const mapa = (dados as any)[colName] || {};
              let list = Object.entries(mapa).map(([id, data]) => ({ id, data }));
              for (const f of filtros) {
                list = list.filter((it) => {
                  const val = (it.data as any)[f.campo];
                  if (f.op === '==') return val === f.valor;
                  return true;
                });
              }
              return {
                empty: list.length === 0,
                docs: list.map((it) => ({
                  id: it.id,
                  data: () => it.data,
                })),
              };
            },
          });
          return criarQuery([{ campo, op, valor }]);
        },
      }),
    } as any;
  }

  it('resolve contexto para voluntário simples sem vínculos pastorais ou administrativos', async () => {
    const db = criarMockDb({
      fichas: {
        'user-1': { estado: 'ATIVA', nomeCompleto: 'Irmão José' },
      },
    });

    const contexto = await obterContextoAcessoRepo(db, 'user-1', 'jose@example.com');

    expect(contexto.uid).toBe('user-1');
    expect(contexto.email).toBe('jose@example.com');
    expect(contexto.capacidades).toEqual(['voluntario']);
    expect(contexto.ehVoluntario).toBe(true);
    expect(contexto.ehPastorLocal).toBe(false);
    expect(contexto.ehResponsavelEquipe).toBe(false);
    expect(contexto.ehAdministrador).toBe(false);
    expect(contexto.ehCoordenador).toBe(false);
    expect(contexto.igrejas).toEqual([]);
    expect(contexto.equipes).toEqual([]);
    expect(contexto.estadoFicha).toBe('ATIVA');
  });

  it('resolve contexto para Pastor Local exclusivo com igreja sob sua responsabilidade', async () => {
    const db = criarMockDb({
      igrejas: {
        'ig-central': {
          nome: 'Maanaim Central',
          codigo: 'IG-01',
          pastorLocalVigentePessoaId: 'pastor-1',
          ativo: true,
        },
      },
      fichas: {
        'pastor-1': { estado: 'ATIVA' },
      },
    });

    const contexto = await obterContextoAcessoRepo(db, 'pastor-1', 'pastor@example.com');

    expect(contexto.capacidades).toContain('voluntario');
    expect(contexto.capacidades).toContain('pastor_local');
    expect(contexto.ehPastorLocal).toBe(true);
    expect(contexto.ehResponsavelEquipe).toBe(false);
    expect(contexto.igrejas).toHaveLength(1);
    expect(contexto.igrejas[0].id).toBe('ig-central');
    expect(contexto.igrejas[0].nome).toBe('Maanaim Central');
    expect(contexto.equipes).toHaveLength(0);
  });

  it('resolve contexto para Responsável de Equipe exclusivo', async () => {
    const db = criarMockDb({
      equipes: {
        'eq-louvor': {
          nome: 'Equipe de Louvor',
          responsavelVigentePessoaId: 'resp-1',
          ativo: true,
        },
      },
    });

    const contexto = await obterContextoAcessoRepo(db, 'resp-1', 'louvor@example.com');

    expect(contexto.capacidades).toContain('voluntario');
    expect(contexto.capacidades).toContain('responsavel_equipe');
    expect(contexto.ehPastorLocal).toBe(false);
    expect(contexto.ehResponsavelEquipe).toBe(true);
    expect(contexto.equipes).toHaveLength(1);
    expect(contexto.equipes[0].nome).toBe('Equipe de Louvor');
  });

  it('resolve contexto com múltiplos vínculos simultâneos (Pastor Local + Responsável de Equipe)', async () => {
    const db = criarMockDb({
      igrejas: {
        'ig-norte': {
          nome: 'Igreja Norte',
          pastorLocalVigentePessoaId: 'lider-1',
          ativo: true,
        },
      },
      equipes: {
        'eq-portaria': {
          nome: 'Portaria e Recepção',
          responsavelVigentePessoaId: 'lider-1',
          ativo: true,
        },
      },
    });

    const contexto = await obterContextoAcessoRepo(db, 'lider-1');

    expect(contexto.capacidades).toContain('voluntario');
    expect(contexto.capacidades).toContain('pastor_local');
    expect(contexto.capacidades).toContain('responsavel_equipe');
    expect(contexto.ehPastorLocal).toBe(true);
    expect(contexto.ehResponsavelEquipe).toBe(true);
    expect(contexto.igrejas).toHaveLength(1);
    expect(contexto.equipes).toHaveLength(1);
  });

  it('resolve contexto para Administrador com autoridadesAdministrativas ativa', async () => {
    const db = criarMockDb({
      autoridadesAdministrativas: {
        'admin-1': {
          ativa: true,
          papeis: ['ADMINISTRADOR'],
          coordenadorGeral: true,
        },
      },
    });

    const contexto = await obterContextoAcessoRepo(db, 'admin-1');

    expect(contexto.ehAdministrador).toBe(true);
    expect(contexto.ehCoordenador).toBe(true);
    expect(contexto.capacidades).toContain('administrador');
    expect(contexto.capacidades).toContain('coordenador');
  });

  it('remove capacidade imediatamente quando vínculo pastoral é revogado ou igreja inativada', async () => {
    // Igreja inativada (ativo: false)
    const db = criarMockDb({
      igrejas: {
        'ig-desativada': {
          nome: 'Igreja Fechada',
          pastorLocalVigentePessoaId: 'ex-pastor',
          ativo: false,
        },
      },
    });

    const contexto = await obterContextoAcessoRepo(db, 'ex-pastor');

    expect(contexto.ehPastorLocal).toBe(false);
    expect(contexto.capacidades).not.toContain('pastor_local');
    expect(contexto.igrejas).toHaveLength(0);
  });
});
