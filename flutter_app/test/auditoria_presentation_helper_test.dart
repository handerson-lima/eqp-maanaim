import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/auditoria/auditoria_presentation_helper.dart';

void main() {
  group('AuditoriaPresentationHelper', () {
    test('traduz ações canônicas para linguagem clara em português', () {
      expect(
        AuditoriaPresentationHelper.obterTituloAcao('CONSULTA_AUDITORIA_GLOBAL'),
        'Consulta à Trilha de Auditoria',
      );
      expect(
        AuditoriaPresentationHelper.obterTituloAcao('CONSULTA_RELATORIO_OPERACIONAL'),
        'Emissão de Relatório Operacional',
      );
      expect(
        AuditoriaPresentationHelper.obterTituloAcao('DECISAO_PASTOR_LOCAL'),
        'Avaliação do Pastor Local',
      );
      expect(
        AuditoriaPresentationHelper.obterTituloAcao('DECISAO_RESPONSAVEL_EQUIPE'),
        'Avaliação do Responsável de Equipe',
      );
      expect(
        AuditoriaPresentationHelper.obterTituloAcao('DECIDIR_ATIVACAO_COORDENADOR'),
        'Homologação da Coordenação Geral',
      );
      expect(
        AuditoriaPresentationHelper.obterTituloAcao('ENVIAR_FICHA_APROVACAO'),
        'Envio de Ficha para Aprovação',
      );
      expect(
        AuditoriaPresentationHelper.obterTituloAcao('PUBLICAR_TERMO'),
        'Publicação de Versão de Termo',
      );
      expect(
        AuditoriaPresentationHelper.obterTituloAcao('ACEITAR_TERMO'),
        'Aceite de Termo de Adesão',
      );
      expect(
        AuditoriaPresentationHelper.obterTituloAcao('ACAO_DESCONHECIDA_CUSTOM'),
        'Acao Desconhecida Custom',
      );
    });

    test('categoriza ações semânticas corretamente', () {
      expect(
        AuditoriaPresentationHelper.obterCategoria('CONSULTA_AUDITORIA_GLOBAL'),
        CategoriaAuditoria.acesso,
      );
      expect(
        AuditoriaPresentationHelper.obterCategoria('DECISAO_PASTOR_LOCAL'),
        CategoriaAuditoria.decisao,
      );
      expect(
        AuditoriaPresentationHelper.obterCategoria('PUBLICAR_TERMO'),
        CategoriaAuditoria.governanca,
      );
      expect(
        AuditoriaPresentationHelper.obterCategoria('CANCELAR_PARTICIPACAO'),
        CategoriaAuditoria.alerta,
      );
      expect(
        AuditoriaPresentationHelper.obterCategoria('OUTRA_COISA'),
        CategoriaAuditoria.geral,
      );
    });

    test('humaniza identificação de atores', () {
      expect(AuditoriaPresentationHelper.obterRotuloAtor('SISTEMA'), 'Sistema Automatizado');
      expect(AuditoriaPresentationHelper.obterRotuloAtor('PASTOR_MARIO'), 'Pastor: MARIO');
      expect(AuditoriaPresentationHelper.obterRotuloAtor('RESP_LOUVOR'), 'Responsável: LOUVOR');
      expect(
        AuditoriaPresentationHelper.obterRotuloAtor('ZHjzDgdOCqWfnak9iTTOWAfD70j2'),
        'Usuário (ZHjzDg...70j2)',
      );
    });

    test('formata entidades envolvidas de forma descritiva', () {
      expect(
        AuditoriaPresentationHelper.formatarEntidade('SISTEMA', 'AUDITORIA'),
        'Sistema: Trilha de Auditoria',
      );
      expect(
        AuditoriaPresentationHelper.formatarEntidade('SISTEMA', 'RELATORIOS'),
        'Sistema: Relatórios Operacionais',
      );
      expect(
        AuditoriaPresentationHelper.formatarEntidade('VOLUNTARIO', 'vol_123'),
        'Voluntário: vol_123',
      );
      expect(
        AuditoriaPresentationHelper.formatarEntidade('IGREJA', 'ig_central'),
        'Igreja: ig_central',
      );
      expect(
        AuditoriaPresentationHelper.formatarEntidade('EQUIPE', 'eq_louvor'),
        'Equipe: eq_louvor',
      );
    });
  });
}
