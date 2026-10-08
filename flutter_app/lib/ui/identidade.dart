import 'package:flutter/material.dart';

import 'tokens.dart';
import 'components/components.dart';

export 'components/components.dart';
export 'theme.dart';
export 'tokens.dart';

// Constantes legadas preservadas para retrocompatibilidade
const azulMaanaim = AppColors.blue600;
const marinhoMaanaim = AppColors.navy900;
const fundoMaanaim = AppColors.background;
const bordaMaanaim = AppColors.border;

/// Moldura de autenticação (S01): bipartida 50/50 no desktop (≥1024px) e
/// topo compacto e responsivo no mobile (<600px) e tablet.
class PainelAcesso extends StatelessWidget {
  const PainelAcesso({super.key, required this.child});
  final Widget child;

  Widget _painelInstitucional({required double minHeight}) => Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.navy900,
              Color(0xFF04192B),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            LogoMaanaim.painel(width: 250),
            const SizedBox(height: AppSpacing.s16),
            const Text(
              'Gestão de Voluntários',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontFamilyFallback: AppTypography.fontFallbacks,
                color: Color(0xFFD5E2EF),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 64),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                children: const [
                  Text(
                    'Servindo juntos no Reino de Deus',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontFamilyFallback: AppTypography.fontFallbacks,
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: AppSpacing.s12),
                  Text(
                    '“Cada um exerça o dom que recebeu para servir aos outros”\n1 Pedro 4:10',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontFamilyFallback: AppTypography.fontFallbacks,
                      color: Color(0xFFD8E7F5),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _headerCompacto() => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const LogoMaanaim(
              height: 48,
              transparente: true,
            ),
            const SizedBox(height: AppSpacing.s8),
            const Text(
              'Gestão de Voluntários',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontFamilyFallback: AppTypography.fontFallbacks,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          final isMobile = constraints.maxWidth < 600;

          if (isDesktop) {
            return Container(
              color: AppColors.background,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Painel esquerdo 50%
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      child: _painelInstitucional(
                        minHeight: constraints.maxHeight,
                      ),
                    ),
                  ),
                  // Painel direito 50% com card centralizado (~360–400px)
                  Expanded(
                    flex: 1,
                    child: Container(
                      color: AppColors.background,
                      alignment: Alignment.center,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s24,
                          vertical: AppSpacing.s32,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 400,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppGeometry.cardBorderRadius,
                              border: Border.all(
                                color: AppColors.border,
                                width: AppGeometry.borderWidth,
                              ),
                            ),
                            padding: const EdgeInsets.all(AppSpacing.s32),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Mobile e Tablet: painel visual pesado oculto; logo compacto no topo
          return Container(
            color: AppColors.background,
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? AppSpacing.s20 : AppSpacing.s32,
                vertical: AppSpacing.s20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 440,
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _headerCompacto(),
                    const SizedBox(height: AppSpacing.s8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppGeometry.cardBorderRadius,
                        border: Border.all(
                          color: AppColors.border,
                          width: AppGeometry.borderWidth,
                        ),
                      ),
                      padding: EdgeInsets.all(
                        isMobile ? AppSpacing.s20 : AppSpacing.s24,
                      ),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
