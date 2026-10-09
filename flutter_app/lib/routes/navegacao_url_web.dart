import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Implementação Flutter Web: lê a URL atual, sincroniza o histórico do
/// navegador e escuta `popstate` (voltar/avançar) para roteamento por URL.
String? rotaInicialDoNavegador() {
  final href = web.window.location.href;
  return href.isEmpty ? null : href;
}

void atualizarRotaNoNavegador(String rota) {
  final alvo = '#$rota';
  final atual = web.window.location.href;
  if (atual.endsWith(alvo)) return;
  web.window.history.pushState(null, '', alvo);
}

void registrarMudancaDeRotaNoNavegador(void Function() aoMudar) {
  web.window.addEventListener(
    'popstate',
    ((web.Event _) => aoMudar()).toJS,
  );
}
