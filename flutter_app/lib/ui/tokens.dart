import 'package:flutter/material.dart';

/// Tokens canônicos de cores do sistema Maanaim.
/// Conforme especificado em:
/// - `_bmad-output/planning-artifacts/ux/DESIGN-SYSTEM.md`
/// - `_bmad-output/planning-artifacts/ux/DESIGN-RULES-FOR-AGENTS.md`
abstract final class AppColors {
  // Institucionais / Navegação
  static const Color navy900 = Color(0xFF082C49); // sidebar / áreas institucionais
  static const Color navy800 = Color(0xFF0D3859); // hover / variações escuras
  static const Color blue600 = Color(0xFF0B6FE8); // ação primária / botões principais
  static const Color blue50 = Color(0xFFEEF6FF); // seleção / fundos informativos

  // Superfícies e Neutros
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F7FA);
  static const Color border = Color(0xFFDDE3EA);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF667085);
  static const Color neutral50 = Color(0xFFF9FAFB); // fundos neutros muito claros
  static const Color neutral100 = Color(0xFFF3F4F6); // chips/etiquetas neutras
  static const Color neutral150 = Color(0xFFF8FAFC); // containers informativos neutros

  // Semânticos (Status e Feedback)
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFEAF8EF);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFFF6DE);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerBg = Color(0xFFFDECEC);
}

/// Escala base de espaçamento (4px).
abstract final class AppSpacing {
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;

  // Padrões de Layout
  static const double pagePaddingDesktop = 24.0;
  static const double pagePaddingMobile = 16.0;
  static const double sectionGap = 24.0;
  static const double cardGap = 16.0;
  static const double cardPadding = 20.0;
}

/// Geometria, raio de cantos e dimensões canônicas.
abstract final class AppGeometry {
  static const double radiusCard = 10.0;
  static const double radiusButton = 6.0;
  static const double radiusInput = 6.0;
  static const double borderWidth = 1.0;

  static final BorderRadius cardBorderRadius = BorderRadius.circular(radiusCard);
  static final BorderRadius buttonBorderRadius = BorderRadius.circular(radiusButton);
  static final BorderRadius inputBorderRadius = BorderRadius.circular(radiusInput);

  static const double minTouchTarget = 44.0;
  static const double sidebarDesktopWidth = 220.0;
  static const double topBarHeight = 64.0;
  static const double inputHeight = 44.0;
  static const double buttonHeight = 44.0;
  static const double tableRowHeight = 48.0;
}

/// Tipografia institucional (Inter com fallback para Roboto/sans-serif).
abstract final class AppTypography {
  static const String fontFamily = 'Inter';
  static const List<String> fontFallbacks = ['Roboto', 'sans-serif'];

  // H1: 24px / 700
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.25,
  );

  // H2: 20px / 700
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );

  // H3: 16px / 600
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  // Body: 14px / 400
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // Label: 12-13px / 500-600
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // Caption: 11-12px / 400
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Botão: 13-14px / 600
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Mapeamento do TextTheme do Material 3 para a tipografia institucional.
  static const TextTheme textTheme = TextTheme(
    displayLarge: h1,
    headlineLarge: h1,
    headlineMedium: h2,
    headlineSmall: h3,
    titleLarge: h3,
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallbacks,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleSmall: label,
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallbacks,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
      height: 1.5,
    ),
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: button,
    labelMedium: label,
    labelSmall: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallbacks,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
  );
}
