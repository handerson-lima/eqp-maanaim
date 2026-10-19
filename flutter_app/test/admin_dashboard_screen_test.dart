import 'package:eqp_maanaim/features/admin/admin_dashboard_screen.dart';
import 'package:eqp_maanaim/ui/identidade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _dashboardApp({
  required void Function(String) onNavegar,
  bool temPastor = false,
  bool temResponsavelEquipe = false,
  bool temCoordenador = false,
}) =>
    MaterialApp(
      theme: temaMaanaim(),
      home: Scaffold(
        body: AdminDashboardScreen(
          onNavegar: onNavegar,
          temPastor: temPastor,
          temResponsavelEquipe: temResponsavelEquipe,
          temCoordenador: temCoordenador,
        ),
      ),
    );

void _definirTamanho(WidgetTester tester, Size tamanho) {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('AdminDashboardScreen - Renderização e Seções', () {
    testWidgets('exibe cabeçalho de boas-vindas e títulos das seções', (tester) async {
      _definirTamanho(tester, const Size(1200, 900));
      await tester.pumpWidget(_dashboardApp(onNavegar: (_) {}));
      await tester.pumpAndSettle();

      expect(find.text('Painel Administrativo'), findsOneWidget);
      expect(
        find.text(
          'Bem-vindo ao Maanaim. Selecione uma área para gerenciar ou acompanhar as operações.',
        ),
        findsOneWidget,
      );

      expect(find.text('Cadastros'), findsOneWidget);
      expect(find.text('Operação'), findsOneWidget);
      expect(find.text('Governança & Sistema'), findsOneWidget);
    });

    testWidgets('exibe todos os cards básicos de cadastros e governança', (tester) async {
      _definirTamanho(tester, const Size(1200, 900));
      await tester.pumpWidget(_dashboardApp(onNavegar: (_) {}));
      await tester.pumpAndSettle();

      // Cadastros
      expect(find.text('Igrejas'), findsOneWidget);
      expect(find.text('Equipes'), findsOneWidget);
      expect(find.text('Pessoas e Papéis'), findsOneWidget);
      expect(find.text('Vínculos e Responsáveis'), findsOneWidget);
      expect(find.text('Termos'), findsOneWidget);

      // Governança
      expect(find.text('Carga inicial do catálogo'), findsOneWidget);
      expect(find.text('Auditoria & Relatórios'), findsOneWidget);
      expect(find.text('Retenção e Privacidade'), findsOneWidget);
    });

    testWidgets('exibe cards condicionais de operação apenas quando habilitados', (tester) async {
      _definirTamanho(tester, const Size(1200, 900));
      // Sem filas de pastor, equipe ou coordenador
      await tester.pumpWidget(_dashboardApp(onNavegar: (_) {}));
      await tester.pumpAndSettle();

      expect(find.text('Solicitações por Equipe'), findsOneWidget);
      expect(find.text('Renovações'), findsOneWidget);
      expect(find.text('Fila do Pastor'), findsNothing);
      expect(find.text('Fila da Equipe'), findsNothing);
      expect(find.text('Fila do Coordenador'), findsNothing);

      // Com todas as filas ativas
      await tester.pumpWidget(
        _dashboardApp(
          onNavegar: (_) {},
          temPastor: true,
          temResponsavelEquipe: true,
          temCoordenador: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fila do Pastor'), findsOneWidget);
      expect(find.text('Fila da Equipe'), findsOneWidget);
      expect(find.text('Fila do Coordenador'), findsOneWidget);
    });
  });

  group('AdminDashboardScreen - Interação e Acessibilidade', () {
    testWidgets('chama onNavegar com o label correto ao clicar no card', (tester) async {
      _definirTamanho(tester, const Size(1200, 900));
      String? rotaNavegada;
      await tester.pumpWidget(_dashboardApp(onNavegar: (label) => rotaNavegada = label));
      await tester.pumpAndSettle();

      // Clicar em Igrejas
      await tester.tap(find.text('Igrejas'));
      await tester.pumpAndSettle();
      expect(rotaNavegada, equals('Igrejas'));

      // Clicar em Vínculos e Responsáveis
      await tester.tap(find.text('Vínculos e Responsáveis'));
      await tester.pumpAndSettle();
      expect(rotaNavegada, equals('Vínculos e Responsáveis'));

      // Clicar em Auditoria & Relatórios
      await tester.tap(find.text('Auditoria & Relatórios'));
      await tester.pumpAndSettle();
      expect(rotaNavegada, equals('Auditoria & Relatórios'));
    });

    testWidgets('cards possuem semântica de botão e área de toque acessível (>= 44px)', (tester) async {
      _definirTamanho(tester, const Size(1200, 900));
      await tester.pumpWidget(_dashboardApp(onNavegar: (_) {}));
      await tester.pumpAndSettle();

      final igrejasSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            (widget.properties.label?.contains('Igrejas') ?? false),
      );
      expect(igrejasSemantics, findsOneWidget);

      final box = tester.renderObject<RenderBox>(igrejasSemantics);
      expect(box.size.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('renderiza sem overflow em mobile (360px), tablet (768px) e desktop (1280px)', (tester) async {
      for (final tamanho in const [Size(360, 640), Size(768, 1024), Size(1280, 800)]) {
        _definirTamanho(tester, tamanho);
        await tester.pumpWidget(_dashboardApp(onNavegar: (_) {}));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
