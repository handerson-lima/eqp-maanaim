import 'package:eqp_maanaim/features/voluntario/cancelar_voluntariado_dialog.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final participacoesAfetadas = [
    const ParticipacaoModel(
      id: 'part-som',
      fichaId: 'vol-01',
      equipeId: 'eq-som',
      nomeEquipe: 'Som e Mídia',
      estado: 'ATIVA',
      ciclo: 'INICIAL',
      proximaAcao: 'Voluntariado ativo',
    ),
    const ParticipacaoModel(
      id: 'part-louvor',
      fichaId: 'vol-01',
      equipeId: 'eq-louvor',
      nomeEquipe: 'Louvor',
      estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
      ciclo: 'INICIAL',
      proximaAcao: 'Aguardando avaliação do Responsável de Equipe',
    ),
  ];

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

  testWidgets('Story 4.3: Exibe diálogo de encerramento total com preview de todos os itens afetados (Sally)', (tester) async {
    await tester.pumpWidget(
      criarAppParaDialog(
        child: CancelarVoluntariadoDialog(
          fichaId: 'vol-01',
          participacoesAfetadas: participacoesAfetadas,
          isLideranca: false,
          onConfirmar: (_) async {},
        ),
      ),
    );

    expect(find.text('Encerrar Voluntariado'), findsOneWidget);
    expect(find.text('Equipes e participações que serão canceladas:'), findsOneWidget);

    // Deve listar explicitamente Som e Louvor
    expect(find.byKey(const Key('item_afetado_part-som')), findsOneWidget);
    expect(find.text('Som e Mídia'), findsOneWidget);
    expect(find.byKey(const Key('item_afetado_part-louvor')), findsOneWidget);
    expect(find.text('Louvor'), findsOneWidget);

    expect(find.byKey(const Key('btn_cancelar_modal_voluntariado')), findsOneWidget);
    expect(find.byKey(const Key('btn_confirmar_cancelamento_voluntariado')), findsOneWidget);
  });

  testWidgets('Story 4.3: Confirma encerramento de voluntariado com sucesso', (tester) async {
    var confirmado = false;

    await tester.pumpWidget(
      criarAppParaDialog(
        child: CancelarVoluntariadoDialog(
          fichaId: 'vol-01',
          participacoesAfetadas: participacoesAfetadas,
          isLideranca: false,
          onConfirmar: (_) async {
            confirmado = true;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('btn_confirmar_cancelamento_voluntariado')));
    await tester.pumpAndSettle();

    expect(confirmado, isTrue);
  });

  testWidgets('Story 4.3: Liderança é obrigada a informar justificativa de cancelamento geral', (tester) async {
    String? motivoRecebido;
    var confirmado = false;

    await tester.pumpWidget(
      criarAppParaDialog(
        child: CancelarVoluntariadoDialog(
          fichaId: 'vol-01',
          participacoesAfetadas: participacoesAfetadas,
          isLideranca: true,
          onConfirmar: (motivo) async {
            motivoRecebido = motivo;
            confirmado = true;
          },
        ),
      ),
    );

    expect(find.byKey(const Key('campo_motivo_cancelamento_voluntariado')), findsOneWidget);

    // Tentar sem preencher
    await tester.ensureVisible(find.byKey(const Key('btn_confirmar_cancelamento_voluntariado')));
    await tester.tap(find.byKey(const Key('btn_confirmar_cancelamento_voluntariado')));
    await tester.pumpAndSettle();
    expect(confirmado, isFalse);

    // Preencher justificativa
    await tester.enterText(
      find.byKey(const Key('campo_motivo_cancelamento_voluntariado')),
      'Desligamento geral a pedido ministerial',
    );
    await tester.ensureVisible(find.byKey(const Key('btn_confirmar_cancelamento_voluntariado')));
    await tester.tap(find.byKey(const Key('btn_confirmar_cancelamento_voluntariado')));
    await tester.pumpAndSettle();

    expect(confirmado, isTrue);
    expect(motivoRecebido, 'Desligamento geral a pedido ministerial');
  });

  testWidgets('Story 4.3: Renderiza diálogo de cancelamento geral sem overflow em mobile e desktop', (tester) async {
    for (final size in [const Size(390, 844), const Size(1024, 768)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        criarAppParaDialog(
          tamanho: size,
          child: CancelarVoluntariadoDialog(
            fichaId: 'vol-01',
            participacoesAfetadas: participacoesAfetadas,
            isLideranca: true,
            onConfirmar: (_) async {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Encerrar Voluntariado'), findsOneWidget);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
