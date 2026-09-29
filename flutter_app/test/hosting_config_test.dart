import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('firebase.json publica a build web do Flutter com rewrite SPA', () {
    // O diretório de trabalho dos testes é `flutter_app`.
    final arquivo = File('../firebase.json');
    expect(arquivo.existsSync(), isTrue,
        reason: 'firebase.json ausente na raiz do repositório');

    final config =
        jsonDecode(arquivo.readAsStringSync()) as Map<String, dynamic>;
    final hosting = config['hosting'] as Map<String, dynamic>?;
    expect(hosting, isNotNull, reason: 'bloco hosting ausente');

    expect(hosting!['public'], 'flutter_app/build/web');

    final rewrites =
        (hosting['rewrites'] as List? ?? const []).cast<Map<String, dynamic>>();
    expect(
        rewrites.any((r) =>
            r['source'] == '**' && r['destination'] == '/index.html'),
        isTrue,
        reason: 'rewrite catch-all ** -> /index.html ausente');
  });
}
