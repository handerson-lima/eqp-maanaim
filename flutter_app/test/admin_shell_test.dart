import 'package:eqp_maanaim/features/admin/admin_shell.dart';
import 'package:eqp_maanaim/features/admin/consulta_catalogo.dart';
import 'package:eqp_maanaim/features/admin/seed_catalogo.dart';
import 'package:eqp_maanaim/features/admin/termos_screen.dart';
import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'package:eqp_maanaim/ui/identidade.dart';

const _igrejas = <IgrejaCatalogo>[
  IgrejaCatalogo(id: '1', nome: 'Goianinha', codigo: '240008', ativo: true),
];
const _equipes = <EquipeCatalogo>[
  EquipeCatalogo(id: 'e1', nome: 'Apoio', ativo: true),
];

Widget _shell({required VoidCallback onSair, double escala = 1}) => MaterialApp(
  theme: temaMaanaim(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(escala)),
    child: child!,
  ),
  home: AdminShell(
    onSair: onSair,
    catalogo: CatalogoFake(
      resposta: const CatalogoResposta(igrejas: _igrejas, equipes: _equipes),
    ),
    seed: SeedFake(),
    termos: TermosFake(),
  ),
);

void _definirTamanho(WidgetTester tester, Size tamanho) {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  for (final largura in [600.0, 1024.0]) {
    testWidgets('navegação responsiva em $largura com texto ampliado', (
      tester,
    ) async {
      _definirTamanho(tester, Size(largura, 900));
      await tester.pumpWidget(_shell(onSair: () {}, escala: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ConsultaCatalogo), findsOneWidget);
    });
  }

  group('AdminShell desktop (≥1024px)', () {
    testWidgets('exibe AppShell com sidebar, papel ativo e sign-out', (
      tester,
    ) async {
      _definirTamanho(tester, const Size(1200, 800));
      bool saiu = false;
      await tester.pumpWidget(_shell(onSair: () => saiu = true));
      await tester.pumpAndSettle();

      // AppSidebar presente
      expect(find.byType(AppSidebar), findsOneWidget);
      // Papel ativo e usuário visíveis
      expect(find.text('Administrador'), findsOneWidget);
      expect(find.text('Administração'), findsOneWidget);
      // Catálogo carregado por padrão
      expect(find.byType(ConsultaCatalogo), findsOneWidget);

      // Clicar em sair
      await tester.tap(find.byIcon(Icons.logout).first);
      await tester.pump();
      expect(saiu, isTrue);
    });

    testWidgets('navega para Seed ao clicar no destino', (tester) async {
      _definirTamanho(tester, const Size(1200, 800));
      await tester.pumpWidget(_shell(onSair: () {}));
      await tester.pumpAndSettle();

      // Clicar no destino Seed
      await tester.tap(find.text('Seed'));
      await tester.pumpAndSettle();
      expect(find.byType(SeedCatalogo), findsOneWidget);
    });

    testWidgets('navega para Termos ao clicar no destino', (tester) async {
      _definirTamanho(tester, const Size(1200, 800));
      await tester.pumpWidget(_shell(onSair: () {}));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Termos'));
      await tester.pumpAndSettle();
      expect(find.byType(TermosScreen), findsOneWidget);
    });
  });

  group('AdminShell mobile (<600px)', () {
    testWidgets('exibe TopBar com Drawer e papel ativo', (tester) async {
      _definirTamanho(tester, const Size(400, 700));
      bool saiu = false;
      await tester.pumpWidget(_shell(onSair: () => saiu = true));
      await tester.pumpAndSettle();

      // Papel ativo e usuário na TopBar
      expect(find.text('Administrador'), findsOneWidget);
      expect(find.text('Administração'), findsOneWidget);

      // Abrir o drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      // Drawer contém papel e itens
      expect(find.text('Maanaim'), findsOneWidget);
      expect(find.text('Catálogo'), findsOneWidget);
      expect(find.text('Seed'), findsOneWidget);
      expect(find.text('Termos'), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);

      // Sair via drawer
      await tester.tap(find.text('Sair'));
      await tester.pump();
      expect(saiu, isTrue);
    });

    testWidgets('navega para Termos via drawer mobile', (tester) async {
      _definirTamanho(tester, const Size(400, 700));
      await tester.pumpWidget(_shell(onSair: () {}));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Termos'));
      await tester.pumpAndSettle();
      expect(find.byType(TermosScreen), findsOneWidget);
    });
  });
}
