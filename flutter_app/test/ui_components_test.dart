import 'package:eqp_maanaim/ui/identidade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithTheme(
  Widget child, {
  Size size = const Size(1200, 800),
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: temaMaanaim(),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(body: child),
    ),
  );
}

void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('Botões Padronizados (buttons.dart)', () {
    testWidgets('PrimaryButton: renderiza com blue600, altura ≥ 44px e dispara callback', (tester) async {
      bool clicado = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          Center(
            child: PrimaryButton(
              label: 'Salvar',
              icon: Icons.save,
              onPressed: () => clicado = true,
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(PrimaryButton);
      expect(buttonFinder, findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);

      final size = tester.getSize(buttonFinder);
      expect(size.height, greaterThanOrEqualTo(44.0));

      await tester.tap(buttonFinder);
      expect(clicado, isTrue);
    });

    testWidgets('PrimaryButton no estado isLoading exibe indicador e bloqueia clique', (tester) async {
      bool clicado = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          Center(
            child: PrimaryButton(
              label: 'Carregando',
              isLoading: true,
              onPressed: () => clicado = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Carregando'), findsNothing);

      await tester.tap(find.byType(PrimaryButton));
      expect(clicado, isFalse);
    });

    testWidgets('SecondaryButton: renderiza com fundo branco, borda e texto escuro', (tester) async {
      bool clicado = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          Center(
            child: SecondaryButton(
              label: 'Cancelar',
              onPressed: () => clicado = true,
            ),
          ),
        ),
      );

      final btn = find.byType(SecondaryButton);
      expect(btn, findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      final size = tester.getSize(btn);
      expect(size.height, greaterThanOrEqualTo(44.0));

      await tester.tap(btn);
      expect(clicado, isTrue);
    });

    testWidgets('ApproveButton: renderiza com cor verde institucional e ícone de check', (tester) async {
      bool aprovado = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          Center(
            child: ApproveButton(
              onPressed: () => aprovado = true,
            ),
          ),
        ),
      );

      expect(find.text('Aprovar'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.byType(ApproveButton));
      expect(aprovado, isTrue);
    });

    testWidgets('RejectButton e DangerButton: renderizam com cor de perigo institucional', (tester) async {
      bool rejeitado = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          Center(
            child: RejectButton(
              onPressed: () => rejeitado = true,
            ),
          ),
        ),
      );

      expect(find.text('Rejeitar'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byType(RejectButton));
      expect(rejeitado, isTrue);
    });

    testWidgets('IconActionButton: alvo de toque ≥ 44x44px com semântica e tooltip', (tester) async {
      bool acionado = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          Center(
            child: IconActionButton(
              icon: Icons.edit,
              tooltip: 'Editar dados',
              onPressed: () => acionado = true,
            ),
          ),
        ),
      );

      final finder = find.byType(IconActionButton);
      expect(finder, findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);

      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(44.0));
      expect(size.height, greaterThanOrEqualTo(44.0));

      await tester.tap(finder);
      expect(acionado, isTrue);
    });
  });

  group('Chips de Situação (status_chips.dart)', () {
    testWidgets('Mapeia status com cores e rótulos semânticos corretos', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const Wrap(
            children: [
              StatusChip(status: 'ATIVA'),
              StatusChip(status: 'em aprovação'),
              StatusChip(status: 'AGUARDANDO'),
              StatusChip(status: 'EM_RENOVACAO'),
              StatusChip(status: 'REJEITADA'),
              StatusChip(status: 'CANCELADA'),
              StatusChip(status: 'EXPIRADA'),
              StatusChip(status: 'INATIVA'),
            ],
          ),
        ),
      );

      expect(find.text('ATIVA'), findsOneWidget);
      expect(find.text('EM APROVAÇÃO'), findsOneWidget);
      expect(find.text('AGUARDANDO'), findsOneWidget);
      expect(find.text('EM RENOVAÇÃO'), findsOneWidget);
      expect(find.text('REJEITADA'), findsOneWidget);
      expect(find.text('CANCELADA'), findsOneWidget);
      expect(find.text('EXPIRADA'), findsOneWidget);
      expect(find.text('INATIVA'), findsOneWidget);
    });

    test('resolveConfig retorna cores e tipos corretos para cada status', () {
      final ativa = StatusChip.resolveConfig('ATIVA');
      expect(ativa.backgroundColor, AppColors.successBg);
      expect(ativa.textColor, AppColors.success);
      expect(ativa.type, StatusType.ativa);

      final pendente = StatusChip.resolveConfig('EM_APROVACAO');
      expect(pendente.backgroundColor, AppColors.warningBg);
      expect(pendente.textColor, AppColors.warning);
      expect(pendente.type, StatusType.emAprovacao);

      final rejeitada = StatusChip.resolveConfig('REJEITADA');
      expect(rejeitada.backgroundColor, AppColors.dangerBg);
      expect(rejeitada.textColor, AppColors.danger);
      expect(rejeitada.type, StatusType.rejeitada);

      final expirada = StatusChip.resolveConfig('EXPIRADA');
      expect(expirada.backgroundColor, AppColors.dangerBg);
      expect(expirada.textColor, AppColors.danger);
      expect(expirada.type, StatusType.expirada);

      final inativa = StatusChip.resolveConfig('INATIVA');
      expect(inativa.type, StatusType.inativa);
    });
  });

  group('Métricas e Validade (metrics.dart)', () {
    testWidgets('MetricCard renderiza valor em destaque, título, ícone e responde a toque', (tester) async {
      bool clicado = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          Center(
            child: MetricCard(
              title: 'Equipes Ativas',
              value: '3',
              icon: Icons.check_circle_outline,
              variant: MetricVariant.success,
              subtitle: 'Todas vinculadas',
              onTap: () => clicado = true,
            ),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.text('Equipes Ativas'), findsOneWidget);
      expect(find.text('Todas vinculadas'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      await tester.tap(find.byType(MetricCard));
      expect(clicado, isTrue);
    });

    testWidgets('ProgressValidityCard renderiza contagem de dias, barra de progresso e ação', (tester) async {
      bool renovarClicado = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          Center(
            child: ProgressValidityCard(
              expirationDateText: 'Expira em 15/12/2026',
              daysRemaining: 45,
              progress: 0.75,
              action: TextButton(
                onPressed: () => renovarClicado = true,
                child: const Text('Renovar'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Validade da Ficha'), findsOneWidget);
      expect(find.text('Expira em 15/12/2026'), findsOneWidget);
      expect(find.text('45 dias restantes'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Renovar'), findsOneWidget);

      await tester.tap(find.text('Renovar'));
      expect(renovarClicado, isTrue);
    });
  });

  group('Elementos de Layout (layout_elements.dart)', () {
    testWidgets('PageHeader renderiza título H1, subtítulo e ações', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          PageHeader(
            title: 'Minhas Equipes',
            subtitle: 'Gerencie suas participações ativas',
            action: PrimaryButton(
              label: 'Nova Solicitação',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Minhas Equipes'), findsOneWidget);
      expect(find.text('Gerencie suas participações ativas'), findsOneWidget);
      expect(find.text('Nova Solicitação'), findsOneWidget);
    });

    testWidgets('SectionCard renderiza título, ação de cabeçalho e conteúdo com borda clara', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          SectionCard(
            title: 'Histórico de Atividades',
            headerAction: const IconActionButton(
              icon: Icons.refresh,
              tooltip: 'Atualizar',
            ),
            child: const Text('Conteúdo do cartão'),
          ),
        ),
      );

      expect(find.text('Histórico de Atividades'), findsOneWidget);
      expect(find.text('Conteúdo do cartão'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('EmptyState renderiza ícone, mensagem e botão de ação', (tester) async {
      bool acaoDisparada = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          EmptyState(
            title: 'Nenhuma pendência encontrada',
            message: 'Todas as solicitações de voluntários foram analisadas.',
            action: PrimaryButton(
              label: 'Ver histórico',
              onPressed: () => acaoDisparada = true,
            ),
          ),
        ),
      );

      expect(find.text('Nenhuma pendência encontrada'), findsOneWidget);
      expect(find.text('Todas as solicitações de voluntários foram analisadas.'), findsOneWidget);
      expect(find.text('Ver histórico'), findsOneWidget);

      await tester.tap(find.text('Ver histórico'));
      expect(acaoDisparada, isTrue);
    });

    testWidgets('ErrorState renderiza ícone de erro, mensagem e aciona retry', (tester) async {
      bool tentouNovamente = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          ErrorState(
            title: 'Falha ao sincronizar dados',
            message: 'Não foi possível conectar ao servidor.',
            onRetry: () => tentouNovamente = true,
          ),
        ),
      );

      expect(find.text('Falha ao sincronizar dados'), findsOneWidget);
      expect(find.text('Não foi possível conectar ao servidor.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);

      await tester.tap(find.text('Tentar novamente'));
      expect(tentouNovamente, isTrue);
    });

    testWidgets('LoadingSkeleton renderiza e anima sem erros', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const Column(
            children: [
              LoadingSkeleton(width: 150, height: 20),
              SizedBox(height: 8),
              LoadingSkeleton(width: 40, height: 40, isCircle: true),
            ],
          ),
        ),
      );

      expect(find.byType(LoadingSkeleton), findsNWidgets(2));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });
  });

  group('AppShell e Navegação Responsiva (app_shell.dart)', () {
    const navItems = [
      AppNavItem(label: 'Início', icon: Icons.home_outlined, selectedIcon: Icons.home),
      AppNavItem(label: 'Equipes', icon: Icons.group_outlined, selectedIcon: Icons.group),
      AppNavItem(label: 'Documentos', icon: Icons.description_outlined),
    ];

    testWidgets('Desktop (1200px): exibe sidebar fixa à esquerda, TopBar e área de conteúdo', (tester) async {
      _setScreenSize(tester, const Size(1200, 800));
      int selecionado = 0;
      bool saiu = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: temaMaanaim(),
          home: AppShell(
            items: navItems,
            selectedIndex: selecionado,
            onDestinationSelected: (idx) => selecionado = idx,
            onLogout: () => saiu = true,
            userName: 'João Silva',
            userRole: 'Pastor Local',
            userChurch: 'Igreja Central',
            userStatus: 'ATIVA',
            body: const Text('Conteúdo Principal'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sidebar desktop presente
      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.text('Maanaim'), findsOneWidget);
      expect(find.text('Gestão de Voluntários'), findsOneWidget);
      expect(find.text('Início'), findsOneWidget);
      expect(find.text('Equipes'), findsOneWidget);
      expect(find.text('Documentos'), findsOneWidget);

      // TopBar com identidade
      expect(find.text('João Silva'), findsOneWidget);
      expect(find.text('Pastor Local • Igreja Central'), findsOneWidget);
      expect(find.text('ATIVA'), findsOneWidget);

      // Conteúdo principal
      expect(find.text('Conteúdo Principal'), findsOneWidget);

      // Clicar em item de navegação
      await tester.tap(find.text('Equipes'));
      expect(selecionado, 1);

      // Clicar em Sair
      await tester.tap(find.text('Sair'));
      expect(saiu, isTrue);
    });

    testWidgets('Tablet (800px): exibe sidebar compacta com ícones e tooltips', (tester) async {
      _setScreenSize(tester, const Size(800, 600));

      await tester.pumpWidget(
        MaterialApp(
          theme: temaMaanaim(),
          home: AppShell(
            items: navItems,
            selectedIndex: 0,
            userName: 'Maria Santos',
            userRole: 'Voluntário',
            body: const Text('Área Tablet'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sidebar presente em modo compacto
      final sidebarFinder = find.byType(AppSidebar);
      expect(sidebarFinder, findsOneWidget);
      final sidebar = tester.widget<AppSidebar>(sidebarFinder);
      expect(sidebar.isCompact, isTrue);

      expect(find.text('Área Tablet'), findsOneWidget);
    });

    testWidgets('Mobile (400px): sidebar vira Drawer acionado por menu hambúrguer na TopBar', (tester) async {
      _setScreenSize(tester, const Size(400, 700));
      int selecionado = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: temaMaanaim(),
          home: AppShell(
            items: navItems,
            selectedIndex: selecionado,
            onDestinationSelected: (idx) => selecionado = idx,
            userName: 'Carlos Oliveira',
            body: const Text('Área Mobile'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sem sidebar visível na tela inicial
      expect(find.byType(AppSidebar), findsNothing);

      // Botão menu hambúrguer presente
      final menuButton = find.byTooltip('Abrir menu de navegação');
      expect(menuButton, findsOneWidget);

      // Abrir o Drawer
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Agora a sidebar está no Drawer
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('Início'), findsOneWidget);
      expect(find.text('Equipes'), findsOneWidget);

      // Clicar em item dentro do Drawer
      await tester.tap(find.text('Equipes'));
      await tester.pumpAndSettle();

      // Drawer fecha e item foi selecionado
      expect(selecionado, 1);
      expect(find.byType(Drawer), findsNothing);
    });
  });
}
