import 'package:flutter/material.dart';

import '../../ui/tokens.dart';

/// Aviso institucional de privacidade e retenção de dados (AD-12 / LGPD).
///
/// Reutilizável no aceite do termo e na ficha do voluntário. Mobile-first,
/// estado nunca comunicado apenas por cor e alvos de toque de ao menos 44 px.
class PoliticaPrivacidadeCard extends StatelessWidget {
  const PoliticaPrivacidadeCard({
    super.key,
    this.compacto = false,
  });

  /// Quando `true`, reduz espaçamentos para uso em diálogo no celular.
  final bool compacto;

  static const String _textoRetencao =
      'Seus dados pessoais e os documentos do voluntariado são retidos por 5 anos '
      '(política AD-12_V1), prazo necessário para comprovar a relação de serviço '
      'voluntário, salvo obrigação legal superior.';
  static const String _textoFinalidade =
      'Finalidade: identificar o voluntário, registrar o aceite do Termo de Adesão '
      'e comprovar a atuação na equipe. Não usamos seus dados para outras finalidades.';
  static const String _textoPdf =
      'O Termo em PDF é privado e individual por equipe. Ele só é gerado por função '
      'autorizada, a partir de registros oficiais, e o download usa link curto e revogável.';
  static const String _textoCanal =
      'Canal da Privacidade (LGPD): para solicitar acesso, correção ou exclusão de dados, '
      'procure a coordenação geral do Maanaim. Fichas encerradas elegíveis são anonimizadas.';

  @override
  Widget build(BuildContext context) {
    final padding = compacto ? AppSpacing.s12 : AppSpacing.cardPadding;

    return Semantics(
      container: true,
      label: 'Aviso de privacidade e retenção de dados',
      child: Container(
        key: const Key('politica_privacidade_card'),
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: AppColors.blue50,
          borderRadius: AppGeometry.cardBorderRadius,
          border: Border.all(color: AppColors.border, width: AppGeometry.borderWidth),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.privacy_tip_outlined, color: AppColors.navy900, size: 22),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'Privacidade e Retenção de Dados',
                    style: AppTypography.h3.copyWith(fontSize: compacto ? 15 : 16),
                  ),
                ),
              ],
            ),
            SizedBox(height: compacto ? AppSpacing.s8 : AppSpacing.s12),
            _linha(Icons.schedule, _textoRetencao),
            const SizedBox(height: AppSpacing.s8),
            _linha(Icons.flag_outlined, _textoFinalidade),
            const SizedBox(height: AppSpacing.s8),
            _linha(Icons.lock_outline, _textoPdf),
            const SizedBox(height: AppSpacing.s8),
            _linha(Icons.support_agent_outlined, _textoCanal),
          ],
        ),
      ),
    );
  }

  Widget _linha(IconData icone, String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icone, size: 18, color: AppColors.blue600),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            texto,
            style: AppTypography.body.copyWith(
              fontSize: compacto ? 13 : 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
