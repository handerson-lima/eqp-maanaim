import 'package:flutter/material.dart';
import 'participacao_service.dart';

/// Diálogo acessível para cancelamento integral do voluntariado (toda a ficha).
///
/// Apresenta previamente os itens afetados (participações não terminais)
/// antes de requerer a confirmação explícita do usuário (Story 4.3 / Sally).
class CancelarVoluntariadoDialog extends StatefulWidget {
  const CancelarVoluntariadoDialog({
    super.key,
    required this.fichaId,
    required this.participacoesAfetadas,
    this.isLideranca = false,
    required this.onConfirmar,
  });

  final String fichaId;
  final List<ParticipacaoModel> participacoesAfetadas;
  final bool isLideranca;
  final Future<void> Function(String? motivo) onConfirmar;

  static Future<bool?> show(
    BuildContext context, {
    required String fichaId,
    required List<ParticipacaoModel> participacoesAfetadas,
    bool isLideranca = false,
    required Future<void> Function(String? motivo) onConfirmar,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CancelarVoluntariadoDialog(
        fichaId: fichaId,
        participacoesAfetadas: participacoesAfetadas,
        isLideranca: isLideranca,
        onConfirmar: onConfirmar,
      ),
    );
  }

  @override
  State<CancelarVoluntariadoDialog> createState() => _CancelarVoluntariadoDialogState();
}

class _CancelarVoluntariadoDialogState extends State<CancelarVoluntariadoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _motivoController = TextEditingController();
  bool _enviando = false;
  String? _erroMensagem;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _submeter() async {
    if (widget.isLideranca) {
      if (!_formKey.currentState!.validate()) return;
    }

    setState(() {
      _enviando = true;
      _erroMensagem = null;
    });

    try {
      await widget.onConfirmar(
        _motivoController.text.trim().isNotEmpty
            ? _motivoController.text.trim()
            : null,
      );
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
          _erroMensagem = 'Falha ao encerrar voluntariado: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  static String _rotuloEstado(String estado) {
    final s = estado.trim().toUpperCase();
    if (s.startsWith('AGUARDANDO')) return 'AGUARDANDO';
    if (s == 'EM_APROVACAO') return 'EM APROVAÇÃO';
    return estado;
  }

  @override
  Widget build(BuildContext context) {
    const corPerigo = Color(0xFFEF4444);
    const corPerigoBg = Color(0xFFFDECEC);
    const corNavy900 = Color(0xFF0F172A);
    const corGray600 = Color(0xFF475569);
    const corGray100 = Color(0xFFF1F5F9);

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabeçalho de Alerta
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: corPerigoBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.report_problem_rounded,
                        color: corPerigo,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Encerrar Voluntariado',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: corNavy900,
                            ),
                          ),
                          Text(
                            'Cancelamento integral da ficha',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: corGray600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Aviso de consequência
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: corPerigoBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: corPerigo.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Atenção: Esta ação encerrará definitivamente todo o seu voluntariado no Maanaim e todas as suas participações ativas e em andamento. O histórico será preservado para auditoria.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF991B1B),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Lista prévia dos itens afetados (Sally / Acceptance Criteria)
                if (widget.participacoesAfetadas.isNotEmpty) ...[
                  const Text(
                    'Equipes e participações que serão canceladas:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: corNavy900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: corGray100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.participacoesAfetadas.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (ctx, i) {
                        final p = widget.participacoesAfetadas[i];
                        return Padding(
                          key: Key('item_afetado_${p.id}'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.group_outlined, size: 18, color: corNavy900),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p.nomeEquipe,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: corNavy900,
                                  ),
                                ),
                              ),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 110),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    _rotuloEstado(p.estado),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: corGray600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Campo de justificativa se liderança
                if (widget.isLideranca) ...[
                  const Text(
                    'Justificativa da liderança (obrigatória para auditoria)*',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: corNavy900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('campo_motivo_cancelamento_voluntariado'),
                    controller: _motivoController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Informe o motivo detalhado para fins de registro eclesiástico...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length < 5) {
                        return 'Informe uma justificativa com no mínimo 5 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                if (_erroMensagem != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: corPerigoBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _erroMensagem!,
                      style: const TextStyle(fontSize: 12, color: corPerigo),
                    ),
                  ),
                ],

                // Ações com alvos de toque >= 44px e Wrap responsivo
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      key: const Key('btn_cancelar_modal_voluntariado'),
                      onPressed: _enviando
                          ? null
                          : () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop(false);
                              }
                            },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(100, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text(
                        'Desistir',
                        style: TextStyle(color: corGray600, fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton(
                      key: const Key('btn_confirmar_cancelamento_voluntariado'),
                      onPressed: _enviando ? null : _submeter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: corPerigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(160, 44),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _enviando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Confirmar Cancelamento Total',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
