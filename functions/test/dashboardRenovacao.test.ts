import { describe, expect, it } from 'vitest';
import {
  ItemRenovacaoCoordenador,
  ItemRenovacaoPastor,
  ItemRenovacaoResponsavel,
  ItemRenovacaoVoluntario,
  MetricasRenovacaoCoordenador,
  MetricasRenovacaoPastor,
  MetricasRenovacaoResponsavel,
  MetricasRenovacaoVoluntario,
  ParametroInvalidoDashboardError,
  PermissaoNegadaDashboardError,
  ResultadoDashboardRenovacao,
  validarEntradaDashboard,
} from '../src/domain/dashboardRenovacao.js';
import { obterDashboardRenovacaoRepo } from '../src/repositories/dashboardRenovacao.js';

describe('Story 5.4: Domínio de Dashboard de Renovação', () => {
  it('valida parâmetros padrão e paginação segura', () => {
    const res = validarEntradaDashboard({});
    expect(res.limite).toBe(20);
    expect(res.pagina).toBe(1);
    expect(res.papelDesejado).toBeUndefined();
  });

  it('normaliza papel e filtros válidos', () => {
    const res = validarEntradaDashboard({
      papelDesejado: 'pastor_local',
      igrejaId: 'ig-123',
      equipeId: 'eq-456',
      estadoRenovacao: 'pendente_pastor',
      anoVigencia: 2026,
      limite: 15,
      pagina: 2,
    });
    expect(res.papelDesejado).toBe('PASTOR_LOCAL');
    expect(res.igrejaId).toBe('ig-123');
    expect(res.equipeId).toBe('eq-456');
    expect(res.estadoRenovacao).toBe('PENDENTE_PASTOR');
    expect(res.anoVigencia).toBe(2026);
    expect(res.limite).toBe(15);
    expect(res.pagina).toBe(2);
  });

  it('rejeita papel inexistente', () => {
    expect(() =>
      validarEntradaDashboard({ papelDesejado: 'SUPER_USER' }),
    ).toThrow(ParametroInvalidoDashboardError);
  });

  it('rejeita ano de vigência fora da faixa razoável', () => {
    expect(() =>
      validarEntradaDashboard({ anoVigencia: 1999 }),
    ).toThrow(ParametroInvalidoDashboardError);
  });
});

