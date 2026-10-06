import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/responsavel_equipe/fila_responsavel_equipe_screen.dart';
import 'package:eqp_maanaim/features/responsavel_equipe/responsavel_equipe_service.dart';
import 'package:eqp_maanaim/ui/theme.dart';

void main() {
  final itemExemplo1 = ItemFilaResponsavelEquipe(
    participacaoId: 'part-01',
    fichaId: 'ficha-01',
    voluntarioUid: 'vol-01',
    voluntarioNome: 'Gabriel Santos',
    igrejaId: 'igreja-01',
    nomeIgreja: 'Igreja Central',
    equipeId: 'eq-cozinha',
    nomeEquipe: 'Cozinha',
    estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
    proximaAcao: 'Aguardando avaliação do Responsável de Equipe',
    versao: 1,
    enviadoEm: '2026-10-06T14:00:00Z',
  );

  final itemExemplo2 = ItemFilaResponsavelEquipe(
    participacaoId: 'part-02',
    fichaId: 'ficha-02',
    voluntarioUid: 'vol-02',
    voluntarioNome: 'Larissa Souza',
    igrejaId: 'igreja-02',
    nomeIgreja: 'Igreja Norte',
    equipeId: 'eq-louvor',
    nomeEquipe: 'Louvor',
    estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
    proximaAcao: 'Aguardando avaliação do Responsável de Equipe',
    versao: 1,
    enviadoEm: '2026-10-06T15:00:00Z',
  );

  final equipe1 = const EquipeEscopoResponsavel(id: 'eq-cozinha', nome: 'Cozinha');
  final equipe2 = const EquipeEscopoResponsavel(id: 'eq-louvor', nome: 'Louvor');

  Widget criarApp(ResponsavelEquipeGateway gateway) {
    return MaterialApp(
      theme: temaMaanaim(),
      home: FilaResponsavelEquipeScreen(gateway: gateway),
    );
  }

  testWidgets('exibe cards de pendências com dados do voluntário e equipe', (tester) async {
    final gateway = MemoriaResponsavelEquipeGateway(
      pendenciasIniciais: [itemExemplo1],
      equipesIniciais: [equipe1],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Fila do Responsável de Equipe'), findsOneWidget);
    expect(find.text('Gabriel Santos'), findsOneWidget);
    expect(find.text('Igreja: Igreja Central'), findsOneWidget);
    expect(find.text('Cozinha'), findsWidgets);
    expect(find.text('Pendente'), findsOneWidget);
    expect(find.byKey(const Key('btnAprovar_part-01')), findsOneWidget);
    expect(find.byKey(const Key('btnRecusar_part-01')), findsOneWidget);
  });

  testWidgets('exibe estado vazio quando não há pendências na fila', (tester) async {
    final gateway = MemoriaResponsavelEquipeGateway(
      pendenciasIniciais: [],
      equipesIniciais: [equipe1],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma pendência na fila!'), findsOneWidget);
    expect(
      find.text('Todas as participações sob sua responsabilidade foram avaliadas.'),
      findsOneWidget,
    );
  });

  testWidgets('exibe mensagem quando usuário não possui equipes sob sua responsabilidade', (tester) async {
    final gateway = MemoriaResponsavelEquipeGateway(
      pendenciasIniciais: [],
      equipesIniciais: [],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma equipe sob sua responsabilidade vigente.'), findsOneWidget);
  });

  testWidgets('filtra pendências por equipe quando há mais de uma equipe no escopo', (tester) async {
    final gateway = MemoriaResponsavelEquipeGateway(
      pendenciasIniciais: [itemExemplo1, itemExemplo2],
      equipesIniciais: [equipe1, equipe2],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    // Inicialmente mostra ambos
    expect(find.text('Gabriel Santos'), findsOneWidget);
    expect(find.text('Larissa Souza'), findsOneWidget);

    // Abre dropdown de equipes
    final dropdown = find.byKey(const Key('dropdownFiltroEquipe'));
    expect(dropdown, findsOneWidget);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    // Seleciona "Cozinha"
    await tester.tap(find.text('Cozinha').last);
    await tester.pumpAndSettle();

    // Apenas Gabriel Santos da Cozinha deve estar visível
    expect(find.text('Gabriel Santos'), findsOneWidget);
    expect(find.text('Larissa Souza'), findsNothing);
  });

  testWidgets('fluxo de aprovação: abre modal, confirma e remove item da fila', (tester) async {
    final gateway = MemoriaResponsavelEquipeGateway(
      pendenciasIniciais: [itemExemplo1],
      equipesIniciais: [equipe1],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    // Clica em Aprovar
    await tester.tap(find.byKey(const Key('btnAprovar_part-01')));
    await tester.pumpAndSettle();

    // Verifica modal
    expect(find.text('Confirmar Aprovação da Participação'), findsOneWidget);
    expect(
      find.text('Deseja aprovar a participação de Gabriel Santos na equipe Cozinha?'),
      findsOneWidget,
    );

    // Confirma aprovação
    await tester.tap(find.byKey(const Key('btnConfirmarAprovacaoModal')));
    await tester.pumpAndSettle();

    // Verifica que o item foi removido
    expect(find.text('Gabriel Santos'), findsNothing);
    expect(
      find.text('Participação na equipe Cozinha aprovada com sucesso!'),
      findsOneWidget,
    );
    expect(gateway.chamadasDecisao, hasLength(1));
    expect(gateway.chamadasDecisao[0].decisao, 'APROVADO');
    expect(gateway.chamadasDecisao[0].participacaoId, 'part-01');
  });

  testWidgets('fluxo de recusa: exige justificativa, confirma e remove item da fila', (tester) async {
    final gateway = MemoriaResponsavelEquipeGateway(
      pendenciasIniciais: [itemExemplo1],
      equipesIniciais: [equipe1],
    );

    await tester.pumpWidget(criarApp(gateway));
    await tester.pumpAndSettle();

    // Clica em Recusar
    await tester.tap(find.byKey(const Key('btnRecusar_part-01')));
    await tester.pumpAndSettle();

    // Verifica modal e aviso sobre mensagem neutra ao voluntário
    expect(find.text('Decisão Negativa de Equipe'), findsOneWidget);
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
      'Não há disponibilidade na escala de preparação de alimentos.',
    );
    await tester.pumpAndSettle();

    // Confirma recusa
    await tester.tap(find.byKey(const Key('btnConfirmarRecusaModal')));
    await tester.pumpAndSettle();

    // Verifica remoção e mensagem
    expect(find.text('Gabriel Santos'), findsNothing);
    expect(
      find.text('Participação recusada. Mensagem padrão enviada ao voluntário.'),
      findsOneWidget,
    );
    expect(gateway.chamadasDecisao, hasLength(1));
    expect(gateway.chamadasDecisao[0].decisao, 'DESFAVORAVEL');
    expect(
      gateway.chamadasDecisao[0].justificativa,
      'Não há disponibilidade na escala de preparação de alimentos.',
    );
  });

  testWidgets('renderiza sem overflow em mobile (390x844) e desktop (1024x768)', (tester) async {
    final gateway = MemoriaResponsavelEquipeGateway(
      pendenciasIniciais: [itemExemplo1, itemExemplo2],
      equipesIniciais: [equipe1, equipe2],
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
}
