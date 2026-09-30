import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lê um inteiro big-endian de 4 bytes na posição [offset].
int _uint32BigEndian(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

/// Dimensões reais lidas do chunk IHDR (offsets 16 e 20 do PNG).
({int largura, int altura}) _dimensoesPng(List<int> bytes) => (
      largura: _uint32BigEndian(bytes, 16),
      altura: _uint32BigEndian(bytes, 20),
    );

void main() {
  late Map<String, dynamic> manifest;

  setUpAll(() {
    final arquivo = File('web/manifest.json');
    expect(arquivo.existsSync(), isTrue);
    manifest = jsonDecode(arquivo.readAsStringSync()) as Map<String, dynamic>;
  });

  test('manifest declara os campos obrigatórios de instalabilidade', () {
    expect(manifest['name'], isNotEmpty);
    expect(manifest['short_name'], isNotEmpty);
    expect(manifest['start_url'], isNotEmpty);
    expect(manifest['scope'], '/');
    expect(manifest['display'], 'standalone');
    expect(manifest['theme_color'], '#005BD8');
    expect(manifest['prefer_related_applications'], false);
  });

  test('manifest referencia ícones 192 e 512 existentes no disco', () {
    final icones = (manifest['icons'] as List).cast<Map<String, dynamic>>();
    final tamanhos = icones.map((i) => i['sizes']).toSet();
    expect(tamanhos, containsAll(<String>['192x192', '512x512']));
    expect(icones.any((i) => i['purpose'] == 'maskable'), isTrue);

    for (final icone in icones) {
      final caminho = File('web/${icone['src']}');
      expect(caminho.existsSync(), isTrue, reason: 'ícone ausente: ${icone['src']}');
      final bytes = caminho.readAsBytesSync();
      expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47],
          reason: 'não é PNG: ${icone['src']}');

      final declarado = RegExp(r'^(\d+)x(\d+)$')
          .firstMatch(icone['sizes'] as String);
      expect(declarado, isNotNull,
          reason: 'sizes inválido: ${icone['sizes']}');
      final largura = int.parse(declarado!.group(1)!);
      final altura = int.parse(declarado.group(2)!);

      final real = _dimensoesPng(bytes);
      expect(real.largura, largura,
          reason: 'largura real difere de ${icone['sizes']}: ${icone['src']}');
      expect(real.altura, altura,
          reason: 'altura real difere de ${icone['sizes']}: ${icone['src']}');
    }
  });
}
