import 'package:flutter/material.dart';

import '../tokens.dart';

/// Helper para construir feedback de loading com semântica acessível.
Widget _buildButtonLoading({required Color color, required String label}) {
  return Semantics(
    label: '$label, carregando...',
    button: true,
    child: SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    ),
  );
}

/// Helper para conteúdo de botão com ícone opcional e suporte a escala de fonte sem corte.
Widget _buildButtonContent({
  required String label,
  IconData? icon,
  required Color color,
  required bool isFullWidth,
}) {
  return Row(
    mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.s8),
      ],
      Flexible(
        child: Text(
          label,
          style: AppTypography.button.copyWith(color: color),
          textAlign: TextAlign.center,
          softWrap: true,
        ),
      ),
    ],
  );
}

/// Botão de ação primária institucional (blue-600, texto branco).
/// Atende às diretrizes WCAG 2.2 AA (altura mínima de 44px, foco, sem gradientes).
/// Suporta os estados: default, hover, focus, pressed, disabled e loading.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    final Widget content = isLoading
        ? _buildButtonLoading(color: Colors.white, label: label)
        : _buildButtonContent(
            label: label,
            icon: icon,
            color: effectiveOnPressed != null
                ? Colors.white
                : AppColors.textDisabled,
            isFullWidth: isFullWidth,
          );

    final style = ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(
        Size(
          isFullWidth ? double.infinity : AppGeometry.minTouchTarget,
          AppGeometry.buttonHeight,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppGeometry.buttonBorderRadius),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) && !isLoading) {
          return AppColors.border;
        }
        if (states.contains(WidgetState.pressed)) {
          return const Color(0xFF084B9C);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFF0959BA);
        }
        return AppColors.blue600;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textDisabled;
        }
        return Colors.white;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return const BorderSide(color: AppColors.focusDark, width: 2.0);
        }
        return BorderSide.none;
      }),
    );

    final button = ElevatedButton(
      onPressed: effectiveOnPressed,
      style: style,
      child: content,
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Botão de ação secundária institucional (fundo branco, borda neutra interativa, texto escuro).
/// Suporta os estados: default, hover, focus, pressed, disabled e loading.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    final Widget content = isLoading
        ? _buildButtonLoading(color: AppColors.textPrimary, label: label)
        : _buildButtonContent(
            label: label,
            icon: icon,
            color: effectiveOnPressed != null
                ? AppColors.textPrimary
                : AppColors.textDisabled,
            isFullWidth: isFullWidth,
          );

    final style = ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(
        Size(
          isFullWidth ? double.infinity : AppGeometry.minTouchTarget,
          AppGeometry.buttonHeight,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppGeometry.buttonBorderRadius),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.surface;
        }
        if (states.contains(WidgetState.pressed)) {
          return const Color(0xFFD8E7F5);
        }
        if (states.contains(WidgetState.hovered)) {
          return AppColors.blue50;
        }
        return AppColors.surface;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textDisabled;
        }
        return AppColors.textPrimary;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return const BorderSide(
            color: AppColors.border,
            width: AppGeometry.borderWidth,
          );
        }
        if (states.contains(WidgetState.focused)) {
          return const BorderSide(color: AppColors.focusLight, width: 2.0);
        }
        if (states.contains(WidgetState.hovered)) {
          return const BorderSide(
            color: AppColors.blue600,
            width: AppGeometry.borderWidth,
          );
        }
        return const BorderSide(
          color: AppColors.borderInteractive,
          width: AppGeometry.borderWidth,
        );
      }),
    );

    final button = OutlinedButton(
      onPressed: effectiveOnPressed,
      style: style,
      child: content,
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Botão institucional de aprovação (verde success acessível, texto branco, ícone de check por padrão).
/// Suporta os estados: default, hover, focus, pressed, disabled e loading.
class ApproveButton extends StatelessWidget {
  const ApproveButton({
    super.key,
    this.label = 'Aprovar',
    this.onPressed,
    this.icon = Icons.check,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    final Widget content = isLoading
        ? _buildButtonLoading(color: Colors.white, label: label)
        : _buildButtonContent(
            label: label,
            icon: icon,
            color: effectiveOnPressed != null
                ? Colors.white
                : AppColors.textDisabled,
            isFullWidth: isFullWidth,
          );

    final style = ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(
        Size(
          isFullWidth ? double.infinity : AppGeometry.minTouchTarget,
          AppGeometry.buttonHeight,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppGeometry.buttonBorderRadius),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) && !isLoading) {
          return AppColors.border;
        }
        if (states.contains(WidgetState.pressed)) {
          return const Color(0xFF0D4B2E);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFF12633C);
        }
        return AppColors.success;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textDisabled;
        }
        return Colors.white;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return const BorderSide(color: AppColors.focusDark, width: 2.0);
        }
        return BorderSide.none;
      }),
    );

    final button = ElevatedButton(
      onPressed: effectiveOnPressed,
      style: style,
      child: content,
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Botão institucional de rejeição / ação destrutiva (vermelho danger acessível, texto branco).
/// Suporta os estados: default, hover, focus, pressed, disabled e loading.
class DangerButton extends StatelessWidget {
  const DangerButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    final Widget content = isLoading
        ? _buildButtonLoading(color: Colors.white, label: label)
        : _buildButtonContent(
            label: label,
            icon: icon,
            color: effectiveOnPressed != null
                ? Colors.white
                : AppColors.textDisabled,
            isFullWidth: isFullWidth,
          );

    final style = ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(
        Size(
          isFullWidth ? double.infinity : AppGeometry.minTouchTarget,
          AppGeometry.buttonHeight,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppGeometry.buttonBorderRadius),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) && !isLoading) {
          return AppColors.border;
        }
        if (states.contains(WidgetState.pressed)) {
          return const Color(0xFF70160F);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFF911C13);
        }
        return AppColors.danger;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.textDisabled;
        }
        return Colors.white;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return const BorderSide(color: AppColors.focusDark, width: 2.0);
        }
        return BorderSide.none;
      }),
    );

    final button = ElevatedButton(
      onPressed: effectiveOnPressed,
      style: style,
      child: content,
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Alias para [DangerButton] com label padrão 'Rejeitar' e ícone de cancelamento.
class RejectButton extends StatelessWidget {
  const RejectButton({
    super.key,
    this.label = 'Rejeitar',
    this.onPressed,
    this.icon = Icons.close,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    return DangerButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
    );
  }
}

/// Botão de ação com ícone para tabelas, toolbars e cabeçalhos.
/// Garante área mínima de toque de 44x44px para acessibilidade WCAG 2.2 AA.
class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.backgroundColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AppGeometry.buttonBorderRadius,
            focusColor: AppColors.blue50,
            hoverColor: const Color(0xFFF0F4F8),
            child: Container(
              width: AppGeometry.minTouchTarget,
              height: AppGeometry.minTouchTarget,
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.transparent,
                borderRadius: AppGeometry.buttonBorderRadius,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color: onPressed != null
                    ? (color ?? AppColors.textPrimary)
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
