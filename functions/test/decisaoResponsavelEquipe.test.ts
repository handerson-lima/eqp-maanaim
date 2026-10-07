import { describe, expect, it } from 'vitest';
import {
  ComandoDivergenteError,
  ConflitoVersaoError,
  DecisaoInvalidaError,
  JustificativaObrigatoriaError,
  MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
  ParticipacaoNaoAguardandoResponsavelError,
  ParticipacaoNaoEncontradaError,
  SemVinculoResponsavelEquipeError,
  calcularPayloadHashDecisaoResponsavel,
  normalizarDecisao,
  validarDecidirParticipacaoResponsavel,
} from '../src/domain/decisaoResponsavelEquipe.js';
import {
  decidirParticipacaoResponsavelEquipeRepo,
  obterFilaResponsavelEquipeRepo,
} from '../src/repositories/decisaoResponsavelEquipe.js';
import { obterFilaResponsavelEquipe } from '../src/commands/obterFilaResponsavelEquipe.js';
import { decidirParticipacaoResponsavelEquipe } from '../src/commands/decidirParticipacaoResponsavelEquipe.js';

describe('Story 3.2: Domínio de Decisão por Responsável de Equipe', () => {
  const dadosAprovacao = {
    commandId: 'cmd-responsavel-equipe-123456',
    participacaoId: 'part-01',
    decisao: 'APROVADO',
    expectedVersion: 1,
  };

  it('normaliza decisões válidas', () => {
    expect(normalizarDecisao('APROVADO')).toBe('APROVADO');
    expect(normalizarDecisao('aprovar')).toBe('APROVADO');
    expect(normalizarDecisao('DESFAVORAVEL')).toBe('DESFAVORAVEL');
    expect(normalizarDecisao('desfavorável')).toBe('DESFAVORAVEL');
    expect(normalizarDecisao('RECUSADO')).toBe('DESFAVORAVEL');
    expect(normalizarDecisao('recusar')).toBe('DESFAVORAVEL');
  });

  it('rejeita decisões inválidas', () => {
    expect(() => normalizarDecisao('TALVEZ')).toThrow(DecisaoInvalidaError);
    expect(() => normalizarDecisao(123)).toThrow(DecisaoInvalidaError);
  });

  it('valida comando de aprovação com cálculo determinístico de hash', () => {
    const entrada = validarDecidirParticipacaoResponsavel(dadosAprovacao);
    expect(entrada.commandId).toBe(dadosAprovacao.commandId);
    expect(entrada.participacaoId).toBe('part-01');
    expect(entrada.decisao).toBe('APROVADO');
    expect(entrada.expectedVersion).toBe(1);

    const hashCalculado = calcularPayloadHashDecisaoResponsavel({
      participacaoId: 'part-01',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });
    expect(entrada.payloadHash).toBe(hashCalculado);
  });

  it('valida comando de decisão desfavorável com justificativa', () => {
    const entrada = validarDecidirParticipacaoResponsavel({
      ...dadosAprovacao,
      decisao: 'DESFAVORAVEL',
      justificativa: 'Equipe já atingiu limite de voluntários para este ciclo.',
    });
    expect(entrada.decisao).toBe('DESFAVORAVEL');
    expect(entrada.justificativa).toBe(
      'Equipe já atingiu limite de voluntários para este ciclo.',
    );
  });

  it('rejeita decisão desfavorável sem justificativa ou menor que 5 caracteres', () => {
    expect(() =>
      validarDecidirParticipacaoResponsavel({
        ...dadosAprovacao,
        decisao: 'DESFAVORAVEL',
      }),
    ).toThrow(JustificativaObrigatoriaError);

    expect(() =>
      validarDecidirParticipacaoResponsavel({
        ...dadosAprovacao,
        decisao: 'DESFAVORAVEL',
        justificativa: 'abc',
      }),
    ).toThrow(JustificativaObrigatoriaError);
  });

  it('rejeita payload sem commandId válido ou com expectedVersion inválido', () => {
    expect(() =>
      validarDecidirParticipacaoResponsavel({
        ...dadosAprovacao,
        commandId: 'curto',
      }),
    ).toThrow(DecisaoInvalidaError);

    expect(() =>
      validarDecidirParticipacaoResponsavel({
        ...dadosAprovacao,
        expectedVersion: -1,
      }),
    ).toThrow(DecisaoInvalidaError);
  });
});

