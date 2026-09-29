import 'dart:async';

import 'package:eqp_maanaim/features/admin/admin_shell.dart';
import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/admin/consulta_catalogo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _igrejas = <IgrejaCatalogo>[
  IgrejaCatalogo(id: '1', nome: 'Goianinha', codigo: '240008', ativo: true),
  IgrejaCatalogo(id: '2', nome: 'Igapó', codigo: '240001', ativo: true),
  IgrejaCatalogo(id: '3', nome: 'Mossoró', codigo: '240006', ativo: false),
];

const _equipes = <EquipeCatalogo>[
  EquipeCatalogo(id: 'e1', nome: 'Apoio', ativo: true),
];

Future<void> _abrir(WidgetTester tester, CatalogoFake gateway) async {
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ConsultaCatalogo(gateway))));
}

void main() {
  testWidgets('anuncia carregamento de forma acessível', (tester) async {
    final gateway = CatalogoFake()..pendente = Completer<void>();
    await _abrir(tester, gateway);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Semantics && widget.properties.label == 'Carregando catálogo'),
        findsOneWidget);
    gateway.pendente!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Nenhum resultado encontrado.'), findsOneWidget);
  });

  testWidgets('lista igrejas como "Nome - Código" e equipes', (tester) async {
    await _abrir(
        tester,
        CatalogoFake(
            resposta: const CatalogoResposta(
                igrejas: _igrejas, equipes: _equipes)));
    await tester.pumpAndSettle();
    expect(find.text('Goianinha - 240008'), findsOneWidget);
    expect(find.text('Igapó - 240001'), findsOneWidget);
    expect(find.text('Mossoró - 240006'), findsOneWidget);
    expect(find.text('Apoio'), findsOneWidget);
  });

  testWidgets('comunica estado inativo por texto além do ícone', (tester) async {
    await _abrir(
        tester,
        CatalogoFake(
            resposta: const CatalogoResposta(
                igrejas: _igrejas, equipes: _equipes)));
    await tester.pumpAndSettle();
    expect(find.text('Inativa'), findsOneWidget);
  });

  testWidgets('pesquisa por nome sem acento e por código parcial',
      (tester) async {
    await _abrir(
        tester,
        CatalogoFake(
            resposta: const CatalogoResposta(
                igrejas: _igrejas, equipes: _equipes)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'igapo');
    await tester.pump();
    expect(find.text('Igapó - 240001'), findsOneWidget);
    expect(find.text('Goianinha - 240008'), findsNothing);

    await tester.enterText(find.byType(TextField), '24000');
    await tester.pump();
    expect(find.text('Goianinha - 240008'), findsOneWidget);
    expect(find.text('Igapó - 240001'), findsOneWidget);
    expect(find.text('Apoio'), findsNothing);
  });

  testWidgets('resultado vazio é anunciado acessivelmente', (tester) async {
    await _abrir(
        tester,
        CatalogoFake(
            resposta: const CatalogoResposta(
                igrejas: _igrejas, equipes: _equipes)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pump();
    expect(find.text('Nenhum resultado encontrado.'), findsOneWidget);
  });

  testWidgets('erro mostra mensagem e retentativa recarrega', (tester) async {
    final gateway = CatalogoFake()..falhar = true;
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar o catálogo.'), findsOneWidget);

    gateway.falhar = false;
    gateway.resposta = const CatalogoResposta(igrejas: _igrejas, equipes: _equipes);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Igapó - 240001'), findsOneWidget);
    expect(gateway.chamadas, 2);
  });

  testWidgets('AdminShell conecta a consulta de catálogo', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: AdminShell(
            onSair: () {},
            catalogo: CatalogoFake(
                resposta: const CatalogoResposta(
                    igrejas: _igrejas, equipes: _equipes)),
            seed: SeedFake())));
    await tester.pumpAndSettle();
    expect(find.byType(ConsultaCatalogo), findsOneWidget);
    expect(find.text('Igapó - 240001'), findsOneWidget);
  });
}
