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

  group('Story 7.2: Inativação e reativação com modal acessível', () {
    testWidgets('exibe modal de confirmação e inativa igreja com sucesso',
        (tester) async {
      final gateway = CatalogoFake(
          resposta: const CatalogoResposta(
              igrejas: _igrejas, equipes: _equipes));
      await _abrir(tester, gateway);
      await tester.pumpAndSettle();

      // Igreja 1 (Goianinha) está ATIVA. Deve ter botão "Inativar".
      final botaoInativar = find.widgetWithText(OutlinedButton, 'Inativar').first;
      expect(botaoInativar, findsOneWidget);

      await tester.tap(botaoInativar);
      await tester.pumpAndSettle();

      // Diálogo de confirmação aberto
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Inativar Igreja'), findsOneWidget);
      expect(find.textContaining('Ela deixará de ser exibida em novos cadastros'), findsOneWidget);

      // Confirmar inativação
      await tester.tap(find.widgetWithText(ElevatedButton, 'Inativar'));
      await tester.pumpAndSettle();

      expect(gateway.alternadasIgreja, 1);
      expect(gateway.ultimoAlvoId, '1');
      expect(gateway.ultimoAtivo, false);
      expect(find.textContaining('inativada com sucesso'), findsOneWidget);
    });

    testWidgets('cancelar no modal não altera o status', (tester) async {
      final gateway = CatalogoFake(
          resposta: const CatalogoResposta(
              igrejas: _igrejas, equipes: _equipes));
      await _abrir(tester, gateway);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Inativar').first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(gateway.alternadasIgreja, 0);
    });

    testWidgets('reativa igreja inativa pelo modal de confirmação',
        (tester) async {
      final gateway = CatalogoFake(
          resposta: const CatalogoResposta(
              igrejas: _igrejas, equipes: _equipes));
      await _abrir(tester, gateway);
      await tester.pumpAndSettle();

      // Mossoró está inativa, deve ter botão Reativar
      final botaoReativar = find.widgetWithText(OutlinedButton, 'Reativar');
      expect(botaoReativar, findsOneWidget);

      await tester.tap(botaoReativar);
      await tester.pumpAndSettle();

      expect(find.text('Reativar Igreja'), findsOneWidget);
      expect(find.textContaining('Ela voltará a ficar disponível para novos cadastros'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Reativar'));
      await tester.pumpAndSettle();

      expect(gateway.alternadasIgreja, 1);
      expect(gateway.ultimoAlvoId, '3');
      expect(gateway.ultimoAtivo, true);
      expect(find.textContaining('reativada com sucesso'), findsOneWidget);
    });

    testWidgets('inativa equipe pelo modal de confirmação', (tester) async {
      final gateway = CatalogoFake(
          resposta: const CatalogoResposta(
              igrejas: _igrejas, equipes: _equipes));
      await _abrir(tester, gateway);
      await tester.pumpAndSettle();

      // Equipe Apoio (e1) é a última lista
      final botaoInativarEquipe = find.widgetWithText(OutlinedButton, 'Inativar').last;
      await tester.tap(botaoInativarEquipe);
      await tester.pumpAndSettle();

      expect(find.text('Inativar Equipe'), findsOneWidget);
      expect(find.textContaining('Ela deixará de ser exibida em novas seleções'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Inativar'));
      await tester.pumpAndSettle();

      expect(gateway.alternadasEquipe, 1);
      expect(gateway.ultimoAlvoId, 'e1');
      expect(gateway.ultimoAtivo, false);
      expect(find.textContaining('Equipe "Apoio" inativada com sucesso'), findsOneWidget);
    });

    testWidgets('garante alvos de toque >= 44px e rotulagem semântica acessível',
        (tester) async {
      final gateway = CatalogoFake(
          resposta: const CatalogoResposta(
              igrejas: _igrejas, equipes: _equipes));
      await _abrir(tester, gateway);
      await tester.pumpAndSettle();

      final botoes = find.byType(OutlinedButton);
      for (final elemento in botoes.evaluate()) {
        final box = elemento.renderObject as RenderBox?;
        if (box != null && box.hasSize) {
          expect(box.size.height, greaterThanOrEqualTo(44.0));
          expect(box.size.width, greaterThanOrEqualTo(44.0));
        }
      }

      // Abre diálogo e valida botões do diálogo também
      await tester.tap(find.widgetWithText(OutlinedButton, 'Inativar').first);
      await tester.pumpAndSettle();

      final botaoCancelar = find.widgetWithText(OutlinedButton, 'Cancelar');
      final botaoConfirmar = find.widgetWithText(ElevatedButton, 'Inativar');

      final sizeCancelar = tester.getSize(botaoCancelar);
      final sizeConfirmar = tester.getSize(botaoConfirmar);

      expect(sizeCancelar.height, greaterThanOrEqualTo(44.0));
      expect(sizeCancelar.width, greaterThanOrEqualTo(44.0));
      expect(sizeConfirmar.height, greaterThanOrEqualTo(44.0));
      expect(sizeConfirmar.width, greaterThanOrEqualTo(44.0));
    });

    testWidgets('exibe mensagem de erro acessível se a alternância falhar',
        (tester) async {
      final gateway = CatalogoFake(
          resposta: const CatalogoResposta(
              igrejas: _igrejas, equipes: _equipes))
        ..alternarFalhar = true;
      await _abrir(tester, gateway);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Inativar').first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Inativar'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível alterar o status da igreja.'), findsOneWidget);
    });
  });
}
