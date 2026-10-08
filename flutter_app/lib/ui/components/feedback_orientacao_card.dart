import 'package:flutter/material.dart';

import '../tokens.dart';
import 'status_chips.dart';

/// Tipo semântico de feedback institucional.
enum FeedbackTipo {
  sucesso,
  atencao,
  erro,
  info,
}

/// Card de feedback e orientação acessível (WCAG 2.2 AA).
/// Combina:
/// - Texto de status
/// - Ícone semântico de alto contraste (não depende exclusivamente de cor)
/// - Orientação inequívoca para a próxima ação do usuário
/// - Alvos mínimos de toque de 44 px nos botões de ação
class FeedbackOrientacaoCard extends StatelessWidget {
  const FeedbackOrientacaoCard({
    super.key,
    required this.titulo,
    required this.mensagem,
    this.orientacaoAcao,
    this.tipo = FeedbackTipo.info,
    this.icone,
    this.statusChipLabel,
    this.acao,
  });

  /// Construtor de conveniência para decisão desfavorável ou cancelamento por liderança.
  /// Fixa a orientação canônica de acolhimento e privacidade:
  /// "Procure o Pastor da igreja local para mais informações" (AD-11, AD-12).
  factory FeedbackOrientacaoCard.decisaoDesfavoravel({
    Key? key,
    String titulo = 'Decisão registrada',
    String mensagem = 'A solicitação de participação não foi aprovada neste ciclo.',
    Widget? acao,
  }) {
    return FeedbackOrientacaoCard(
      key: key,
      titulo: titulo,
      mensagem: mensagem,
      orientacaoAcao: 'Procure o Pastor da igreja local para mais informações',
      tipo: FeedbackTipo.atencao,
      icone: Icons.help_outline_rounded,
      statusChipLabel: 'CONSULTE O PASTOR',
      acao: acao,
    );
  }

  /// Construtor de conveniência para erro recuperável.
  factory FeedbackOrientacaoCard.erro({
    Key? key,
    required String titulo,
    required String mensagem,
    String orientacaoAcao = 'Verifique sua conexão ou tente novamente.',
    Widget? acao,
  }) {
    return FeedbackOrientacaoCard(
      key: key,
      titulo: titulo,
      mensagem: mensagem,
      orientacaoAcao: orientacaoAcao,
      tipo: FeedbackTipo.erro,
      icone: Icons.error_outline_rounded,
      acao: acao,
    );
  }

  final String titulo;
  final String mensagem;
  final String? orientacaoAcao;
  final FeedbackTipo tipo;
  final IconData? icone;
  final String? statusChipLabel;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final cores = _resolverCores(tipo);
    final iconeEfetivo = icone ?? _resolverIcone(tipo);

    return Semantics(
      container: true,
      label: '$titulo. $mensagem${orientacaoAcao != null ? ". Orientação: $orientacaoAcao" : ""}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: cores.fundo,
          borderRadius: AppGeometry.cardBorderRadius,
          border: Border.all(
            color: cores.borda,
            width: AppGeometry.borderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: cores.borda),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    iconeEfetivo,
                    size: 20,
                    color: cores.icone,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              titulo,
                              style: AppTypography.h3.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (statusChipLabel != null) ...[
                            const SizedBox(width: AppSpacing.s8),
                            StatusChip(status: statusChipLabel!),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        mensagem,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (orientacaoAcao != null) ...[
              const SizedBox(height: AppSpacing.s12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppGeometry.radiusInput),
                  border: Border.all(color: cores.borda),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: cores.icone,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        orientacaoAcao!,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (acao != null) ...[
              const SizedBox(height: AppSpacing.s16),
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppGeometry.minTouchTarget,
                  ),
                  child: acao!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static _CoresFeedback _resolverCores(FeedbackTipo tipo) {
    switch (tipo) {
      case FeedbackTipo.sucesso:
        return const _CoresFeedback(
          fundo: AppColors.successBg,
          borda: Color(0xFFB7EB8F),
          icone: AppColors.success,
        );
      case FeedbackTipo.atencao:
        return const _CoresFeedback(
          fundo: AppColors.warningBg,
          borda: Color(0xFFFFE58F),
          icone: AppColors.warning,
        );
      case FeedbackTipo.erro:
        return const _CoresFeedback(
          fundo: AppColors.dangerBg,
          borda: Color(0xFFFFA39E),
          icone: AppColors.danger,
        );
      case FeedbackTipo.info:
        return const _CoresFeedback(
          fundo: AppColors.blue50,
          borda: Color(0xFFADC6FF),
          icone: AppColors.blue600,
        );
    }
  }

  static IconData _resolverIcone(FeedbackTipo tipo) {
    switch (tipo) {
      case FeedbackTipo.sucesso:
        return Icons.check_circle_outline_rounded;
      case FeedbackTipo.atencao:
        return Icons.warning_amber_rounded;
      case FeedbackTipo.erro:
        return Icons.error_outline_rounded;
      case FeedbackTipo.info:
        return Icons.info_outline_rounded;
    }
  }
}

class _CoresFeedback {
  const _CoresFeedback({
    required this.fundo,
    required this.borda,
    required this.icone,
  });

  final Color fundo;
  final Color borda;
  final Color icone;
}
