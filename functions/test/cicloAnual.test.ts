import { describe, expect, it } from 'vitest';
import {
  CicloNaoElegivelError,
  CicloNaoEncontradoError,
  ComandoDivergenteError,
  ConflitoVersaoError,
  DecisaoInvalidaError,
  JustificativaObrigatoriaError,
  MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
  ReuniaoPastoresNaoConfirmadaError,
  SemAutoridadeCoordenadorError,
  SemVinculoPastoralError,
  SemVinculoResponsavelEquipeError,
  validarConcluirCicloAnualCoordenador,
  validarDecidirCicloAnualPastor,
  validarDecidirCicloAnualResponsavel,
} from '../src/domain/decisaoCicloAnual.js';
import {
  concluirCicloAnualCoordenadorRepo,
  decidirCicloAnualPastorRepo,
  decidirCicloAnualResponsavelRepo,
} from '../src/repositories/decisaoCicloAnual.js';

describe('Story 5.3: Validações de Domínio do Ciclo Anual', () => {
  it('valida payload do Pastor Local para aprovação', () => {
    const entrada = validarDecidirCicloAnualPastor({
      commandId: 'cmd-pastor-ciclo-001',
      cicloId: 'ciclo_part1_2026',
      decisao: 'APROVADO',
    });

    expect(entrada.commandId).toBe('cmd-pastor-ciclo-001');
    expect(entrada.cicloId).toBe('ciclo_part1_2026');
    expect(entrada.decisao).toBe('APROVADO');
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it('exige justificativa mínima de 5 caracteres para decisão pastoral desfavorável', () => {
    expect(() =>
      validarDecidirCicloAnualPastor({
        commandId: 'cmd-pastor-ciclo-002',
        cicloId: 'ciclo_part1_2026',
        decisao: 'DESFAVORAVEL',
      }),
    ).toThrow(JustificativaObrigatoriaError);

    expect(() =>
      validarDecidirCicloAnualPastor({
        commandId: 'cmd-pastor-ciclo-003',
        cicloId: 'ciclo_part1_2026',
        decisao: 'DESFAVORAVEL',
        justificativa: 'abc',
      }),
    ).toThrow(JustificativaObrigatoriaError);
  });

  it('valida payload do Responsável de Equipe', () => {
    const entrada = validarDecidirCicloAnualResponsavel({
      commandId: 'cmd-resp-ciclo-001',
      cicloId: 'ciclo_part1_2026',
      decisao: 'APROVADO',
    });

    expect(entrada.decisao).toBe('APROVADO');
    expect(entrada.payloadHash).toMatch(/^[a-f0-9]{64}$/);
  });

  it('exige confirmação de reunião de pastores para aprovação na Coordenação', () => {
    expect(() =>
      validarConcluirCicloAnualCoordenador({
        commandId: 'cmd-coord-ciclo-001',
        cicloId: 'ciclo_part1_2026',
        decisao: 'APROVADO',
        confirmouReuniaoPastores: false,
      }),
    ).toThrow(ReuniaoPastoresNaoConfirmadaError);

    const valida = validarConcluirCicloAnualCoordenador({
      commandId: 'cmd-coord-ciclo-002',
      cicloId: 'ciclo_part1_2026',
      decisao: 'APROVADO',
      confirmouReuniaoPastores: true,
      observacao: 'Homologado em reunião ministerial',
    });

    expect(valida.decisao).toBe('APROVADO');
    expect(valida.confirmouReuniaoPastores).toBe(true);
  });

  it('rejeita commandId ou cicloId inválidos', () => {
    expect(() =>
      validarDecidirCicloAnualPastor({
        commandId: 'curto',
        cicloId: 'ciclo_1',
        decisao: 'APROVADO',
      }),
    ).toThrow(DecisaoInvalidaError);
  });
});

describe('Story 5.3: Repositório e Transações do Ciclo Anual', () => {
  const pastorUid = 'pastor-titular-001';
  const responsavelUid = 'responsavel-musica-001';
  const coordenadorUid = 'coordenador-geral-001';
  const voluntarioUid = 'voluntario-001';
  const igrejaId = 'igreja-central-001';
  const equipeId = 'equipe-musica-001';
  const participacaoId = 'part-musica-001';
  const cicloId = 'ciclo_part-musica-001_2026';

  function criarMockDb(cenario: {
    ciclo?: any;
    participacao?: any;
    ficha?: any;
    igreja?: any;
    equipe?: any;
    autoridadeAdmin?: any;
    pessoas?: Record<string, any>;
    commands?: Record<string, any>;
    filaPendencias?: any;
  }) {
    const sets: Array<{ col: string; id: string; data: any }> = [];
    const updates: Array<{ col: string; id: string; data: any }> = [];
    const deletes: Array<{ col: string; id: string }> = [];

    const mockDb: any = {
      collection: (col: string) => ({
        doc: (id: string) => {
          const docRef = {
            col,
            id,
            collection: (subCol: string) => ({
              doc: (subId: string) => ({
                col: `${col}/${id}/${subCol}`,
                id: subId,
                set: (data: any) => sets.push({ col: `${col}/${id}/${subCol}`, id: subId, data }),
              }),
            }),
            get: async () => {
              if (col === 'ciclos') {
                const d = cenario.ciclo?.id === id ? cenario.ciclo : undefined;
                return { exists: !!d, id, data: () => d };
              }
              if (col === 'participacoes') {
                const d = cenario.participacao?.id === id ? cenario.participacao : undefined;
                return { exists: !!d, id, data: () => d };
              }
              if (col === 'fichas') {
                const d = cenario.ficha;
                return { exists: !!d, id, data: () => d };
              }
              if (col === 'igrejas') {
                const d = cenario.igreja;
                return { exists: !!d, id, data: () => d };
              }
              if (col === 'equipes') {
                const d = cenario.equipe;
                return { exists: !!d, id, data: () => d };
              }
              if (col === 'autoridadesAdministrativas') {
                const d = cenario.autoridadeAdmin;
                return { exists: !!d, id, data: () => d };
              }
              if (col === 'pessoas') {
                const d = cenario.pessoas?.[id];
                return { exists: !!d, id, data: () => d };
              }
              if (col === 'commands') {
                const d = cenario.commands?.[id];
                return { exists: !!d, id, data: () => d };
              }
              if (col === 'filaPendencias') {
                const d = cenario.filaPendencias;
                return { exists: !!d, id, data: () => d };
              }
              if (col === 'vinculosPastorIgreja') {
                return { exists: true, id, data: () => ({ estado: 'VIGENTE', pessoaId: pastorUid }) };
              }
              if (col === 'vinculosPastorEquipe') {
                return { exists: true, id, data: () => ({ estado: 'VIGENTE', pessoaId: responsavelUid }) };
              }
              return { exists: false, id, data: () => undefined };
            },
            set: (data: any) => sets.push({ col, id, data }),
            update: (data: any) => updates.push({ col, id, data }),
            delete: () => deletes.push({ col, id }),
          };
          return docRef;
        },
      }),
      runTransaction: async (cb: any) => {
        const tx: any = {
          get: async (ref: any) => ref.get(),
          set: (ref: any, data: any) => ref.set(data),
          update: (ref: any, data: any) => ref.update(data),
          delete: (ref: any) => ref.delete(),
        };
        return cb(tx);
      },
    };

    return { mockDb, sets, updates, deletes };
  }

  it('Pastor Local APROVA ciclo anual: avança para AGUARDANDO_RESPONSAVEL_EQUIPE', async () => {
    const { mockDb, updates, sets } = criarMockDb({
      ciclo: {
        id: cicloId,
        participacaoId,
        fichaId: voluntarioUid,
        equipeId,
        estado: 'AGUARDANDO_PASTOR_LOCAL',
        tipo: 'RENOVACAO_ANUAL',
        versao: 1,
      },
      participacao: {
        id: participacaoId,
        fichaId: voluntarioUid,
        equipeId,
        estado: 'ATIVA',
        versao: 2,
      },
      ficha: {
        id: voluntarioUid,
        igrejaId,
        estado: 'ATIVA',
      },
      igreja: {
        id: igrejaId,
        pastorLocalVigentePessoaId: pastorUid,
        pastorLocalVigenteVinculoId: 'vinc-pastor-01',
        ativo: true,
      },
      pessoas: {
        [pastorUid]: { nomeCompleto: 'Pastor João' },
      },
    });

    const resultado = await decidirCicloAnualPastorRepo(
      mockDb,
      { commandId: 'cmd-pastor-aprov-001', uid: pastorUid },
      {
        commandId: 'cmd-pastor-aprov-001',
        cicloId,
        decisao: 'APROVADO',
        payloadHash: 'hash-001',
      },
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.estadoCiclo).toBe('AGUARDANDO_RESPONSAVEL_EQUIPE');
    expect(resultado.proximaAcao).toContain('Responsável de Equipe');

    // Confirma atualização do ciclo e da participação
    const updCiclo = updates.find((u) => u.col === 'ciclos' && u.id === cicloId);
    expect(updCiclo?.data.estado).toBe('AGUARDANDO_RESPONSAVEL_EQUIPE');

    // Confirma gravação de evidência sem PII
    const ev = sets.find((s) => s.col === 'evidenciasDecisao');
    expect(ev?.data.decisao).toBe('APROVADO');
    expect(ev?.data.atorUid).toBe(pastorUid);
  });

  it('Pastor Local nega com DESFAVORAVEL: ciclo vai para REJEITADO com mensagem canônica neutra', async () => {
    const { mockDb, updates } = criarMockDb({
      ciclo: {
        id: cicloId,
        participacaoId,
        fichaId: voluntarioUid,
        equipeId,
        estado: 'AGUARDANDO_PASTOR_LOCAL',
        tipo: 'RENOVACAO_ANUAL',
        versao: 1,
      },
      participacao: {
        id: participacaoId,
        fichaId: voluntarioUid,
        equipeId,
        estado: 'ATIVA',
        vigenciaFim: '2026-12-31T23:59:59.000Z',
        versao: 2,
      },
      ficha: {
        id: voluntarioUid,
        igrejaId,
        estado: 'ATIVA',
      },
      igreja: {
        id: igrejaId,
        pastorLocalVigentePessoaId: pastorUid,
        ativo: true,
      },
    });

    const resultado = await decidirCicloAnualPastorRepo(
      mockDb,
      { commandId: 'cmd-pastor-recusa-001', uid: pastorUid },
      {
        commandId: 'cmd-pastor-recusa-001',
        cicloId,
        decisao: 'DESFAVORAVEL',
        justificativa: 'Voluntário transferido para outro ministério',
        payloadHash: 'hash-recusa-001',
      },
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.estadoCiclo).toBe('REJEITADO');
    expect(resultado.proximaAcao).toBe(MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA);

    const updPart = updates.find((u) => u.col === 'participacoes' && u.id === participacaoId);
    expect(updPart?.data.intencaoRenovacao).toBe('NAO_CONTINUAR');
    expect(updPart?.data.proximaAcao).toBe(MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA);
  });

  it('Pastor Local sem vínculo vigente é barrado com SemVinculoPastoralError', async () => {
    const { mockDb } = criarMockDb({
      ciclo: {
        id: cicloId,
        participacaoId,
        fichaId: voluntarioUid,
        equipeId,
        estado: 'AGUARDANDO_PASTOR_LOCAL',
      },
      participacao: { id: participacaoId, fichaId: voluntarioUid },
      ficha: { id: voluntarioUid, igrejaId },
      igreja: {
        id: igrejaId,
        pastorLocalVigentePessoaId: 'outro-pastor-999',
        ativo: true,
      },
    });

    await expect(
      decidirCicloAnualPastorRepo(
        mockDb,
        { commandId: 'cmd-pastor-unauth-001', uid: pastorUid },
        {
          commandId: 'cmd-pastor-unauth-001',
          cicloId,
          decisao: 'APROVADO',
          payloadHash: 'hash-001',
        },
      ),
    ).rejects.toThrow(SemVinculoPastoralError);
  });

  it('Responsável de Equipe APROVA ciclo anual: avança para AGUARDANDO_COORDENADOR', async () => {
    const { mockDb, updates } = criarMockDb({
      ciclo: {
        id: cicloId,
        participacaoId,
        fichaId: voluntarioUid,
        equipeId,
        estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
        versao: 2,
      },
      participacao: {
        id: participacaoId,
        fichaId: voluntarioUid,
        equipeId,
        estado: 'ATIVA',
        versao: 3,
      },
      equipe: {
        id: equipeId,
        responsavelVigentePessoaId: responsavelUid,
        ativo: true,
      },
      pessoas: {
        [responsavelUid]: { nomeCompleto: 'Pr. Carlos Responsável' },
      },
    });

    const resultado = await decidirCicloAnualResponsavelRepo(
      mockDb,
      { commandId: 'cmd-resp-aprov-001', uid: responsavelUid },
      {
        commandId: 'cmd-resp-aprov-001',
        cicloId,
        decisao: 'APROVADO',
        payloadHash: 'hash-resp-001',
      },
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.estadoCiclo).toBe('AGUARDANDO_COORDENADOR');
    expect(resultado.proximaAcao).toContain('Coordenador');

    const updCiclo = updates.find((u) => u.col === 'ciclos' && u.id === cicloId);
    expect(updCiclo?.data.estado).toBe('AGUARDANDO_COORDENADOR');
  });

  it('Responsável sem vínculo vigente na equipe lança SemVinculoResponsavelEquipeError', async () => {
    const { mockDb } = criarMockDb({
      ciclo: {
        id: cicloId,
        participacaoId,
        fichaId: voluntarioUid,
        equipeId,
        estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
      },
      participacao: { id: participacaoId, fichaId: voluntarioUid },
      equipe: {
        id: equipeId,
        responsavelVigentePessoaId: 'outro-responsavel-888',
        ativo: true,
      },
    });

    await expect(
      decidirCicloAnualResponsavelRepo(
        mockDb,
        { commandId: 'cmd-resp-unauth-001', uid: responsavelUid },
        {
          commandId: 'cmd-resp-unauth-001',
          cicloId,
          decisao: 'APROVADO',
          payloadHash: 'hash-001',
        },
      ),
    ).rejects.toThrow(SemVinculoResponsavelEquipeError);
  });

  it('Coordenador Geral APROVA: conclui ciclo, gera nova vigência de 1 ano e ativa participação', async () => {
    const { mockDb, updates } = criarMockDb({
      ciclo: {
        id: cicloId,
        participacaoId,
        fichaId: voluntarioUid,
        equipeId,
        estado: 'AGUARDANDO_COORDENADOR',
        versao: 3,
      },
      participacao: {
        id: participacaoId,
        fichaId: voluntarioUid,
        equipeId,
        estado: 'ATIVA',
        versao: 4,
      },
      autoridadeAdmin: {
        papeis: ['COORDENADOR'],
        ativa: true,
      },
      pessoas: {
        [coordenadorUid]: { nomeCompleto: 'Coordenador Mário' },
      },
    });

    const resultado = await concluirCicloAnualCoordenadorRepo(
      mockDb,
      { commandId: 'cmd-coord-concluir-001', uid: coordenadorUid },
      {
        commandId: 'cmd-coord-concluir-001',
        cicloId,
        decisao: 'APROVADO',
        confirmouReuniaoPastores: true,
        observacao: 'Aprovado por unanimidade',
        payloadHash: 'hash-coord-001',
      },
    );

    expect(resultado.sucesso).toBe(true);
    expect(resultado.estadoCiclo).toBe('CONCLUIDO');
    expect(resultado.proximaAcao).toBe('Voluntariado ativo');
    expect(resultado.vigenciaInicio).toBeDefined();
    expect(resultado.vigenciaFim).toBeDefined();

    // Vigência calculada de 1 ano
    const inicio = new Date(resultado.vigenciaInicio!);
    const fim = new Date(resultado.vigenciaFim!);
    expect(fim.getUTCFullYear() - inicio.getUTCFullYear()).toBe(1);

    // Valida atualização da participação
    const updPart = updates.find((u) => u.col === 'participacoes' && u.id === participacaoId);
    expect(updPart?.data.estado).toBe('ATIVA');
    expect(updPart?.data.cicloAtualId).toBe(cicloId);
    expect(updPart?.data.cicloRenovacaoId).toBeNull();
    expect(updPart?.data.intencaoRenovacao).toBeNull();
  });

  it('Coordenador sem papel administrativo ou coordenação é bloqueado com SemAutoridadeCoordenadorError', async () => {
    const { mockDb } = criarMockDb({
      ciclo: {
        id: cicloId,
        participacaoId,
        fichaId: voluntarioUid,
        equipeId,
        estado: 'AGUARDANDO_COORDENADOR',
      },
      participacao: { id: participacaoId, fichaId: voluntarioUid },
      autoridadeAdmin: {
        papeis: ['VOLUNTARIO'], // Sem papel de coordenador
      },
    });

    await expect(
      concluirCicloAnualCoordenadorRepo(
        mockDb,
        { commandId: 'cmd-coord-unauth-001', uid: 'user-comum' },
        {
          commandId: 'cmd-coord-unauth-001',
          cicloId,
          decisao: 'APROVADO',
          confirmouReuniaoPastores: true,
          payloadHash: 'hash-001',
        },
      ),
    ).rejects.toThrow(SemAutoridadeCoordenadorError);
  });

  it('Garante idempotência estrita via recibo em commands', async () => {
    const { mockDb } = criarMockDb({
      commands: {
        'cmd-repetido-001': {
          uid: pastorUid,
          payloadHash: 'hash-idempotente',
          resultado: {
            estadoCiclo: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
            proximaAcao: 'Aguardando avaliação do Responsável de Equipe',
          },
          criadoEm: new Date().toISOString(),
        },
      },
    });

    const res = await decidirCicloAnualPastorRepo(
      mockDb,
      { commandId: 'cmd-repetido-001', uid: pastorUid },
      {
        commandId: 'cmd-repetido-001',
        cicloId,
        decisao: 'APROVADO',
        payloadHash: 'hash-idempotente',
      },
    );

    expect(res.sucesso).toBe(true);
    expect(res.repetido).toBe(true);
  });
});
