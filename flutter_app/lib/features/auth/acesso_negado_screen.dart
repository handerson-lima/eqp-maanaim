import 'package:flutter/material.dart';
import '../../ui/tokens.dart';
import '../../ui/components/buttons.dart';

/// Tela exibida quando o usuário tenta acessar uma rota ou área para a qual
/// não possui capacidade autorizada no backend (HTTP 403 / Proibido).
class AcessoNegadoScreen extends StatelessWidget {
  const AcessoNegadoScreen({
    super.key,
    this.mensagem = 'Você não possui permissão para acessar esta área com seu vínculo atual.',
    this.capacidadeNecessaria,
    this.onVoltar,
    this.onSair,
  });

  final String mensagem;
  final String? capacidadeNecessaria;
  final VoidCallback? onVoltar;
  final VoidCallback? onSair;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Card(
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: AppColors.dangerBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: AppColors.danger,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      Semantics(
                        header: true,
                        child: Text(
                          'Acesso não autorizado',
                          textAlign: TextAlign.center,
                          style: AppTypography.h2.copyWith(
                            color: AppColors.navy900,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Text(
                        mensagem,
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (capacidadeNecessaria != null) ...[
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          'Área restrita: $capacidadeNecessaria',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s24),
                      if (onVoltar != null)
                        PrimaryButton(
                          label: 'Voltar para área permitida',
                          onPressed: onVoltar,
                          icon: Icons.arrow_back,
                        ),
                      if (onSair != null) ...[
                        const SizedBox(height: AppSpacing.s8),
                        SecondaryButton(
                          label: 'Sair da conta',
                          onPressed: onSair,
                          icon: Icons.logout,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
