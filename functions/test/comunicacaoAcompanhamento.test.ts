import { describe, expect, it } from 'vitest';
import {
  MENSAGEM_NEUTRA_CANONICA,
  construirNotificacaoVoluntario,
  validarAusenciaPIIEJustificativas,
} from '../src/domain/notificacao.js';
import {
  MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA,
} from '../src/domain/participacao.js';
import {
  obterMinhasParticipacoesRepo,
} from '../src/repositories/participacao.js';
import {
  obterMinhaFichaRepo,
} from '../src/repositories/ficha.js';
import {
  emitirNotificacaoSeguraRepo,
  obterMinhasNotificacoesRepo,
} from '../src/repositories/notificacao.js';
import { obterMinhasNotificacoes } from '../src/commands/obterMinhasNotificacoes.js';
import { mapearEventoAuditoriaParaNotificacao } from '../src/domain/notificacao.js';
import { processarEventoAuditOutbox } from '../src/triggers/notificacoes.js';
import { obterDetalheSolicitacaoRepo } from '../src/repositories/detalheSolicitacao.js';
import { SemVinculoVigenteError } from '../src/domain/detalheSolicitacao.js';

describe('Story 3.4: Comunicação de decisões e acompanhamento por público', () => {
  describe('Sanitização de Projeções do Voluntário (AD-11, AD-12 e FR28)', () => {
    it('obterMinhasParticipacoesRepo sanitiza participações com decisão desfavorável com mensagem neutra canônica', async () => {
      const docs = [
        {
          id: 'part-rejeitada-1',
          data: () => ({
            fichaId: 'voluntario-1',
            equipeId: 'eq-apoio',
            nomeEquipe: 'Apoio',
            estado: 'REJEITADA',
            ciclo: 'INICIAL',
            proximaAcao: 'Justificativa interna sigilosa do avaliador que não deve vazar',
            justificativaInterna: 'Não atendeu aos pré-requisitos espirituais locais',
            decisaoPastorLocal: {
              decisao: 'DESFAVORAVEL',
              pastorUid: 'pastor-sigiloso',
              pastorNome: 'Pastor João',
              justificativa: 'Falta assiduidade',
            },
          }),
        },
        {
          id: 'part-ativa-1',
          data: () => ({
            fichaId: 'voluntario-1',
            equipeId: 'eq-louvor',
            nomeEquipe: 'Louvor',
            estado: 'ATIVA',
            ciclo: 'INICIAL',
            proximaAcao: 'Voluntariado ativo',
            vigenciaInicio: '2026-10-01T00:00:00.000Z',
            vigenciaFim: '2027-10-01T00:00:00.000Z',
            cicloAtualId: 'ciclo_part-ativa-1_2026',
          }),
        },
        {
          id: 'part-pendente-1',
          data: () => ({
            fichaId: 'voluntario-1',
            equipeId: 'eq-transporte',
            nomeEquipe: 'Transporte',
            estado: 'AGUARDANDO_COORDENADOR',
            ciclo: 'INICIAL',
            proximaAcao: 'Aguardando homologação do Coordenador Geral',
          }),
        },
      ];

      const mockDb: any = {
        collection: (col: string) => ({
          where: (campo: string, op: string, valor: string) => ({
            limit: () => ({ get: async () => ({ docs }) }),
          }),
        }),
      };

      const resultado = await obterMinhasParticipacoesRepo(mockDb, 'voluntario-1');

      expect(resultado).toHaveLength(3);

      // 1. Participação com decisão desfavorável (Apoio)
      const partDesfavoravel = resultado.find((p) => p.nomeEquipe === 'Apoio')!;
      expect(partDesfavoravel).toBeDefined();
      expect(partDesfavoravel.proximaAcao).toBe(
        'Procure o Pastor da igreja local para mais informações',
      );
      expect(partDesfavoravel.proximaAcao).toBe(MENSAGEM_VOLUNTARIO_DECISAO_NEGATIVA);
      expect((partDesfavoravel as any).justificativaInterna).toBeUndefined();
      expect((partDesfavoravel as any).decisaoPastorLocal).toBeUndefined();
      // Não pode conter a palavra "rejeitado" na mensagem de orientação
      expect(partDesfavoravel.proximaAcao).not.toContain('rejeitado');
      expect(partDesfavoravel.proximaAcao).not.toContain('indeferido');

      // 2. Participação ativa (Louvor)
      const partAtiva = resultado.find((p) => p.nomeEquipe === 'Louvor')!;
      expect(partAtiva).toBeDefined();
      expect(partAtiva.estado).toBe('ATIVA');
      expect(partAtiva.proximaAcao).toBe('Voluntariado ativo');
      expect(partAtiva.vigenciaInicio).toBe('2026-10-01T00:00:00.000Z');
      expect(partAtiva.vigenciaFim).toBe('2027-10-01T00:00:00.000Z');
      expect(partAtiva.cicloAtualId).toBe('ciclo_part-ativa-1_2026');

      // 3. Participação em tramitação (Transporte)
      const partPendente = resultado.find((p) => p.nomeEquipe === 'Transporte')!;
      expect(partPendente).toBeDefined();
      expect(partPendente.estado).toBe('AGUARDANDO_COORDENADOR');
      expect(partPendente.proximaAcao).toBe('Aguardando homologação do Coordenador Geral');
    });

    it('obterMinhaFichaRepo sanitiza a ficha consolidada em caso de decisão desfavorável geral', async () => {
      const mockDoc = {
        exists: true,
        data: () => ({
          ownerUid: 'voluntario-recusado',
          nomeCompleto: 'Irmão Silveira',
          profissao: 'Engenheiro',
          cpf: '12345678901',
          igrejaId: 'igreja-1',
          estado: 'REJEITADA',
          versao: 3,
          mensagemVoluntario: 'Procure o Pastor da igreja local para mais informações',
          justificativaInterna: 'Justificativa confidencial do conselho de pastores',
        }),
      };

      const mockDb: any = {
        collection: (col: string) => ({
          doc: (id: string) => ({
            get: async () => mockDoc,
          }),
        }),
      };

      const ficha = await obterMinhaFichaRepo(mockDb, 'voluntario-recusado');

      expect(ficha).not.toBeNull();
      expect(ficha!.estado).toBe('REJEITADA');
      expect(ficha!.proximaAcao).toBe('Procure o Pastor da igreja local para mais informações');
      expect(ficha!.mensagemVoluntario).toBe('Procure o Pastor da igreja local para mais informações');
      expect((ficha as any).justificativaInterna).toBeUndefined();
    });
  });

  describe('Notificações Seguras Pós-Compromisso (AD-10 e AD-12)', () => {
    it('construirNotificacaoVoluntario para decisão favorável gera payload seguro sem PII', () => {
      const notif = construirNotificacaoVoluntario(
        'notif-1',
        'voluntario-10',
        'DECISAO_COORDENADOR',
        'ATIVA',
        '/minha-ficha',
        '2026-10-06T20:00:00.000Z',
      );

      expect(notif.destinatarioUid).toBe('voluntario-10');
      expect(notif.estado).toBe('ATIVA');
      expect(notif.proximaAcao).toBe('Voluntariado ativo no Maanaim');
      expect(notif.deepLink).toBe('/minha-ficha');

      const checagem = validarAusenciaPIIEJustificativas(notif as any);
      expect(checagem.seguro).toBe(true);
    });

    it('construirNotificacaoVoluntario para decisão desfavorável usa mensagem canônica e não expõe "REJEITADA"', () => {
      const notif = construirNotificacaoVoluntario(
        'notif-2',
        'voluntario-20',
        'DECISAO_PASTOR_LOCAL',
        'REJEITADA',
        '/minha-ficha',
        '2026-10-06T20:00:00.000Z',
      );

      expect(notif.destinatarioUid).toBe('voluntario-20');
      expect(notif.estado).toBe('DECISAO_CONCLUIDA');
      expect(notif.proximaAcao).toBe(MENSAGEM_NEUTRA_CANONICA);
      expect(notif.proximaAcao).toBe('Procure o Pastor da igreja local para mais informações');

      const checagem = validarAusenciaPIIEJustificativas(notif as any);
      expect(checagem.seguro).toBe(true);
    });

    it('validarAusenciaPIIEJustificativas detecta e barra violações com CPF ou justificativas', () => {
      // Violação por CPF
      const payloadComCpf = {
        destinatarioUid: 'u1',
        proximaAcao: 'Verifique seu CPF 123.456.789-00',
      };
      expect(validarAusenciaPIIEJustificativas(payloadComCpf).seguro).toBe(false);

      // Violação por justificativa interna
      const payloadComJustificativa = {
        destinatarioUid: 'u2',
        justificativaInterna: 'Falta assiduidade aos cultos',
      };
      expect(validarAusenciaPIIEJustificativas(payloadComJustificativa).seguro).toBe(false);

      // Violação por palavra rejeitado
      const payloadComRejeitado = {
        destinatarioUid: 'u3',
        mensagem: 'Seu pedido foi rejeitado',
      };
      expect(validarAusenciaPIIEJustificativas(payloadComRejeitado).seguro).toBe(false);

      // Violação por chave de PII em camelCase/alias (checagem case-insensitive)
      const payloadComNomeCompleto = {
        destinatarioUid: 'u4',
        nomeCompleto: 'José da Silva',
      };
      expect(validarAusenciaPIIEJustificativas(payloadComNomeCompleto).seguro).toBe(false);
      const payloadComCpfMaiusculo = { destinatarioUid: 'u5', CPF: '00000000000' };
      expect(validarAusenciaPIIEJustificativas(payloadComCpfMaiusculo).seguro).toBe(false);
    });

    it('emitirNotificacaoSeguraRepo persiste a notificação validada no Firestore', async () => {
      let gravado: any = null;
      const mockDb: any = {
        collection: (col: string) => ({
          doc: (id: string) => ({
            set: async (dados: any) => {
              gravado = dados;
            },
          }),
        }),
      };

      const resultado = await emitirNotificacaoSeguraRepo(mockDb, {
        commandId: 'cmd-notif-100',
        destinatarioUid: 'voluntario-100',
        tipo: 'DECISAO_COORDENADOR',
        estado: 'ATIVA',
      });

      expect(resultado.destinatarioUid).toBe('voluntario-100');
      expect(resultado.proximaAcao).toBe('Voluntariado ativo no Maanaim');
      expect(gravado).not.toBeNull();
      expect(gravado.commandId).toBe('cmd-notif-100');
      expect(gravado.destinatarioUid).toBe('voluntario-100');
    });

    it('emitirNotificacaoSeguraRepo lança erro se payload violar invariante de segurança', async () => {
      const mockDb: any = {
        collection: () => ({ doc: () => ({ set: async () => {} }) }),
      };

      await expect(
        emitirNotificacaoSeguraRepo(mockDb, {
          commandId: 'cmd-violacao',
          destinatarioUid: 'voluntario-200',
          tipo: 'DECISAO_PASTOR_LOCAL',
          estado: 'REJEITADA',
          deepLink: '/minha-ficha?motivo=rejeitado',
        }),
      ).rejects.toThrow(/Tentativa de emitir notificação inválida/);
    });

    it('obterMinhasNotificacoesRepo isola por destinatarioUid (ignora notificações de outro usuário)', async () => {
      const docs = [
        {
          id: 'n-1',
          data: () => ({
            destinatarioUid: 'vol-300',
            tipo: 'FICHA_ENVIADA',
            estado: 'AGUARDANDO_PASTOR_LOCAL',
            proximaAcao: 'Acompanhe o andamento da sua solicitação',
            deepLink: '/minha-ficha',
            criadoEm: '2026-10-06T10:00:00.000Z',
          }),
        },
        {
          id: 'n-2',
          data: () => ({
            destinatarioUid: 'vol-300',
            tipo: 'DECISAO_COORDENADOR',
            estado: 'ATIVA',
            proximaAcao: 'Voluntariado ativo no Maanaim',
            deepLink: '/minha-ficha',
            criadoEm: '2026-10-06T18:00:00.000Z',
          }),
        },
        {
          id: 'n-intruso',
          data: () => ({
            destinatarioUid: 'outro-voluntario',
            tipo: 'DECISAO_COORDENADOR',
            estado: 'ATIVA',
            proximaAcao: 'Voluntariado ativo no Maanaim',
            deepLink: '/minha-ficha',
            criadoEm: '2026-10-06T20:00:00.000Z',
          }),
        },
      ];

      // O mock honra o filtro `where` para provar o isolamento por uid.
      const mockDb: any = {
        collection: (col: string) => ({
          where: (campo: string, op: string, valor: string) => ({
            limit: () => ({
              get: async () => ({
                docs: docs.filter((d) => (d.data() as any)[campo] === valor),
              }),
            }),
          }),
        }),
      };

      const resultado = await obterMinhasNotificacoesRepo(mockDb, 'vol-300');

      expect(resultado).toHaveLength(2);
      expect(resultado.map((n) => n.id)).not.toContain('n-intruso');
      // Mais recente primeiro
      expect(resultado[0].id).toBe('n-2');
      expect(resultado[1].id).toBe('n-1');
    });
  });

  describe('Callable de Notificações e Reautorização em Runtime', () => {
    it('obterMinhasNotificacoes rejeita requisição não autenticada', async () => {
      await expect(
        obterMinhasNotificacoes.run({ auth: null, data: {} } as any),
      ).rejects.toThrow('É necessário entrar na conta.');
    });

    it('obterMinhasNotificacoes rejeita tentativa de consultar notificações de outro voluntário', async () => {
      await expect(
        obterMinhasNotificacoes.run({
          auth: { uid: 'voluntario-a' },
          data: { uid: 'voluntario-b' },
        } as any),
      ).rejects.toThrow('Não é permitido consultar as notificações de outro voluntário.');
    });
  });

  describe('Trigger de notificações pós-compromisso (AD-10)', () => {
    it('mapeia eventos decisórios de auditOutbox para parâmetros de notificação', () => {
      const enviada = mapearEventoAuditoriaParaNotificacao({
        acao: 'FICHA_ENVIADA_APROVACAO',
        entidades: [{ tipo: 'FICHA', id: 'vol-1' }],
        depois: { estado: 'AGUARDANDO_PASTOR_LOCAL' },
      });
      expect(enviada).toEqual({
        destinatarioUid: 'vol-1',
        tipo: 'FICHA_ENVIADA',
        estado: 'AGUARDANDO_PASTOR_LOCAL',
      });

      const coordenador = mapearEventoAuditoriaParaNotificacao({
        action: 'DECISAO_COORDENADOR',
        fichaId: 'vol-2',
        novoEstadoFicha: 'ATIVA',
      });
      expect(coordenador).toEqual({
        destinatarioUid: 'vol-2',
        tipo: 'DECISAO_COORDENADOR',
        estado: 'ATIVA',
      });
    });

    it('não gera notificação para eventos não decisórios ou sem destinatário', () => {
      expect(
        mapearEventoAuditoriaParaNotificacao({
          action: 'FICHA_ATUALIZADA',
          fichaId: 'vol-1',
          estado: 'RASCUNHO',
        }),
      ).toBeNull();
      expect(
        mapearEventoAuditoriaParaNotificacao({
          action: 'DECISAO_COORDENADOR',
          novoEstadoFicha: 'ATIVA',
        }),
      ).toBeNull();
    });

    it('processarEventoAuditOutbox emite notificação idempotente a partir do evento', async () => {
      const gravados: any[] = [];
      const db: any = {
        collection: () => ({
          doc: (id: string) => ({
            set: async (dados: any) => {
              gravados.push({ id, dados });
            },
          }),
        }),
      };

      const emitida = await processarEventoAuditOutbox(db, 'cmd-notif-1', {
        action: 'DECISAO_COORDENADOR',
        fichaId: 'vol-9',
        novoEstadoFicha: 'ATIVA',
      });

      expect(emitida).toBe(true);
      expect(gravados).toHaveLength(1);
      expect(gravados[0].id).toBe('notif_cmd-notif-1_vol-9');
      expect(gravados[0].dados.destinatarioUid).toBe('vol-9');
      expect(gravados[0].dados.proximaAcao).toBe('Voluntariado ativo no Maanaim');
    });

    it('processarEventoAuditOutbox ignora eventos não notificáveis', async () => {
      const gravados: any[] = [];
      const db: any = {
        collection: () => ({
          doc: (id: string) => ({
            set: async (dados: any) => {
              gravados.push({ id, dados });
            },
          }),
        }),
      };

      const emitida = await processarEventoAuditOutbox(db, 'cmd-save', {
        action: 'FICHA_ATUALIZADA',
        fichaId: 'vol-9',
        estado: 'RASCUNHO',
      });

      expect(emitida).toBe(false);
      expect(gravados).toHaveLength(0);
    });
  });

  describe('Reautorização em runtime de acesso a solicitação (AD-2)', () => {
    function mockDetalheDb(overrides: {
      ficha?: Record<string, unknown>;
      igreja?: Record<string, unknown>;
      vinculoPastorIgreja?: Record<string, unknown>;
      equipe?: Record<string, unknown>;
      vinculoPastorEquipe?: Record<string, unknown>;
      autoridade?: Record<string, unknown>;
      participacoes?: Array<Record<string, unknown> & { id: string }>;
    }): any {
      return {
        collection: (col: string) => ({
          doc: () => ({
            get: async () => {
              const data =
                col === 'fichas'
                  ? overrides.ficha
                  : col === 'igrejas'
                    ? overrides.igreja
                    : col === 'vinculosPastorIgreja'
                      ? overrides.vinculoPastorIgreja
                      : col === 'equipes'
                        ? overrides.equipe
                        : col === 'vinculosPastorEquipe'
                          ? overrides.vinculoPastorEquipe
                          : col === 'autoridadesAdministrativas'
                            ? overrides.autoridade
                            : undefined;
              return { exists: data !== undefined, data: () => data ?? {} };
            },
          }),
          where: () => ({
            limit: () => ({
              get: async () => ({
                docs: (overrides.participacoes ?? []).map((p) => ({
                  id: p.id,
                  data: () => p,
                })),
              }),
            }),
          }),
        }),
      };
    }

    it('voluntário dono acessa a própria solicitação', async () => {
      const db = mockDetalheDb({
        ficha: { ownerUid: 'vol-1', igrejaId: 'ig-1', nomeCompleto: 'Ana', estado: 'ATIVA', versao: 4 },
        participacoes: [{ id: 'p1', equipeId: 'eq-1', nomeEquipe: 'Louvor', estado: 'ATIVA', ciclo: '2026' }],
      });

      const detalhe = await obterDetalheSolicitacaoRepo(db, 'vol-1', 'vol-1');

      expect(detalhe.papelSolicitante).toBe('VOLUNTARIO');
      expect(detalhe.participacoes).toHaveLength(1);
    });

    it('pastor com vínculo vigente acessa a solicitação da sua igreja', async () => {
      const db = mockDetalheDb({
        ficha: { ownerUid: 'vol-2', igrejaId: 'ig-2', nomeCompleto: 'João', estado: 'AGUARDANDO_PASTOR_LOCAL', versao: 2 },
        igreja: { ativo: true, pastorLocalVigentePessoaId: 'pastor-1', pastorLocalVigenteVinculoId: 'v-1' },
        vinculoPastorIgreja: { estado: 'VIGENTE', pessoaId: 'pastor-1' },
      });

      const detalhe = await obterDetalheSolicitacaoRepo(db, 'pastor-1', 'vol-2');

      expect(detalhe.papelSolicitante).toBe('PASTOR_LOCAL');
      expect(detalhe.vinculoId).toBe('v-1');
    });

    it('bloqueia pastor cujo vínculo foi encerrado (deep link após expiração)', async () => {
      const db = mockDetalheDb({
        ficha: { ownerUid: 'vol-2', igrejaId: 'ig-2', nomeCompleto: 'João', estado: 'AGUARDANDO_PASTOR_LOCAL', versao: 2 },
        igreja: { ativo: true, pastorLocalVigentePessoaId: 'pastor-1', pastorLocalVigenteVinculoId: 'v-1' },
        vinculoPastorIgreja: { estado: 'ENCERRADO', pessoaId: 'pastor-1' },
      });

      await expect(
        obterDetalheSolicitacaoRepo(db, 'pastor-1', 'vol-2'),
      ).rejects.toThrow(SemVinculoVigenteError);
    });

    it('responsável vigente de uma equipe da ficha acessa a solicitação', async () => {
      const db = mockDetalheDb({
        ficha: { ownerUid: 'vol-3', igrejaId: 'ig-3', nomeCompleto: 'Maria', estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE', versao: 2 },
        igreja: { ativo: true },
        equipe: { responsavelVigentePessoaId: 'resp-1', responsavelVigenteVinculoId: 've-1' },
        vinculoPastorEquipe: { estado: 'VIGENTE', pessoaId: 'resp-1' },
        participacoes: [{ id: 'p1', equipeId: 'eq-9', nomeEquipe: 'Apoio', estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE' }],
      });

      const detalhe = await obterDetalheSolicitacaoRepo(db, 'resp-1', 'vol-3');

      expect(detalhe.papelSolicitante).toBe('RESPONSAVEL_EQUIPE');
    });

    it('bloqueia usuário sem vínculo vigente com permission-denied', async () => {
      const db = mockDetalheDb({
        ficha: { ownerUid: 'vol-4', igrejaId: 'ig-4', nomeCompleto: 'Rui', estado: 'AGUARDANDO_PASTOR_LOCAL', versao: 1 },
        igreja: { ativo: true, pastorLocalVigentePessoaId: 'outro-pastor' },
        participacoes: [{ id: 'p1', equipeId: 'eq-x', nomeEquipe: 'Som', estado: 'AGUARDANDO_PASTOR_LOCAL' }],
        equipe: { responsavelVigentePessoaId: 'outro-resp' },
      });

      await expect(
        obterDetalheSolicitacaoRepo(db, 'intruso', 'vol-4'),
      ).rejects.toThrow('Usuário não possui vínculo vigente.');
    });
  });
});
