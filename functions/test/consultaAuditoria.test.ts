import { describe, expect, it } from 'vitest';
import {
  AcessoConsultaNegadoError,
  ConsultaAuditoriaInvalidaError,
  codificarCursorAuditoria,
  decodificarCursorAuditoria,
  mascararCpfSeguro,
  validarFiltrosConsultaAuditoria,
} from '../src/domain/consultaAuditoria.js';
import {
  consultarAuditoriaAutorizadaRepo,
  consultarRelatorioOperacionalRepo,
  resolverEscopoAtorAuditoria,
} from '../src/repositories/consultaAuditoria.js';

interface DocMock {
  id: string;
  data: Record<string, unknown>;
}

function criarDbMock(dados: Record<string, DocMock[]>) {
  return {
    collection(nome: string) {
      const colecaoDocs = dados[nome] ?? [];
      return {
        doc(id: string) {
          const docEncontrado = colecaoDocs.find((d) => d.id === id);
          return {
            id,
            async get() {
              return {
                id,
                exists: Boolean(docEncontrado),
                data: () => docEncontrado?.data,
              };
            },
            async set(conteudo: Record<string, unknown>) {
              if (docEncontrado) {
                docEncontrado.data = { ...docEncontrado.data, ...conteudo };
              } else {
                colecaoDocs.push({ id, data: conteudo });
              }
            },
          };
        },
        where(campo: string, op: string, valor: unknown) {
          return {
            where(campo2: string, op2: string, valor2: unknown) {
              const filtrados = colecaoDocs.filter((d) => {
                const c1 = op === '==' ? d.data[campo] === valor : true;
                const c2 = op2 === '==' ? d.data[campo2] === valor2 : true;
                return c1 && c2;
              });
              return {
                async get() {
                  return {
                    empty: filtrados.length === 0,
                    docs: filtrados.map((d) => ({
                      id: d.id,
                      data: () => d.data,
                    })),
                  };
                },
              };
            },
            async get() {
              const filtrados = colecaoDocs.filter((d) => {
                if (op === '==') return d.data[campo] === valor;
                return true;
              });
              return {
                empty: filtrados.length === 0,
                docs: filtrados.map((d) => ({
                  id: d.id,
                  data: () => d.data,
                })),
              };
            },
          };
        },
        async get() {
          return {
            empty: colecaoDocs.length === 0,
            docs: colecaoDocs.map((d) => ({
              id: d.id,
              data: () => d.data,
            })),
          };
        },
      };
    },
  } as any;
}

describe('Story 6.2: Domínio e Validações de Consulta de Auditoria', () => {
  it('valida mascaramento de CPF seguro (AD-12)', () => {
    expect(mascararCpfSeguro('12345678901')).toBe('123.***.***-01');
    expect(mascararCpfSeguro('123.456.789-01')).toBe('123.***.***-01');
    expect(mascararCpfSeguro('invalido')).toBe('***.***.***-**');
    expect(mascararCpfSeguro(undefined)).toBe('***.***.***-**');
  });

  it('codifica e decodifica cursor de forma estável e determinística', () => {
    const ts = 1728345600000;
    const cmdId = 'CMD_123456';
    const cursor = codificarCursorAuditoria(ts, cmdId);
    expect(typeof cursor).toBe('string');
    expect(cursor.length).toBeGreaterThan(0);

    const decodificado = decodificarCursorAuditoria(cursor);
    expect(decodificado).not.toBeNull();
    expect(decodificado?.timestampMs).toBe(ts);
    expect(decodificado?.commandId).toBe(cmdId);
  });

  it('rejeita cursores corrompidos ou inválidos', () => {
    expect(decodificarCursorAuditoria('')).toBeNull();
    expect(decodificarCursorAuditoria('abc-invalido')).toBeNull();
  });

  it('valida filtros de consulta e limites de paginação', () => {
    const valid = validarFiltrosConsultaAuditoria({
      igrejaId: 'igreja_centro',
      equipeId: 'equipe_louvor',
      acao: 'APROVAR_EQUIPE',
      limite: 50,
      periodoInicio: '2026-01-01T00:00:00.000Z',
      periodoFim: '2026-12-31T23:59:59.000Z',
    });

    expect(valid.limite).toBe(50);
    expect(valid.filtros.igrejaId).toBe('igreja_centro');
    expect(valid.filtros.equipeId).toBe('equipe_louvor');
    expect(valid.filtros.acao).toBe('APROVAR_EQUIPE');
  });

  it('rejeita limite superior ao teto máximo de 100 registros', () => {
    expect(() =>
      validarFiltrosConsultaAuditoria({ limite: 101 }),
    ).toThrow(ConsultaAuditoriaInvalidaError);
  });

  it('rejeita datas mal formatadas', () => {
    expect(() =>
      validarFiltrosConsultaAuditoria({ periodoInicio: 'data-invalida' }),
    ).toThrow(ConsultaAuditoriaInvalidaError);
  });
});

