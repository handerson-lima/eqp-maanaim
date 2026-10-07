import 'termo_pdf_launcher_stub.dart'
    if (dart.library.js_interop) 'termo_pdf_launcher_web.dart';

/// Ponto de entrada unificado para abertura/download seguro do termo em PDF.
void baixarOuAbrirPdf(String url) {
  abrirUrlPdf(url);
}
