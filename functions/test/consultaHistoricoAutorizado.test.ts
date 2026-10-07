import { describe, expect, it } from 'vitest';
import {
  AcessoNaoAutorizadoError,
  MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
  mascararCpf,
  sanitizarEventoParaVoluntario,
  type EventoLinhaDoTempo,
} from '../src/domain/consultaHistorico.js';
import {
  consultarFichaAutorizadaRepo,
  consultarLinhaDoTempoAutorizadaRepo,
  determinarEscopoAtor,
} from '../src/repositories/consultaHistorico.js';
import { consultarFichaAutorizada } from '../src/commands/consultarFichaAutorizada.js';
import { consultarLinhaDoTempoAutorizada } from '../src/commands/consultarLinhaDoTempoAutorizada.js';

function criarMockQuery(docs: any[] = []) {
  const query: any = {
    where: () => query,
    limit: () => query,
    get: async () => ({ docs, empty: docs.length === 0 }),
  };
  return query;
}

describe('Story 4.1: Consultar ficha, participações e histórico autorizado', () => {
  describe('Regras de Domínio e Sanitização (FR28, AD-12)', () => {
    it('mascararCpf oculta os primeiros e últimos dígitos mantendo apenas o miolo', () => {
      expect(mascararCpf('12345678901')).toBe('***.456.789-**');
      expect(mascararCpf('123.456.789-01')).toBe('***.456.789-**');
      expect(mascararCpf('invalido')).toBe('***.***.***-**');
    });

    it('sanitizarEventoParaVoluntario mascara avaliadores e justificativas em decisões desfavoráveis', () => {
      const eventoOriginal: EventoLinhaDoTempo = {
        id: 'ev-1',
        tipo: 'DECISAO_PASTORAL',
        etapa: 'PASTOR_LOCAL',
        titulo: 'Decisão pastoral desfavorável',
        descricao: 'Voluntário desfavorável por questões pastorais internas',
        estadoVisual: 'ORIENTACAO_PASTORAL',
        timestamp: '2026-10-06T12:00:00Z',
        ator: {
          nome: 'Pastor João Silva',
          papel: 'PASTOR_LOCAL',
        },
        justificativaInterna: 'Falta regularidade nos cultos',
      };

      const sanitizado = sanitizarEventoParaVoluntario(eventoOriginal);

      expect(sanitizado.descricao).toBe(MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA);
      expect(sanitizado.descricao).toBe('Procure o Pastor da igreja local para mais informações');
      expect(sanitizado.ator).toBeNull();
      expect(sanitizado.justificativaInterna).toBeNull();
      expect(sanitizado.titulo).not.toContain('rejeitado');
      expect(sanitizado.titulo).not.toContain('desfavorável');
    });

    it('sanitizarEventoParaVoluntario mantém eventos aprovados sem expor justificativas internas', () => {
      const eventoAprovado: EventoLinhaDoTempo = {
        id: 'ev-2',
        tipo: 'DECISAO_PASTORAL',
        etapa: 'PASTOR_LOCAL',
        titulo: 'Aprovação pastoral',
        descricao: 'Ficha e conduta aprovadas pelo Pastor da igreja local.',
        estadoVisual: 'CONCLUIDO',
        timestamp: '2026-10-06T12:00:00Z',
        ator: {
          nome: 'Pastor João Silva',
          papel: 'PASTOR_LOCAL',
        },
        justificativaInterna: 'Nota interna confidencial',
      };

      const sanitizado = sanitizarEventoParaVoluntario(eventoAprovado);

      expect(sanitizado.titulo).toBe('Aprovação pastoral');
      expect(sanitizado.descricao).toBe('Ficha e conduta aprovadas pelo Pastor da igreja local.');
      expect(sanitizado.justificativaInterna).toBeNull();
    });
  });

  describe('Revalidação Dinâmica de Escopo em Runtime (AD-9, AD-12)', () => {
    it('determinarEscopoAtor autoriza voluntário consultando sua própria ficha', async () => {
      const mockDb: any = {};
      const escopo = await determinarEscopoAtor(mockDb, 'vol-123', 'vol-123');

      expect(escopo.papel).toBe('VOLUNTARIO');
      expect(escopo.ehProprioVoluntario).toBe(true);
      expect(escopo.atorUid).toBe('vol-123');
    });

    it('determinarEscopoAtor bloqueia voluntário tentando consultar ficha alheia', async () => {
      const mockDb: any = {
        collection: (col: string) => {
          if (col === 'autoridadesAdministrativas') {
            return { doc: () => ({ get: async () => ({ exists: false }) }) };
          }
          if (col === 'fichas') {
            return {
              doc: () => ({
                get: async () => ({ exists: true, data: () => ({ igrejaId: 'igreja-1' }) }),
              }),
            };
          }
          if (col === 'igrejas') {
            return {
              doc: () => ({
                get: async () => ({ exists: true, data: () => ({ pastorLocalVigentePessoaId: 'pastor-1' }) }),
              }),
            };
          }
          return criarMockQuery([]);
        },
      };

      await expect(
        determinarEscopoAtor(mockDb, 'vol-hacker', 'vol-vitima'),
      ).rejects.toThrow(AcessoNaoAutorizadoError);
    });

    it('determinarEscopoAtor autoriza Pastor Local vigente da mesma igreja', async () => {
      const mockDb: any = {
        collection: (col: string) => {
          if (col === 'autoridadesAdministrativas') {
            return { doc: () => ({ get: async () => ({ exists: false }) }) };
          }
          if (col === 'fichas') {
            return {
              doc: (id: string) => ({
                get: async () => ({
                  exists: true,
                  data: () => ({ igrejaId: 'igreja-sede' }),
                }),
              }),
            };
          }
          if (col === 'igrejas') {
            return {
              doc: (id: string) => ({
                get: async () => ({
                  exists: true,
                  data: () => ({
                    ativo: true,
                    pastorLocalVigentePessoaId: 'pastor-sede-uid',
                  }),
                }),
              }),
            };
          }
          return criarMockQuery([]);
        },
      };

      const escopo = await determinarEscopoAtor(mockDb, 'pastor-sede-uid', 'vol-membro-sede');
      expect(escopo.papel).toBe('PASTOR_LOCAL');
      expect(escopo.igrejaId).toBe('igreja-sede');
      expect(escopo.ehProprioVoluntario).toBe(false);
    });

    it('determinarEscopoAtor rejeita pastor de outra igreja', async () => {
      const mockDb: any = {
        collection: (col: string) => {
          if (col === 'autoridadesAdministrativas') {
            return { doc: () => ({ get: async () => ({ exists: false }) }) };
          }
          if (col === 'fichas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({ igrejaId: 'igreja-bairro' }),
                }),
              }),
            };
          }
          if (col === 'igrejas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({
                    ativo: true,
                    pastorLocalVigentePessoaId: 'outro-pastor-uid',
                  }),
                }),
              }),
            };
          }
          return criarMockQuery([]);
        },
      };

      await expect(
        determinarEscopoAtor(mockDb, 'pastor-sede-uid', 'vol-membro-bairro'),
      ).rejects.toThrow(AcessoNaoAutorizadoError);
    });

    it('determinarEscopoAtor autoriza Responsável de Equipe se voluntário tiver participação na sua equipe', async () => {
      const mockDb: any = {
        collection: (col: string) => {
          if (col === 'autoridadesAdministrativas') {
            return { doc: () => ({ get: async () => ({ exists: false }) }) };
          }
          if (col === 'fichas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({ igrejaId: 'igreja-1' }),
                }),
              }),
            };
          }
          if (col === 'igrejas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({ pastorLocalVigentePessoaId: 'pastor-1' }),
                }),
              }),
            };
          }
          if (col === 'equipes') {
            return criarMockQuery([{ id: 'eq-musica', data: () => ({ ativo: true }) }]);
          }
          if (col === 'vinculosPastorEquipe') {
            return criarMockQuery([]);
          }
          if (col === 'participacoes') {
            return criarMockQuery([
              { data: () => ({ equipeId: 'eq-musica' }) },
              { data: () => ({ equipeId: 'eq-som' }) },
            ]);
          }
          return criarMockQuery([]);
        },
      };

      const escopo = await determinarEscopoAtor(mockDb, 'lider-musica', 'vol-candidato');
      expect(escopo.papel).toBe('RESPONSAVEL_EQUIPE');
      expect(escopo.equipeIdsAutorizadas).toContain('eq-musica');
    });

    it('determinarEscopoAtor bloqueia Responsável de Equipe se voluntário não tiver participação na sua equipe', async () => {
      const mockDb: any = {
        collection: (col: string) => {
          if (col === 'autoridadesAdministrativas') {
            return { doc: () => ({ get: async () => ({ exists: false }) }) };
          }
          if (col === 'fichas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({ igrejaId: 'igreja-1' }),
                }),
              }),
            };
          }
          if (col === 'igrejas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({ pastorLocalVigentePessoaId: 'pastor-1' }),
                }),
              }),
            };
          }
          if (col === 'equipes') {
            return criarMockQuery([{ id: 'eq-musica', data: () => ({ ativo: true }) }]);
          }
          if (col === 'vinculosPastorEquipe') {
            return criarMockQuery([]);
          }
          if (col === 'participacoes') {
            return criarMockQuery([
              { data: () => ({ equipeId: 'eq-apoio' }) }, // Não tem eq-musica!
            ]);
          }
          return criarMockQuery([]);
        },
      };

      await expect(
        determinarEscopoAtor(mockDb, 'lider-musica', 'vol-sem-musica'),
      ).rejects.toThrow(AcessoNaoAutorizadoError);
    });

    it('determinarEscopoAtor autoriza Coordenador Geral com autoridade ativa', async () => {
      const mockDb: any = {
        collection: (col: string) => {
          if (col === 'autoridadesAdministrativas') {
            return {
              doc: (id: string) => ({
                get: async () => ({
                  exists: true,
                  data: () => ({
                    ativa: true,
                    papeis: ['COORDENADOR'],
                    revisao: 1,
                  }),
                }),
              }),
            };
          }
          return criarMockQuery([]);
        },
      };

      const escopo = await determinarEscopoAtor(mockDb, 'coord-geral-uid', 'qualquer-ficha');
      expect(escopo.papel).toBe('COORDENADOR_GERAL');
      expect(escopo.ehProprioVoluntario).toBe(false);
    });
  });

  describe('Consulta de Ficha e Participações Segregadas (consultarFichaAutorizadaRepo)', () => {
    it('isola participações para Responsável de Equipe (oculta equipes de terceiros)', async () => {
      const mockFicha = {
        ownerUid: 'vol-1',
        nomeCompleto: 'Gabriel Silva',
        profissao: 'Músico',
        cpf: '11122233344',
        igrejaId: 'igreja-1',
        estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
        versao: 2,
      };

      const mockParticipacoes = [
        {
          id: 'part-louvor',
          data: () => ({
            fichaId: 'vol-1',
            equipeId: 'eq-louvor',
            nomeEquipe: 'Louvor',
            estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
            ciclo: 'INICIAL',
            proximaAcao: 'Em análise',
          }),
        },
        {
          id: 'part-seguranca',
          data: () => ({
            fichaId: 'vol-1',
            equipeId: 'eq-seguranca',
            nomeEquipe: 'Segurança e Apoio',
            estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
            ciclo: 'INICIAL',
            proximaAcao: 'Em análise',
          }),
        },
      ];

      const mockDb: any = {
        collection: (col: string) => {
          if (col === 'autoridadesAdministrativas') {
            return { doc: () => ({ get: async () => ({ exists: false }) }) };
          }
          if (col === 'fichas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  id: 'vol-1',
                  data: () => mockFicha,
                }),
              }),
            };
          }
          if (col === 'igrejas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({ nome: 'Igreja Central', pastorLocalVigentePessoaId: 'pastor-x' }),
                }),
              }),
            };
          }
          if (col === 'equipes') {
            return {
              where: () => criarMockQuery([{ id: 'eq-louvor', data: () => ({ ativo: true }) }]),
              doc: () => ({ get: async () => ({ exists: true, data: () => ({ nome: 'Louvor' }) }) }),
            };
          }
          if (col === 'vinculosPastorEquipe') {
            return criarMockQuery([]);
          }
          if (col === 'participacoes') {
            return criarMockQuery(mockParticipacoes);
          }
          return criarMockQuery([]);
        },
      };

      const resultado = await consultarFichaAutorizadaRepo(mockDb, 'lider-louvor', 'vol-1');

      expect(resultado.existe).toBe(true);
      expect(resultado.escopo.papel).toBe('RESPONSAVEL_EQUIPE');
      expect(resultado.escopo.equipesFiltradas).toBe(true);

      // O líder do Louvor só recebe a participação do Louvor!
      expect(resultado.participacoes).toHaveLength(1);
      expect(resultado.participacoes[0].equipeId).toBe('eq-louvor');
      expect(resultado.participacoes[0].nomeEquipe).toBe('Louvor');

      // CPF da ficha deve estar mascarado para o responsável de equipe (AD-12)
      expect(resultado.ficha?.cpfMascarado).toBe('***.222.333-**');
      expect(resultado.ficha?.cpfCompleto).toBeUndefined();
    });

    it('retorna todas as participações para o próprio voluntário com sanitização', async () => {
      const mockDb: any = {
        collection: (col: string) => {
          if (col === 'fichas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  id: 'vol-proprio',
                  data: () => ({
                    ownerUid: 'vol-proprio',
                    nomeCompleto: 'Ana Paula',
                    profissao: 'Arquiteta',
                    cpf: '98765432100',
                    igrejaId: 'igreja-2',
                    estado: 'REJEITADA',
                    versao: 1,
                  }),
                }),
              }),
            };
          }
          if (col === 'igrejas') {
            return {
              doc: () => ({
                get: async () => ({ exists: true, data: () => ({ nome: 'Igreja Norte' }) }),
              }),
            };
          }
          if (col === 'participacoes') {
            return criarMockQuery([
              {
                id: 'p-1',
                data: () => ({
                  fichaId: 'vol-proprio',
                  equipeId: 'eq-1',
                  nomeEquipe: 'Equipe 1',
                  estado: 'REJEITADA',
                  decisao: 'DESFAVORAVEL',
                  proximaAcao: 'Mensagem interna que nao deve vazar',
                }),
              },
            ]);
          }
          return criarMockQuery([]);
        },
      };

      const resultado = await consultarFichaAutorizadaRepo(mockDb, 'vol-proprio', 'vol-proprio');

      expect(resultado.existe).toBe(true);
      expect(resultado.escopo.papel).toBe('VOLUNTARIO');
      expect(resultado.ficha?.proximaAcao).toBe(MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA);
      expect(resultado.participacoes[0].proximaAcao).toBe(MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA);
      // CPF do próprio voluntário é mantido completo para conferência própria
      expect(resultado.ficha?.cpfCompleto).toBe('98765432100');
    });

    it('mascara CPF para Pastor Local e expõe completo para Coordenador', async () => {
      const dadosFicha = {
        ownerUid: 'vol-1',
        nomeCompleto: 'Carlos Souza',
        profissao: 'Pedreiro',
        cpf: '12345678901',
        igrejaId: 'igreja-1',
        estado: 'AGUARDANDO_PASTOR_LOCAL',
        versao: 1,
      };

      const criarDb = (autoridade: boolean, pastorUid: string): any => ({
        collection: (col: string) => {
          if (col === 'autoridadesAdministrativas') {
            return {
              doc: () => ({
                get: async () =>
                  autoridade
                    ? {
                        exists: true,
                        data: () => ({ ativa: true, papeis: ['COORDENADOR'], revisao: 1 }),
                      }
                    : { exists: false },
              }),
            };
          }
          if (col === 'fichas') {
            return {
              doc: () => ({
                get: async () => ({ exists: true, id: 'vol-1', data: () => dadosFicha }),
              }),
            };
          }
          if (col === 'igrejas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({
                    nome: 'Igreja Central',
                    ativo: true,
                    pastorLocalVigentePessoaId: pastorUid,
                  }),
                }),
              }),
            };
          }
          return criarMockQuery([]);
        },
      });

      const pastor = await consultarFichaAutorizadaRepo(
        criarDb(false, 'pastor-sede'),
        'pastor-sede',
        'vol-1',
      );
      expect(pastor.escopo.papel).toBe('PASTOR_LOCAL');
      expect(pastor.ficha?.cpfMascarado).toBe('***.456.789-**');
      expect(pastor.ficha?.cpfCompleto).toBeUndefined();

      const coord = await consultarFichaAutorizadaRepo(
        criarDb(true, 'outro-pastor'),
        'coord-uid',
        'vol-1',
      );
      expect(coord.escopo.papel).toBe('COORDENADOR_GERAL');
      expect(coord.ficha?.cpfCompleto).toBe('12345678901');
    });
  });

  describe('Linha do Tempo Auditável e Sanitização Contextual (consultarLinhaDoTempoAutorizadaRepo)', () => {
    it('sanitiza eventos na linha do tempo para o voluntário (oculta ator desfavorável e justificativa)', async () => {
      const mockEvidencias = [
        {
          id: 'ev-pastor-negativa',
          data: () => ({
            fichaId: 'vol-1',
            etapa: 'PASTOR_LOCAL',
            decisao: 'DESFAVORAVEL',
            atorUid: 'pastor-sigiloso',
            atorNome: 'Pastor Severino',
            justificativa: 'Falta carta de recomendação',
            timestamp: '2026-10-06T10:00:00Z',
          }),
        },
      ];

      const mockDb: any = {
        collection: (col: string) => {
          if (col === 'fichas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({
                    nomeCompleto: 'Membro Teste',
                    criadoEm: '2026-10-05T08:00:00Z',
                    atualizadoEm: '2026-10-05T09:00:00Z',
                    estado: 'REJEITADA',
                  }),
                }),
              }),
            };
          }
          if (col === 'evidenciasDecisao') {
            return criarMockQuery(mockEvidencias);
          }
          return criarMockQuery([]);
        },
      };

      const resultado = await consultarLinhaDoTempoAutorizadaRepo(mockDb, 'vol-1', 'vol-1');

      expect(resultado.eventos.length).toBeGreaterThan(0);

      const eventoPastoral = resultado.eventos.find((e) => e.etapa === 'PASTOR_LOCAL')!;
      expect(eventoPastoral).toBeDefined();
      expect(eventoPastoral.descricao).toBe(MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA);
      expect(eventoPastoral.ator).toBeNull();
      expect(eventoPastoral.justificativaInterna).toBeNull();
      expect(eventoPastoral.titulo).not.toContain('rejeitado');
    });

    it('exibe justificativa interna e ator para Pastor Local da mesma igreja', async () => {
      const mockEvidencias = [
        {
          id: 'ev-pastor-negativa',
          data: () => ({
            fichaId: 'vol-1',
            etapa: 'PASTOR_LOCAL',
            decisao: 'DESFAVORAVEL',
            atorUid: 'pastor-sede',
            atorNome: 'Pastor Severino',
            justificativa: 'Falta carta de recomendação',
            timestamp: '2026-10-06T10:00:00Z',
          }),
        },
      ];

      const mockDb: any = {
        collection: (col: string) => {
          if (col === 'autoridadesAdministrativas') {
            return { doc: () => ({ get: async () => ({ exists: false }) }) };
          }
          if (col === 'fichas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({
                    nomeCompleto: 'Membro Teste',
                    igrejaId: 'igreja-1',
                    criadoEm: '2026-10-05T08:00:00Z',
                    estado: 'REJEITADA',
                  }),
                }),
              }),
            };
          }
          if (col === 'igrejas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({ pastorLocalVigentePessoaId: 'pastor-sede' }),
                }),
              }),
            };
          }
          if (col === 'evidenciasDecisao') {
            return criarMockQuery(mockEvidencias);
          }
          return criarMockQuery([]);
        },
      };

      const resultado = await consultarLinhaDoTempoAutorizadaRepo(mockDb, 'pastor-sede', 'vol-1');

      const eventoPastoral = resultado.eventos.find((e) => e.etapa === 'PASTOR_LOCAL')!;
      expect(eventoPastoral).toBeDefined();
      expect(eventoPastoral.ator?.nome).toBe('Pastor Severino');
      expect(eventoPastoral.justificativaInterna).toBe('Falta carta de recomendação');
    });

    it('filtra a linha do tempo por participacaoId excluindo evidências de outras participações', async () => {
      const mockEvidencias = [
        {
          id: 'ev-a',
          data: () => ({
            fichaId: 'vol-1',
            participacaoId: 'p-1',
            etapa: 'RESPONSAVEL_EQUIPE',
            decisao: 'APROVADO',
            equipeId: 'eq-1',
            atorNome: 'Líder A',
            timestamp: '2026-10-06T10:00:00Z',
          }),
        },
        {
          id: 'ev-b',
          data: () => ({
            fichaId: 'vol-1',
            participacaoId: 'p-2',
            etapa: 'RESPONSAVEL_EQUIPE',
            decisao: 'APROVADO',
            equipeId: 'eq-1',
            atorNome: 'Líder B',
            timestamp: '2026-10-06T11:00:00Z',
          }),
        },
        {
          id: 'ev-sem-part',
          data: () => ({
            fichaId: 'vol-1',
            etapa: 'PASTOR_LOCAL',
            decisao: 'APROVADO',
            atorNome: 'Pastor',
            timestamp: '2026-10-06T12:00:00Z',
          }),
        },
      ];

      const mockDb: any = {
        collection: (col: string) => {
          if (col === 'fichas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({
                    nomeCompleto: 'Membro',
                    criadoEm: '2026-10-05T08:00:00Z',
                    estado: 'ATIVA',
                  }),
                }),
              }),
            };
          }
          if (col === 'evidenciasDecisao') {
            return criarMockQuery(mockEvidencias);
          }
          if (col === 'equipes') {
            return { doc: () => ({ get: async () => ({ exists: false }) }) };
          }
          return criarMockQuery([]);
        },
      };

      const todas = await consultarLinhaDoTempoAutorizadaRepo(mockDb, 'vol-1', 'vol-1');
      expect(todas.eventos.some((e) => e.id === 'ev-a')).toBe(true);
      expect(todas.eventos.some((e) => e.id === 'ev-b')).toBe(true);

      const filtrado = await consultarLinhaDoTempoAutorizadaRepo(mockDb, 'vol-1', 'vol-1', 'p-1');
      const ids = filtrado.eventos.map((e) => e.id);
      expect(ids).toContain('ev-a');
      expect(ids).not.toContain('ev-b');
      expect(ids).not.toContain('ev-sem-part');
    });

    it('isola a linha do tempo do Responsável de Equipe (sem eventos de outras equipes nem pastorais)', async () => {
      const mockEvidencias = [
        {
          id: 'ev-louvor',
          data: () => ({
            fichaId: 'vol-1',
            participacaoId: 'p-1',
            etapa: 'RESPONSAVEL_EQUIPE',
            decisao: 'APROVADO',
            equipeId: 'eq-louvor',
            atorNome: 'Líder Louvor',
            timestamp: '2026-10-06T10:00:00Z',
          }),
        },
        {
          id: 'ev-seguranca',
          data: () => ({
            fichaId: 'vol-1',
            participacaoId: 'p-2',
            etapa: 'RESPONSAVEL_EQUIPE',
            decisao: 'DESFAVORAVEL',
            equipeId: 'eq-seguranca',
            atorNome: 'Líder Segurança',
            justificativa: 'nota interna de outra equipe',
            timestamp: '2026-10-06T11:00:00Z',
          }),
        },
        {
          id: 'ev-pastor',
          data: () => ({
            fichaId: 'vol-1',
            etapa: 'PASTOR_LOCAL',
            decisao: 'DESFAVORAVEL',
            atorNome: 'Pastor Sigiloso',
            justificativa: 'sigilo pastoral',
            timestamp: '2026-10-06T12:00:00Z',
          }),
        },
      ];

      const mockDb: any = {
        collection: (col: string) => {
          if (col === 'autoridadesAdministrativas') {
            return { doc: () => ({ get: async () => ({ exists: false }) }) };
          }
          if (col === 'fichas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({
                    nomeCompleto: 'Membro',
                    igrejaId: 'igreja-1',
                    criadoEm: '2026-10-05T08:00:00Z',
                  }),
                }),
              }),
            };
          }
          if (col === 'igrejas') {
            return {
              doc: () => ({
                get: async () => ({
                  exists: true,
                  data: () => ({ pastorLocalVigentePessoaId: 'pastor-x' }),
                }),
              }),
            };
          }
          if (col === 'equipes') {
            return {
              where: () => criarMockQuery([{ id: 'eq-louvor', data: () => ({ ativo: true }) }]),
              doc: () => ({ get: async () => ({ exists: true, data: () => ({ nome: 'Louvor' }) }) }),
            };
          }
          if (col === 'participacoes') {
            return criarMockQuery([{ data: () => ({ equipeId: 'eq-louvor' }) }]);
          }
          if (col === 'evidenciasDecisao') {
            return criarMockQuery(mockEvidencias);
          }
          return criarMockQuery([]);
        },
      };

      const resultado = await consultarLinhaDoTempoAutorizadaRepo(mockDb, 'lider-louvor', 'vol-1');
      const ids = resultado.eventos.map((e) => e.id);
      expect(ids).toContain('ev-louvor');
      expect(ids).not.toContain('ev-seguranca');
      expect(ids).not.toContain('ev-pastor');
      expect(resultado.eventos.every((e) => e.justificativaInterna == null)).toBe(true);
    });
  });

  describe('Callables HTTP (consultarFichaAutorizada e consultarLinhaDoTempoAutorizada)', () => {
    it('consultarFichaAutorizada rejeita chamadas não autenticadas', async () => {
      await expect(
        (consultarFichaAutorizada as any).run({ auth: null, data: {} }),
      ).rejects.toThrow('É necessário entrar na conta.');
    });

    it('consultarLinhaDoTempoAutorizada rejeita chamadas não autenticadas', async () => {
      await expect(
        (consultarLinhaDoTempoAutorizada as any).run({ auth: null, data: {} }),
      ).rejects.toThrow('É necessário entrar na conta.');
    });

    it('rejeita payload com tipo inválido antes de acessar o Firestore', async () => {
      await expect(
        (consultarFichaAutorizada as any).run({ auth: { uid: 'u' }, data: { fichaId: 123 } }),
      ).rejects.toThrow('Parâmetros de consulta inválidos.');

      await expect(
        (consultarLinhaDoTempoAutorizada as any).run({
          auth: { uid: 'u' },
          data: { participacaoId: 5 },
        }),
      ).rejects.toThrow('Parâmetros de consulta inválidos.');
    });
  });
});
