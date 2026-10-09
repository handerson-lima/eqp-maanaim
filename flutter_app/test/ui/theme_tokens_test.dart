import 'package:eqp_maanaim/ui/identidade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Design Tokens Canônicos e Acessíveis (Story 8.2)', () {
    test(
      'Cores canônicas e semânticas acessíveis correspondem à especificação normativa',
      () {
        expect(AppColors.navy900, const Color(0xFF082C49));
        expect(AppColors.navy800, const Color(0xFF0D3859));
        expect(AppColors.blue600, const Color(0xFF0B6FE8));
        expect(AppColors.blue50, const Color(0xFFEEF6FF));
        expect(AppColors.surface, const Color(0xFFFFFFFF));
        expect(AppColors.background, const Color(0xFFF5F7FA));
        expect(AppColors.border, const Color(0xFFDDE3EA));
        expect(AppColors.borderInteractive, const Color(0xFF667085));
        expect(AppColors.textPrimary, const Color(0xFF172033));
        expect(AppColors.textSecondary, const Color(0xFF667085));
        expect(AppColors.textDisabled, const Color(0xFF475467));
        expect(AppColors.focusLight, const Color(0xFF0B6FE8));
        expect(AppColors.focusDark, const Color(0xFFFFFFFF));
        expect(AppColors.success, const Color(0xFF16794A));
        expect(AppColors.successBg, const Color(0xFFEAF8EF));
        expect(AppColors.warning, const Color(0xFF9A6700));
        expect(AppColors.warningBg, const Color(0xFFFFF6DE));
        expect(AppColors.danger, const Color(0xFFB42318));
        expect(AppColors.dangerBg, const Color(0xFFFDECEC));
      },
    );

    test(
      'Constantes legadas em identidade.dart apontam para tokens canônicos',
      () {
        expect(azulMaanaim, AppColors.blue600);
        expect(marinhoMaanaim, AppColors.navy900);
        expect(fundoMaanaim, AppColors.background);
        expect(bordaMaanaim, AppColors.border);
      },
    );

    test('Escala de espaçamento base 4px está correta', () {
      expect(AppSpacing.s4, 4.0);
      expect(AppSpacing.s8, 8.0);
      expect(AppSpacing.s12, 12.0);
      expect(AppSpacing.s16, 16.0);
      expect(AppSpacing.s20, 20.0);
      expect(AppSpacing.s24, 24.0);
      expect(AppSpacing.s32, 32.0);
      expect(AppSpacing.s40, 40.0);
      expect(AppSpacing.s48, 48.0);
    });

    test('Geometria, raios e alvos mínimos de toque atendem às diretrizes', () {
      expect(AppGeometry.radiusCard, 10.0);
      expect(AppGeometry.radiusButton, 6.0);
      expect(AppGeometry.radiusInput, 6.0);
      expect(AppGeometry.borderWidth, 1.0);
      expect(AppGeometry.minTouchTarget, greaterThanOrEqualTo(44.0));
      expect(AppGeometry.buttonHeight, greaterThanOrEqualTo(40.0));
      expect(AppGeometry.tableRowHeight, 48.0);
    });

    test(
      'Tipografia institucional declara Inter com fallback e pesos corretos',
      () {
        expect(AppTypography.fontFamily, 'Inter');
        expect(AppTypography.fontFallbacks, contains('Roboto'));
        expect(AppTypography.fontFallbacks, contains('sans-serif'));

        // H1 (24px / 700)
        expect(AppTypography.h1.fontSize, 24);
        expect(AppTypography.h1.fontWeight, FontWeight.w700);

        // H2 (20px / 700)
        expect(AppTypography.h2.fontSize, 20);
        expect(AppTypography.h2.fontWeight, FontWeight.w700);

        // H3 (16px / 600)
        expect(AppTypography.h3.fontSize, 16);
        expect(AppTypography.h3.fontWeight, FontWeight.w600);

        // Body (14px / 400)
        expect(AppTypography.body.fontSize, 14);
        expect(AppTypography.body.fontWeight, FontWeight.w400);

        // Label (12-13px / 500-600)
        expect(AppTypography.label.fontSize, 13);
        expect(AppTypography.label.fontWeight, FontWeight.w600);

        // Caption (11-12px / 400)
        expect(AppTypography.caption.fontSize, 12);
        expect(AppTypography.caption.fontWeight, FontWeight.w400);

        // Botão (13-14px / 600)
        expect(AppTypography.button.fontSize, 14);
        expect(AppTypography.button.fontWeight, FontWeight.w600);
      },
    );
  });

  group('ThemeData Canônico (temaMaanaim)', () {
    final tema = temaMaanaim();

    test('Configura Material 3 e cores canônicas de superfície e fundo', () {
      expect(tema.useMaterial3, isTrue);
      expect(tema.colorScheme.primary, AppColors.blue600);
      expect(tema.colorScheme.onPrimary, Colors.white);
      expect(tema.colorScheme.surface, AppColors.surface);
      expect(tema.colorScheme.onSurface, AppColors.textPrimary);
      expect(tema.colorScheme.error, AppColors.danger);
      expect(tema.scaffoldBackgroundColor, AppColors.background);
      expect(tema.dividerColor, AppColors.border);
    });

    test(
      'Cards possuem borda fina, sem elevação excessiva e radius canônico',
      () {
        final cardShape = tema.cardTheme.shape as RoundedRectangleBorder;
        expect(cardShape.borderRadius, AppGeometry.cardBorderRadius);
        expect(cardShape.side.color, AppColors.border);
        expect(cardShape.side.width, AppGeometry.borderWidth);
        expect(tema.cardTheme.elevation, 0);
        expect(tema.cardTheme.color, AppColors.surface);
      },
    );

    test(
      'Inputs possuem padding adequado, fundo branco e borda interativa',
      () {
        final inputTheme = tema.inputDecorationTheme;
        expect(inputTheme.filled, isTrue);
        expect(inputTheme.fillColor, AppColors.surface);
        final border = inputTheme.border as OutlineInputBorder;
        expect(border.borderRadius, AppGeometry.inputBorderRadius);
        expect(border.borderSide.color, AppColors.borderInteractive);
      },
    );

    test('Botões atendem tamanho mínimo de 44px para WCAG AA', () {
      final elevatedStyle = tema.elevatedButtonTheme.style;
      final minSize = elevatedStyle?.minimumSize?.resolve({});
      expect(minSize?.height, greaterThanOrEqualTo(44.0));
      expect(minSize?.width, greaterThanOrEqualTo(44.0));
    });

    test(
      'Contraste WCAG 2.2 AA verificado matematicamente para todos os pares normativos',
      () {
        double contrastRatio(Color fg, Color bg) {
          final l1 = fg.computeLuminance();
          final l2 = bg.computeLuminance();
          final lighter = l1 > l2 ? l1 : l2;
          final darker = l1 > l2 ? l2 : l1;
          return (lighter + 0.05) / (darker + 0.05);
        }

        // 1. Texto primário (#172033) em surface (#FFFFFF) e background (#F5F7FA)
        final contrastTextPrimary = contrastRatio(
          AppColors.textPrimary,
          AppColors.surface,
        );
        expect(contrastTextPrimary, greaterThanOrEqualTo(7.0)); // Atende AAA

        // 2. Texto secundário (#667085) em surface (#FFFFFF)
        final contrastTextSecondary = contrastRatio(
          AppColors.textSecondary,
          AppColors.surface,
        );
        expect(
          contrastTextSecondary,
          greaterThanOrEqualTo(4.5),
        ); // Atende AA normal text

        // 3. Botão primário (Texto branco em blue600)
        final contrastButtonPrimary = contrastRatio(
          Colors.white,
          AppColors.blue600,
        );
        expect(contrastButtonPrimary, greaterThanOrEqualTo(4.5)); // Atende AA

        // 4. Botão aprovação (Texto branco em success #16794A)
        final contrastApprove = contrastRatio(Colors.white, AppColors.success);
        expect(contrastApprove, greaterThanOrEqualTo(4.5)); // Atende AA

        // 5. Botão perigo (Texto branco em danger #B42318)
        final contrastDanger = contrastRatio(Colors.white, AppColors.danger);
        expect(contrastDanger, greaterThanOrEqualTo(4.5)); // Atende AA

        // 6. Chip sucesso (#16794A em successBg #EAF8EF)
        final contrastChipSuccess = contrastRatio(
          AppColors.success,
          AppColors.successBg,
        );
        expect(contrastChipSuccess, greaterThanOrEqualTo(4.5)); // Atende AA

        // 7. Chip atenção (#9A6700 em warningBg #FFF6DE)
        final contrastChipWarning = contrastRatio(
          AppColors.warning,
          AppColors.warningBg,
        );
        expect(contrastChipWarning, greaterThanOrEqualTo(4.5)); // Atende AA

        // 8. Chip erro (#B42318 em dangerBg #FDECEC)
        final contrastChipDanger = contrastRatio(
          AppColors.danger,
          AppColors.dangerBg,
        );
        expect(contrastChipDanger, greaterThanOrEqualTo(4.5)); // Atende AA

        // 9. Borda interativa (#667085 em surface #FFFFFF)
        final contrastBorderInteractive = contrastRatio(
          AppColors.borderInteractive,
          AppColors.surface,
        );
        expect(
          contrastBorderInteractive,
          greaterThanOrEqualTo(3.0),
        ); // Atende controle/foco ≥ 3:1

        // 10. Foco em seleção clara (blue600 em blue50)
        final contrastFocusLight = contrastRatio(
          AppColors.focusLight,
          AppColors.blue50,
        );
        expect(
          contrastFocusLight,
          greaterThanOrEqualTo(3.0),
        ); // Atende foco ≥ 3:1

        // 11. Sidebar institucional (Texto branco em navy900)
        final contrastSidebar = contrastRatio(Colors.white, AppColors.navy900);
        expect(contrastSidebar, greaterThanOrEqualTo(7.0)); // Atende AAA

        // 12. Botão desabilitado (textDisabled #475467 em border #DDE3EA)
        final contrastDisabled = contrastRatio(
          AppColors.textDisabled,
          AppColors.border,
        );
        expect(contrastDisabled, greaterThanOrEqualTo(4.5)); // Atende AA
      },
    );
  });
}
