import 'package:flutter/material.dart';

import '../tokens.dart';

/// Variação semântica para o ícone e destaque visual do [MetricCard].
enum MetricVariant {
  primary,
  success,
  warning,
  danger,
  neutral,
}

/// Card de métrica/KPI institucional padronizado.
/// Exibe ícone linear em círculo colorido suave, valor numérico destacado e legenda.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.variant = MetricVariant.primary,
    this.subtitle,
    this.badge,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final MetricVariant variant;
  final String? subtitle;
  final Widget? badge;
  final VoidCallback? onTap;

  (Color bg, Color fg) _resolveColors() {
    switch (variant) {
      case MetricVariant.primary:
        return (AppColors.blue50, AppColors.blue600);
      case MetricVariant.success:
        return (AppColors.successBg, AppColors.success);
      case MetricVariant.warning:
        return (AppColors.warningBg, AppColors.warning);
      case MetricVariant.danger:
        return (AppColors.dangerBg, AppColors.danger);
      case MetricVariant.neutral:
        return (const Color(0xFFF0F2F5), AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (iconBg, iconFg) = _resolveColors();

    Widget cardContent = Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(
          color: AppColors.border,
          width: AppGeometry.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconFg, size: 20),
              ),
              if (badge != null) badge!,
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontFamilyFallback: AppTypography.fontFallbacks,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            title,
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              subtitle!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppGeometry.cardBorderRadius,
        child: cardContent,
      );
    }

    return cardContent;
  }
}

/// Card de validade da ficha e contagem regressiva com barra de progresso.
class ProgressValidityCard extends StatelessWidget {
  const ProgressValidityCard({
    super.key,
    required this.expirationDateText,
    required this.daysRemaining,
    required this.progress,
    this.title = 'Validade da Ficha',
    this.action,
  });

  final String title;
  final String expirationDateText;
  final int daysRemaining;

  /// Valor de progresso de 0.0 a 1.0 (onde 1.0 é validade plena e 0.0 é expirada).
  final double progress;

  /// Ação opcional à direita (ex.: botão de renovação).
  final Widget? action;

  Color _resolveProgressColor() {
    if (daysRemaining <= 0) {
      return AppColors.danger;
    } else if (daysRemaining <= 30) {
      return AppColors.warning;
    }
    return AppColors.blue600;
  }

  @override
  Widget build(BuildContext context) {
    final progressColor = _resolveProgressColor();
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppGeometry.cardBorderRadius,
        border: Border.all(
          color: AppColors.border,
          width: AppGeometry.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.h3,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      expirationDateText,
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.s12),
                action!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: LinearProgressIndicator(
              value: clampedProgress,
              minHeight: 8.0,
              backgroundColor: const Color(0xFFE4E7EC),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                daysRemaining <= 0
                    ? 'Ficha expirada'
                    : '$daysRemaining ${daysRemaining == 1 ? "dia restante" : "dias restantes"}',
                style: AppTypography.label.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(clampedProgress * 100).toInt()}%',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Alias retrocompatível com a nomenclatura do catálogo [ValidityCard].
typedef ValidityCard = ProgressValidityCard;
