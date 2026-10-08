import 'package:eqp_maanaim/ui/identidade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapComTema(Widget child, {Size tamanho = const Size(800, 600)}) {
  return MaterialApp(
    theme: temaMaanaim(),
    home: MediaQuery(
      data: MediaQueryData(size: tamanho),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: tamanho.width,
            height: tamanho.height,
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Story 6.5: Acesso inclusivo e responsivo às superfícies do voluntariado', () {
    group('Critério 1: Estados Textual + Ícone (WCAG 1.4.1 - Não depender apenas de cor)', () {
      testWidgets('StatusChip renderiza texto E ícone semântico explícito para cada estado', (tester) async {
        await tester.pumpWidget(
          _wrapComTema(
            const Wrap(
              children: [
                StatusChip(status: 'ATIVA'),
                StatusChip(status: 'EM_APROVACAO'),
                StatusChip(status: 'AGUARDANDO'),
                StatusChip(status: 'EM_RENOVACAO'),
                StatusChip(status: 'REJEITADA'),
                StatusChip(status: 'CANCELADA'),
                StatusChip(status: 'EXPIRADA'),
                StatusChip(status: 'INATIVA'),
                StatusChip(status: 'RASCUNHO'),
                StatusChip(status: 'ORIENTACAO_PASTORAL'),
              ],
            ),
          ),
        );

        // Verifica os textos
        expect(find.text('ATIVA'), findsOneWidget);
        expect(find.text('EM APROVAÇÃO'), findsOneWidget);
        expect(find.text('AGUARDANDO'), findsOneWidget);
        expect(find.text('EM RENOVAÇÃO'), findsOneWidget);
        expect(find.text('REJEITADA'), findsOneWidget);
        expect(find.text('CANCELADA'), findsOneWidget);
        expect(find.text('EXPIRADA'), findsOneWidget);
        expect(find.text('INATIVA'), findsOneWidget);
        expect(find.text('RASCUNHO'), findsOneWidget);
        expect(find.text('CONSULTE O PASTOR'), findsOneWidget);

        // Verifica que ícones estão presentes para não depender apenas de cor
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.byIcon(Icons.hourglass_top_outlined), findsOneWidget);
        expect(find.byIcon(Icons.pending_outlined), findsOneWidget);
        expect(find.byIcon(Icons.sync_outlined), findsOneWidget);
        expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
        expect(find.byIcon(Icons.do_not_disturb_on_outlined), findsOneWidget);
        expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
        expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
        expect(find.byIcon(Icons.edit_note_outlined), findsOneWidget);
        expect(find.byIcon(Icons.help_outline), findsOneWidget);
      });

      testWidgets('StatusChip anuncia situação via Semantics para leitores de tela', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrapComTema(
            const StatusChip(status: 'ATIVA'),
          ),
        );

        expect(
          find.bySemanticsLabel('Situação: ATIVA'),
          findsOneWidget,
        );
        handle.dispose();
      });
    });

    group('Critério 2: Feedback e Orientação para Próxima Ação (WCAG 2.2 AA)', () {
      testWidgets('FeedbackOrientacaoCard exibe ícone, mensagem e orientação com alto contraste', (tester) async {
        await tester.pumpWidget(
          _wrapComTema(
            FeedbackOrientacaoCard(
              titulo: 'Participação Aprovada',
              mensagem: 'Sua solicitação na equipe de Recepção foi homologada.',
              orientacaoAcao: 'Compareça ao próximo treinamento operacional.',
              tipo: FeedbackTipo.sucesso,
              statusChipLabel: 'ATIVA',
              acao: PrimaryButton(
                label: 'Ver detalhes',
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('Participação Aprovada'), findsOneWidget);
        expect(find.text('Sua solicitação na equipe de Recepção foi homologada.'), findsOneWidget);
        expect(find.text('Compareça ao próximo treinamento operacional.'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
        expect(find.text('ATIVA'), findsOneWidget);
        expect(find.text('Ver detalhes'), findsOneWidget);
      });

      testWidgets('Decisão desfavorável/cancelamento orienta canonicamente "Procure o Pastor da igreja local para mais informações"', (tester) async {
        await tester.pumpWidget(
          _wrapComTema(
            FeedbackOrientacaoCard.decisaoDesfavoravel(
              titulo: 'Solicitação não concluída',
              mensagem: 'A participação na equipe de Mídia não foi homologada.',
            ),
          ),
        );

        expect(find.text('Solicitação não concluída'), findsOneWidget);
        expect(find.text('A participação na equipe de Mídia não foi homologada.'), findsOneWidget);
        expect(
          find.text('Procure o Pastor da igreja local para mais informações'),
          findsOneWidget,
        );
        expect(find.text('CONSULTE O PASTOR'), findsOneWidget);
        expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
      });

      testWidgets('Erro operacional orienta recuperação clara com alvo de toque ≥ 44px', (tester) async {
        await tester.pumpWidget(
          _wrapComTema(
            FeedbackOrientacaoCard.erro(
              titulo: 'Falha na conexão',
              mensagem: 'Não foi possível registrar sua manifestação.',
              acao: SecondaryButton(
                label: 'Tentar novamente',
                onPressed: () {},
              ),
            ),
          ),
        );

        expect(find.text('Falha na conexão'), findsOneWidget);
        expect(find.text('Verifique sua conexão ou tente novamente.'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

        final btnFinder = find.widgetWithText(SecondaryButton, 'Tentar novamente');
        expect(btnFinder, findsOneWidget);
        final size = tester.getSize(btnFinder);
        expect(size.height, greaterThanOrEqualTo(AppGeometry.minTouchTarget));
      });
    });

    group('Critério 3: Alvos de toque (Mínimo 44x44 px) e Acessibilidade de Controles', () {
      testWidgets('Botões institucionais garantem área mínima de toque ≥ 44 px', (tester) async {
        await tester.pumpWidget(
          _wrapComTema(
            Column(
              children: [
                PrimaryButton(label: 'Salvar', onPressed: () {}),
                SecondaryButton(label: 'Voltar', onPressed: () {}),
                ApproveButton(label: 'Aprovar', onPressed: () {}),
                DangerButton(label: 'Rejeitar', onPressed: () {}),
                IconActionButton(
                  icon: Icons.refresh,
                  tooltip: 'Atualizar',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );

        for (final label in ['Salvar', 'Voltar', 'Aprovar', 'Rejeitar']) {
          final finder = find.text(label);
          final size = tester.getSize(finder);
          // O botão pai deve ter altura >= 44
          final parentButton = find.ancestor(
            of: finder,
            matching: find.byType(ElevatedButton),
          );
          if (parentButton.evaluate().isNotEmpty) {
            expect(tester.getSize(parentButton).height, greaterThanOrEqualTo(AppGeometry.minTouchTarget));
          }
        }

        final iconBtnFinder = find.byType(IconActionButton);
        final iconSize = tester.getSize(iconBtnFinder);
        expect(iconSize.width, greaterThanOrEqualTo(AppGeometry.minTouchTarget));
        expect(iconSize.height, greaterThanOrEqualTo(AppGeometry.minTouchTarget));
      });
    });

    group('Critério 4: Adaptação de Tabelas para Cartões (AppDataTable & ResponsiveRecordList)', () {
      final itensExemplo = [
        {'nome': 'João Silva', 'equipe': 'Recepção', 'status': 'ATIVA'},
        {'nome': 'Maria Souza', 'equipe': 'Mídia', 'status': 'EM_APROVACAO'},
      ];

      final colunasExemplo = [
        AppDataColumn<Map<String, String>>(
          label: 'Voluntário',
          cellBuilder: (it) => Text(it['nome']!),
        ),
        AppDataColumn<Map<String, String>>(
          label: 'Equipe',
          cellBuilder: (it) => Text(it['equipe']!),
        ),
        AppDataColumn<Map<String, String>>(
          label: 'Situação',
          cellBuilder: (it) => StatusChip(status: it['status']!),
        ),
      ];

      testWidgets('No Desktop (1280px), AppDataTable renderiza como DataTable', (tester) async {
        await tester.pumpWidget(
          _wrapComTema(
            AppDataTable<Map<String, String>>(
              columns: colunasExemplo,
              items: itensExemplo,
              breakpoint: 768.0,
            ),
            tamanho: const Size(1280, 800),
          ),
        );

        expect(find.byType(DataTable), findsOneWidget);
        expect(find.text('João Silva'), findsOneWidget);
        expect(find.text('Maria Souza'), findsOneWidget);
        expect(find.text('Recepção'), findsOneWidget);
        expect(find.text('Mídia'), findsOneWidget);
      });

      testWidgets('No Mobile (390px), AppDataTable adapta automaticamente para ResponsiveRecordList em cartões', (tester) async {
        await tester.pumpWidget(
          _wrapComTema(
            SingleChildScrollView(
              child: AppDataTable<Map<String, String>>(
                columns: colunasExemplo,
                items: itensExemplo,
                breakpoint: 768.0,
              ),
            ),
            tamanho: const Size(390, 844),
          ),
        );

        // No mobile, NÃO deve renderizar DataTable
        expect(find.byType(DataTable), findsNothing);
        // Deve renderizar a lista de cartões responsiva
        expect(find.byType(ResponsiveRecordList<Map<String, String>>), findsOneWidget);
        expect(find.text('João Silva'), findsOneWidget);
        expect(find.text('Maria Souza'), findsOneWidget);
        // Nenhum erro de RenderFlex overflow
        expect(tester.takeException(), isNull);
      });

      testWidgets('FilterBar quebra layout fluidamente no mobile com controles acessíveis', (tester) async {
        final ctrl = TextEditingController();
        await tester.pumpWidget(
          _wrapComTema(
            FilterBar(
              searchController: ctrl,
              searchHint: 'Buscar voluntário...',
              filters: [
                ElevatedButton(onPressed: () {}, child: const Text('Filtro 1')),
              ],
              onClear: () {},
            ),
            tamanho: const Size(390, 844),
          ),
        );

        expect(find.text('Buscar voluntário...'), findsOneWidget);
        expect(find.text('Filtro 1'), findsOneWidget);
        expect(find.text('Limpar filtros'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Critério 5: Responsividade Completa nas 3 Faixas de Viewport', () {
      testWidgets('AppShell adapta navegação: Drawer no mobile (390x844), compacta no tablet (768x1024) e sidebar fixa no desktop (1280x800)', (tester) async {
        final items = [
          const AppNavItem(label: 'Início', icon: Icons.home),
          const AppNavItem(label: 'Fichas', icon: Icons.people),
        ];

        // 1. Mobile (390x844)
        await tester.pumpWidget(
          _wrapComTema(
            AppShell(
              items: items,
              body: const Text('Conteúdo Mobile'),
            ),
            tamanho: const Size(390, 844),
          ),
        );
        expect(find.byIcon(Icons.menu), findsOneWidget);
        expect(find.text('Conteúdo Mobile'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 2. Tablet (768x1024)
        await tester.pumpWidget(
          _wrapComTema(
            AppShell(
              items: items,
              body: const Text('Conteúdo Tablet'),
            ),
            tamanho: const Size(768, 1024),
          ),
        );
        // Sidebar compacta (72px)
        expect(find.byType(AppSidebar), findsOneWidget);
        expect(find.text('Conteúdo Tablet'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 3. Desktop (1280x800)
        await tester.pumpWidget(
          _wrapComTema(
            AppShell(
              items: items,
              body: const Text('Conteúdo Desktop'),
            ),
            tamanho: const Size(1280, 800),
          ),
        );
        expect(find.byType(AppSidebar), findsOneWidget);
        expect(find.text('Conteúdo Desktop'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Critério 6: Navegação por Teclado e Foco Visível (WCAG 2.4.7 e 2.4.13)', () {
      testWidgets('ThemeData institucional possui foco visível e inputs com borda de 2.0px', (tester) async {
        final tema = temaMaanaim();

        expect(tema.focusColor, const Color(0x330B6FE8));
        expect(tema.inputDecorationTheme.focusedBorder, isNotNull);

        final focusedBorder = tema.inputDecorationTheme.focusedBorder as OutlineInputBorder;
        expect(focusedBorder.borderSide.width, 2.0);
        expect(focusedBorder.borderSide.color, AppColors.blue600);

        final focusedErrorBorder = tema.inputDecorationTheme.focusedErrorBorder as OutlineInputBorder;
        expect(focusedErrorBorder.borderSide.width, 2.0);
        expect(focusedErrorBorder.borderSide.color, AppColors.danger);
      });
    });
  });
}
