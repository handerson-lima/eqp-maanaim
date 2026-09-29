import 'package:eqp_maanaim/features/admin/admin_shell.dart';
import 'package:eqp_maanaim/features/admin/consulta_catalogo.dart';
import 'package:eqp_maanaim/features/admin/seed_catalogo.dart';
import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _igrejas = <IgrejaCatalogo>[
  IgrejaCatalogo(id: '1', nome: 'Goianinha', codigo: '240008', ativo: true),
];
const _equipes = <EquipeCatalogo>[
  EquipeCatalogo(id: 'e1', nome: 'Apoio', ativo: true),
];

Widget _shell({required VoidCallback onSair}) => MaterialApp(
      home: AdminShell(
        onSair: onSair,
        catalogo: CatalogoFake(
            resposta:
                const CatalogoResposta(igrejas: _igrejas, equipes: _equipes)),
        seed: SeedFake(),
      ),
    );

void _definirTamanho(WidgetTester tester, Size tamanho) {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('AdminShell desktop (≥600px)', () {
    testWidgets('exibe NavigationRail com papel ativo e sign-out',
        (tester) async {
      _definirTamanho(tester, const Size(800, 600));
      bool saiu = false;
      await tester.pumpWidget(_shell(onSair: () => saiu = true));
      await tester.pumpAndSettle();

      // NavigationRail presente
      expect(find.byType(NavigationRail), findsOneWidget);
      // Papel ativo visível
      expect(find.text('Administrador'), findsOneWidget);
      // Catálogo carregado por padrão
      expect(find.byType(ConsultaCatalogo), findsOneWidget);

      // Clicar em sair
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pump();
      expect(saiu, isTrue);
    });

    testWidgets('navega para Seed ao clicar no destino', (tester) async {
      _definirTamanho(tester, const Size(800, 600));
      await tester.pumpWidget(_shell(onSair: () {}));
      await tester.pumpAndSettle();

      // Clicar no destino Seed
      await tester.tap(find.text('Seed'));
      await tester.pumpAndSettle();
      expect(find.byType(SeedCatalogo), findsOneWidget);
    });
  });

  group('AdminShell mobile (<600px)', () {
    testWidgets('exibe AppBar com Drawer e papel ativo', (tester) async {
      _definirTamanho(tester, const Size(400, 700));
      bool saiu = false;
      await tester.pumpWidget(_shell(onSair: () => saiu = true));
      await tester.pumpAndSettle();

      // Sem NavigationRail no mobile
      expect(find.byType(NavigationRail), findsNothing);
      // Papel ativo na AppBar
      expect(find.text('Administrador'), findsOneWidget);
      // AppBar com título
      expect(find.text('Administração'), findsOneWidget);

      // Abrir o drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      // Drawer contém papel e itens
      expect(find.text('Maanaim'), findsOneWidget);
      expect(find.text('Catálogo'), findsOneWidget);
      expect(find.text('Seed'), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);

      // Sair via drawer
      await tester.tap(find.text('Sair'));
      await tester.pump();
      expect(saiu, isTrue);
    });
  });
}
