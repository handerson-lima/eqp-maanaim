import 'package:flutter/material.dart';

import '../../ui/components/buttons.dart';
import '../../ui/tokens.dart';
import '../../ui/components/cpf_formatter.dart';
import 'termo_adesao_model.dart';
import 'termo_logo_asset.dart';
import 'termo_printer.dart';

/// Widget visual que reproduz fielmente a folha física do
/// "TERMO DE ADESÃO DE VOLUNTÁRIO" da Igreja Cristã Maranata / Maanaim do RN.
class TermoAdesaoWidget extends StatelessWidget {
  const TermoAdesaoWidget({
    super.key,
    required this.model,
    this.onFechar,
    this.mostrarAcoes = true,
  });

  final TermoAdesaoModel model;
  final VoidCallback? onFechar;
  final bool mostrarAcoes;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mostrarAcoes) _buildBarraAcoes(context),
              if (mostrarAcoes) const SizedBox(height: AppSpacing.s16),
              _buildFolhaDocumento(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarraAcoes(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s16,
            runSpacing: AppSpacing.s12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined, color: AppColors.navy900),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    'Termo Oficial de Adesão',
                    style: AppTypography.h3.copyWith(fontSize: 16),
                  ),
                ],
              ),
              Wrap(
                spacing: AppSpacing.s12,
                runSpacing: AppSpacing.s8,
                children: [
                  if (onFechar != null)
                    SecondaryButton(
                      label: 'Voltar',
                      icon: Icons.arrow_back,
                      onPressed: onFechar,
                    ),
                  PrimaryButton(
                    key: const Key('botao_imprimir_termo'),
                    label: isNarrow ? 'Imprimir PDF' : 'Imprimir / Salvar PDF',
                    icon: Icons.print_outlined,
                    onPressed: () => imprimirTermo(model),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFolhaDocumento(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Logotipo oficial da Igreja Cristã Maranata
          Center(
            child: Image.memory(
              kLogoMaranataBytes,
              height: 68,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              semanticLabel: 'Logo Igreja Cristã Maranata',
            ),
          ),
          const SizedBox(height: 18),

          // 2. Títulos
          const Text(
            'MAANAIM DO RIO GRANDE DO NORTE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'TERMO DE ADESÃO DE VOLUNTÁRIO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),

          // Linha divisória horizontal
          const Divider(
            color: Colors.black,
            thickness: 1.2,
            height: 24,
          ),
          const SizedBox(height: 16),

          // 3. Subtítulo Legal
          const Center(
            child: Text(
              'Lei do Serviço Voluntário (LEI 9.608/1998)',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.underline,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 4. Parágrafo Principal com dados dinâmicos
          RichText(
            textAlign: TextAlign.justify,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                height: 1.65,
                color: Colors.black,
                fontFamily: 'Arial',
              ),
              children: [
                TextSpan(
                  text: model.nomeVoluntario.trim().toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(
                  text: ', ${model.nacionalidadeVoluntario}, Profissão ',
                ),
                TextSpan(
                  text: model.profissaoVoluntario.trim().toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const TextSpan(
                  text: ', inscrito(a) no CPF/MF sob o nº ',
                ),
                TextSpan(
                  text: CpfFormatter.formatar(model.cpfVoluntario),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const TextSpan(
                  text: ', celebra com a ',
                ),
                const TextSpan(
                  text: 'IGREJA CRISTÃ MARANATA',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const TextSpan(
                  text: ', pessoa jurídica de direito privado, inscrito no CNPJ '
                      'sob o nº 27.056.910/0001-42, com sede na Rua Torquato Laranja, 90, '
                      'Centro, Vila Velha – ES, CEP 29106-720, neste ato, representado '
                      'pelo Administrador Voluntário do Maanaim do RIO GRANDE DO NORTE, ',
                ),
                TextSpan(
                  text: model.nomeCoordenador.trim().toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(
                  text: ', ${model.nacionalidadeCoordenador}, '
                      '${model.estadoCivilCoordenador}, inscrito no CPF/MF sob o nº ',
                ),
                TextSpan(
                  text: CpfFormatter.formatar(model.cpfCoordenador),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const TextSpan(
                  text: ', em conformidade aos preceitos da Lei nº 9.608 de 18/02/1998, '
                      'o presente ',
                ),
                const TextSpan(
                  text: 'TERMO DE ADESÃO AO SERVIÇO VOLUNTÁRIO',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const TextSpan(
                  text: ' para prestação de serviço na equipe ',
                ),
                TextSpan(
                  text: model.nomeEquipe.trim().toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 5. Parágrafo Secundário
          const Text(
            TermoAdesaoModel.textoParagrafoSecundario,
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontSize: 13,
              height: 1.65,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 32),

          // 6. Local e Data
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black,
              ),
              children: [
                const TextSpan(text: 'Natal – RN, '),
                TextSpan(
                  text: '${model.dataFormatadaExtenso}.',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // 7. Bloco de Assinaturas
          _buildBlocoAssinaturas(),
        ],
      ),
    );
  }

  Widget _buildBlocoAssinaturas() {
    return Column(
      children: [
        // Assinatura do Voluntário
        _buildItemAssinatura(
          nome: model.nomeVoluntario.trim().toUpperCase(),
          papel: 'VOLUNTÁRIO(A)',
        ),
        const SizedBox(height: 40),

        // Assinatura do Coordenador do Maanaim
        _buildItemAssinatura(
          nome: model.nomeCoordenador.trim().toUpperCase(),
          papel: 'COORDENADOR DO MAANAIM',
        ),
        const SizedBox(height: 32),

        // Título Testemunhas
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'TESTEMUNHAS:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 36),

        // Testemunha 1: Pastor da Igreja Local do Voluntário
        _buildItemAssinatura(
          nome: model.nomePastorVoluntario.trim().toUpperCase(),
          papel: 'PASTOR DA IGREJA LOCAL',
        ),
        const SizedBox(height: 40),

        // Testemunha 2: Pastor Chefe da Equipe
        _buildItemAssinatura(
          nome: model.nomePastorEquipe.trim().toUpperCase(),
          papel: 'PASTOR CHEFE DA EQUIPE',
        ),
      ],
    );
  }

  Widget _buildItemAssinatura({
    required String nome,
    required String papel,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          children: [
            Container(
              height: 1.2,
              color: Colors.black,
              width: double.infinity,
            ),
            const SizedBox(height: 6),
            Text(
              nome,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              papel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
