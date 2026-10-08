// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class WebImageResult {
  const WebImageResult(this.bytes, this.extensao);
  final Uint8List bytes;
  final String extensao;
}

/// Implementação nativa Web via HTML FileUploadInputElement.
/// Não depende de canais de método nem sofre com MissingPluginException.
Future<WebImageResult?> pickImageWeb() async {
  final completer = Completer<WebImageResult?>();
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = 'image/png,image/jpeg,image/webp,image/jpg';

  uploadInput.onChange.listen((event) {
    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files[0];
    final reader = html.FileReader();

    reader.onLoadEnd.listen((event) {
      try {
        final result = reader.result;
        Uint8List bytes;
        if (result is Uint8List) {
          bytes = result;
        } else if (result is ByteBuffer) {
          bytes = result.asUint8List();
        } else if (result is List<int>) {
          bytes = Uint8List.fromList(result);
        } else {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final nome = file.name;
        final ext =
            nome.contains('.') ? nome.split('.').last.toLowerCase() : 'jpg';

        if (!completer.isCompleted) {
          completer.complete(WebImageResult(bytes, ext));
        }
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });

    reader.readAsArrayBuffer(file);
  });

  uploadInput.click();
  return completer.future;
}
