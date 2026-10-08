import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class WebImageResult {
  const WebImageResult(this.bytes, this.extensao);
  final Uint8List bytes;
  final String extensao;
}

/// Fallback para plataformas móveis ou testes onde dart:html não está presente.
Future<WebImageResult?> pickImageWeb() async {
  final picker = ImagePicker();
  final arquivo = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    maxHeight: 800,
    imageQuality: 85,
  );

  if (arquivo == null) return null;

  final bytes = await arquivo.readAsBytes();
  final ext = arquivo.name.contains('.') ? arquivo.name.split('.').last : 'jpg';
  return WebImageResult(bytes, ext);
}