describe('Story 6.2: Repositório de Auditoria e Isolamento de Escopo (AD-8, AD-9, AD-12)', () => {
  const eventosAuditoria: DocMock[] = [
    {
      id: 'CMD_001',
      data: {
        commandId: 'CMD_001',
        correlationId: 'CORR_001',
        atorUid: 'PASTOR_CENTRO',
        acao: 'DECISAO_PASTOR_LOCAL',
        entidades: [
          { tipo: 'IGREJA', id: 'igreja_centro' },
          { tipo: 'VOLUNTARIO', id: 'vol_001' },
        ],
        timestampOriginal: '2026-10-01T10:00:00.000Z',
        materializadoEm: '2026-10-01T10:00:01.000Z',
      },
    },
    {
      id: 'CMD_002',
      data: {
        commandId: 'CMD_002',
        correlationId: 'CORR_002',
        atorUid: 'RESP_LOUVOR',
        acao: 'DECISAO_RESPONSAVEL_EQUIPE',
        entidades: [
          { tipo: 'EQUIPE', id: 'equipe_louvor' },
          { tipo: 'VOLUNTARIO', id: 'vol_001' },
        ],
        timestampOriginal: '2026-10-02T10:00:00.000Z',
        materializadoEm: '2026-10-02T10:00:01.000Z',
      },
    },
    {
      id: 'CMD_003',
      data: {
        commandId: 'CMD_003',
        correlationId: 'CORR_003',
        atorUid: 'PASTOR_BAIRRO',
        acao: 'DECISAO_PASTOR_LOCAL',
        entidades: [
          { tipo: 'IGREJA', id: 'igreja_bairro' },
          { tipo: 'VOLUNTARIO', id: 'vol_002' },
        ],
        timestampOriginal: '2026-10-03T10:00:00.000Z',
        materializadoEm: '2026-10-03T10:00:01.000Z',
      },
    },
  ];

  it('nega acesso para voluntário comum sem papel pastoral ou de equipe', async () => {
    const db = criarDbMock({
      autoridadesAdministrativas: [],
      igrejas: [],
      vinculosPastorIgreja: [],
      equipes: [],
      vinculosPastorEquipe: [],
    });

    await expect(
      resolverEscopoAtorAuditoria(db, 'voluntario_sem_papel'),
    ).rejects.toThrow(AcessoConsultaNegadoError);
  });

  it('Pastor Local acessa somente eventos da sua igreja vigente', async () => {
    const db = criarDbMock({
      autoridadesAdministrativas: [],
      igrejas: [
        {
          id: 'igreja_centro',
          data: { pastorLocalVigentePessoaId: 'pastor_1', ativo: true },
        },
      ],
      vinculosPastorIgreja: [],
      equipes: [],
      vinculosPastorEquipe: [],
      auditoria: [...eventosAuditoria],
    });

    const res = await consultarAuditoriaAutorizadaRepo(
      db,
      'pastor_1',
      {},
      20,
      null,
    );

    expect(res.itens.length).toBe(1);
    expect(res.itens[0].id).toBe('CMD_001');
    expect(res.itens[0].acao).toBe('DECISAO_PASTOR_LOCAL');
  });

  it('Pastor Local recebe resultado vazio neutro ao tentar filtrar igreja alheia (Prevenção IDOR)', async () => {
    const db = criarDbMock({
      autoridadesAdministrativas: [],
      igrejas: [
        {
          id: 'igreja_centro',
          data: { pastorLocalVigentePessoaId: 'pastor_1', ativo: true },
        },
      ],
      vinculosPastorIgreja: [],
      equipes: [],
      vinculosPastorEquipe: [],
      auditoria: [...eventosAuditoria],
    });

    const res = await consultarAuditoriaAutorizadaRepo(
      db,
      'pastor_1',
      { igrejaId: 'igreja_bairro' }, // Outra igreja
      20,
      null,
    );

    // Deve retornar lista vazia neutra sem erro descritivo
    expect(res.itens.length).toBe(0);
    expect(res.temMais).toBe(false);
  });

  it('Responsável de Equipe acessa somente eventos da sua equipe vigente', async () => {
    const db = criarDbMock({
      autoridadesAdministrativas: [],
      igrejas: [],
      vinculosPastorIgreja: [],
      equipes: [
        {
          id: 'equipe_louvor',
          data: { responsavelVigentePessoaId: 'resp_louvor_1', ativo: true },
        },
      ],
      vinculosPastorEquipe: [],
      auditoria: [...eventosAuditoria],
    });

    const res = await consultarAuditoriaAutorizadaRepo(
      db,
      'resp_louvor_1',
      {},
      20,
      null,
    );

    expect(res.itens.length).toBe(1);
    expect(res.itens[0].id).toBe('CMD_002');
  });

  it('Coordenador Geral possui visão global e registra evento probatório de auditoria (AD-8/AD-12)', async () => {
    const auditoriaColecao = [...eventosAuditoria];
    const db = criarDbMock({
      autoridadesAdministrativas: [
        {
          id: 'coord_geral',
          data: { papel: 'COORDENADOR_GERAL', ativo: true },
        },
      ],
      igrejas: [],
      vinculosPastorIgreja: [],
      equipes: [],
      vinculosPastorEquipe: [],
      auditoria: auditoriaColecao,
    });

    const res = await consultarAuditoriaAutorizadaRepo(
      db,
      'coord_geral',
      {},
      20,
      null,
    );

    // Visão global retorna todos os 3 eventos
    expect(res.itens.length).toBe(3);

    // Confirma que gravou auditoria probatória da consulta global
    const eventosGravados = auditoriaColecao.filter((e) =>
      e.data.acao === 'CONSULTA_AUDITORIA_GLOBAL',
    );
    expect(eventosGravados.length).toBe(1);
    expect(eventosGravados[0].data.atorUid).toBe('coord_geral');
    expect(eventosGravados[0].data.retencaoAte).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });

  it('paginação por cursor determinístico funciona ordenando descendente com desempate', async () => {
    const auditoriaColecao = [...eventosAuditoria];
    const db = criarDbMock({
      autoridadesAdministrativas: [
        {
          id: 'coord_geral',
          data: { papel: 'COORDENADOR_GERAL', ativo: true },
        },
      ],
      igrejas: [],
      vinculosPastorIgreja: [],
      equipes: [],
      vinculosPastorEquipe: [],
      auditoria: auditoriaColecao,
    });

    // Pede página com limite 2
    const pag1 = await consultarAuditoriaAutorizadaRepo(
      db,
      'coord_geral',
      {},
      2,
      null,
    );

    expect(pag1.itens.length).toBe(2);
    expect(pag1.temMais).toBe(true);
    expect(pag1.proximoCursor).not.toBeNull();
    expect(pag1.itens[0].id).toBe('CMD_003'); // mais recente
    expect(pag1.itens[1].id).toBe('CMD_002');

    // Pede segunda página usando o proximoCursor
    const cursorDecodificado = decodificarCursorAuditoria(pag1.proximoCursor!);
    const pag2 = await consultarAuditoriaAutorizadaRepo(
      db,
      'coord_geral',
      {},
      2,
      cursorDecodificado,
    );

    expect(pag2.itens.length).toBe(1);
    expect(pag2.itens[0].id).toBe('CMD_001');
    expect(pag2.temMais).toBe(false);
  });
});

