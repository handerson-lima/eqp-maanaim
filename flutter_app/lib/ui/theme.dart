import 'package:flutter/material.dart';

import 'tokens.dart';

/// Constrói o [ThemeData] institucional do Maanaim baseado nos tokens canônicos.
ThemeData temaMaanaim() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.blue600,
    onPrimary: Colors.white,
    primaryContainer: AppColors.blue50,
    onPrimaryContainer: AppColors.navy900,
    secondary: AppColors.navy900,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.navy800,
    onSecondaryContainer: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    error: AppColors.danger,
    onError: Colors.white,
    errorContainer: AppColors.dangerBg,
    onErrorContainer: AppColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.surface,
    focusColor: const Color(0x330B6FE8),
    hoverColor: const Color(0xFFF0F4F8),
    highlightColor: AppColors.blue50,
    dividerColor: AppColors.border,
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.navy900,
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontFamily: AppTypography.fontFamily,
      ),
      waitDuration: const Duration(milliseconds: 400),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(AppGeometry.minTouchTarget, AppGeometry.minTouchTarget),
        shape: RoundedRectangleBorder(
          borderRadius: AppGeometry.buttonBorderRadius,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: AppGeometry.borderWidth,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 20),
      titleTextStyle: AppTypography.h3,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppGeometry.cardBorderRadius,
        side: const BorderSide(
          color: AppColors.border,
          width: AppGeometry.borderWidth,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: AppTypography.label.copyWith(color: AppColors.textSecondary),
      hintStyle: AppTypography.body.copyWith(color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: AppGeometry.inputBorderRadius,
        borderSide: const BorderSide(
          color: AppColors.border,
          width: AppGeometry.borderWidth,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppGeometry.inputBorderRadius,
        borderSide: const BorderSide(
          color: AppColors.border,
          width: AppGeometry.borderWidth,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppGeometry.inputBorderRadius,
        borderSide: const BorderSide(
          color: AppColors.blue600,
          width: 2.0,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppGeometry.inputBorderRadius,
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: AppGeometry.borderWidth,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppGeometry.inputBorderRadius,
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: 2.0,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue600,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.textSecondary,
        minimumSize: const Size(AppGeometry.minTouchTarget, AppGeometry.buttonHeight),
        elevation: 0,
        textStyle: AppTypography.button,
        shape: RoundedRectangleBorder(
          borderRadius: AppGeometry.buttonBorderRadius,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue600,
        backgroundColor: AppColors.surface,
        disabledForegroundColor: AppColors.textSecondary,
        side: const BorderSide(
          color: AppColors.border,
          width: AppGeometry.borderWidth,
        ),
        minimumSize: const Size(AppGeometry.minTouchTarget, AppGeometry.buttonHeight),
        elevation: 0,
        textStyle: AppTypography.button,
        shape: RoundedRectangleBorder(
          borderRadius: AppGeometry.buttonBorderRadius,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.blue600,
        minimumSize: const Size(AppGeometry.minTouchTarget, AppGeometry.buttonHeight),
        textStyle: AppTypography.button,
        shape: RoundedRectangleBorder(
          borderRadius: AppGeometry.buttonBorderRadius,
        ),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.navy900,
      selectedIconTheme: IconThemeData(color: Colors.white, size: 20),
      unselectedIconTheme: IconThemeData(color: Color(0xFFD5E2EF), size: 20),
      selectedLabelTextStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontFamilyFallback: AppTypography.fontFallbacks,
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontFamilyFallback: AppTypography.fontFallbacks,
        color: Color(0xFFD5E2EF),
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      indicatorColor: AppColors.navy800,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.navy900,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: AppTypography.textTheme,
  );
}
