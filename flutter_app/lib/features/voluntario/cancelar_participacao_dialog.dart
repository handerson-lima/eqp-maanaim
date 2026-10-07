import 'package:flutter/material.dart';
import 'participacao_service.dart';

/// Diálogo acessível para confirmação de cancelamento de uma participação individual.
///
/// Desenvolvido em conformidade com o Design System de Maanaim (Sally):
/// - Cores canônicas: Danger `#EF4444`, Danger-bg `#FDECEC`, Navy-900 `#0F172A`.
/// - Alvos de toque >= 44px.
/// - WCAG 2.2 AA: contraste elevado e comunicação semântica com ícones e texto.
/// - Campo opcional/obrigatório de motivo caso o cancelador seja liderança.
class CancelarParticipacaoDialog extends StatefulWidget {
  const CancelarParticipacaoDialog({
    super.key,
    required this.participacao,
    this.isLideranca = false,
    required this.onConfirmar,
  });

  final ParticipacaoModel participacao;
  final bool isLideranca;
  final Future<void> Function(String? motivo) onConfirmar;

  static Future<bool?> show(
    BuildContext context, {
    required ParticipacaoModel participacao,
    bool isLideranca = false,
    required Future<void> Function(String? motivo) onConfirmar,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CancelarParticipacaoDialog(
        participacao: participacao,
        isLideranca: isLideranca,
        onConfirmar: onConfirmar,
      ),
    );
  }

  @override
  State<CancelarParticipacaoDialog> createState() => _CancelarParticipacaoDialogState();
}

class _CancelarParticipacaoDialogState extends State<CancelarParticipacaoDialog> {
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
          _erroMensagem = 'Falha ao cancelar: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const corPerigo = Color(0xFFEF4444);
    const corPerigoBg = Color(0xFFFDECEC);
    const corNavy900 = Color(0xFF0F172A);
    const corGray600 = Color(0xFF475569);

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: corPerigoBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: corPerigo,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cancelar Participação',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: corNavy900,
                            ),
                          ),
                          Text(
                            widget.participacao.nomeEquipe,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: corGray600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Mensagem explicativa
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: corPerigoBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: corPerigo.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    widget.isLideranca
                        ? 'Você está cancelando a participação deste voluntário na equipe ${widget.participacao.nomeEquipe}. A justificativa interna é obrigatória e será gravada para auditoria.'
                        : 'Atenção: Ao cancelar sua participação na equipe ${widget.participacao.nomeEquipe}, ela será encerrada imediatamente. Suas outras equipes permanecerão ativas.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF991B1B),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Campo de justificativa (obrigatório se liderança, opcional se voluntário)
                if (widget.isLideranca) ...[
                  const Text(
                    'Justificativa interna (obrigatória para auditoria)*',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: corNavy900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: const Key('campo_motivo_cancelamento'),
                    controller: _motivoController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Informe o motivo detalhado para fins de auditoria...',
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
                      key: const Key('btn_cancelar_modal_participacao'),
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
                        'Manter Equipe',
                        style: TextStyle(color: corGray600, fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton(
                      key: const Key('btn_confirmar_cancelamento_participacao'),
                      onPressed: _enviando ? null : _submeter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: corPerigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(140, 44),
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
                              'Confirmar Cancelamento',
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
