/// Fachada de navegação por URL com implementação condicional:
/// `navegacao_url_web.dart` em Flutter Web e `navegacao_url_stub.dart` nas
/// demais plataformas/testes.
library;

export 'navegacao_url_stub.dart'
    if (dart.library.js_interop) 'navegacao_url_web.dart';
