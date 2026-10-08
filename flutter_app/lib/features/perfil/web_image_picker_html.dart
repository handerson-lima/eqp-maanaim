// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:typed_data';

class WebImageResult {
  const WebImageResult(this.bytes, this.extensao);
  final Uint8List bytes;
  final String extensao;
}

@JS('converterHeicSeNecessario')
external JSPromise<JSAny?> _converterHeicJs(JSAny? file);

/// Implementação nativa Web via HTML FileUploadInputElement.
/// Suporta imagens padrão e conversão automática de arquivos HEIC/HEIF para JPEG.
Future<WebImageResult?> pickImageWeb() async {
  final completer = Completer<WebImageResult?>();
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept =
      'image/png,image/jpeg,image/webp,image/jpg,.heic,.heif,image/heic,image/heif';

  uploadInput.onChange.listen((event) async {
    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files[0];
    final nome = file.name;
    var ext = nome.contains('.') ? nome.split('.').last.toLowerCase() : 'jpg';

    dynamic blobAlvo = file;

    // Se for formato HEIC/HEIF, converte para JPEG usando o helper
    if (ext == 'heic' || ext == 'heif') {
      try {
        final JSAny? resultadoJs =
            await _converterHeicJs(file as dynamic).toDart;
        if (resultadoJs != null) {
          blobAlvo = resultadoJs as dynamic;
          ext = 'jpg';
        }
      } catch (_) {
        // Fallback: mantém o arquivo original se a conversão falhar
      }
    }

    final reader = html.FileReader();

    reader.onLoadEnd.listen((event) {
      try {
        final result = reader.result;
        Uint8List? bytes;

        if (result is String) {
          final uri = UriData.parse(result);
          bytes = uri.contentAsBytes();
        } else if (result is Uint8List) {
          bytes = result;
        } else if (result is ByteBuffer) {
          bytes = result.asUint8List();
        } else if (result is List<int>) {
          bytes = Uint8List.fromList(result);
        }

        if (bytes != null && !completer.isCompleted) {
          completer.complete(WebImageResult(bytes, ext));
        } else if (!completer.isCompleted) {
          completer.complete(null);
        }
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });

    reader.readAsDataUrl(blobAlvo as html.Blob);
  });

  uploadInput.click();
  return completer.future;
}
