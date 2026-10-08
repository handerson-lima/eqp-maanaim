import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../ui/tokens.dart';

/// Callback disparado quando uma imagem válida é selecionada pelo usuário.
typedef OnImageSelectedCallback = void Function(
  Uint8List bytes,
  String extensao,
);

/// Widget acessível e mobile-first para exibição e seleção de foto de perfil.
///
/// Segue as diretrizes do Design System do Maanaim com foco em WCAG 2.2 AA:
/// - Alvo de toque de no mínimo 48x48 px
/// - Feedback visual imediato com preview em memória
/// - Validação preventiva de tamanho de arquivo (máx 2 MB)
class AvatarPickerWidget extends StatefulWidget {
  const AvatarPickerWidget({
    super.key,
    required this.nome,
    this.fotoUrl,
    this.previewBytes,
    this.carregando = false,
    required this.onImageSelected,
    this.onImageTooLarge,
    this.raio = 50.0,
  });

  final String nome;
  final String? fotoUrl;
  final Uint8List? previewBytes;
  final bool carregando;
  final OnImageSelectedCallback onImageSelected;
  final VoidCallback? onImageTooLarge;
  final double raio;

  static const int limiteMaximoBytes = 2 * 1024 * 1024; // 2 MB

  @override
  State<AvatarPickerWidget> createState() => _AvatarPickerWidgetState();
}

class _AvatarPickerWidgetState extends State<AvatarPickerWidget> {
  final ImagePicker _picker = ImagePicker();

  String _extrairIniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return 'U';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  Future<void> _selecionarImagem() async {
    if (widget.carregando) return;

    try {
      final XFile? arquivo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (arquivo == null) return;

      final bytes = await arquivo.readAsBytes();
      if (bytes.lengthInBytes > AvatarPickerWidget.limiteMaximoBytes) {
        if (widget.onImageTooLarge != null) {
          widget.onImageTooLarge!();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A imagem deve ter no máximo 2 MB.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      final nomeArquivo = arquivo.name;
      final extensao = nomeArquivo.contains('.')
          ? nomeArquivo.split('.').last.toLowerCase()
          : 'jpg';

      widget.onImageSelected(bytes, extensao);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível carregar a imagem: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tamanho = widget.raio * 2;
    final iniciais = _extrairIniciais(widget.nome);

    return Semantics(
      label: 'Foto de perfil de ${widget.nome}',
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Container do Avatar
            Container(
              width: tamanho,
              height: tamanho,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.navy900,
                border: Border.all(
                  color: AppColors.surface,
                  width: 3.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: widget.carregando
                    ? const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.surface,
                          ),
                        ),
                      )
                    : widget.previewBytes != null
                        ? Image.memory(
                            widget.previewBytes!,
                            width: tamanho,
                            height: tamanho,
                            fit: BoxFit.cover,
                          )
                        : (widget.fotoUrl != null &&
                                widget.fotoUrl!.trim().isNotEmpty)
                            ? Image.network(
                                widget.fotoUrl!,
                                width: tamanho,
                                height: tamanho,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildIniciais(iniciais),
                              )
                            : _buildIniciais(iniciais),
              ),
            ),

            // Badge Flutuante de Câmera (Alvo de toque com 48x48)
            Positioned(
              right: -4,
              bottom: -4,
              child: Semantics(
                button: true,
                label: 'Alterar foto de perfil',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.carregando ? null : _selecionarImagem,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.blue600,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: AppColors.surface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIniciais(String iniciais) {
    return Container(
      color: AppColors.navy900,
      alignment: Alignment.center,
      child: Text(
        iniciais,
        style: TextStyle(
          color: AppColors.surface,
          fontSize: widget.raio * 0.7,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
