import 'package:flutter/material.dart';

import '../../ui/tokens.dart';

/// Categorias semânticas de eventos de auditoria para visualização clara e acessível.
enum CategoriaAuditoria {
  acesso,
  decisao,
  governanca,
  alerta,
  geral,
}

/// Configuração visual para uma categoria de auditoria.
class CategoriaConfig {
  const CategoriaConfig({
    required this.rotulo,
    required this.corFundo,
    required this.corTexto,
    required this.icone,
  });

  final String rotulo;
  final Color corFundo;
  final Color corTexto;
  final IconData icone;
}

/// Helper para converter dados brutos de auditoria em informação legível,
/// amigável para pastores e coordenadores (WCAG 2.2 AA).
class AuditoriaPresentationHelper {
  AuditoriaPresentationHelper._();

  /// Converte a chave bruta de ação em um título amigável em Português.
  static String obterTituloAcao(String acaoBruta) {
    final chave = acaoBruta.trim().toUpperCase();

    switch (chave) {
      case 'CONSULTA_AUDITORIA_GLOBAL':
        return 'Consulta à Trilha de Auditoria';
      case 'CONSULTA_RELATORIO_OPERACIONAL':
        return 'Emissão de Relatório Operacional';
      case 'DECISAO_PASTOR_LOCAL':
      case 'DECIDIR_FICHA_PASTOR_LOCAL':
      case 'DECISAO_PASTORAL_REGISTRADA':
        return 'Avaliação do Pastor Local';
      case 'DECISAO_RESPONSAVEL_EQUIPE':
      case 'DECIDIR_PARTICIPACAO_RESPONSAVEL_EQUIPE':
        return 'Avaliação do Responsável de Equipe';
      case 'DECIDIR_ATIVACAO_COORDENADOR':
        return 'Homologação da Coordenação Geral';
      case 'ENVIAR_FICHA_APROVACAO':
      case 'FICHA_ENVIADA_APROVACAO':
        return 'Envio de Ficha para Aprovação';
      case 'DECISAO_PASTORAL_CICLO_ANUAL':
      case 'DECIDIR_CICLO_ANUAL_PASTOR':
        return 'Renovação Anual (Pastor Local)';
      case 'DECISAO_RESPONSAVEL_CICLO_ANUAL':
      case 'DECIDIR_CICLO_ANUAL_RESPONSAVEL':
        return 'Renovação Anual (Responsável de Equipe)';
      case 'CONCLUSAO_COORDENADOR_CICLO_ANUAL':
      case 'CONCLUIR_CICLO_ANUAL_COORDENADOR':
        return 'Conclusão de Ciclo Anual';
      case 'MANIFESTAR_RENOVACAO':
        return 'Manifestação de Renovação do Voluntário';
      case 'EXPIRAR_CICLO_ANUAL':
        return 'Expiração de Ciclo Anual';
      case 'CANCELAR_PARTICIPACAO':
        return 'Cancelamento de Participação';
      case 'SOLICITAR_REATIVACAO':
        return 'Solicitação de Reativação de Ficha';
      case 'GERAR_PDF_TERMO':
        return 'Emissão de Termo Probatório (PDF)';
      case 'ACESSAR_PDF_TERMO':
        return 'Visualização de Termo Probatório (PDF)';
      case 'PUBLICAR_TERMO':
        return 'Publicação de Versão de Termo';
      case 'ACEITAR_TERMO':
        return 'Aceite de Termo de Adesão';
      case 'SUBSTITUIR_RESPONSAVEL':
        return 'Substituição de Responsável de Equipe';
      case 'ANONIMIZAR':
        return 'Anonimização de Dados (LGPD)';
      case 'EXPURGAR':
        return 'Expurgo de Dados (LGPD)';
      default:
        // Formata SNAKE_CASE para Capitalizado amigável
        if (chave.contains('_')) {
          final palavras = chave.split('_');
          return palavras
              .map((p) => p.isEmpty ? '' : '${p[0]}${p.substring(1).toLowerCase()}')
              .join(' ');
        }
        return acaoBruta;
    }
  }

  /// Retorna a categoria semântica correspondente à ação.
  static CategoriaAuditoria obterCategoria(String acaoBruta) {
    final chave = acaoBruta.trim().toUpperCase();

    if (chave.contains('CONSULTA') || chave.contains('ACESSAR') || chave.contains('QUERY')) {
      return CategoriaAuditoria.acesso;
    }
    if (chave.contains('DECISAO') ||
        chave.contains('DECIDIR') ||
        chave.contains('ENVIAR') ||
        chave.contains('CONCLU') ||
        chave.contains('MANIFESTAR') ||
        chave.contains('REATIVACAO')) {
      return CategoriaAuditoria.decisao;
    }
    if (chave.contains('TERMO') ||
        chave.contains('ACEITAR') ||
        chave.contains('PUBLICAR') ||
        chave.contains('SUBSTITUIR')) {
      return CategoriaAuditoria.governanca;
    }
    if (chave.contains('CANCELAR') ||
        chave.contains('EXPIRAR') ||
        chave.contains('REJEIT') ||
        chave.contains('EXPURG') ||
        chave.contains('ANONIMIZ')) {
      return CategoriaAuditoria.alerta;
    }

    return CategoriaAuditoria.geral;
  }

