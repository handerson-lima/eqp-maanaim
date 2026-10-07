import 'package:eqp_maanaim/features/admin/admin_shell.dart';
import 'package:eqp_maanaim/features/privacidade/conformidade_retencao_screen.dart';
import 'package:eqp_maanaim/features/privacidade/politica_privacidade_card.dart';
import 'package:eqp_maanaim/features/privacidade/retencao_service.dart';
import 'package:eqp_maanaim/ui/identidade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _GatewayComItens implements RetencaoGateway {
  @override
  Future<IndicadoresRetencao> consultarConformidade() async {
    return const IndicadoresRetencao(
      politicaId: 'AD-12_V1',
      anosRetencao: 5,
      diasRascunho: 180,
      expurgoAutomaticoHabilitado: false,
      totalFichas: 3,
      fichasAnonimizadas: 1,
      fichasAtivas: 1,
      fichasElegiveisAnonimizacao: 1,
      rascunhosElegiveisExpurgo: 1,
      porEstado: {'ATIVA': 1, 'EXPIRADA': 1, 'RASCUNHO': 1},
      geradoEm: '2026-10-07T12:00:00.000Z',
    );
  }

  @override
  Future<ResultadoRotinaRetencao> executarRotina({
    required String commandId,
    required bool dryRun,
    String motivo = 'EXECUCAO_MANUAL',
    int limite = 100,
  }) async {
    return ResultadoRotinaRetencao(
      sucesso: true,
      repetido: false,
      dryRun: dryRun,
      politicaId: 'AD-12_V1',
      totalAnalisadas: 3,
      totalAnonimizadas: 1,
      totalExpurgadas: 1,
      ignoradas: 1,
      itens: const [
        ItemRetencao(
          fichaId: 'ficha-secreta-123',
          estado: 'EXPIRADA',
          acao: 'ANONIMIZAR',
          motivo: 'EXECUCAO_MANUAL',
        ),
      ],
      processadoEm: '2026-10-07T12:00:00.000Z',
    );
  }
}

class _GatewayFalhaAposSucesso implements RetencaoGateway {
  int chamadas = 0;

  @override
  Future<IndicadoresRetencao> consultarConformidade() async {
    chamadas++;
    if (chamadas > 1) {
      throw const RetencaoFalhaException('Indicadores indisponíveis no momento.');
    }
    return const IndicadoresRetencao(
      politicaId: 'AD-12_V1',
      anosRetencao: 5,
      diasRascunho: 180,
      expurgoAutomaticoHabilitado: false,
      totalFichas: 10,
      fichasAnonimizadas: 1,
      fichasAtivas: 5,
      fichasElegiveisAnonimizacao: 1,
      rascunhosElegiveisExpurgo: 1,
      porEstado: {'ATIVA': 5},
      geradoEm: '2026-10-07T12:00:00.000Z',
    );
  }

  @override
  Future<ResultadoRotinaRetencao> executarRotina({
    required String commandId,
    required bool dryRun,
    String motivo = 'EXECUCAO_MANUAL',
    int limite = 100,
  }) async {
    throw const RetencaoFalhaException('Falha simulada.');
  }
}

Widget _appWidget(RetencaoGateway gateway, {Size tamanho = const Size(390, 844)}) {
  return MaterialApp(
    theme: temaMaanaim(),
    home: MediaQuery(
      data: MediaQueryData(size: tamanho),
      child: ConformidadeRetencaoScreen(gateway: gateway),
    ),
  );
}

void _definirTamanho(WidgetTester tester, Size tamanho) {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('renderiza o painel de conformidade sem overflow em mobile e desktop', (
    tester,
  ) async {
    final gateway = MemoriaRetencaoGateway();

    _definirTamanho(tester, const Size(390, 844));
    await tester.pumpWidget(_appWidget(gateway, tamanho: const Size(390, 844)));
    await tester.pumpAndSettle();
    expect(find.text('Retenção e Privacidade'), findsOneWidget);
    expect(find.text('Política vigente'), findsOneWidget);
    expect(find.text('AD-12_V1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    _definirTamanho(tester, const Size(1280, 900));
    await tester.pumpWidget(_appWidget(gateway, tamanho: const Size(1280, 900)));
    await tester.pumpAndSettle();
    expect(find.text('Retenção e Privacidade'), findsOneWidget);
    expect(find.text('Elegíveis à Anonimização'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mostra estado de acesso negado sem vazar dados', (tester) async {
    _definirTamanho(tester, const Size(390, 844));
    await tester.pumpWidget(
      _appWidget(MemoriaRetencaoGateway(negarAcesso: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Acesso negado'), findsOneWidget);
  });

  testWidgets('simula a rotina sem exibir IDs de voluntários', (tester) async {
    _definirTamanho(tester, const Size(390, 844));
    await tester.pumpWidget(_appWidget(_GatewayComItens()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('retencao_simular_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('retencao_simular_button')));
    await tester.pumpAndSettle();

    expect(find.text('Resultado da simulação'), findsOneWidget);
    expect(find.text('Simulação concluída. Nada foi alterado.'), findsOneWidget);
    // Somente contagens: nenhum ID de voluntário é exibido.
    expect(find.textContaining('ficha-secreta-123'), findsNothing);
  });

  testWidgets('exige confirmação antes de executar a rotina', (tester) async {
    _definirTamanho(tester, const Size(390, 844));
    await tester.pumpWidget(_appWidget(MemoriaRetencaoGateway()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('retencao_executar_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('retencao_executar_button')));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar execução da rotina'), findsOneWidget);

    await tester.tap(find.byKey(const Key('retencao_confirmar_execucao')));
    await tester.pumpAndSettle();
    expect(find.text('Rotina executada com sucesso.'), findsOneWidget);
  });

  testWidgets('mostra banner de erro ao falhar atualização com indicadores carregados', (
    tester,
  ) async {
    _definirTamanho(tester, const Size(390, 844));
    await tester.pumpWidget(_appWidget(_GatewayFalhaAposSucesso()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('retencao_simular_button')), findsOneWidget);

    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('retencao_erro_banner')), findsOneWidget);
    expect(
      find.text('Não foi possível atualizar os indicadores'),
      findsOneWidget,
    );
  });

  testWidgets('cartão de privacidade apresenta retenção, finalidade, PDF e canal LGPD', (
    tester,
  ) async {
    _definirTamanho(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: temaMaanaim(),
        home: const Scaffold(
          body: SingleChildScrollView(child: PoliticaPrivacidadeCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('politica_privacidade_card')), findsOneWidget);
    expect(find.text('Privacidade e Retenção de Dados'), findsOneWidget);
    expect(find.textContaining('5 anos'), findsWidgets);
    expect(find.textContaining('Finalidade'), findsOneWidget);
    expect(find.textContaining('PDF é privado'), findsOneWidget);
    expect(find.textContaining('Canal da Privacidade (LGPD)'), findsOneWidget);
  });

  testWidgets('AdminShell expõe a aba Retenção e Privacidade', (tester) async {
    _definirTamanho(tester, const Size(1280, 900));
    await tester.pumpWidget(
      MaterialApp(
        theme: temaMaanaim(),
        home: AdminShell(
          onSair: () {},
          retencao: MemoriaRetencaoGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retenção e Privacidade'));
    await tester.pumpAndSettle();
    expect(find.byType(ConformidadeRetencaoScreen), findsOneWidget);
  });
}
