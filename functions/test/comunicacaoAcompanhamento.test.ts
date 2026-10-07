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
            get: async () => ({ docs }),
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

    it('obterMinhasNotificacoesRepo retorna apenas as notificações do usuário ordenadas por data', async () => {
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
      ];

      const mockDb: any = {
        collection: (col: string) => ({
          where: (campo: string, op: string, valor: string) => ({
            get: async () => ({ docs }),
          }),
        }),
      };

      const resultado = await obterMinhasNotificacoesRepo(mockDb, 'vol-300');

      expect(resultado).toHaveLength(2);
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
});
