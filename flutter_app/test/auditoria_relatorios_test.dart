import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/auditoria/auditoria_relatorios_screen.dart';
import 'package:eqp_maanaim/features/auditoria/auditoria_service.dart';
import 'package:eqp_maanaim/ui/identidade.dart';

void main() {
  final eventoExemplo1 = ItemAuditoria(
    id: 'CMD_101',
    commandId: 'CMD_101',
    correlationId: 'CORR_101',
    atorUid: 'PASTOR_MARIO',
    acao: 'DECISAO_PASTOR_LOCAL',
    entidades: [
      {'tipo': 'IGREJA', 'id': 'ig_central'},
      {'tipo': 'VOLUNTARIO', 'id': 'vol_101'},
    ],
    timestamp: '2026-10-07T14:30:00.000Z',
    metadados: {'decisao': 'APROVADO'},
  );

  final eventoExemplo2 = ItemAuditoria(
    id: 'CMD_102',
    commandId: 'CMD_102',
    correlationId: 'CORR_102',
    atorUid: 'RESP_LOUVOR',
    acao: 'DECISAO_RESPONSAVEL_EQUIPE',
    entidades: [
      {'tipo': 'EQUIPE', 'id': 'eq_louvor'},
      {'tipo': 'VOLUNTARIO', 'id': 'vol_101'},
    ],
    timestamp: '2026-10-07T15:00:00.000Z',
    metadados: {'decisao': 'APROVADO'},
  );

  Widget criarApp(AuditoriaRelatoriosGateway gateway, {Size tamanho = const Size(1024, 768)}) {
    return MaterialApp(
      theme: temaMaanaim(),
      home: MediaQuery(
        data: MediaQueryData(size: tamanho),
        child: AuditoriaRelatoriosScreen(gateway: gateway),
      ),
    );
  }

  testWidgets('renderiza sem overflow em mobile (390x844) e desktop (1024x768)', (tester) async {
    final gateway = MemoriaAuditoriaGateway(
      eventosIniciais: [eventoExemplo1, eventoExemplo2],
    );

    // Desktop
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(criarApp(gateway, tamanho: const Size(1024, 768)));
    await tester.pumpAndSettle();

    expect(find.text('Auditoria & Relatórios'), findsOneWidget);
    expect(find.text('Trilha de Auditoria'), findsOneWidget);
    expect(find.text('Relatório Operacional'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Mobile
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(criarApp(gateway, tamanho: const Size(390, 844)));
    await tester.pumpAndSettle();

    expect(find.text('Auditoria & Relatórios'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exibe cards de eventos na trilha de auditoria mobile', (tester) async {
    final gateway = MemoriaAuditoriaGateway(
      eventosIniciais: [eventoExemplo1, eventoExemplo2],
    );

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(criarApp(gateway, tamanho: const Size(390, 844)));
    await tester.pumpAndSettle();

    expect(find.text('Comando: CMD_101'), findsOneWidget);
    expect(find.text('Ator: PASTOR_MARIO'), findsOneWidget);
    expect(find.text('Comando: CMD_102'), findsOneWidget);
    expect(find.text('Ator: RESP_LOUVOR'), findsOneWidget);
  });

  testWidgets('alterna para a aba Relatório Operacional e exibe métricas e CPF mascarado', (tester) async {
    final gateway = MemoriaAuditoriaGateway(
      eventosIniciais: [eventoExemplo1],
    );

    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(criarApp(gateway, tamanho: const Size(1024, 768)));
    await tester.pumpAndSettle();

    // Clica na aba Relatório Operacional
    await tester.tap(find.text('Relatório Operacional'));
    await tester.pumpAndSettle();

    expect(find.text('Total de Voluntários'), findsOneWidget);
    expect(find.text('Fichas Ativas'), findsOneWidget);
    expect(find.text('Carlos Eduardo Santos'), findsOneWidget);
    // Valida que o CPF é exibido estritamente mascarado (AD-12)
    expect(find.text('123.***.***-00'), findsOneWidget);
    expect(find.text('Ana Beatriz Ferreira'), findsOneWidget);
    expect(find.text('987.***.***-11'), findsOneWidget);
  });

  testWidgets('filtra auditoria por ação', (tester) async {
    final gateway = MemoriaAuditoriaGateway(
      eventosIniciais: [eventoExemplo1, eventoExemplo2],
    );

    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(criarApp(gateway, tamanho: const Size(1024, 768)));
    await tester.pumpAndSettle();

    expect(find.text('PASTOR_MARIO'), findsOneWidget);
    expect(find.text('RESP_LOUVOR'), findsOneWidget);

    // Preenche campo de filtro
    await tester.enterText(find.byType(TextField), 'DECISAO_PASTOR_LOCAL');
    await tester.tap(find.text('Filtrar'));
    await tester.pumpAndSettle();

    expect(find.text('PASTOR_MARIO'), findsOneWidget);
    expect(find.text('RESP_LOUVOR'), findsNothing);

    // Limpa filtro
    await tester.tap(find.text('Limpar Filtros'));
    await tester.pumpAndSettle();

    expect(find.text('PASTOR_MARIO'), findsOneWidget);
    expect(find.text('RESP_LOUVOR'), findsOneWidget);
  });

  testWidgets('exibe EmptyState quando não há eventos de auditoria', (tester) async {
    final gateway = MemoriaAuditoriaGateway(eventosIniciais: []);

    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(criarApp(gateway, tamanho: const Size(1024, 768)));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum registro de auditoria encontrado'), findsOneWidget);
  });
}