describe('Story 6.2: Relatórios Operacionais Consolidados', () => {
  it('gera relatório operacional agregando métricas e mascarando CPF', async () => {
    const auditoriaColecao: any[] = [];
    const db = criarDbMock({
      autoridadesAdministrativas: [
        {
          id: 'coord_geral',
          data: { papel: 'COORDENADOR_GERAL', ativo: true },
        },
      ],
      igrejas: [
        { id: 'ig_1', data: { nome: 'Igreja Central', ativo: true } },
      ],
      equipes: [
        { id: 'eq_1', data: { nome: 'Recepção', ativo: true } },
      ],
      fichas: [
        {
          id: 'ficha_1',
          data: {
            nomeCompleto: 'João da Silva',
            cpf: '12345678900',
            igrejaId: 'ig_1',
            estado: 'ATIVA',
          },
        },
        {
          id: 'ficha_2',
          data: {
            nomeCompleto: 'Maria Oliveira',
            cpf: '98765432100',
            igrejaId: 'ig_1',
            estado: 'AGUARDANDO_PASTOR_LOCAL',
          },
        },
      ],
      participacoes: [
        {
          id: 'ficha_1_eq_1',
          data: {
            fichaId: 'ficha_1',
            equipeId: 'eq_1',
            estado: 'ATIVA',
            anoVigencia: 2026,
          },
        },
      ],
      auditoria: auditoriaColecao,
    });

    const relatorio = await consultarRelatorioOperacionalRepo(
      db,
      'coord_geral',
      {},
    );

    expect(relatorio.escopoAtor).toBe('GLOBAL');
    expect(relatorio.metricas.totalVoluntarios).toBe(2);
    expect(relatorio.metricas.totalFichasAtivas).toBe(1);
    expect(relatorio.metricas.totalParticipacoesAtivas).toBe(1);
    expect(relatorio.metricas.totalAguardandoAprovacao).toBe(1);

    // CPF rigorosamente mascarado
    expect(relatorio.voluntarios[0].cpfMascarado).toBe('123.***.***-00');
    expect(relatorio.voluntarios[1].cpfMascarado).toBe('987.***.***-00');

    // Auditoria probatória do relatório carrega retenção de 5 anos (AD-12/AC1)
    const eventoRelatorio = auditoriaColecao.find(
      (e) => e.data.acao === 'CONSULTA_RELATORIO_OPERACIONAL',
    );
    expect(eventoRelatorio).toBeDefined();
    expect(eventoRelatorio!.data.retencaoAte).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });

  it('Pastor Local gera relatório restrito à sua igreja', async () => {
    const db = criarDbMock({
      autoridadesAdministrativas: [],
      igrejas: [
        {
          id: 'ig_1',
          data: {
            nome: 'Igreja Central',
            pastorLocalVigentePessoaId: 'pastor_1',
            ativo: true,
          },
        },
        {
          id: 'ig_2',
          data: {
            nome: 'Igreja Norte',
            pastorLocalVigentePessoaId: 'outro_pastor',
            ativo: true,
          },
        },
      ],
      vinculosPastorIgreja: [],
      equipes: [],
      vinculosPastorEquipe: [],
      fichas: [
        {
          id: 'ficha_1',
          data: { nomeCompleto: 'Membro Central', igrejaId: 'ig_1', estado: 'ATIVA' },
        },
        {
          id: 'ficha_2',
          data: { nomeCompleto: 'Membro Norte', igrejaId: 'ig_2', estado: 'ATIVA' },
        },
      ],
      participacoes: [],
      auditoria: [],
    });

    const relatorio = await consultarRelatorioOperacionalRepo(
      db,
      'pastor_1',
      {},
    );

    expect(relatorio.escopoAtor).toBe('PASTOR_LOCAL');
    expect(relatorio.voluntarios.length).toBe(1);
    expect(relatorio.voluntarios[0].nomeCompleto).toBe('Membro Central');
  });
});
