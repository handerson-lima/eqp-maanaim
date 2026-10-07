import 'package:eqp_maanaim/features/voluntario/cancelar_participacao_dialog.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final participacaoAtiva = const ParticipacaoModel(
    id: 'part-som-01',
    fichaId: 'voluntario-01',
    equipeId: 'eq-som',
    nomeEquipe: 'Som e Mídia',
    estado: 'ATIVA',
    ciclo: 'INICIAL',
    proximaAcao: 'Voluntariado ativo',
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

  testWidgets('Story 4.3: Exibe diálogo de cancelamento individual com advertência e equipe', (tester) async {
    await tester.pumpWidget(
      criarAppParaDialog(
        child: CancelarParticipacaoDialog(
          participacao: participacaoAtiva,
          isLideranca: false,
          onConfirmar: (_) async {},
        ),
      ),
    );

    expect(find.text('Cancelar Participação'), findsOneWidget);
    expect(find.text('Som e Mídia'), findsOneWidget);
    expect(find.textContaining('Suas outras equipes permanecerão ativas'), findsOneWidget);
    expect(find.byKey(const Key('btn_cancelar_modal_participacao')), findsOneWidget);
    expect(find.byKey(const Key('btn_confirmar_cancelamento_participacao')), findsOneWidget);
  });

  testWidgets('Story 4.3: Voluntário confirma cancelamento acionando callback com sucesso', (tester) async {
    String? motivoRecebido;
    var confirmado = false;

    await tester.pumpWidget(
      criarAppParaDialog(
        child: CancelarParticipacaoDialog(
          participacao: participacaoAtiva,
          isLideranca: false,
          onConfirmar: (motivo) async {
            motivoRecebido = motivo;
            confirmado = true;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('btn_confirmar_cancelamento_participacao')));
    await tester.pumpAndSettle();

    expect(confirmado, isTrue);
    expect(motivoRecebido, isNull);
  });

  testWidgets('Story 4.3: Diálogo sob visão de liderança exige justificativa interna com validação', (tester) async {
    String? motivoRecebido;
    var confirmado = false;

    await tester.pumpWidget(
      criarAppParaDialog(
        child: CancelarParticipacaoDialog(
          participacao: participacaoAtiva,
          isLideranca: true,
          onConfirmar: (motivo) async {
            motivoRecebido = motivo;
            confirmado = true;
          },
        ),
      ),
    );

    // Campo de justificativa deve estar visível
    expect(find.byKey(const Key('campo_motivo_cancelamento')), findsOneWidget);

    // Tentar submeter sem justificativa
    await tester.tap(find.byKey(const Key('btn_confirmar_cancelamento_participacao')));
    await tester.pumpAndSettle();

    expect(confirmado, isFalse);
    expect(find.text('Informe uma justificativa com no mínimo 5 caracteres.'), findsOneWidget);

    // Preencher justificativa válida
    await tester.enterText(
      find.byKey(const Key('campo_motivo_cancelamento')),
      'Mudança eclesiástica de comum acordo',
    );
    await tester.tap(find.byKey(const Key('btn_confirmar_cancelamento_participacao')));
    await tester.pumpAndSettle();

    expect(confirmado, isTrue);
    expect(motivoRecebido, 'Mudança eclesiástica de comum acordo');
  });

  testWidgets('Story 4.3: Renderiza diálogo sem overflow em mobile (390x844) e desktop (1024x768)', (tester) async {
    for (final size in [const Size(390, 844), const Size(1024, 768)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        criarAppParaDialog(
          tamanho: size,
          child: CancelarParticipacaoDialog(
            participacao: participacaoAtiva,
            isLideranca: true,
            onConfirmar: (_) async {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Cancelar Participação'), findsOneWidget);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