describe('Story 3.2: Repositório de Fila e Decisão do Responsável de Equipe', () => {
  const respUid = 'resp-uid-100';
  const outroRespUid = 'resp-uid-200';
  const equipeCozinhaId = 'equipe-cozinha';
  const equipeLouvorId = 'equipe-louvor';
  const voluntarioUid = 'voluntario-01';
  const fichaId = 'voluntario-01';

  function criarMockDb(cenario: {
    equipes?: Record<string, any>;
    vinculosEquipe?: Record<string, any>;
    pessoas?: Record<string, any>;
    fichas?: Record<string, any>;
    igrejas?: Record<string, any>;
    participacoes?: Array<{ id: string; fichaId: string; equipeId: string; estado: string; data: any }>;
    recibos?: Record<string, any>;
  }) {
    const updates: Array<{ ref: any; data: any }> = [];
    const sets: Array<{ ref: any; data: any }> = [];
    const deletes: Array<{ ref: any }> = [];
    const creates: Array<{ ref: any; data: any }> = [];

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({
          col,
          id,
          get: async () => {
            if (col === 'equipes') {
              const d = cenario.equipes?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'vinculosPastorEquipe') {
              const d = cenario.vinculosEquipe?.[id];
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
            if (col === 'commands') {
              const d = cenario.recibos?.[id];
              return { exists: !!d, id, data: () => d };
            }
            if (col === 'participacoes') {
              const p = cenario.participacoes?.find((item) => item.id === id);
              return { exists: !!p, id, data: () => p ? { ...p.data, estado: p.estado, equipeId: p.equipeId, fichaId: p.fichaId } : undefined };
            }
            return { exists: false, id, data: () => undefined };
          },
        }),
        where: (field1: string, op1: string, val1: any) => ({
          where: (field2: string, op2: string, val2: any) => ({
            get: async () => {
              if (col === 'participacoes') {
                const itens = (cenario.participacoes ?? []).filter((item) => {
                  const d = { ...item.data, estado: item.estado, equipeId: item.equipeId, fichaId: item.fichaId };
                  const match1 =
                    op1 === '=='
                      ? d[field1] === val1
                      : op1 === 'in'
                        ? Array.isArray(val1) && val1.includes(d[field1])
                        : false;
                  const match2 =
                    op2 === '=='
                      ? d[field2] === val2
                      : op2 === 'in'
                        ? Array.isArray(val2) && val2.includes(d[field2])
                        : false;
                  return match1 && match2;
                });
                return {
                  docs: itens.map((i) => ({
                    id: i.id,
                    data: () => ({ ...i.data, estado: i.estado, equipeId: i.equipeId, fichaId: i.fichaId }),
                  })),
                  empty: itens.length === 0,
                };
              }
              return { docs: [], empty: true };
            },
          }),
          get: async () => {
            if (col === 'equipes') {
              const itens = Object.entries(cenario.equipes ?? {})
                .filter(([_, item]) => {
                  return op1 === '==' && item[field1] === val1;
                })
                .map(([id, data]) => ({ id, data: () => data }));
              return { docs: itens, empty: itens.length === 0 };
            }
            if (col === 'vinculosPastorEquipe') {
              const itens = Object.entries(cenario.vinculosEquipe ?? {})
                .filter(([_, item]) => {
                  return op1 === '==' && item[field1] === val1;
                })
                .map(([id, data]) => ({ id, data: () => data }));
              return { docs: itens, empty: itens.length === 0 };
            }
            if (col === 'participacoes') {
              const itens = (cenario.participacoes ?? []).filter((item) => {
                const d = { ...item.data, estado: item.estado, equipeId: item.equipeId, fichaId: item.fichaId };
                return op1 === '==' && d[field1] === val1;
              });
              return {
                docs: itens.map((i) => ({
                  id: i.id,
                  ref: { col: 'participacoes', id: i.id },
                  data: () => ({ ...i.data, estado: i.estado, equipeId: i.equipeId, fichaId: i.fichaId }),
                })),
                empty: itens.length === 0,
              };
            }
            return { docs: [], empty: true };
          },
        }),
      }),
      runTransaction: async (cb: (tx: any) => Promise<any>) => {
        let jaEscrito = false;
        const tx = {
          get: async (ref: any) => {
            if (jaEscrito) {
              throw new Error(
                'Firestore transactions require all reads to be executed before all writes.',
              );
            }
            if (ref.col === 'commands') {
              const d = cenario.recibos?.[ref.id];
              return { exists: !!d, id: ref.id, data: () => d };
            }
            if (ref.col === 'participacoes') {
              const p = cenario.participacoes?.find((item) => item.id === ref.id);
              return { exists: !!p, id: ref.id, data: () => p ? { ...p.data, estado: p.estado, equipeId: p.equipeId, fichaId: p.fichaId } : undefined };
            }
            if (ref.col === 'equipes') {
              const d = cenario.equipes?.[ref.id];
              return { exists: !!d, id: ref.id, data: () => d };
            }
            if (ref.col === 'vinculosPastorEquipe') {
              const d = cenario.vinculosEquipe?.[ref.id];
              return { exists: !!d, id: ref.id, data: () => d };
            }
            if (ref.col === 'pessoas') {
              const d = cenario.pessoas?.[ref.id];
              return { exists: !!d, id: ref.id, data: () => d };
            }
            if (ref.col === 'fichas') {
              const d = cenario.fichas?.[ref.id];
              return { exists: !!d, id: ref.id, data: () => d };
            }
            if (ref.where) {
              return ref.get();
            }
            return { exists: false, id: ref.id, data: () => undefined };
          },
          update: (ref: any, data: any) => {
            jaEscrito = true;
            updates.push({ ref, data });
          },
          set: (ref: any, data: any) => {
            jaEscrito = true;
            sets.push({ ref, data });
          },
          create: (ref: any, data: any) => {
            jaEscrito = true;
            creates.push({ ref, data });
          },
          delete: (ref: any) => {
            jaEscrito = true;
            deletes.push({ ref });
          },
        };
        return await cb(tx);
      },
      _updates: updates,
      _sets: sets,
      _deletes: deletes,
      _creates: creates,
    };

    return mockDb;
  }

  it('obterFilaResponsavelEquipeRepo retorna vazio se o usuário não é responsável por nenhuma equipe', async () => {
    const mockDb = criarMockDb({
      equipes: {
        [equipeCozinhaId]: {
          nome: 'Cozinha',
          ativo: true,
          responsavelVigentePessoaId: outroRespUid,
        },
      },
    });

    const resultado = await obterFilaResponsavelEquipeRepo(mockDb, respUid);
    expect(resultado.pendencias).toEqual([]);
    expect(resultado.equipes).toEqual([]);
  });

  it('obterFilaResponsavelEquipeRepo isola as equipes: retorna apenas pendências da equipe sob sua responsabilidade vigente', async () => {
    const mockDb = criarMockDb({
      equipes: {
        [equipeCozinhaId]: {
          nome: 'Cozinha',
          ativo: true,
          responsavelVigentePessoaId: respUid,
          responsavelVigenteVinculoId: 'vinc-cozinha',
        },
        [equipeLouvorId]: {
          nome: 'Louvor',
          ativo: true,
          responsavelVigentePessoaId: outroRespUid,
        },
      },
      vinculosEquipe: {
        'vinc-cozinha': {
          pessoaId: respUid,
          entidadeId: equipeCozinhaId,
          estado: 'VIGENTE',
        },
      },
      fichas: {
        [voluntarioUid]: {
          nomeCompleto: 'Gabriel Silva',
          igrejaId: 'igreja-01',
        },
      },
      igrejas: {
        'igreja-01': {
          nome: 'Igreja Central',
        },
      },
      participacoes: [
        {
          id: 'part-cozinha',
          fichaId: voluntarioUid,
          equipeId: equipeCozinhaId,
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          data: {
            nomeEquipe: 'Cozinha',
            versao: 1,
            proximaAcao: 'Aguardando avaliação do Responsável de Equipe',
          },
        },
        {
          id: 'part-louvor',
          fichaId: voluntarioUid,
          equipeId: equipeLouvorId,
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          data: {
            nomeEquipe: 'Louvor',
            versao: 1,
            proximaAcao: 'Aguardando avaliação do Responsável de Equipe',
          },
        },
      ],
    });

    const resultado = await obterFilaResponsavelEquipeRepo(mockDb, respUid);
    expect(resultado.equipes).toHaveLength(1);
    expect(resultado.equipes[0].id).toBe(equipeCozinhaId);
    expect(resultado.pendencias).toHaveLength(1);
    expect(resultado.pendencias[0].participacaoId).toBe('part-cozinha');
    expect(resultado.pendencias[0].equipeId).toBe(equipeCozinhaId);
    expect(resultado.pendencias[0].voluntarioNome).toBe('Gabriel Silva');
    expect(resultado.pendencias[0].nomeIgreja).toBe('Igreja Central');
    // Não expõe a outra equipe
    expect(resultado.pendencias.some((p) => p.equipeId === equipeLouvorId)).toBe(false);
  });

  it('decidirParticipacaoResponsavelEquipeRepo aprova participação de forma atômica e avança para AGUARDANDO_COORDENADOR', async () => {
    const mockDb = criarMockDb({
      equipes: {
        [equipeCozinhaId]: {
          nome: 'Cozinha',
          ativo: true,
          responsavelVigentePessoaId: respUid,
          responsavelVigenteVinculoId: 'vinc-cozinha',
        },
      },
      vinculosEquipe: {
        'vinc-cozinha': {
          pessoaId: respUid,
          entidadeId: equipeCozinhaId,
          estado: 'VIGENTE',
        },
      },
      pessoas: {
        [respUid]: { nomeCompleto: 'Pr. Carlos Santos' },
      },
      fichas: {
        [fichaId]: {
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          versao: 2,
        },
      },
      participacoes: [
        {
          id: 'part-cozinha',
          fichaId,
          equipeId: equipeCozinhaId,
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          data: {
            nomeEquipe: 'Cozinha',
            versao: 1,
          },
        },
      ],
    });

    const entrada = validarDecidirParticipacaoResponsavel({
      commandId: 'cmd-aprovacao-cozinha-12345',
      participacaoId: 'part-cozinha',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });

    const resultado = await decidirParticipacaoResponsavelEquipeRepo(
      mockDb,
      {
        commandId: entrada.commandId,
        responsavelUid: respUid,
      },
      entrada,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.repetido).toBe(false);
    expect(resultado.estado).toBe('AGUARDANDO_COORDENADOR');
    expect(resultado.versao).toBe(2);

    // Verifica update na participação
    const partUpdate = mockDb._updates.find(
      (u: any) => u.ref.col === 'participacoes' && u.ref.id === 'part-cozinha',
    );
    expect(partUpdate).toBeDefined();
    expect(partUpdate.data.estado).toBe('AGUARDANDO_COORDENADOR');
    expect(partUpdate.data.versao).toBe(2);
    expect(partUpdate.data.decisaoResponsavel.decisao).toBe('APROVADO');
    expect(partUpdate.data.decisaoResponsavel.responsavelUid).toBe(respUid);

    // Verifica evidência imutável
    const evidencia = mockDb._sets.find(
      (s: any) => s.ref.col === 'evidenciasDecisao' && s.ref.id === entrada.commandId,
    );
    expect(evidencia).toBeDefined();
    expect(evidencia.data.decisao).toBe('APROVADO');
    expect(evidencia.data.etapa).toBe('RESPONSAVEL_EQUIPE');
    expect(evidencia.data.papel).toBe('RESPONSAVEL_EQUIPE');

    // Verifica auditoria append-only SEM PII
    const auditoria = mockDb._sets.find(
      (s: any) => s.ref.col === 'auditOutbox' && s.ref.id === entrada.commandId,
    );
    expect(auditoria).toBeDefined();
    expect(auditoria.data.actorUid).toBe(respUid);
    expect(auditoria.data.action).toBe('DECISAO_RESPONSAVEL_EQUIPE');
    expect(auditoria.data.novoEstado).toBe('AGUARDANDO_COORDENADOR');
    expect(auditoria.data.voluntarioNome).toBeUndefined();
    expect(auditoria.data.cpf).toBeUndefined();

    // Verifica recibo em commands
    const recibo = mockDb._creates.find(
      (c: any) => c.ref.col === 'commands' && c.ref.id === entrada.commandId,
    );
    expect(recibo).toBeDefined();
    expect(recibo.data.status).toBe('COMPLETO');
  });

  it('mantém a ficha ATIVA ao aprovar equipe adicional quando já existe participação ativa (AD-11)', async () => {
    const equipeSomId = 'equipe-som';
    const mockDb = criarMockDb({
      equipes: {
        [equipeSomId]: {
          nome: 'Som e Mídia',
          ativo: true,
          responsavelVigentePessoaId: respUid,
          responsavelVigenteVinculoId: 'vinc-som',
        },
      },
      vinculosEquipe: {
        'vinc-som': {
          pessoaId: respUid,
          entidadeId: equipeSomId,
          estado: 'VIGENTE',
        },
      },
      pessoas: {
        [respUid]: { nomeCompleto: 'Pr. Carlos Santos' },
      },
      fichas: {
        [fichaId]: {
          estado: 'ATIVA',
          versao: 4,
        },
      },
      participacoes: [
        {
          id: 'part-recepcao',
          fichaId,
          equipeId: 'equipe-recepcao',
          estado: 'ATIVA',
          data: { nomeEquipe: 'Recepção', versao: 1, cicloAtualId: 'ciclo-recepcao' },
        },
        {
          id: 'part-som',
          fichaId,
          equipeId: equipeSomId,
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          data: { nomeEquipe: 'Som e Mídia', versao: 1, cicloAtualId: 'ciclo-som' },
        },
      ],
    });

    const entrada = validarDecidirParticipacaoResponsavel({
      commandId: 'cmd-aprovacao-adicional-12345',
      participacaoId: 'part-som',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });

    await decidirParticipacaoResponsavelEquipeRepo(
      mockDb,
      { commandId: entrada.commandId, responsavelUid: respUid },
      entrada,
    );

    // A participação adicional avança, mas a ficha permanece ATIVA (AD-11).
    const partUpdate = mockDb._updates.find(
      (u: any) => u.ref.col === 'participacoes' && u.ref.id === 'part-som',
    );
    expect(partUpdate.data.estado).toBe('AGUARDANDO_COORDENADOR');

    const fichaUpdate = mockDb._updates.find((u: any) => u.ref.col === 'fichas');
    expect(fichaUpdate).toBeDefined();
    expect(fichaUpdate.data.estado).toBe('ATIVA');
    expect(fichaUpdate.data.proximaAcao).toBe('Voluntariado ativo');
  });

  it('decidirParticipacaoResponsavelEquipeRepo recusa participação com mensagem neutra ao voluntário e justificativa interna', async () => {
    const mockDb = criarMockDb({
      equipes: {
        [equipeCozinhaId]: {
          nome: 'Cozinha',
          ativo: true,
          responsavelVigentePessoaId: respUid,
          responsavelVigenteVinculoId: 'vinc-cozinha',
        },
      },
      vinculosEquipe: {
        'vinc-cozinha': {
          pessoaId: respUid,
          entidadeId: equipeCozinhaId,
          estado: 'VIGENTE',
        },
      },
      pessoas: {
        [respUid]: { nomeCompleto: 'Pr. Carlos Santos' },
      },
      fichas: {
        [fichaId]: {
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          versao: 2,
        },
      },
      participacoes: [
        {
          id: 'part-cozinha',
          fichaId,
          equipeId: equipeCozinhaId,
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          data: {
            nomeEquipe: 'Cozinha',
            versao: 1,
          },
        },
      ],
    });

    const entrada = validarDecidirParticipacaoResponsavel({
      commandId: 'cmd-recusa-cozinha-123456',
      participacaoId: 'part-cozinha',
      decisao: 'DESFAVORAVEL',
      justificativa: 'Voluntário não atende aos pré-requisitos técnicos da escala.',
      expectedVersion: 1,
    });

    const resultado = await decidirParticipacaoResponsavelEquipeRepo(
      mockDb,
      {
        commandId: entrada.commandId,
        responsavelUid: respUid,
      },
      entrada,
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.estado).toBe('REJEITADA');

    const partUpdate = mockDb._updates.find(
      (u: any) => u.ref.col === 'participacoes' && u.ref.id === 'part-cozinha',
    );
    expect(partUpdate.data.estado).toBe('REJEITADA');
    expect(partUpdate.data.proximaAcao).toBe(MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA);
    expect(partUpdate.data.mensagemVoluntario).toBe(MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA);
    expect(partUpdate.data.justificativaInterna).toBe(
      'Voluntário não atende aos pré-requisitos técnicos da escala.',
    );

    // Evidência contém justificativa interna
    const evidencia = mockDb._sets.find(
      (s: any) => s.ref.col === 'evidenciasDecisao' && s.ref.id === entrada.commandId,
    );
    expect(evidencia.data.decisao).toBe('DESFAVORAVEL');
    expect(evidencia.data.justificativa).toBe(
      'Voluntário não atende aos pré-requisitos técnicos da escala.',
    );

    // Auditoria NÃO contém a justificativa (sem PII / sem texto livre sensível)
    const auditoria = mockDb._sets.find(
      (s: any) => s.ref.col === 'auditOutbox' && s.ref.id === entrada.commandId,
    );
    expect(auditoria.data.justificativa).toBeUndefined();
  });

  it('mantém decisões independentes em paralelo: decisão de uma equipe não bloqueia ou reverte a outra', async () => {
    const cenario = {
      equipes: {
        [equipeCozinhaId]: {
          nome: 'Cozinha',
          ativo: true,
          responsavelVigentePessoaId: respUid,
          responsavelVigenteVinculoId: 'vinc-cozinha',
        },
        [equipeLouvorId]: {
          nome: 'Louvor',
          ativo: true,
          responsavelVigentePessoaId: outroRespUid,
          responsavelVigenteVinculoId: 'vinc-louvor',
        },
      },
      vinculosEquipe: {
        'vinc-cozinha': { pessoaId: respUid, entidadeId: equipeCozinhaId, estado: 'VIGENTE' },
        'vinc-louvor': { pessoaId: outroRespUid, entidadeId: equipeLouvorId, estado: 'VIGENTE' },
      },
      fichas: {
        [fichaId]: {
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          versao: 2,
        },
      },
      participacoes: [
        {
          id: 'part-cozinha',
          fichaId,
          equipeId: equipeCozinhaId,
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          data: { nomeEquipe: 'Cozinha', versao: 1 },
        },
        {
          id: 'part-louvor',
          fichaId,
          equipeId: equipeLouvorId,
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          data: { nomeEquipe: 'Louvor', versao: 1 },
        },
      ],
    };
    const mockDb = criarMockDb(cenario);

    // 1. Responsável da Cozinha aprova
    const entradaCozinha = validarDecidirParticipacaoResponsavel({
      commandId: 'cmd-cozinha-aprov-123456',
      participacaoId: 'part-cozinha',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });
    const resCozinha = await decidirParticipacaoResponsavelEquipeRepo(
      mockDb,
      { commandId: entradaCozinha.commandId, responsavelUid: respUid },
      entradaCozinha,
    );
    expect(resCozinha.estado).toBe('AGUARDANDO_COORDENADOR');

    // Louvor ainda não foi tocado
    const louvorUpdate = mockDb._updates.find(
      (u: any) => u.ref.id === 'part-louvor',
    );
    expect(louvorUpdate).toBeUndefined();

    // 2. Responsável do Louvor recusa
    // Atualizamos o estado da participação da Cozinha no cenário para refletir a aprovação concluída
    cenario.participacoes![0].estado = 'AGUARDANDO_COORDENADOR';
    cenario.participacoes![0].data.versao = 2;

    const entradaLouvor = validarDecidirParticipacaoResponsavel({
      commandId: 'cmd-louvor-recusa-123456',
      participacaoId: 'part-louvor',
      decisao: 'DESFAVORAVEL',
      justificativa: 'Falta de disponibilidade aos sábados.',
      expectedVersion: 1,
    });
    const resLouvor = await decidirParticipacaoResponsavelEquipeRepo(
      mockDb,
      { commandId: entradaLouvor.commandId, responsavelUid: outroRespUid },
      entradaLouvor,
    );
    expect(resLouvor.estado).toBe('REJEITADA');

    // Como uma foi aprovada (Cozinha) e a outra rejeitada (Louvor), a Ficha deve ter avançado para AGUARDANDO_COORDENADOR
    const fichaUpdate = mockDb._updates.find(
      (u: any) => u.ref.col === 'fichas' && u.ref.id === fichaId,
    );
    expect(fichaUpdate).toBeDefined();
    expect(fichaUpdate.data.estado).toBe('AGUARDANDO_COORDENADOR');
  });

  it('rejeita decisão se o usuário não é o responsável vigente da equipe', async () => {
    const mockDb = criarMockDb({
      equipes: {
        [equipeCozinhaId]: {
          nome: 'Cozinha',
          ativo: true,
          responsavelVigentePessoaId: outroRespUid, // Não é o respUid!
        },
      },
      participacoes: [
        {
          id: 'part-cozinha',
          fichaId,
          equipeId: equipeCozinhaId,
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          data: { versao: 1 },
        },
      ],
    });

    const entrada = validarDecidirParticipacaoResponsavel({
      commandId: 'cmd-sem-vinculo-123456',
      participacaoId: 'part-cozinha',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });

    await expect(
      decidirParticipacaoResponsavelEquipeRepo(
        mockDb,
        { commandId: entrada.commandId, responsavelUid: respUid },
        entrada,
      ),
    ).rejects.toThrow(SemVinculoResponsavelEquipeError);
  });

  it('rejeita decisão se a versão esperada não corresponder (concorrência)', async () => {
    const mockDb = criarMockDb({
      equipes: {
        [equipeCozinhaId]: {
          nome: 'Cozinha',
          ativo: true,
          responsavelVigentePessoaId: respUid,
        },
      },
      participacoes: [
        {
          id: 'part-cozinha',
          fichaId,
          equipeId: equipeCozinhaId,
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          data: { versao: 2 }, // Versão atual é 2
        },
      ],
    });

    const entrada = validarDecidirParticipacaoResponsavel({
      commandId: 'cmd-conflito-versao-123456',
      participacaoId: 'part-cozinha',
      decisao: 'APROVADO',
      expectedVersion: 1, // Enviou 1
    });

    await expect(
      decidirParticipacaoResponsavelEquipeRepo(
        mockDb,
        { commandId: entrada.commandId, responsavelUid: respUid },
        entrada,
      ),
    ).rejects.toThrow(ConflitoVersaoError);
  });

  it('rejeita decisão se a participação não está em AGUARDANDO_RESPONSAVEL_EQUIPE', async () => {
    const mockDb = criarMockDb({
      equipes: {
        [equipeCozinhaId]: {
          nome: 'Cozinha',
          ativo: true,
          responsavelVigentePessoaId: respUid,
        },
      },
      participacoes: [
        {
          id: 'part-cozinha',
          fichaId,
          equipeId: equipeCozinhaId,
          estado: 'AGUARDANDO_COORDENADOR', // Já passou
          data: { versao: 1 },
        },
      ],
    });

    const entrada = validarDecidirParticipacaoResponsavel({
      commandId: 'cmd-ja-decidida-123456',
      participacaoId: 'part-cozinha',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });

    await expect(
      decidirParticipacaoResponsavelEquipeRepo(
        mockDb,
        { commandId: entrada.commandId, responsavelUid: respUid },
        entrada,
      ),
    ).rejects.toThrow(ParticipacaoNaoAguardandoResponsavelError);
  });

  it('garante idempotência: retorna resultado original para o mesmo commandId e rejeita se payload divergir', async () => {
    const entrada = validarDecidirParticipacaoResponsavel({
      commandId: 'cmd-idempotente-123456',
      participacaoId: 'part-cozinha',
      decisao: 'APROVADO',
      expectedVersion: 1,
    });

    const mockDb = criarMockDb({
      recibos: {
        [entrada.commandId]: {
          uid: respUid,
          payloadHash: entrada.payloadHash,
          resultado: {
            estado: 'AGUARDANDO_COORDENADOR',
            versao: 2,
            proximaAcao: 'Aguardando conclusão do Coordenador',
          },
          criadoEm: '2026-10-06T18:00:00Z',
        },
      },
    });

    // 1. Mesmo payload -> sucesso idempotente
    const resIdempotente = await decidirParticipacaoResponsavelEquipeRepo(
      mockDb,
      { commandId: entrada.commandId, responsavelUid: respUid },
      entrada,
    );
    expect(resIdempotente.sucesso).toBe(true);
    expect(resIdempotente.repetido).toBe(true);
    expect(resIdempotente.estado).toBe('AGUARDANDO_COORDENADOR');

    // 2. Mesmo commandId com payload diferente -> ComandoDivergenteError
    const entradaDivergente = {
      ...entrada,
      payloadHash: 'hash-completamente-diferente',
    };
    await expect(
      decidirParticipacaoResponsavelEquipeRepo(
        mockDb,
        { commandId: entrada.commandId, responsavelUid: respUid },
        entradaDivergente,
      ),
    ).rejects.toThrow(ComandoDivergenteError);
  });
});

describe('Story 3.2: Callables do Responsável de Equipe', () => {
  it('obterFilaResponsavelEquipe rejeita requisição não autenticada', async () => {
    const fn = (obterFilaResponsavelEquipe as any).run;
    if (typeof fn === 'function') {
      await expect(fn({ auth: null })).rejects.toThrow();
    }
  });

  it('decidirParticipacaoResponsavelEquipe rejeita requisição não autenticada', async () => {
    const fn = (decidirParticipacaoResponsavelEquipe as any).run;
    if (typeof fn === 'function') {
      await expect(fn({ auth: null, data: {} })).rejects.toThrow();
    }
  });
});
