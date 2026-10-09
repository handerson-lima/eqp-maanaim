import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/pastor/fila_pastor_screen.dart';
import 'package:eqp_maanaim/features/pastor/pastor_service.dart';
import 'package:eqp_maanaim/ui/theme.dart';

void main() {
  final itemExemplo1 = ItemFilaPastor(
    id: 'pendencia-01',
    fichaId: 'ficha-01',
    voluntarioUid: 'vol-01',
    voluntarioNome: 'Carlos Eduardo Silva',
    igrejaId: 'igreja-01',
    nomeIgreja: 'Igreja Central',
    estado: 'AGUARDANDO_PASTOR_LOCAL',
    proximaAcao: 'Aguardando avaliação do Pastor Local',
    ano: 2026,
    equipes: const [
      EquipeFilaPastor(equipeId: 'eq-01', nomeEquipe: 'Louvor e Adoração'),
      EquipeFilaPastor(equipeId: 'eq-02', nomeEquipe: 'Acolhimento'),
    ],
    enviadoEm: '2026-10-06T12:00:00Z',
    versao: 1,
  );

  final itemExemplo2 = ItemFilaPastor(
    id: 'pendencia-02',
    fichaId: 'ficha-02',
    voluntarioUid: 'vol-02',
    voluntarioNome: 'Mariana Lima',
    igrejaId: 'igreja-02',
    nomeIgreja: 'Igreja Norte',
    estado: 'AGUARDANDO_PASTOR_LOCAL',
    proximaAcao: 'Aguardando avaliação do Pastor Local',
    ano: 2026,
    equipes: const [
      EquipeFilaPastor(equipeId: 'eq-03', nomeEquipe: 'Intercessão'),
    ],
    enviadoEm: '2026-10-06T13:00:00Z',
    versao: 1,
  );

  final igreja1 = const IgrejaEscopoPastor(id: 'igreja-01', nome: 'Igreja Central');
  final igreja2 = const IgrejaEscopoPastor(id: 'igreja-02', nome: 'Igreja Norte');

  Widget criarApp(PastorLocalGateway gateway) {
    return MaterialApp(
      theme: temaMaanaim(),
      home: FilaPastorScreen(gateway: gateway),
    );
  }

  testWidgets('exibe cards de pendências com dados do voluntário e equipes', (tester) async {
    final gateway = MemoriaPastorLocalGateway(
      pendenciasIniciais: [itemExemplo1],
      igrejasIniciais: [igreja1],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Fila do Pastor Local'), findsOneWidget);
    expect(find.text('Carlos Eduardo Silva'), findsOneWidget);
    expect(find.text('Igreja Central'), findsOneWidget);
    expect(find.text('Louvor e Adoração'), findsOneWidget);
    expect(find.text('Acolhimento'), findsOneWidget);
    expect(find.text('AGUARDANDO AVALIAÇÃO'), findsOneWidget);
    expect(find.byKey(const Key('btnAprovar_ficha-01')), findsOneWidget);
    expect(find.byKey(const Key('btnRecusar_ficha-01')), findsOneWidget);
  });

  testWidgets('exibe estado vazio quando não há pendências na fila', (tester) async {
    final gateway = MemoriaPastorLocalGateway(
      pendenciasIniciais: [],
      igrejasIniciais: [igreja1],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma solicitação pendente'), findsOneWidget);
    expect(
      find.text('Todas as fichas de voluntários nas suas igrejas foram avaliadas.'),
      findsOneWidget,
    );
  });

  testWidgets('filtra pendências por igreja quando há mais de uma igreja no escopo', (tester) async {
    final gateway = MemoriaPastorLocalGateway(
      pendenciasIniciais: [itemExemplo1, itemExemplo2],
      igrejasIniciais: [igreja1, igreja2],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    // Inicialmente mostra ambos
    expect(find.text('Carlos Eduardo Silva'), findsOneWidget);
    expect(find.text('Mariana Lima'), findsOneWidget);

    // Abre o dropdown de filtro
    final dropdown = find.byKey(const Key('dropdownFiltroIgreja'));
    expect(dropdown, findsOneWidget);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    // Seleciona "Igreja Central"
    await tester.tap(find.text('Igreja Central').last);
    await tester.pumpAndSettle();

    // Apenas Carlos Eduardo deve estar visível
    expect(find.text('Carlos Eduardo Silva'), findsOneWidget);
    expect(find.text('Mariana Lima'), findsNothing);
  });

  testWidgets('fluxo de aprovação: abre modal, confirma e remove item da lista', (tester) async {
    final gateway = MemoriaPastorLocalGateway(
      pendenciasIniciais: [itemExemplo1],
      igrejasIniciais: [igreja1],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    // Clica em Aprovar
    await tester.tap(find.byKey(const Key('btnAprovar_ficha-01')));
    await tester.pumpAndSettle();

    // Verifica conteúdo do modal
    expect(find.text('Confirmar Aprovação da Ficha'), findsOneWidget);
    expect(
      find.text('Deseja aprovar a solicitação de voluntariado de Carlos Eduardo Silva?'),
      findsOneWidget,
    );

    // Confirma
    await tester.tap(find.byKey(const Key('btnConfirmarAprovacaoModal')));
    await tester.pumpAndSettle();

    // Item foi removido e mostra mensagem de sucesso
    expect(find.text('Carlos Eduardo Silva'), findsNothing);
    expect(find.text('Ficha de Carlos Eduardo Silva aprovada com sucesso!'), findsOneWidget);
    expect(find.text('Nenhuma solicitação pendente'), findsOneWidget);
  });

  testWidgets('fluxo de recusa: exige justificativa, confirma e remove item da lista', (tester) async {
    final gateway = MemoriaPastorLocalGateway(
      pendenciasIniciais: [itemExemplo1],
      igrejasIniciais: [igreja1],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    // Clica em Recusar
    await tester.tap(find.byKey(const Key('btnRecusar_ficha-01')));
    await tester.pumpAndSettle();

    // Verifica conteúdo do modal e aviso sobre mensagem neutra ao voluntário
    expect(find.text('Decisão Pastoral Desfavorável'), findsOneWidget);
    expect(
      find.textContaining('Procure o Pastor da igreja local para mais informações'),
      findsOneWidget,
    );

    // Tenta confirmar sem justificativa
    await tester.tap(find.byKey(const Key('btnConfirmarRecusaModal')));
    await tester.pumpAndSettle();
    expect(find.text('Informe uma justificativa de ao menos 5 caracteres.'), findsOneWidget);

    // Preenche justificativa válida
    await tester.enterText(
      find.byKey(const Key('campoJustificativaRecusa')),
      'Necessário período de amadurecimento e acompanhamento local.',
    );
    await tester.pumpAndSettle();

    // Confirma recusa
    await tester.tap(find.byKey(const Key('btnConfirmarRecusaModal')));
    await tester.pumpAndSettle();

    // Item removido da fila com mensagem de sucesso
    expect(find.text('Carlos Eduardo Silva'), findsNothing);
    expect(find.text('Decisão desfavorável registrada com sucesso.'), findsOneWidget);
  });

  testWidgets('renderiza sem overflow em mobile (390x844) e desktop (1024x768)', (tester) async {
    final gateway = MemoriaPastorLocalGateway(
      pendenciasIniciais: [itemExemplo1, itemExemplo2],
      igrejasIniciais: [igreja1, igreja2],
    );

    // Mobile
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Desktop
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Story 8.6: Pastor Desktop (1280x800) renderiza 4 KPIs e DataTable com colunas completas', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final gateway = MemoriaPastorLocalGateway(
      pendenciasIniciais: [itemExemplo1],
      igrejasIniciais: [igreja1],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Pendências'), findsOneWidget);
    expect(find.text('Renovações'), findsOneWidget);
    expect(find.text('Ativos'), findsOneWidget);
    expect(find.text('Próximos do vencimento'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Voluntário'), findsOneWidget);
    expect(find.descendant(of: find.byType(DataTable), matching: find.text('Igreja')), findsOneWidget);
    expect(find.text('Equipe(s)'), findsOneWidget);
    expect(find.text('Data de Envio'), findsOneWidget);
    expect(find.byKey(const Key('btnAprovar_ficha-01')), findsOneWidget);
  });

  testWidgets('Story 8.6: Agregação "Todas as igrejas" agrega estritamente igrejas com vínculos vigentes do pastor', (tester) async {
    final gateway = MemoriaPastorLocalGateway(
      pendenciasIniciais: [
        itemExemplo1,
        itemExemplo2,
        ItemFilaPastor(
          id: 'pendencia-fora-03',
          fichaId: 'ficha-fora-03',
          voluntarioUid: 'vol-fora-03',
          voluntarioNome: 'Invasor Fora de Escopo',
          igrejaId: 'igreja-estranha',
          nomeIgreja: 'Igreja Não Pertencente',
          estado: 'AGUARDANDO_PASTOR_LOCAL',
          proximaAcao: 'Aguardando',
          ano: 2026,
          equipes: const [],
          enviadoEm: '2026-10-06T12:00:00Z',
          versao: 1,
        ),
      ],
      igrejasIniciais: [igreja1, igreja2],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Carlos Eduardo Silva'), findsOneWidget);
    expect(find.text('Mariana Lima'), findsOneWidget);
    expect(find.text('Invasor Fora de Escopo'), findsNothing);
  });

  testWidgets('Story 8.6: Clique no KPI Renovações filtra a lista e toggle restaura', (tester) async {
    final itemRenovacao = ItemFilaPastor(
      id: 'pendencia-renov-01',
      fichaId: 'ficha-renov-01',
      voluntarioUid: 'vol-renov-01',
      voluntarioNome: 'Renato Santos',
      igrejaId: 'igreja-01',
      nomeIgreja: 'Igreja Central',
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      proximaAcao: 'Aguardando',
      ano: 2026,
      equipes: const [EquipeFilaPastor(equipeId: 'eq-01', nomeEquipe: 'Acolhimento')],
      enviadoEm: '2026-10-06T12:00:00Z',
      versao: 1,
      isRenovacaoAnual: true,
    );

    final gateway = MemoriaPastorLocalGateway(
      pendenciasIniciais: [itemExemplo1, itemRenovacao],
      igrejasIniciais: [igreja1],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Carlos Eduardo Silva'), findsOneWidget);
    expect(find.text('Renato Santos'), findsOneWidget);

    await tester.tap(find.text('Renovações'));
    await tester.pumpAndSettle();

    expect(find.text('Exibindo apenas solicitações de Renovação Anual'), findsOneWidget);
    expect(find.text('Carlos Eduardo Silva'), findsNothing);
    expect(find.text('Renato Santos'), findsOneWidget);

    await tester.tap(find.text('Limpar filtro'));
    await tester.pumpAndSettle();

    expect(find.text('Carlos Eduardo Silva'), findsOneWidget);
    expect(find.text('Renato Santos'), findsOneWidget);
  });

  testWidgets('Story 8.6: Erro do gateway exibe mensagem amigável sem exibir 0 espúrio nos KPIs', (tester) async {
    final gateway = MemoriaPastorLocalGateway(
      erroAoObterFila: Exception('Falha de rede'),
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar a fila pastoral. Tente novamente.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Pendências'), findsNothing);
    expect(find.byType(DataTable), findsNothing);
  });
}
