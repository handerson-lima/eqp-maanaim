import 'package:flutter/material.dart';

import '../tokens.dart';

/// Enumeração de situações canônicas suportadas pelo sistema.
enum StatusType {
  ativa,
  emAprovacao,
  aguardando,
  emRenovacao,
  rejeitada,
  cancelada,
  expirada,
  inativa,
  desconhecida,
}

/// Chip de situação padronizado e compacto.
/// Sempre exibe texto semântico e indicador com alto contraste (WCAG 2.2 AA).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.label,
    this.showIcon = true,
    this.showDot = false,
  });

  /// Status bruto ou normalizado (ex.: 'ATIVA', 'EM_APROVACAO', 'REJEITADA', 'EXPIRADA', etc.).
  final String status;

  /// Rótulo alternativo para exibição. Se nulo, utiliza a formatação canônica.
  final String? label;

  /// Se deve exibir o ícone canônico ao lado do texto (padrão true para acessibilidade WCAG 2.2 AA).
  final bool showIcon;

  /// Se deve exibir o indicador circular ao lado do texto (quando showIcon for false).
  final bool showDot;

  static StatusConfig resolveConfig(String statusRaw) {
    final s = statusRaw.trim().toUpperCase().replaceAll(' ', '_');

    switch (s) {
      case 'ATIVA':
      case 'ATIVO':
      case 'APROVADA':
      case 'APROVADO':
        return const StatusConfig(
          label: 'ATIVA',
          backgroundColor: AppColors.successBg,
          textColor: AppColors.success,
          type: StatusType.ativa,
          icon: Icons.check_circle_outline,
        );

      case 'EM_APROVACAO':
      case 'EM_APROVAÇÃO':
        return const StatusConfig(
          label: 'EM APROVAÇÃO',
          backgroundColor: AppColors.warningBg,
          textColor: AppColors.warning,
          type: StatusType.emAprovacao,
          icon: Icons.hourglass_top_outlined,
        );

      case 'AGUARDANDO':
      case 'PENDENTE':
      case 'AGUARDANDO_APROVACAO':
      case 'AGUARDANDO_APROVAÇÃO':
      case 'AGUARDANDO_PASTOR_LOCAL':
      case 'AGUARDANDO_RESPONSAVEL_EQUIPE':
      case 'AGUARDANDO_COORDENADOR':
        return const StatusConfig(
          label: 'AGUARDANDO',
          backgroundColor: AppColors.warningBg,
          textColor: AppColors.warning,
          type: StatusType.aguardando,
          icon: Icons.pending_outlined,
        );

      case 'EM_RENOVACAO':
      case 'EM_RENOVAÇÃO':
        return const StatusConfig(
          label: 'EM RENOVAÇÃO',
          backgroundColor: AppColors.warningBg,
          textColor: AppColors.warning,
          type: StatusType.emRenovacao,
          icon: Icons.sync_outlined,
        );

      case 'REJEITADA':
      case 'REJEITADO':
        return const StatusConfig(
          label: 'REJEITADA',
          backgroundColor: AppColors.dangerBg,
          textColor: AppColors.danger,
          type: StatusType.rejeitada,
          icon: Icons.cancel_outlined,
        );

      case 'CANCELADA':
      case 'CANCELADO':
        return const StatusConfig(
          label: 'CANCELADA',
          backgroundColor: AppColors.dangerBg,
          textColor: AppColors.danger,
          type: StatusType.cancelada,
          icon: Icons.do_not_disturb_on_outlined,
        );

      case 'EXPIRADA':
      case 'EXPIRADO':
        return const StatusConfig(
          label: 'EXPIRADA',
          backgroundColor: AppColors.dangerBg,
          textColor: AppColors.danger,
          type: StatusType.expirada,
          icon: Icons.timer_off_outlined,
        );

      case 'INATIVA':
      case 'INATIVO':
        return const StatusConfig(
          label: 'INATIVA',
          backgroundColor: Color(0xFFF0F2F5),
          textColor: Color(0xFF475467),
          type: StatusType.inativa,
          icon: Icons.pause_circle_outline,
        );

      case 'RASCUNHO':
        return const StatusConfig(
          label: 'RASCUNHO',
          backgroundColor: Color(0xFFF0F2F5),
          textColor: Color(0xFF475467),
          type: StatusType.inativa,
          icon: Icons.edit_note_outlined,
        );

      case 'ORIENTACAO':
      case 'ORIENTACAO_PASTORAL':
        return const StatusConfig(
          label: 'CONSULTE O PASTOR',
          backgroundColor: AppColors.warningBg,
          textColor: AppColors.warning,
          type: StatusType.aguardando,
          icon: Icons.help_outline,
        );

      default:
        return StatusConfig(
          label: statusRaw.toUpperCase(),
          backgroundColor: const Color(0xFFF0F2F5),
          textColor: const Color(0xFF475467),
          type: StatusType.desconhecida,
          icon: Icons.info_outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = resolveConfig(status);
    final displayLabel = label ?? config.label;

    return Semantics(
      label: 'Situação: $displayLabel',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showIcon) ...[
              Icon(
                config.icon,
                size: 14,
                color: config.textColor,
              ),
              const SizedBox(width: AppSpacing.s4 + 2),
            ] else if (showDot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: config.textColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.s4 + 2),
            ],
            Flexible(
              child: Text(
                displayLabel,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: config.textColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Configuração visual de um status.
class StatusConfig {
  const StatusConfig({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.type,
    required this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final StatusType type;
  final IconData icon;
}