describe('Story 5.4: Repositório de Dashboard de Renovação por Papel', () => {
  function criarMockDb(dados: {
    autoridades?: Record<string, any>;
    autoridadesAdministrativas?: Record<string, any>;
    igrejas?: Record<string, any>;
    equipes?: Record<string, any>;
    vinculosPastor?: Record<string, any>;
    vinculosResp?: Record<string, any>;
    fichas?: Record<string, any>;
    participacoes?: Record<string, any>;
    ciclos?: Record<string, any>;
  }) {
    const mockDb: any = {
      collection: (colName: string) => {
        return {
          doc: (id: string) => ({
            get: async () => {
              const mapa =
                colName === 'autoridadesAdministrativas'
                  ? dados.autoridadesAdministrativas || dados.autoridades || {}
                  : (dados as any)[colName] || {};
              const docData = mapa[id];
              return {
                id,
                exists: !!docData,
                data: () => docData,
              };
            },
          }),
          where: (campo: string, op: string, valor: any) => {
            const filtrar = (itens: Array<{ id: string; data: any }>) => {
              return itens.filter((it) => {
                const val = it.data[campo];
                if (op === '==') return val === valor;
                if (op === 'in') return Array.isArray(valor) && valor.includes(val);
                return true;
              });
            };

            const criarQuery = (filtros: Array<{ campo: string; op: string; valor: any }>) => ({
              where: (c: string, o: string, v: any) =>
                criarQuery([...filtros, { campo: c, op: o, valor: v }]),
              limit: (n: number) => ({
                get: async () => {
                  const mapa = (dados as any)[colName] || {};
                  let list = Object.entries(mapa).map(([id, data]) => ({ id, data }));
                  for (const f of filtros) {
                    list = list.filter((it) => {
                      const val = (it.data as any)[f.campo];
                      if (f.op === '==') return val === f.valor;
                      if (f.op === 'in') return Array.isArray(f.valor) && f.valor.includes(val);
                      return true;
                    });
                  }
                  const sliced = list.slice(0, n);
                  return {
                    empty: sliced.length === 0,
                    docs: sliced.map((it) => ({
                      id: it.id,
                      data: () => it.data,
                    })),
                  };
                },
              }),
              get: async () => {
                const mapa = (dados as any)[colName] || {};
                let list = Object.entries(mapa).map(([id, data]) => ({ id, data }));
                for (const f of filtros) {
                  list = list.filter((it) => {
                    const val = (it.data as any)[f.campo];
                    if (f.op === '==') return val === f.valor;
                    if (f.op === 'in') return Array.isArray(f.valor) && f.valor.includes(val);
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
          get: async () => {
            const mapa = (dados as any)[colName] || {};
            const docs = Object.entries(mapa).map(([id, data]) => ({
              id,
              data: () => data,
            }));
            return {
              empty: docs.length === 0,
              docs,
            };
          },
        };
      },
    };
    return mockDb;
  }

  // -------------------------------------------------------------
  // Teste 1: Dashboard do Voluntário
  // -------------------------------------------------------------
  it('Voluntário: visualiza apenas suas participações, validade e situação do ciclo anual', async () => {
    const agora = new Date();
    const em20Dias = new Date(agora.getTime() + 20 * 24 * 60 * 60 * 1000).toISOString();
    const em80Dias = new Date(agora.getTime() + 80 * 24 * 60 * 60 * 1000).toISOString();

    const mockDb = criarMockDb({
      autoridades: {},
      equipes: {
        'eq-louvor': { nome: 'Louvor', ativo: true },
        'eq-som': { nome: 'Sonoplastia', ativo: true },
      },
      participacoes: {
        'part-01': {
          fichaId: 'vol-123',
          equipeId: 'eq-louvor',
          estado: 'ATIVA',
          vigenciaInicio: new Date(agora.getTime() - 345 * 24 * 60 * 60 * 1000).toISOString(),
          vigenciaFim: em20Dias,
          anoVigencia: 2026,
          cicloAtualId: null,
        },
        'part-02': {
          fichaId: 'vol-123',
          equipeId: 'eq-som',
          estado: 'ATIVA',
          vigenciaInicio: new Date(agora.getTime() - 100 * 24 * 60 * 60 * 1000).toISOString(),
          vigenciaFim: em80Dias,
          anoVigencia: 2026,
          cicloAtualId: null,
        },
        'part-outro': {
          fichaId: 'outro-voluntario',
          equipeId: 'eq-louvor',
          estado: 'ATIVA',
          vigenciaFim: em20Dias,
        },
      },
      ciclos: {},
    });

    const resultado = (await obterDashboardRenovacaoRepo(mockDb, 'vol-123', {
      papelDesejado: 'VOLUNTARIO',
    })) as ResultadoDashboardRenovacao<MetricasRenovacaoVoluntario, ItemRenovacaoVoluntario>;

    expect(resultado.papelResolvido).toBe('VOLUNTARIO');
    expect(resultado.metricas.totalParticipacoesAtivas).toBe(2);
    expect(resultado.metricas.emJanelaRenovacao).toBe(1); // apenas a de 20 dias está < 60d
    expect(resultado.metricas.pendentesManifestacao).toBe(1);
    expect(resultado.itens).toHaveLength(2);

    const itemLouvor = resultado.itens.find((i) => i.equipeId === 'eq-louvor')!;
    expect(itemLouvor.podeManifestar).toBe(true);
    expect(itemLouvor.emJanelaRenovacao).toBe(true);
    expect(itemLouvor.situacaoVigencia).toBe('RENOVACAO_IMINENTE_30D');

    const itemSom = resultado.itens.find((i) => i.equipeId === 'eq-som')!;
    expect(itemSom.podeManifestar).toBe(false);
    expect(itemSom.emJanelaRenovacao).toBe(false);
    expect(itemSom.situacaoVigencia).toBe('VIGENTE');
  });

  // -------------------------------------------------------------
  // Teste 2: Dashboard do Pastor Local
  // -------------------------------------------------------------
  it('Pastor Local: visualiza exclusivamente igrejas sob seu escopo com métricas e itens', async () => {
    const agora = new Date();
    const em15Dias = new Date(agora.getTime() + 15 * 24 * 60 * 60 * 1000).toISOString();

    const mockDb = criarMockDb({
      igrejas: {
        'ig-central': {
          nome: 'Igreja Central',
          pastorLocalVigentePessoaId: 'pastor-01',
          ativo: true,
        },
        'ig-norte': {
          nome: 'Igreja Norte',
          pastorLocalVigentePessoaId: 'outro-pastor',
          ativo: true,
        },
      },
      equipes: {
        'eq-portaria': { nome: 'Portaria', ativo: true },
      },
      fichas: {
        'f-vol-1': {
          nomeCompleto: 'João Silva',
          igrejaId: 'ig-central',
          estado: 'ATIVA',
        },
        'f-vol-2': {
          nomeCompleto: 'Carlos Santos',
          igrejaId: 'ig-norte',
          estado: 'ATIVA',
        },
      },
      participacoes: {
        'p-01': {
          fichaId: 'f-vol-1',
          equipeId: 'eq-portaria',
          estado: 'ATIVA',
          vigenciaFim: em15Dias,
          cicloAtualId: 'ciclo-01',
        },
        'p-02': {
          fichaId: 'f-vol-2',
          equipeId: 'eq-portaria',
          estado: 'ATIVA',
          vigenciaFim: em15Dias,
        },
      },
      ciclos: {
        'ciclo-01': {
          participacaoId: 'p-01',
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          ano: 2026,
        },
      },
    });

    const resultado = (await obterDashboardRenovacaoRepo(mockDb, 'pastor-01', {
      papelDesejado: 'PASTOR_LOCAL',
    })) as ResultadoDashboardRenovacao<MetricasRenovacaoPastor, ItemRenovacaoPastor>;

    expect(resultado.papelResolvido).toBe('PASTOR_LOCAL');
    expect(resultado.igrejasEscopo).toHaveLength(1);
    expect(resultado.igrejasEscopo![0].id).toBe('ig-central');
    expect(resultado.metricas.pendentesParecer).toBe(1);
    expect(resultado.metricas.totalSobEscopo).toBe(1);
    expect(resultado.itens).toHaveLength(1);
    expect(resultado.itens[0].voluntarioNome).toBe('João Silva');
    expect(resultado.itens[0].estadoRenovacao).toBe('PENDENTE_PASTOR');

    // Tentar acessar igreja fora do escopo lança erro
    await expect(
      obterDashboardRenovacaoRepo(mockDb, 'pastor-01', {
        papelDesejado: 'PASTOR_LOCAL',
        igrejaId: 'ig-norte',
      }),
    ).rejects.toThrow(PermissaoNegadaDashboardError);
  });

  // -------------------------------------------------------------
  // Teste 3: Responsável de Equipe
  // -------------------------------------------------------------
  it('Responsável de Equipe: visualiza exclusivamente equipes sob sua responsabilidade', async () => {
    const agora = new Date();
    const em25Dias = new Date(agora.getTime() + 25 * 24 * 60 * 60 * 1000).toISOString();

    const mockDb = criarMockDb({
      equipes: {
        'eq-musica': {
          nome: 'Música',
          responsavelVigentePessoaId: 'resp-01',
          ativo: true,
        },
        'eq-apoio': {
          nome: 'Apoio',
          responsavelVigentePessoaId: 'outro-resp',
          ativo: true,
        },
      },
      fichas: {
        'f-01': {
          nomeCompleto: 'Ana Paula',
          igrejaId: 'ig-central',
          estado: 'ATIVA',
        },
      },
      participacoes: {
        'part-m': {
          fichaId: 'f-01',
          equipeId: 'eq-musica',
          estado: 'ATIVA',
          vigenciaFim: em25Dias,
          cicloAtualId: 'ciclo-m',
        },
        'part-a': {
          fichaId: 'f-01',
          equipeId: 'eq-apoio',
          estado: 'ATIVA',
          vigenciaFim: em25Dias,
        },
      },
      ciclos: {
        'ciclo-m': {
          participacaoId: 'part-m',
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          ano: 2026,
        },
      },
    });

    const resultado = (await obterDashboardRenovacaoRepo(mockDb, 'resp-01', {
      papelDesejado: 'RESPONSAVEL_EQUIPE',
    })) as ResultadoDashboardRenovacao<MetricasRenovacaoResponsavel, ItemRenovacaoResponsavel>;

    expect(resultado.papelResolvido).toBe('RESPONSAVEL_EQUIPE');
    expect(resultado.equipesEscopo).toHaveLength(1);
    expect(resultado.equipesEscopo![0].id).toBe('eq-musica');
    expect(resultado.metricas.pendentesEquipe).toBe(1);
    expect(resultado.itens).toHaveLength(1);
    expect(resultado.itens[0].equipeNome).toBe('Música');
    expect(resultado.itens[0].voluntarioNome).toBe('Ana Paula');

    // Tentar acessar equipe fora do escopo lança erro
    await expect(
      obterDashboardRenovacaoRepo(mockDb, 'resp-01', {
        papelDesejado: 'RESPONSAVEL_EQUIPE',
        equipeId: 'eq-apoio',
      }),
    ).rejects.toThrow(PermissaoNegadaDashboardError);
  });

  // -------------------------------------------------------------
  // Teste 4: Coordenador Geral / Administrador
  // -------------------------------------------------------------
  it('Coordenador Geral: visão consolidada global com métricas agregadas e filtros dinâmicos', async () => {
    const agora = new Date();
    const em10Dias = new Date(agora.getTime() + 10 * 24 * 60 * 60 * 1000).toISOString();

    const mockDb = criarMockDb({
      autoridades: {
        'coord-01': {
          papel: 'COORDENADOR',
          ativa: true,
        },
      },
      igrejas: {
        'ig-1': { nome: 'Igreja 1', ativo: true },
        'ig-2': { nome: 'Igreja 2', ativo: true },
      },
      equipes: {
        'eq-1': { nome: 'Equipe 1', ativo: true },
      },
      fichas: {
        'f-1': { nomeCompleto: 'Voluntário 1', igrejaId: 'ig-1', estado: 'ATIVA' },
        'f-2': { nomeCompleto: 'Voluntário 2', igrejaId: 'ig-2', estado: 'ATIVA' },
      },
      participacoes: {
        'p-1': {
          fichaId: 'f-1',
          equipeId: 'eq-1',
          estado: 'ATIVA',
          vigenciaFim: em10Dias,
          anoVigencia: 2026,
          cicloAtualId: 'c-coord',
        },
        'p-2': {
          fichaId: 'f-2',
          equipeId: 'eq-1',
          estado: 'ATIVA',
          vigenciaFim: em10Dias,
          anoVigencia: 2026,
        },
      },
      ciclos: {
        'c-coord': {
          participacaoId: 'p-1',
          estado: 'AGUARDANDO_COORDENADOR',
          ano: 2026,
        },
      },
    });

    const resultado = (await obterDashboardRenovacaoRepo(mockDb, 'coord-01', {
      papelDesejado: 'COORDENADOR',
      limite: 10,
      pagina: 1,
    })) as ResultadoDashboardRenovacao<MetricasRenovacaoCoordenador, ItemRenovacaoCoordenador>;

    expect(resultado.papelResolvido).toBe('COORDENADOR');
    expect(resultado.metricas.totalAtivos).toBe(2);
    expect(resultado.metricas.emJanelaRenovacao).toBe(2);
    expect(resultado.metricas.aguardandoCoordenador).toBe(1);
    expect(resultado.itens).toHaveLength(2);
    expect(resultado.totalItens).toBe(2);
    expect(resultado.totalPaginas).toBe(1);
  });

  it('Usuário sem autorização de coordenação tem acesso negado', async () => {
    const mockDb = criarMockDb({
      autoridades: {},
    });

    await expect(
      obterDashboardRenovacaoRepo(mockDb, 'usuario-comum', {
        papelDesejado: 'COORDENADOR',
      }),
    ).rejects.toThrow(PermissaoNegadaDashboardError);
  });
});
