import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// Campo de entrada de texto padronizado e acessível (WCAG 2.2 AA).
/// Garante:
/// - Rótulo persistente posicionado acima do campo (nunca desaparece ou flutua para fora de vista)
/// - Indicador de campo obrigatório acessível
/// - Foco visível reforçado com contorno de 2px
/// - Limite interativo claro com [AppColors.borderInteractive]
/// - Mensagem de erro semântica associada e destacada em [AppColors.danger]
/// - Altura mínima de toque de 44px
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hintText,
    this.helperText,
    this.errorText,
    this.isRequired = false,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final bool isRequired;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rótulo persistente acima do campo
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: enabled
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: AppSpacing.s4),
              Semantics(
                label: 'obrigatório',
                child: const Text(
                  '*',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        // Campo de entrada
        Semantics(
          label: isRequired ? '$label, obrigatório' : label,
          child: TextFormField(
            key: key != null ? ValueKey('field_$key') : null,
            controller: controller,
            initialValue: initialValue,
            enabled: enabled,
            readOnly: readOnly,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            minLines: minLines,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            validator: validator,
            focusNode: focusNode,
            autofocus: autofocus,
            style: AppTypography.body.copyWith(
              color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              helperText: helperText,
              errorText: errorText,
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              isDense: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: 12,
              ),
              filled: true,
              fillColor: enabled ? AppColors.surface : AppColors.background,
              border: OutlineInputBorder(
                borderRadius: AppGeometry.inputBorderRadius,
                borderSide: const BorderSide(
                  color: AppColors.borderInteractive,
                  width: AppGeometry.borderWidth,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppGeometry.inputBorderRadius,
                borderSide: const BorderSide(
                  color: AppColors.borderInteractive,
                  width: AppGeometry.borderWidth,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppGeometry.inputBorderRadius,
                borderSide: const BorderSide(
                  color: AppColors.focusLight,
                  width: 2.0,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: AppGeometry.inputBorderRadius,
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: AppGeometry.borderWidth,
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
              errorStyle: AppTypography.caption.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w500,
              ),
              helperStyle: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Seletor / Dropdown padronizado e acessível (WCAG 2.2 AA).
/// Garante:
/// - Rótulo persistente acima do campo
/// - Semântica explícita de nome, papel e seleção
/// - Contornos e foco consistentes com [AppTextField]
/// - Alvo de toque mínimo de 44px
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.items,
    this.value,
    this.onChanged,
    this.hintText,
    this.helperText,
    this.errorText,
    this.isRequired = false,
    this.enabled = true,
  });

  final String label;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final bool isRequired;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rótulo persistente
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: enabled
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: AppSpacing.s4),
              Semantics(
                label: 'obrigatório',
                child: const Text(
                  '*',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        // Campo dropdown
        Semantics(
          label: label,
          hint: hintText,
          button: true,
          child: DropdownButtonFormField<T>(
            initialValue: value,
            items: items,
            onChanged: enabled ? onChanged : null,
            style: AppTypography.body.copyWith(
              color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            icon: const Icon(
              Icons.arrow_drop_down,
              color: AppColors.textSecondary,
              size: 24,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              helperText: helperText,
              errorText: errorText,
              isDense: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: 12,
              ),
              filled: true,
              fillColor: enabled ? AppColors.surface : AppColors.background,
              border: OutlineInputBorder(
                borderRadius: AppGeometry.inputBorderRadius,
                borderSide: const BorderSide(
                  color: AppColors.borderInteractive,
                  width: AppGeometry.borderWidth,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppGeometry.inputBorderRadius,
                borderSide: const BorderSide(
                  color: AppColors.borderInteractive,
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
              disabledBorder: OutlineInputBorder(
                borderRadius: AppGeometry.inputBorderRadius,
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: AppGeometry.borderWidth,
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
              errorStyle: AppTypography.caption.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
