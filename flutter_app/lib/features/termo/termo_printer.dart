import 'termo_adesao_model.dart';
import 'termo_printer_stub.dart'
    if (dart.library.js_interop) 'termo_printer_web.dart';

/// Ponto de entrada unificado para impressão e geração de PDF do Termo de Adesão.
void imprimirTermo(TermoAdesaoModel model) {
  imprimirTermoWeb(model);
}
