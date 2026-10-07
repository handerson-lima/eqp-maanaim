import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:eqp_maanaim/features/voluntario/solicitar_reativacao_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const participacaoCancelada = ParticipacaoModel(
    id: 'part-louvor-01',
    fichaId: 'voluntario-01',
    equipeId: 'eq-louvor',
    nomeEquipe: 'Equipe de Louvor',
    estado: 'CANCELADA',
    ciclo: 'INICIAL',
    proximaAcao: 'Participação cancelada pelo voluntário',
  );

  Widget criarAppParaDialog({
    required Widget child,
    Size tamanho = const Size(390, 844),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: tamanho),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('Story 4.4: Exibe diálogo de solicitação de reativação com as 3 etapas de aprovação', (tester) async {
    await tester.pumpWidget(
      criarAppParaDialog(
        child: SolicitarReativacaoDialog(
          participacao: participacaoCancelada,
          onConfirmar: (_) async {},
        ),
      ),
    );

    expect(find.text('Solicitar Reativação'), findsOneWidget);
    expect(find.text('Equipe de Louvor'), findsOneWidget);
    expect(find.text('Como funciona a reativação?'), findsOneWidget);
    expect(find.textContaining('1️⃣ Aprovação pelo Pastor Local'), findsOneWidget);
    expect(find.textContaining('2️⃣ Avaliação pelo Responsável'), findsOneWidget);
    expect(find.textContaining('3️⃣ Homologação final pelo Coordenador'), findsOneWidget);
    expect(find.byKey(const Key('input_justificativa_reativacao')), findsOneWidget);
    expect(find.byKey(const Key('btn_cancelar_dialog_reativacao')), findsOneWidget);
    expect(find.byKey(const Key('btn_confirmar_dialog_reativacao')), findsOneWidget);
  });

  testWidgets('Story 4.4: Voluntário confirma reativação com justificativa opcional preenchida', (tester) async {
    String? justificativaEnviada;
    var confirmado = false;

    await tester.pumpWidget(
      criarAppParaDialog(
        child: SolicitarReativacaoDialog(
          participacao: participacaoCancelada,
          onConfirmar: (justificativa) async {
            justificativaEnviada = justificativa;
            confirmado = true;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('input_justificativa_reativacao')),
      'Estou disponível novamente para escala de louvor.',
    );

    await tester.ensureVisible(find.byKey(const Key('btn_confirmar_dialog_reativacao')));
    await tester.tap(find.byKey(const Key('btn_confirmar_dialog_reativacao')));
    await tester.pumpAndSettle();

    expect(confirmado, isTrue);
    expect(justificativaEnviada, 'Estou disponível novamente para escala de louvor.');
  });

  testWidgets('Story 4.4: Exibe mensagem de erro na falha do envio', (tester) async {
    await tester.pumpWidget(
      criarAppParaDialog(
        child: SolicitarReativacaoDialog(
          participacao: participacaoCancelada,
          onConfirmar: (_) async {
            throw Exception('Já existe solicitação em andamento para esta equipe');
          },
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('btn_confirmar_dialog_reativacao')));
    await tester.tap(find.byKey(const Key('btn_confirmar_dialog_reativacao')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Já existe solicitação em andamento para esta equipe'),
      findsOneWidget,
    );
  });

  testWidgets('Story 4.4: Layout responsivo sem overflow em mobile (390x844) e desktop (1024x768)', (tester) async {
    // Mobile
    await tester.pumpWidget(
      criarAppParaDialog(
        tamanho: const Size(390, 844),
        child: SolicitarReativacaoDialog(
          participacao: participacaoCancelada,
          onConfirmar: (_) async {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    // Desktop
    await tester.pumpWidget(
      criarAppParaDialog(
        tamanho: const Size(1024, 768),
        child: SolicitarReativacaoDialog(
          participacao: participacaoCancelada,
          onConfirmar: (_) async {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Story 4.4: MemoriaParticipacaoGateway cria nova participação reativada com estado AGUARDANDO_PASTOR_LOCAL', (tester) async {
    final gateway = MemoriaParticipacaoGateway(
      participacoesIniciais: [participacaoCancelada],
    );
    gateway.nomesEquipes['eq-louvor'] = 'Equipe de Louvor';

    final nova = await gateway.solicitarReativacao(
      equipeId: 'eq-louvor',
      participacaoId: participacaoCancelada.id,
      justificativa: 'Disponível',
    );

    expect(nova.equipeId, 'eq-louvor');
    expect(nova.estado, 'AGUARDANDO_PASTOR_LOCAL');
    expect(nova.ciclo, 'REATIVACAO');
    expect(nova.proximaAcao, 'Aguardando avaliação do Pastor Local');

    final todas = await gateway.obterMinhasParticipacoes();
    expect(todas.length, 2);
    // A anterior permanece intacta (append-only)
    final anterior = todas.firstWhere((p) => p.id == participacaoCancelada.id);
    expect(anterior.estado, 'CANCELADA');
  });
}
