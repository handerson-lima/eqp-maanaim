import 'package:flutter/material.dart';

import '../tokens.dart';

/// Níveis de alerta temporal de vigência anual (Story 5.1).
enum VigenciaNivelAlerta {
  normal,
  alerta60d,
  alerta30d,
  expirada,
  desconhecida,
}

/// Badge e chip de exibição de vigência e alertas de renovação.
/// Conforme WCAG 2.2 AA (Sally):
/// - Combina texto explícito, ícone semântico e contraste visual elevado (> 4.5:1).
/// - Suporta mobile-first sem quebra horizontal de layout (390x844).
class VigenciaBadge extends StatelessWidget {
  const VigenciaBadge({
    super.key,
    this.vigenciaInicio,
    this.vigenciaFim,
    this.situacaoVigencia,
    this.diasParaVencimento,
    this.alertaVigencia,
    this.compact = false,
  });

  /// Início da vigência anual (ISO UTC).
  final String? vigenciaInicio;

  /// Vencimento da vigência anual (ISO UTC).
  final String? vigenciaFim;

  /// Situação calculada (ex.: 'VIGENTE', 'ALERTA_PREVIO_60D', 'RENOVACAO_IMINENTE_30D', 'EXPIRADA').
  final String? situacaoVigencia;

  /// Dias restantes para o término da vigência.
  final int? diasParaVencimento;

  /// Mensagem de alerta customizada ou projetada.
  final String? alertaVigencia;

  /// Se deve renderizar em formato compacto para listagens densas.
  final bool compact;

  static String formatarData(String? dataIso) {
    if (dataIso == null || dataIso.trim().isEmpty) return '';
    try {
      final d = DateTime.parse(dataIso).toUtc();
      final dia = d.day.toString().padLeft(2, '0');
      final mes = d.month.toString().padLeft(2, '0');
      final ano = d.year.toString();
      return '$dia/$mes/$ano';
    } catch (_) {
      return dataIso;
    }
  }

  VigenciaNivelAlerta get nivelAlerta {
    final sit = (situacaoVigencia ?? '').trim().toUpperCase();
    if (sit == 'EXPIRADA') return VigenciaNivelAlerta.expirada;
    if (sit == 'RENOVACAO_IMINENTE_30D') return VigenciaNivelAlerta.alerta30d;
    if (sit == 'ALERTA_PREVIO_60D') return VigenciaNivelAlerta.alerta60d;
    if (sit == 'VIGENTE') return VigenciaNivelAlerta.normal;

    if (diasParaVencimento != null) {
      if (diasParaVencimento! <= 0) return VigenciaNivelAlerta.expirada;
      if (diasParaVencimento! <= 30) return VigenciaNivelAlerta.alerta30d;
      if (diasParaVencimento! <= 60) return VigenciaNivelAlerta.alerta60d;
      return VigenciaNivelAlerta.normal;
    }

    if (vigenciaFim != null && vigenciaFim!.isNotEmpty) {
      try {
        final fim = DateTime.parse(vigenciaFim!);
        final agora = DateTime.now();
        final diffDias = (fim.difference(agora).inHours / 24).ceil();
        if (diffDias <= 0) return VigenciaNivelAlerta.expirada;
        if (diffDias <= 30) return VigenciaNivelAlerta.alerta30d;
        if (diffDias <= 60) return VigenciaNivelAlerta.alerta60d;
        return VigenciaNivelAlerta.normal;
      } catch (_) {
        return VigenciaNivelAlerta.desconhecida;
      }
    }

    return VigenciaNivelAlerta.desconhecida;
  }

  @override
  Widget build(BuildContext context) {
    if (vigenciaInicio == null &&
        vigenciaFim == null &&
        situacaoVigencia == null &&
        diasParaVencimento == null &&
        alertaVigencia == null) {
      return const SizedBox.shrink();
    }

    final nivel = nivelAlerta;
    final dataFimFormatada = formatarData(vigenciaFim);
    final dataInicioFormatada = formatarData(vigenciaInicio);

    Color bg;
    Color borderCol;
    Color textCol;
    IconData icon;
    String labelText;
    String semanticsDescription;

    switch (nivel) {
      case VigenciaNivelAlerta.expirada:
        bg = AppColors.dangerBg;
        borderCol = AppColors.danger.withValues(alpha: 0.3);
        textCol = AppColors.danger;
        icon = Icons.cancel_outlined;
        labelText = alertaVigencia ?? 'Vigência expirada';
        semanticsDescription = 'Vigência anual expirada. Necessária solicitação de renovação ou reativação.';
        break;

      case VigenciaNivelAlerta.alerta30d:
        bg = AppColors.warningBg;
        borderCol = AppColors.warning;
        textCol = AppColors.navy900;
        icon = Icons.warning_amber_rounded;
        final dias = diasParaVencimento ?? 30;
        labelText = alertaVigencia ??
            (dias <= 1
                ? 'Renovação necessária: vence em 1 dia'
                : 'Renovação necessária: vence em $dias dias');
        semanticsDescription = 'Alerta de renovação iminente. Vencimento em $dias dias.';
        break;

      case VigenciaNivelAlerta.alerta60d:
        bg = AppColors.warningBg;
        borderCol = AppColors.warning.withValues(alpha: 0.4);
        textCol = AppColors.navy900;
        icon = Icons.schedule;
        final dias = diasParaVencimento ?? 60;
        labelText = alertaVigencia ?? 'Aviso de renovação: vence em $dias dias';
        semanticsDescription = 'Aviso de renovação anual. Vigência expira em $dias dias.';
        break;

      case VigenciaNivelAlerta.normal:
        bg = AppColors.successBg;
        borderCol = AppColors.success.withValues(alpha: 0.25);
        textCol = AppColors.success;
        icon = Icons.check_circle_outline;
        labelText = compact
            ? 'Válido até $dataFimFormatada'
            : (dataInicioFormatada.isNotEmpty
                ? 'Vigência: $dataInicioFormatada até $dataFimFormatada'
                : 'Válido até $dataFimFormatada');
        semanticsDescription = 'Vigência anual ativa até $dataFimFormatada.';
        break;

      case VigenciaNivelAlerta.desconhecida:
        bg = AppColors.neutral100;
        borderCol = AppColors.border;
        textCol = AppColors.textSecondary;
        icon = Icons.info_outline;
        labelText = 'Vigência a definir';
        semanticsDescription = 'Período de vigência em definição.';
        break;
    }

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticsDescription,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.s8 : AppSpacing.s12,
          vertical: compact ? AppSpacing.s4 : AppSpacing.s8 - 2,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: borderCol, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: compact ? 14 : 16,
              color: textCol,
            ),
            const SizedBox(width: AppSpacing.s8 - 2),
            Flexible(
              child: Text(
                labelText,
                style: (compact ? AppTypography.caption : AppTypography.body).copyWith(
                  color: textCol,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
