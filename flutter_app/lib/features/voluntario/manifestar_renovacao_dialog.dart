import 'package:flutter/material.dart';
import '../../ui/components/vigencia_badge.dart';
import '../../ui/tokens.dart';
import 'participacao_service.dart';

/// Diálogo acessível para o voluntário manifestar interesse de renovação por equipe (Story 5.2).
///
/// Desenvolvido em conformidade com o Design System de Maanaim (Sally):
/// - Cores canônicas: Blue-600, Navy-900, TextPrimary, TextSecondary.
/// - Alvos de toque >= 44px (WCAG 2.2 AA).
/// - Linguagem semântica, sem jargão técnico (sem "payload", "commandId" ou "AD-11").
/// - Escolha inequívoca ("Continuar" vs "Não Continuar") com confirmação clara de impacto.
class ManifestarRenovacaoDialog extends StatefulWidget {
  const ManifestarRenovacaoDialog({
    super.key,
    required this.participacoesElegiveis,
    required this.onConfirmar,
    this.participacaoPreSelecionadaId,
  });

  final List<ParticipacaoModel> participacoesElegiveis;
  final Future<void> Function(List<ManifestacaoEquipeInput> manifestacoes) onConfirmar;
  final String? participacaoPreSelecionadaId;

  static Future<bool?> show(
    BuildContext context, {
    required List<ParticipacaoModel> participacoesElegiveis,
    required Future<void> Function(List<ManifestacaoEquipeInput> manifestacoes) onConfirmar,
    String? participacaoPreSelecionadaId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ManifestarRenovacaoDialog(
        participacoesElegiveis: participacoesElegiveis,
        onConfirmar: onConfirmar,
        participacaoPreSelecionadaId: participacaoPreSelecionadaId,
      ),
    );
  }

  @override
  State<ManifestarRenovacaoDialog> createState() => _ManifestarRenovacaoDialogState();
}

class _ManifestarRenovacaoDialogState extends State<ManifestarRenovacaoDialog> {
  // Mapa de participacaoId -> 'CONTINUAR' ou 'NAO_CONTINUAR'
  final Map<String, String> _decisoes = {};
  bool _enviando = false;
  String? _erroMensagem;

  @override
  void initState() {
    super.initState();
    // Inicializa decisões padrão: por padrão todas iniciam como 'CONTINUAR'
    for (final p in widget.participacoesElegiveis) {
      _decisoes[p.id] = p.intencaoRenovacao ?? 'CONTINUAR';
    }
  }

  Future<void> _submeter() async {
    // Valida se há pelo menos uma escolha de não continuar que exija confirmação
    final temNaoContinuar = _decisoes.values.any((d) => d == 'NAO_CONTINUAR');

    if (temNaoContinuar) {
      final confirmou = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'Confirmar Encerramento?',
            style: TextStyle(
              color: AppColors.navy900,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: const Text(
            'Para as equipes marcadas como "Não continuar", você continuará servindo até o final da vigência atual. Após o vencimento, a participação será encerrada. Suas demais equipes não serão afetadas.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text('Revisar Escolhas', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue600,
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
              ),
              child: const Text('Confirmar Envio'),
            ),
          ],
        ),
      );

      if (confirmou != true) {
        return;
      }
    }

    setState(() {
      _enviando = true;
      _erroMensagem = null;
    });

    try {
      final listaInputs = widget.participacoesElegiveis.map((p) {
        final dec = _decisoes[p.id] ?? 'CONTINUAR';
        return ManifestacaoEquipeInput(
          participacaoId: p.id,
          decisao: dec,
        );
      }).toList();

      await widget.onConfirmar(listaInputs);

      if (mounted) {
        setState(() {
          _enviando = false;
        });
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _erroMensagem = 'Não foi possível registrar a renovação: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Dialog(
      key: const Key('dialog_manifestar_renovacao'),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 520,
          maxHeight: 720,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.blue50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.autorenew_rounded,
                      color: AppColors.blue600,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Renovação Anual',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Indique se você deseja continuar atuando em cada equipe no próximo ano.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.s16),

              // Erro se houver
              if (_erroMensagem != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _erroMensagem!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
              ],

              // Lista de equipes elegíveis com seletores
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.participacoesElegiveis.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s16),
                  itemBuilder: (context, index) {
                    final p = widget.participacoesElegiveis[index];
                    final decisaoAtual = _decisoes[p.id] ?? 'CONTINUAR';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Título da equipe e badge de vigência
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                p.nomeEquipe,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy900,
                                ),
                              ),
                              if (p.diasParaVencimento != null || p.alertaVigencia != null)
                                VigenciaBadge(
                                  vigenciaInicio: p.vigenciaInicio,
                                  vigenciaFim: p.vigenciaFim,
                                  situacaoVigencia: p.situacaoVigencia,
                                  diasParaVencimento: p.diasParaVencimento,
                                  alertaVigencia: p.alertaVigencia,
                                  compact: true,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s12),

                          // Opção 1: Continuar
                          _buildOpcaoSelecao(
                            key: Key('btn_continuar_${p.id}'),
                            titulo: 'Sim, quero continuar nesta equipe',
                            descricao:
                                'Sua solicitação de renovação será enviada para confirmação do Pastor e da Coordenação.',
                            selecionado: decisaoAtual == 'CONTINUAR',
                            onTap: _enviando
                                ? null
                                : () {
                                    setState(() {
                                      _decisoes[p.id] = 'CONTINUAR';
                                    });
                                  },
                            corDestaque: AppColors.blue600,
                          ),
                          const SizedBox(height: AppSpacing.s8),

                          // Opção 2: Não Continuar
                          _buildOpcaoSelecao(
                            key: Key('btn_nao_continuar_${p.id}'),
                            titulo: 'Não pretendo continuar nesta equipe',
                            descricao:
                                'Você segue servindo normalmente até o término da vigência atual.',
                            selecionado: decisaoAtual == 'NAO_CONTINUAR',
                            onTap: _enviando
                                ? null
                                : () {
                                    setState(() {
                                      _decisoes[p.id] = 'NAO_CONTINUAR';
                                    });
                                  },
                            corDestaque: const Color(0xFFD97706),
                          ),

                          if (decisaoAtual == 'NAO_CONTINUAR') ...[
                            const SizedBox(height: AppSpacing.s8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Seu vínculo continuará ativo até o fim do prazo. Suas demais equipes não serão afetadas.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.s20),

              // Botões de Ação
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    key: const Key('btn_cancelar_manifestacao'),
                    onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(88, 44),
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textPrimary,
                    ),
                    child: const Text('Voltar'),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  ElevatedButton(
                    key: const Key('btn_confirmar_manifestacao'),
                    onPressed: _enviando ? null : _submeter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(140, 44),
                      elevation: 0,
                    ),
                    child: _enviando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Confirmar Renovação',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpcaoSelecao({
    required Key key,
    required String titulo,
    required String descricao,
    required bool selecionado,
    required VoidCallback? onTap,
    required Color corDestaque,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? corDestaque.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selecionado ? corDestaque : AppColors.border,
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selecionado ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: selecionado ? corDestaque : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selecionado ? FontWeight.bold : FontWeight.w600,
                      color: selecionado ? AppColors.navy900 : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    descricao,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
