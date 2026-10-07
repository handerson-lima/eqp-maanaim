import { describe, expect, it } from 'vitest';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  DecisaoInvalidaError,
  FichaNaoAguardandoCoordenadorError,
  FichaNaoEncontradaError,
  JustificativaObrigatoriaError,
  MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
  ReuniaoPastoresNaoConfirmadaError,
  SemAutoridadeCoordenadorError,
  calcularPayloadHashDecisaoCoordenador,
  normalizarDecisaoCoordenador,
  validarDecidirAtivacaoCoordenador,
} from '../src/domain/decisaoCoordenador.js';
import {
  decidirAtivacaoCoordenadorRepo,
  obterFilaCoordenadorRepo,
} from '../src/repositories/decisaoCoordenador.js';
import { obterFilaCoordenador } from '../src/commands/obterFilaCoordenador.js';
import { decidirAtivacaoCoordenador } from '../src/commands/decidirAtivacaoCoordenador.js';

describe('Story 3.3: Domínio de Decisão do Coordenador Geral', () => {
  const dadosAprovacao = {
    commandId: 'cmd-coordenador-12345678',
    fichaId: 'ficha-vol-01',
    decisao: 'APROVADO',
    confirmouReuniaoPastores: true,
    observacao: 'Homologado na reunião mensal de pastores.',
    expectedVersion: 1,
  };

  it('normaliza apenas as duas decisões canônicas (case-insensitive)', () => {
    expect(normalizarDecisaoCoordenador('APROVADO')).toBe('APROVADO');
    expect(normalizarDecisaoCoordenador('aprovado')).toBe('APROVADO');
    expect(normalizarDecisaoCoordenador('DESFAVORAVEL')).toBe('DESFAVORAVEL');
    expect(normalizarDecisaoCoordenador('desfavoravel')).toBe('DESFAVORAVEL');
  });

  it('rejeita aliases não documentados de decisão', () => {
    for (const alias of ['APROVAR', 'DESFAVORÁVEL', 'RECUSADO', 'RECUSAR', 'NEGATIVO']) {
      expect(() => normalizarDecisaoCoordenador(alias)).toThrow(DecisaoInvalidaError);
    }
  });

  it('rejeita observação acima de 500 caracteres também na aprovação', () => {
    expect(() =>
      validarDecidirAtivacaoCoordenador({
        ...dadosAprovacao,
        observacao: 'x'.repeat(501),
      }),
    ).toThrow(DecisaoInvalidaError);
  });

  it('rejeita decisões inválidas', () => {
    expect(() => normalizarDecisaoCoordenador('TALVEZ')).toThrow(DecisaoInvalidaError);
    expect(() => normalizarDecisaoCoordenador(123)).toThrow(DecisaoInvalidaError);
  });

  it('valida comando de aprovação com confirmação da reunião de pastores', () => {
    const entrada = validarDecidirAtivacaoCoordenador(dadosAprovacao);
    expect(entrada.commandId).toBe(dadosAprovacao.commandId);
    expect(entrada.fichaId).toBe('ficha-vol-01');
    expect(entrada.decisao).toBe('APROVADO');
    expect(entrada.confirmouReuniaoPastores).toBe(true);
    expect(entrada.expectedVersion).toBe(1);

    const hashCalculado = calcularPayloadHashDecisaoCoordenador({
      fichaId: 'ficha-vol-01',
      decisao: 'APROVADO',
      confirmouReuniaoPastores: true,
      observacao: 'Homologado na reunião mensal de pastores.',
      expectedVersion: 1,
    });
    expect(entrada.payloadHash).toBe(hashCalculado);
  });

  it('rejeita aprovação sem confirmação da reunião de pastores', () => {
    expect(() =>
      validarDecidirAtivacaoCoordenador({
        ...dadosAprovacao,
        confirmouReuniaoPastores: false,
      }),
    ).toThrow(ReuniaoPastoresNaoConfirmadaError);
  });

  it('valida comando de decisão desfavorável com justificativa', () => {
    const entrada = validarDecidirAtivacaoCoordenador({
      ...dadosAprovacao,
      decisao: 'DESFAVORAVEL',
      confirmouReuniaoPastores: true,
      observacao: 'Reunião deliberou pelo adiamento do voluntariado.',
    });
    expect(entrada.decisao).toBe('DESFAVORAVEL');
    expect(entrada.observacao).toBe(
      'Reunião deliberou pelo adiamento do voluntariado.',
    );
  });

  it('rejeita decisão desfavorável sem justificativa ou menor que 5 caracteres', () => {
    expect(() =>
      validarDecidirAtivacaoCoordenador({
        ...dadosAprovacao,
        decisao: 'DESFAVORAVEL',
        observacao: '',
      }),
    ).toThrow(JustificativaObrigatoriaError);

    expect(() =>
      validarDecidirAtivacaoCoordenador({
        ...dadosAprovacao,
        decisao: 'DESFAVORAVEL',
        observacao: '1234',
      }),
    ).toThrow(JustificativaObrigatoriaError);
  });

  it('rejeita payload com commandId ou fichaId inválidos', () => {
    expect(() =>
      validarDecidirAtivacaoCoordenador({
        ...dadosAprovacao,
        commandId: 'curto',
      }),
    ).toThrow(DecisaoInvalidaError);

    expect(() =>
      validarDecidirAtivacaoCoordenador({
        ...dadosAprovacao,
        fichaId: '',
      }),
    ).toThrow(DecisaoInvalidaError);
  });
});

