import 'package:flutter/material.dart';
import 'participacao_service.dart';

/// Diálogo acessível para solicitação de reativação de uma equipe/participação terminal.
///
/// Desenvolvido em conformidade com o Design System de Maanaim (Sally):
/// - Cores canônicas: Blue-600 `#2563EB`, Navy-900 `#0F172A`, Fundo Info `#EFF6FF`.
/// - Alvos de toque >= 44px.
/// - WCAG 2.2 AA: contraste elevado e comunicação semântica com ícones e texto.
/// - Informa com clareza as 3 etapas de aprovação (Pastor -> Responsável -> Coordenador).
class SolicitarReativacaoDialog extends StatefulWidget {
  const SolicitarReativacaoDialog({
    super.key,
    required this.participacao,
    required this.onConfirmar,
  });

  final ParticipacaoModel participacao;
  final Future<void> Function(String? justificativa) onConfirmar;

  static Future<bool?> show(
    BuildContext context, {
    required ParticipacaoModel participacao,
    required Future<void> Function(String? justificativa) onConfirmar,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SolicitarReativacaoDialog(
        participacao: participacao,
        onConfirmar: onConfirmar,
      ),
    );
  }

  @override
  State<SolicitarReativacaoDialog> createState() => _SolicitarReativacaoDialogState();
}

class _SolicitarReativacaoDialogState extends State<SolicitarReativacaoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _justificativaController = TextEditingController();
  bool _enviando = false;
  String? _erroMensagem;

  @override
  void dispose() {
    _justificativaController.dispose();
    super.dispose();
  }

  Future<void> _submeter() async {
    setState(() {
      _enviando = true;
      _erroMensagem = null;
    });

    try {
      await widget.onConfirmar(
        _justificativaController.text.trim().isNotEmpty
            ? _justificativaController.text.trim()
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
          _erroMensagem = 'Falha ao solicitar reativação: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const corBlue600 = Color(0xFF2563EB);
    const corBlueBg = Color(0xFFEFF6FF);
    const corNavy900 = Color(0xFF0F172A);
    const corGray600 = Color(0xFF475569);
    const corBorda = Color(0xFFE2E8F0);

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: corBorda),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: corBlueBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.replay_rounded,
                          color: corBlue600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Solicitar Reativação',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: corNavy900,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Identificação da equipe
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: corBorda),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Equipe selecionada:',
                          style: TextStyle(
                            fontSize: 12,
                            color: corGray600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.participacao.nomeEquipe.isNotEmpty
                              ? widget.participacao.nomeEquipe
                              : widget.participacao.equipeId,
                          style: const TextStyle(
                            fontSize: 16,
                            color: corNavy900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Explicação do Novo Ciclo de Aprovação
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: corBlueBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: corBlue600),
                            SizedBox(width: 8),
                            Text(
                              'Como funciona a reativação?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: corNavy900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'A reativação cria um novo ciclo sem apagar seu histórico. A solicitação percorrerá a cadeia completa de deliberação:',
                          style: TextStyle(fontSize: 12, color: corNavy900),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '1️⃣ Aprovação pelo Pastor Local da igreja\n'
                          '2️⃣ Avaliação pelo Responsável da Equipe\n'
                          '3️⃣ Homologação final pelo Coordenador Geral',
                          style: TextStyle(
                            fontSize: 12,
                            color: corNavy900,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Campo de Justificativa (Opcional)
                  TextFormField(
                    key: const Key('input_justificativa_reativacao'),
                    controller: _justificativaController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Mensagem ou justificativa (opcional)',
                      hintText: 'Explique brevemente o motivo pelo qual deseja retornar...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: corBorda),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: corBlue600, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),

                  // Mensagem de Erro
                  if (_erroMensagem != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _erroMensagem!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Ações (Mobile-First Wrap com alvos >= 44px)
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        key: const Key('btn_cancelar_dialog_reativacao'),
                        onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(100, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          side: const BorderSide(color: corBorda),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Voltar',
                          style: TextStyle(
                            color: corGray600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        key: const Key('btn_confirmar_dialog_reativacao'),
                        onPressed: _enviando ? null : _submeter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: corBlue600,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(150, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _enviando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Confirmar Reativação',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
