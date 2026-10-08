import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/admin/painel_solicitacoes_pendentes_screen.dart';
import 'package:eqp_maanaim/features/admin/solicitacoes_pendentes_service.dart';

void main() {
  final itensExemplo = [
    SolicitacaoPendenteItemModel(
      participacaoId: 'part-1',
      fichaId: 'ficha-1',
      equipeId: 'eqp-apoio',
      equipeNome: 'Apoio',
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      proximaAcao: 'Aguardando validação pastoral',
      enviadoEm: DateTime(2026, 10, 8, 9, 30),
      nomeVoluntario: 'Carlos Eduardo',
      profissao: 'Engenheiro de Software',
      cpfMascarado: '010.***.***-78',
      cpfDigitos: '01012345678',
      igrejaId: 'ig-1',
      igrejaNome: 'Praia da Costa',
      igrejaCodigo: 'PC-01',
    ),
    SolicitacaoPendenteItemModel(
      participacaoId: 'part-2',
      fichaId: 'ficha-2',
      equipeId: 'eqp-apoio',
      equipeNome: 'Apoio',
      estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
      proximaAcao: 'Aguardando parecer do responsável',
      enviadoEm: DateTime(2026, 10, 7, 14, 0),
      nomeVoluntario: 'Mariana Silva',
      profissao: 'Professora',
      cpfMascarado: '020.***.***-99',
      cpfDigitos: '02098765499',
      igrejaId: 'ig-2',
      igrejaNome: 'Itaparica',
      igrejaCodigo: 'IT-02',
    ),
    SolicitacaoPendenteItemModel(
      participacaoId: 'part-3',
      fichaId: 'ficha-3',
      equipeId: 'eqp-louvor',
      equipeNome: 'Louvor',
      estado: 'AGUARDANDO_COORDENADOR',
      proximaAcao: 'Aguardando homologação da coordenação geral',
      enviadoEm: DateTime(2026, 10, 6, 18, 0),
      nomeVoluntario: 'Lucas Pereira',
      profissao: 'Músico',
      cpfMascarado: '030.***.***-11',
      cpfDigitos: '03055544411',
      igrejaId: 'ig-1',
      igrejaNome: 'Praia da Costa',
      igrejaCodigo: 'PC-01',
    ),
  ];

  Widget criarTela(SolicitacoesPendentesGateway gateway) {
    return MaterialApp(
      home: PainelSolicitacoesPendentesScreen(gateway: gateway),
    );
  }

  group('PainelSolicitacoesPendentesScreen', () {
    testWidgets('renderiza itens agrupados por equipe e contadores de métricas',
        (tester) async {
      final gateway = MockSolicitacoesPendentesGateway(initialItems: itensExemplo);

      await tester.pumpWidget(criarTela(gateway));
      await tester.pumpAndSettle();

      // Métricas no topo
      expect(find.text('Central de Solicitações'), findsOneWidget);
      expect(find.text('Total Pendente'), findsOneWidget);
      expect(find.text('3'), findsNWidgets(2)); // Total geral e Itens filtrados
      expect(find.text('Equipes c/ Pendências'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // Apoio e Louvor

      // Equipes renderizadas
      expect(find.text('Apoio'), findsOneWidget);
      expect(find.text('2 pendências'), findsOneWidget);
      expect(find.text('Louvor'), findsOneWidget);
      expect(find.text('1 pendência'), findsOneWidget);

      // Dados dos voluntários
      expect(find.text('Carlos Eduardo'), findsOneWidget);
      expect(find.text('Mariana Silva'), findsOneWidget);
      expect(find.text('Lucas Pereira'), findsOneWidget);
      expect(find.text('Engenheiro de Software'), findsOneWidget);
      expect(find.text('CPF: 010.***.***-78'), findsOneWidget);
    });

    testWidgets('filtra em tempo real por termo de nome', (tester) async {
      final gateway = MockSolicitacoesPendentesGateway(initialItems: itensExemplo);

      await tester.pumpWidget(criarTela(gateway));
      await tester.pumpAndSettle();

      // Digita "Mariana" no campo de busca
      await tester.enterText(find.byType(TextField), 'Mariana');
      await tester.pumpAndSettle();

      expect(find.text('Mariana Silva'), findsOneWidget);
      expect(find.text('Carlos Eduardo'), findsNothing);
      expect(find.text('Lucas Pereira'), findsNothing);
      expect(find.text('Louvor'), findsNothing); // Louvor não tem Mariana
      expect(find.text('1 pendência'), findsOneWidget); // Apenas Mariana em Apoio
    });

    testWidgets('filtra por dígitos de CPF (com ou sem formatação)', (tester) async {
      final gateway = MockSolicitacoesPendentesGateway(initialItems: itensExemplo);

      await tester.pumpWidget(criarTela(gateway));
      await tester.pumpAndSettle();

      // Digita dígitos parciais do CPF de Carlos: "010123"
      await tester.enterText(find.byType(TextField), '010123');
      await tester.pumpAndSettle();

      expect(find.text('Carlos Eduardo'), findsOneWidget);
      expect(find.text('Mariana Silva'), findsNothing);
      expect(find.text('Lucas Pereira'), findsNothing);

      // Digita com pontuação: "010.123"
      await tester.enterText(find.byType(TextField), '010.123');
      await tester.pumpAndSettle();

      expect(find.text('Carlos Eduardo'), findsOneWidget);
      expect(find.text('Mariana Silva'), findsNothing);
    });

    testWidgets('filtra por profissão ou igreja', (tester) async {
      final gateway = MockSolicitacoesPendentesGateway(initialItems: itensExemplo);

      await tester.pumpWidget(criarTela(gateway));
      await tester.pumpAndSettle();

      // Digita profissão "Músico"
      await tester.enterText(find.byType(TextField), 'musico');
      await tester.pumpAndSettle();

      expect(find.text('Lucas Pereira'), findsOneWidget);
      expect(find.text('Carlos Eduardo'), findsNothing);
      expect(find.text('Mariana Silva'), findsNothing);

      // Digita código da igreja "IT-02"
      await tester.enterText(find.byType(TextField), 'IT-02');
      await tester.pumpAndSettle();

      expect(find.text('Mariana Silva'), findsOneWidget);
      expect(find.text('Carlos Eduardo'), findsNothing);
    });

    testWidgets('exibe estado vazio quando busca não tem resultados', (tester) async {
      final gateway = MockSolicitacoesPendentesGateway(initialItems: itensExemplo);

      await tester.pumpWidget(criarTela(gateway));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Inexistente');
      await tester.pumpAndSettle();

      expect(find.text('Nenhum resultado para "Inexistente"'), findsOneWidget);
      expect(find.text('Carlos Eduardo'), findsNothing);
      expect(find.text('Mariana Silva'), findsNothing);
    });

    testWidgets('exibe estado vazio quando não há solicitações cadastradas',
        (tester) async {
      final gateway = MockSolicitacoesPendentesGateway(initialItems: []);

      await tester.pumpWidget(criarTela(gateway));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma solicitação pendente encontrada'), findsOneWidget);
      expect(
        find.text('Todas as solicitações de voluntariado foram processadas.'),
        findsOneWidget,
      );
    });
  });
}
