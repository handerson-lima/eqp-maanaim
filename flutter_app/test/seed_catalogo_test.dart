import 'package:eqp_maanaim/features/admin/seed_catalogo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('exibe cabeçalho, descrição e botão de disparo', (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: SeedCatalogo(SeedFake()))));
    await tester.pumpAndSettle();
    expect(find.text('Seed do catálogo'), findsOneWidget);
    expect(find.textContaining('idempotente'), findsOneWidget);
    expect(find.text('Semear catálogo inicial'), findsOneWidget);
  });

  testWidgets('disparo bem-sucedido exibe recibo', (tester) async {
    final seed = SeedFake();
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: SeedCatalogo(seed))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Semear catálogo inicial'));
    await tester.pumpAndSettle();

    expect(seed.chamadas, 1);
    expect(seed.ultimoCommandId, isNotNull);
    expect(seed.ultimoCommandId!.length, 32); // 16 bytes hex
    expect(find.text('Seed concluído'), findsOneWidget);
    expect(find.textContaining('Igrejas criadas: 25'), findsOneWidget);
  });

  testWidgets('recibo de replay idempotente é comunicado por texto',
      (tester) async {
    final seed = SeedFake()
      ..repetido = true
      ..igrejasCriadas = 0
      ..equipesCriadas = 0;
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: SeedCatalogo(seed))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Semear catálogo inicial'));
    await tester.pumpAndSettle();

    expect(find.text('Seed já executado (idempotente)'), findsOneWidget);
    expect(find.textContaining('Recibo idempotente'), findsOneWidget);
  });

  testWidgets('falha exibe mensagem de erro e retentativa', (tester) async {
    final seed = SeedFake()..falhar = true;
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: SeedCatalogo(seed))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Semear catálogo inicial'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não foi possível executar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    // Retentativa com sucesso reusa o mesmo commandId (replay seguro).
    final commandIdDaFalha = seed.ultimoCommandId;
    seed.falhar = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Seed concluído'), findsOneWidget);
    expect(seed.chamadas, 2);
    expect(seed.ultimoCommandId, commandIdDaFalha);
  });

  testWidgets('segundo disparo gera commandId diferente (idempotência)',
      (tester) async {
    final seed = SeedFake();
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: SeedCatalogo(seed))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Semear catálogo inicial'));
    await tester.pumpAndSettle();
    final primeiro = seed.ultimoCommandId;

    await tester.tap(find.text('Semear catálogo inicial'));
    await tester.pumpAndSettle();
    final segundo = seed.ultimoCommandId;

    expect(primeiro, isNot(equals(segundo)));
    expect(seed.chamadas, 2);
  });
}
