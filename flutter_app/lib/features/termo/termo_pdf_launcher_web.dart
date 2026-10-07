import 'dart:js_interop';

@JS('abrirDocumentoUrl')
external void _abrirDocumentoUrl(JSString url);

/// Implementação Web: abre a URL assinada em nova aba/janela segura.
void abrirUrlPdf(String url) {
  try {
    _abrirDocumentoUrl(url.toJS);
  } catch (_) {
    // Fallback gracioso se a função JS não estiver disponível
  }
}
