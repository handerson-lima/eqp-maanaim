import 'dart:js_interop';

import 'termo_adesao_model.dart';
import 'termo_html_template.dart';

@JS('imprimirDocumentoHtml')
external void _imprimirDocumentoHtml(JSString html);

/// Implementação para Web: gera o HTML canônico e chama a impressão do navegador.
void imprimirTermoWeb(TermoAdesaoModel model) {
  try {
    final html = gerarHtmlTermoAdesao(model);
    _imprimirDocumentoHtml(html.toJS);
  } catch (_) {
    // Fallback gracioso se a função JS não estiver disponível
  }
}