describe('Story 3.3: Repositório e Transações de Ativação do Coordenador', () => {
  const coordUid = 'coord-geral-01';
  const voluntarioUid = 'vol-01';
  const fichaId = 'ficha-01';

  function criarMockDb(cenario: {
    autoridades?: Record<string, any>;
    coordenadores?: Record<string, any>;
    pessoas?: Record<string, any>;
    fichas?: Record<string, any>;
    igrejas?: Record<string, any>;
    equipes?: Record<string, any>;
    participacoes?: Array<{ id: string; fichaId: string; equipeId: string; estado: string; data: any }>;
    recibos?: Record<string, any>;
  }) {
    const updates: Array<{ ref: any; data: any }> = [];
    const sets: Array<{ ref: any; data: any }> = [];
    const creates: Array<{ ref: any; data: any }> = [];
    const ciclosCriados: Record<string, any> = {};

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({
          col,
          id,
          get: async () => {
            if (col === 'autoridadesAdministrativas') {
              const d = cenario.autoridades?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'coordenadores') {
              const d = cenario.coordenadores?.[id];
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
            if (col === 'igrejas') {
              const d = cenario.igrejas?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'equipes') {
              const d = cenario.equipes?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'commands') {
              const d = cenario.recibos?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'participacoes') {
              const p = cenario.participacoes?.find((item) => item.id === id);
              return {
                exists: !!p,
                id,
                data: () =>
                  p
                    ? {
                        ...p.data,
                        estado: p.estado,
                        equipeId: p.equipeId,
                        fichaId: p.fichaId,
                      }
                    : undefined,
              };
            }
            return { exists: false, id, data: () => undefined };
          },
        }),
        where: (field1: string, op1: string, val1: any) => {
          const get = async () => {
            if (col === 'participacoes') {
              const itens = (cenario.participacoes ?? []).filter((item) => {
                const d = {
                  ...item.data,
                  estado: item.estado,
                  equipeId: item.equipeId,
                  fichaId: item.fichaId,
                };
                if (op1 === '==') return d[field1] === val1;
                return false;
              });
              return {
                docs: itens.map((i) => ({
                  id: i.id,
                  ref: { id: i.id, col: 'participacoes' },
                  data: () => ({
                    ...i.data,
                    estado: i.estado,
                    equipeId: i.equipeId,
                    fichaId: i.fichaId,
                  }),
                })),
                empty: itens.length === 0,
              };
            }
            return { docs: [], empty: true };
          };
          return { get, limit: () => ({ get }) };
        },
      }),
      runTransaction: async (cb: (tx: any) => Promise<any>) => {
        const tx = {
          get: async (ref: any) => {
            return ref.get();
          },
          set: (ref: any, data: any) => {
            sets.push({ ref, data });
            if (ref.col === 'ciclos') {
              ciclosCriados[ref.id] = data;
            }
          },
          update: (ref: any, data: any) => {
            updates.push({ ref, data });
            if (ref.col === 'fichas') {
              if (cenario.fichas?.[ref.id]) {
                Object.assign(cenario.fichas[ref.id], data);
              }
            }
            if (ref.col === 'participacoes') {
              const p = cenario.participacoes?.find((item) => item.id === ref.id);
              if (p) {
                Object.assign(p, { estado: data.estado ?? p.estado });
                Object.assign(p.data, data);
              }
            }
          },
          create: (ref: any, data: any) => {
            creates.push({ ref, data });
          },
        };
        return cb(tx);
      },
      _updates: updates,
      _sets: sets,
      _creates: creates,
      _ciclos: ciclosCriados,
    };

    return mockDb;
  }

  it('obterFilaCoordenadorRepo recusa usuário sem autoridade de Coordenador', async () => {
    const db = criarMockDb({
      autoridades: {},
      coordenadores: {},
      pessoas: {},
    });

    await expect(obterFilaCoordenadorRepo(db, 'usuario-comum')).rejects.toThrow(
      SemAutoridadeCoordenadorError,
    );
  });

  it('obterFilaCoordenadorRepo lista fichas com participações em AGUARDANDO_COORDENADOR', async () => {
    const db = criarMockDb({
      autoridades: {
        [coordUid]: { ativa: true, papeis: ['COORDENADOR'] },
      },
      pessoas: {
        [coordUid]: { nomeCompleto: 'Pastor Coordenador Geral' },
      },
      fichas: {
        [fichaId]: {
          ownerUid: voluntarioUid,
          nomeCompleto: 'Matheus Pereira',
          profissao: 'Engenheiro',
          cpf: '12345678901',
          igrejaId: 'igreja-central',
          estado: 'AGUARDANDO_COORDENADOR',
          versao: 1,
          decisaoPastorLocal: {
            pastorNome: 'Pastor João',
            decididoEm: '2026-10-06T10:00:00Z',
          },
        },
      },
      igrejas: {
        'igreja-central': { nome: 'Igreja Central de Vitória' },
      },
      equipes: {
        'eq-cozinha': { nome: 'Cozinha' },
        'eq-portaria': { nome: 'Portaria' },
      },
      participacoes: [
        {
          id: 'part-01',
          fichaId,
          equipeId: 'eq-cozinha',
          estado: 'AGUARDANDO_COORDENADOR',
          data: {
            versao: 2,
            decisaoResponsavel: {
              decisao: 'APROVADO',
              responsavelNome: 'Responsável Cozinha',
              decididoEm: '2026-10-06T12:00:00Z',
            },
          },
        },
        {
          id: 'part-02',
          fichaId,
          equipeId: 'eq-portaria',
          estado: 'REJEITADA',
          data: {
            versao: 2,
            decisaoResponsavel: {
              decisao: 'DESFAVORAVEL',
              responsavelNome: 'Responsável Portaria',
              justificativa: 'Sem vagas',
            },
          },
        },
      ],
    });

    const resultado = await obterFilaCoordenadorRepo(db, coordUid);
    expect(resultado.pendencias).toHaveLength(1);

    const item = resultado.pendencias[0];
    expect(item.fichaId).toBe(fichaId);
    expect(item.voluntarioNome).toBe('Matheus Pereira');
    expect(item.nomeIgreja).toBe('Igreja Central de Vitória');
    expect(item.cpfMascarado).toBe('123.***.***-01');
    expect(item.pastorLocalNome).toBe('Pastor João');
    expect(item.participacoes).toHaveLength(2);

    const partAprovada = item.participacoes.find((p) => p.participacaoId === 'part-01');
    expect(partAprovada?.elegivelAtivacao).toBe(true);
    expect(partAprovada?.nomeEquipe).toBe('Cozinha');

    const partRejeitada = item.participacoes.find((p) => p.participacaoId === 'part-02');
    expect(partRejeitada?.elegivelAtivacao).toBe(false);
  });

  it('decidirAtivacaoCoordenadorRepo aprova e ativa ciclo com vigência de exatamente 1 ano', async () => {
    const db = criarMockDb({
      autoridades: {
        [coordUid]: { ativa: true, papeis: ['COORDENADOR'] },
      },
      pessoas: {
        [coordUid]: { nomeCompleto: 'Pastor Coordenador Geral' },
      },
      fichas: {
        [fichaId]: {
          ownerUid: voluntarioUid,
          nomeCompleto: 'Matheus Pereira',
          estado: 'AGUARDANDO_COORDENADOR',
          versao: 1,
        },
      },
      participacoes: [
        {
          id: 'part-01',
          fichaId,
          equipeId: 'eq-cozinha',
          estado: 'AGUARDANDO_COORDENADOR',
          data: { versao: 2 },
        },
        {
          id: 'part-02',
          fichaId,
          equipeId: 'eq-portaria',
          estado: 'REJEITADA',
          data: { versao: 2 },
        },
      ],
    });

    const entrada = validarDecidirAtivacaoCoordenador({
      commandId: 'cmd-ativacao-coordenador-12345',
      fichaId,
      decisao: 'APROVADO',
      confirmouReuniaoPastores: true,
      observacao: 'Aprovado após reunião',
      expectedVersion: 1,
    });

    const res = await decidirAtivacaoCoordenadorRepo(
      db,
      {
        commandId: entrada.commandId,
        coordenadorUid: coordUid,
      },
      entrada,
    );

    expect(res.sucesso).toBe(true);
    expect(res.repetido).toBe(false);
    expect(res.estadoFicha).toBe('ATIVA');
    expect(res.versaoFicha).toBe(2);
    expect(res.participacoesAtivadas).toEqual(['part-01']);
    expect(res.vigenciaInicio).toBeDefined();
    expect(res.vigenciaFim).toBeDefined();

    // Valida vigência anual
    const dtInicio = new Date(res.vigenciaInicio!);
    const dtFim = new Date(res.vigenciaFim!);
    expect(dtFim.getUTCFullYear() - dtInicio.getUTCFullYear()).toBe(1);

    // Verifica que o ciclo foi criado
    const ano = dtInicio.getUTCFullYear();
    const cicloId = `ciclo_part-01_${ano}`;
    expect(db._ciclos[cicloId]).toBeDefined();
    expect(db._ciclos[cicloId].estado).toBe('ATIVO');
    expect(db._ciclos[cicloId].confirmouReuniaoPastores).toBe(true);

    // Verifica que a participação part-02 (já rejeitada) NÃO foi ativada
    const part02 = db.collection('participacoes').doc('part-02');
    const p02Data = (await part02.get()).data();
    expect(p02Data.estado).toBe('REJEITADA');

    // A participação elegível precisa estar persistida como ATIVA
    const p01Data = (await db.collection('participacoes').doc('part-01').get()).data();
    expect(p01Data?.estado).toBe('ATIVA');
    expect(p01Data?.cicloAtualId).toBe(`ciclo_part-01_${ano}`);

    // A ficha persistida consolida estado ATIVA e vigência anual
    const fichaAtivada = await db.collection('fichas').doc(fichaId).get();
    expect(fichaAtivada.data()?.estado).toBe('ATIVA');
    expect(fichaAtivada.data()?.vigenciaInicio).toBeDefined();
    expect(fichaAtivada.data()?.vigenciaFim).toBeDefined();

    // Valida recibo em commands
    const recibo = db._creates.find(
      (c: any) => c.ref.col === 'commands' && c.ref.id === entrada.commandId,
    );
    expect(recibo).toBeDefined();
    expect(recibo.data.status).toBe('COMPLETO');

    // Valida auditoria sem PII
    const auditoria = db._sets.find(
      (s: any) => s.ref.col === 'auditOutbox' && s.ref.id === entrada.commandId,
    );
    expect(auditoria).toBeDefined();
    expect(auditoria.data.action).toBe('DECISAO_COORDENADOR');
    expect(auditoria.data.novoEstadoFicha).toBe('ATIVA');
    expect(auditoria.data.actorUid).toBe(coordUid);
    expect(auditoria.data).not.toHaveProperty('cpf');
    expect(auditoria.data).not.toHaveProperty('nomeCompleto');
  });

  it('decidirAtivacaoCoordenadorRepo suporta reenvio idempotente com mesmo hash', async () => {
    const db = criarMockDb({
      autoridades: {
        [coordUid]: { ativa: true, papeis: ['COORDENADOR'] },
      },
      recibos: {
        'cmd-repetido-12345678': {
          uid: coordUid,
          payloadHash: 'hash-valido-123',
          status: 'COMPLETO',
          resultado: {
            estadoFicha: 'ATIVA',
            versaoFicha: 2,
            participacoesAtivadas: ['part-01'],
            vigenciaInicio: '2026-10-06T12:00:00Z',
            vigenciaFim: '2027-10-06T12:00:00Z',
          },
          criadoEm: '2026-10-06T12:00:00Z',
        },
      },
    });

    const entrada = {
      commandId: 'cmd-repetido-12345678',
      fichaId,
      decisao: 'APROVADO' as const,
      confirmouReuniaoPastores: true,
      expectedVersion: 1,
      payloadHash: 'hash-valido-123',
    };

    const res = await decidirAtivacaoCoordenadorRepo(
      db,
      {
        commandId: entrada.commandId,
        coordenadorUid: coordUid,
      },
      entrada,
    );

    expect(res.sucesso).toBe(true);
    expect(res.repetido).toBe(true);
    expect(res.estadoFicha).toBe('ATIVA');
  });

  it('decidirAtivacaoCoordenadorRepo rejeita reenvio com payload divergente', async () => {
    const db = criarMockDb({
      autoridades: {
        [coordUid]: { ativa: true, papeis: ['COORDENADOR'] },
      },
      recibos: {
        'cmd-divergente-12345': {
          uid: coordUid,
          payloadHash: 'hash-original',
        },
      },
    });

    const entrada = {
      commandId: 'cmd-divergente-12345',
      fichaId,
      decisao: 'APROVADO' as const,
      confirmouReuniaoPastores: true,
      expectedVersion: 1,
      payloadHash: 'hash-diferente',
    };

    await expect(
      decidirAtivacaoCoordenadorRepo(
        db,
        {
          commandId: entrada.commandId,
          coordenadorUid: coordUid,
        },
        entrada,
      ),
    ).rejects.toThrow(ComandoDivergenteError);
  });

  it('decidirAtivacaoCoordenadorRepo rejeita conflito de versão da ficha', async () => {
    const db = criarMockDb({
      autoridades: {
        [coordUid]: { ativa: true, papeis: ['COORDENADOR'] },
      },
      fichas: {
        [fichaId]: {
          ownerUid: voluntarioUid,
          versao: 5,
        },
      },
    });

    const entrada = validarDecidirAtivacaoCoordenador({
      commandId: 'cmd-conflito-12345678',
      fichaId,
      decisao: 'APROVADO',
      confirmouReuniaoPastores: true,
      expectedVersion: 1, // difere de 5
    });

    await expect(
      decidirAtivacaoCoordenadorRepo(
        db,
        {
          commandId: entrada.commandId,
          coordenadorUid: coordUid,
        },
        entrada,
      ),
    ).rejects.toThrow(ConflitoVersaoError);
  });

  it('decidirAtivacaoCoordenadorRepo recusa solicitação sem participações em AGUARDANDO_COORDENADOR', async () => {
    const db = criarMockDb({
      autoridades: {
        [coordUid]: { ativa: true, papeis: ['COORDENADOR'] },
      },
      fichas: {
        [fichaId]: {
          ownerUid: voluntarioUid,
          versao: 1,
        },
      },
      participacoes: [
        {
          id: 'part-01',
          fichaId,
          equipeId: 'eq-cozinha',
          estado: 'ATIVA', // já ativa
          data: { versao: 1 },
        },
      ],
    });

    const entrada = validarDecidirAtivacaoCoordenador({
      commandId: 'cmd-sem-pendencia-1234',
      fichaId,
      decisao: 'APROVADO',
      confirmouReuniaoPastores: true,
      expectedVersion: 1,
    });

    await expect(
      decidirAtivacaoCoordenadorRepo(
        db,
        {
          commandId: entrada.commandId,
          coordenadorUid: coordUid,
        },
        entrada,
      ),
    ).rejects.toThrow(FichaNaoAguardandoCoordenadorError);
  });

  it('decidirAtivacaoCoordenadorRepo executa decisão desfavorável com mensagem neutra canônica', async () => {
    const db = criarMockDb({
      autoridades: {
        [coordUid]: { ativa: true, papeis: ['COORDENADOR'] },
      },
      pessoas: {
        [coordUid]: { nomeCompleto: 'Pastor Coordenador Geral' },
      },
      fichas: {
        [fichaId]: {
          ownerUid: voluntarioUid,
          nomeCompleto: 'Matheus Pereira',
          estado: 'AGUARDANDO_COORDENADOR',
          versao: 1,
        },
      },
      participacoes: [
        {
          id: 'part-01',
          fichaId,
          equipeId: 'eq-cozinha',
          estado: 'AGUARDANDO_COORDENADOR',
          data: { versao: 2 },
        },
      ],
    });

    const entrada = validarDecidirAtivacaoCoordenador({
      commandId: 'cmd-desfavoravel-coordenador-1',
      fichaId,
      decisao: 'DESFAVORAVEL',
      confirmouReuniaoPastores: true,
      observacao: 'Decisão em reunião de pastores por não homologar no momento.',
      expectedVersion: 1,
    });

    const res = await decidirAtivacaoCoordenadorRepo(
      db,
      {
        commandId: entrada.commandId,
        coordenadorUid: coordUid,
      },
      entrada,
    );

    expect(res.sucesso).toBe(true);
    expect(res.estadoFicha).toBe('REJEITADA');
    expect(res.participacoesRejeitadas).toEqual(['part-01']);

    // Verifica que a ficha foi atualizada com a mensagem canônica neutra
    const fichaDoc = await db.collection('fichas').doc(fichaId).get();
    expect(fichaDoc.data()?.mensagemVoluntario).toBe(
      MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
    );
    expect(fichaDoc.data()?.proximaAcao).toBe(
      MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
    );

    // Verifica que a evidência imutável guardou a justificativa interna
    const evidencia = db._sets.find(
      (s: any) => s.ref.col === 'evidenciasDecisao' && s.ref.id === entrada.commandId,
    );
    expect(evidencia).toBeDefined();
    expect(evidencia.data.justificativaInterna).toBe(
      'Decisão em reunião de pastores por não homologar no momento.',
    );
  });

  it('decidirAtivacaoCoordenadorRepo mantém a ficha ATIVA quando resta participação ativa', async () => {
    const db = criarMockDb({
      autoridades: {
        [coordUid]: { ativa: true, papeis: ['COORDENADOR'] },
      },
      pessoas: {
        [coordUid]: { nomeCompleto: 'Pastor Coordenador Geral' },
      },
      fichas: {
        [fichaId]: {
          ownerUid: voluntarioUid,
          estado: 'AGUARDANDO_COORDENADOR',
          versao: 1,
        },
      },
      participacoes: [
        {
          id: 'part-01',
          fichaId,
          equipeId: 'eq-cozinha',
          estado: 'AGUARDANDO_COORDENADOR',
          data: { versao: 2 },
        },
        {
          id: 'part-02',
          fichaId,
          equipeId: 'eq-portaria',
          estado: 'ATIVA',
          data: { versao: 3 },
        },
      ],
    });

    const entrada = validarDecidirAtivacaoCoordenador({
      commandId: 'cmd-desfavoravel-com-ativa-1',
      fichaId,
      decisao: 'DESFAVORAVEL',
      confirmouReuniaoPastores: false,
      observacao: 'Não homologar esta equipe mantendo a já ativa.',
      expectedVersion: 1,
    });

    const res = await decidirAtivacaoCoordenadorRepo(
      db,
      {
        commandId: entrada.commandId,
        coordenadorUid: coordUid,
      },
      entrada,
    );

    expect(res.estadoFicha).toBe('ATIVA');
    const fichaDoc = await db.collection('fichas').doc(fichaId).get();
    expect(fichaDoc.data()?.estado).toBe('ATIVA');
    expect(fichaDoc.data()?.mensagemVoluntario).toBeUndefined();
  });

  it('decidirAtivacaoCoordenadorRepo recusa recibo pertencente a outro usuário', async () => {
    const db = criarMockDb({
      autoridades: {
        [coordUid]: { ativa: true, papeis: ['COORDENADOR'] },
      },
      recibos: {
        'cmd-de-outro-12345678': {
          uid: 'outro-coordenador',
          payloadHash: 'hash-de-outro',
        },
      },
    });

    const entrada = validarDecidirAtivacaoCoordenador({
      commandId: 'cmd-de-outro-12345678',
      fichaId,
      decisao: 'APROVADO',
      confirmouReuniaoPastores: true,
      expectedVersion: 1,
    });

    await expect(
      decidirAtivacaoCoordenadorRepo(
        db,
        {
          commandId: entrada.commandId,
          coordenadorUid: coordUid,
        },
        entrada,
      ),
    ).rejects.toThrow(SemAutoridadeCoordenadorError);
  });
});

describe('Story 3.3: Callables e Proteção de Autenticação', () => {
  it('obterFilaCoordenador exige autenticação', async () => {
    const fn = (obterFilaCoordenador as any).run;
    expect(typeof fn).toBe('function');
    await expect(fn({ auth: null })).rejects.toThrow('É necessário entrar na conta.');
  });

  it('decidirAtivacaoCoordenador exige autenticação', async () => {
    const fn = (decidirAtivacaoCoordenador as any).run;
    expect(typeof fn).toBe('function');
    await expect(
      fn({ auth: null, data: {} }),
    ).rejects.toThrow('É necessário entrar na conta.');
  });
});
