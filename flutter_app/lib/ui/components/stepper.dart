import 'package:flutter/material.dart';
import '../tokens.dart';

/// Modelo de dados para uma etapa do [AppStepper].
class StepperEtapa {
  const StepperEtapa({
    required this.titulo,
    this.subtitulo,
    this.icone,
  });

  final String titulo;
  final String? subtitulo;
  final IconData? icone;
}

/// Componente de Stepper responsivo e acessível (WCAG 2.2 AA).
///
/// Exibe layout horizontal com títulos e conectores no desktop/tablet (≥ 600px)
/// e apresentação compacta com indicador textual e barra de progresso no mobile (< 600px).
class AppStepper extends StatelessWidget {
  const AppStepper({
    super.key,
    required this.etapas,
    required this.etapaAtual,
    this.onEtapaTap,
  });

  final List<StepperEtapa> etapas;
  final int etapaAtual;
  final ValueChanged<int>? onEtapaTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ehMobile = constraints.maxWidth < 600;
        if (ehMobile) {
          return _buildMobileStepper(context);
        } else {
          return _buildDesktopStepper(context);
        }
      },
    );
  }

  /// Stepper compacto para telas mobile (< 600px).
  Widget _buildMobileStepper(BuildContext context) {
    final total = etapas.length;
    final progresso = total > 1 ? (etapaAtual / (total - 1)).clamp(0.0, 1.0) : 1.0;
    final etapaAtualObj = etapas[etapaAtual.clamp(0, total - 1)];

    return Semantics(
      container: true,
      label: 'Progresso da solicitação: Etapa ${etapaAtual + 1} de $total, ${etapaAtualObj.titulo}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Etapa ${etapaAtual + 1} de $total',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.blue600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        etapaAtualObj.titulo,
                        style: AppTypography.body.copyWith(
                          color: AppColors.navy900,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Indicador visual de badges compactas
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(total, (i) {
                    final concluida = i < etapaAtual;
                    final atual = i == etapaAtual;
                    return Container(
                      margin: const EdgeInsets.only(left: 6),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: concluida
                            ? AppColors.blue600
                            : atual
                                ? AppColors.blue50
                                : AppColors.neutral150,
                        border: Border.all(
                          color: atual
                              ? AppColors.blue600
                              : concluida
                                  ? AppColors.blue600
                                  : AppColors.border,
                          width: atual ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: concluida
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: atual
                                      ? AppColors.blue600
                                      : AppColors.textSecondary,
                                ),
                              ),
                      ),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progresso,
                minHeight: 4,
                backgroundColor: AppColors.neutral150,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Stepper horizontal completo para telas desktop e tablet (≥ 600px).
  Widget _buildDesktopStepper(BuildContext context) {
    final total = etapas.length;

    return Semantics(
      container: true,
      label: 'Etapas do processo de solicitação',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s24,
          vertical: AppSpacing.s16,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: List.generate(total, (i) {
            final etapa = etapas[i];
            final concluida = i < etapaAtual;
            final atual = i == etapaAtual;
            final ehUltima = i == total - 1;
            final podeClicar = onEtapaTap != null && i <= etapaAtual;

            final itemWidget = Semantics(
              button: podeClicar,
              enabled: podeClicar,
              selected: atual,
              label: 'Etapa ${i + 1} de $total: ${etapa.titulo}. ${concluida ? "Concluída" : atual ? "Em andamento" : "Pendente"}',
              child: InkWell(
                onTap: podeClicar ? () => onEtapaTap!(i) : null,
                borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: concluida
                              ? AppColors.blue600
                              : atual
                                  ? AppColors.blue50
                                  : AppColors.surface,
                          border: Border.all(
                            color: atual || concluida
                                ? AppColors.blue600
                                : AppColors.border,
                            width: atual ? 2 : 1.5,
                          ),
                        ),
                        child: Center(
                          child: concluida
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: atual
                                        ? AppColors.blue600
                                        : AppColors.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              etapa.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body.copyWith(
                                fontSize: 13,
                                fontWeight: atual || concluida
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: atual
                                    ? AppColors.navy900
                                    : concluida
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                              ),
                            ),
                            if (etapa.subtitulo != null && etapa.subtitulo!.isNotEmpty)
                              Text(
                                etapa.subtitulo!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            if (ehUltima) {
              return Expanded(
                child: itemWidget,
              );
            }

            return Expanded(
              child: Row(
                children: [
                  Expanded(child: itemWidget),
                  const SizedBox(width: 4),
                  Container(
                    width: 16,
                    height: 2,
                    color: concluida
                        ? AppColors.blue600
                        : AppColors.border,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