  /// Retorna as propriedades visuais da categoria.
  static CategoriaConfig obterConfigCategoria(CategoriaAuditoria categoria) {
    switch (categoria) {
      case CategoriaAuditoria.acesso:
        return const CategoriaConfig(
          rotulo: 'Consulta & Acesso',
          corFundo: Color(0xFFE0F2FE),
          corTexto: Color(0xFF0369A1),
          icone: Icons.search,
        );
      case CategoriaAuditoria.decisao:
        return const CategoriaConfig(
          rotulo: 'Decisão & Trâmite',
          corFundo: AppColors.successBg,
          corTexto: AppColors.success,
          icone: Icons.fact_check_outlined,
        );
      case CategoriaAuditoria.governanca:
        return const CategoriaConfig(
          rotulo: 'Governança & Termos',
          corFundo: Color(0xFFEEF2FF),
          corTexto: AppColors.navy900,
          icone: Icons.shield_outlined,
        );
      case CategoriaAuditoria.alerta:
        return const CategoriaConfig(
          rotulo: 'Atenção & Encerramento',
          corFundo: AppColors.warningBg,
          corTexto: AppColors.warning,
          icone: Icons.warning_amber_outlined,
        );
      case CategoriaAuditoria.geral:
        return const CategoriaConfig(
          rotulo: 'Registro Operacional',
          corFundo: Color(0xFFF0F2F5),
          corTexto: Color(0xFF475467),
          icone: Icons.history_outlined,
        );
    }
  }

  /// Retorna um rótulo amigável para o ator (quem executou).
  static String obterRotuloAtor(String atorUid) {
    final uid = atorUid.trim();
    if (uid.isEmpty || uid.toUpperCase() == 'SISTEMA') {
      return 'Sistema Automatizado';
    }
    if (uid.toUpperCase().startsWith('PASTOR_')) {
      final nome = uid.substring(7).replaceAll('_', ' ');
      return 'Pastor: $nome';
    }
    if (uid.toUpperCase().startsWith('RESP_')) {
      final nome = uid.substring(5).replaceAll('_', ' ');
      return 'Responsável: $nome';
    }
    if (uid.toUpperCase().startsWith('COORD_')) {
      final nome = uid.substring(6).replaceAll('_', ' ');
      return 'Coordenador: $nome';
    }
    if (uid.length > 16) {
      // Encurta UID longo para legibilidade
      final inicio = uid.substring(0, 6);
      final fim = uid.substring(uid.length - 4);
      return 'Usuário ($inicio...$fim)';
    }
    return 'Usuário ($uid)';
  }

  /// Formata data/hora ISO em padrão brasileiro intuitivo.
  static String formatarDataHoraAmigavel(String timestampIso) {
    if (timestampIso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(timestampIso).toLocal();
      final agora = DateTime.now();
      final hoje = DateTime(agora.year, agora.month, agora.day);
      final diaEvento = DateTime(dt.year, dt.month, dt.day);

      final horaFormatada =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

      if (diaEvento == hoje) {
        return 'Hoje às $horaFormatada';
      }
      final ontem = hoje.subtract(const Duration(days: 1));
      if (diaEvento == ontem) {
        return 'Ontem às $horaFormatada';
      }

      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      final ano = dt.year;
      return '$dia/$mes/$ano às $horaFormatada';
    } catch (_) {
      // Fallback caso não seja ISO válido
      return timestampIso.length > 19
          ? timestampIso.substring(0, 19).replaceAll('T', ' ')
          : timestampIso;
    }
  }

  /// Retorna ícone representativo para o tipo de entidade referenciada.
  static IconData obterIconeEntidade(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'IGREJA':
        return Icons.church_outlined;
      case 'EQUIPE':
        return Icons.groups_outlined;
      case 'VOLUNTARIO':
        return Icons.person_outline;
      case 'FICHA':
        return Icons.assignment_outlined;
      case 'TERMO':
        return Icons.gavel_outlined;
      case 'SISTEMA':
        return Icons.settings_suggest_outlined;
      default:
        return Icons.label_outline;
    }
  }

  /// Formata a descrição da entidade para leitura amigável.
  static String formatarEntidade(String tipo, String id) {
    final tipoFormatado = tipo.toUpperCase();
    switch (tipoFormatado) {
      case 'SISTEMA':
        if (id.toUpperCase() == 'AUDITORIA') {
          return 'Sistema: Trilha de Auditoria';
        }
        if (id.toUpperCase() == 'RELATORIOS') {
          return 'Sistema: Relatórios Operacionais';
        }
        return 'Sistema: $id';
      case 'VOLUNTARIO':
        return 'Voluntário: $id';
      case 'IGREJA':
        return 'Igreja: $id';
      case 'EQUIPE':
        return 'Equipe: $id';
      case 'FICHA':
        return 'Ficha: $id';
      case 'TERMO':
        return 'Termo: $id';
      default:
        return '$tipo: $id';
    }
  }
}
