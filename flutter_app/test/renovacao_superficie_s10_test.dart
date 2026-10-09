import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:eqp_maanaim/features/voluntario/renovacao_screen.dart';

class MockTestParticipacaoGateway extends MemoriaParticipacaoGateway {
  MockTestParticipacaoGateway({
    super.participacoesIniciais,
    this.lancarErro = false,
  });

  bool lancarErro;
  List<ManifestacaoEquipeInput>? ultimasManifestacoes;
  String? ultimoCommandId;
  int chamadasManifestar = 0;

  @override
  Future<List<Map<String, dynamic>>> manifestarRenovacao({
    required List<ManifestacaoEquipeInput> manifestacoes,
    String? commandId,
  }) async {
    chamadasManifestar++;
    ultimasManifestacoes = manifestacoes;
    ultimoCommandId = commandId;

    if (lancarErro) {
      throw Exception('A janela de renovação para uma ou mais equipes foi encerrada.');
    }

    return super.manifestarRenovacao(
      manifestacoes: manifestacoes,
      commandId: commandId,
    );
  }
}

Widget criarTestApp({required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  final part1 = ParticipacaoModel(
    id: 'part-01',
    fichaId: 'user-001',
    equipeId: 'eq-louvor',
    nomeEquipe: 'Equipe de Louvor',
    estado: 'ATIVA',
    ciclo: 'INICIAL',
    proximaAcao: 'Vigência ativa',
    vigenciaInicio: '2025-11-01T00:00:00Z',
    vigenciaFim: '2026-11-01T00:00:00Z',
    diasParaVencimento: 25,
    situacaoVigencia: 'RENOVACAO_IMINENTE_30D',
    emAlertaRenovacao: true,
  );

  final part2 = ParticipacaoModel(
    id: 'part-02',
    fichaId: 'user-001',
    equipeId: 'eq-recepcao',
    nomeEquipe: 'Equipe de Recepção',
    estado: 'ATIVA',
    ciclo: 'INICIAL',
    proximaAcao: 'Vigência ativa',
    vigenciaInicio: '2025-10-15T00:00:00Z',
    vigenciaFim: '2026-10-15T00:00:00Z',
    diasParaVencimento: 10,
    situacaoVigencia: 'RENOVACAO_IMINENTE_30D',
    emAlertaRenovacao: true,
  );

  group('Story 8.9: RenovacaoScreen S10 (Fluxo em Etapas e Validações)', () {
    testWidgets('renderiza tela S10 com stepper na etapa 1 e escolhas explícitas sem default silencioso', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      final fakeGateway = MockTestParticipacaoGateway(participacoesIniciais: [part1]);

      await tester.pumpWidget(
        criarTestApp(
          child: RenovacaoScreen(
            participacaoGateway: fakeGateway,
            participacoesIniciais: [part1],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cabeçalho e Stepper
      expect(find.text('Renovação de Participação'), findsOneWidget);
      expect(find.text('Escolhas por Equipe'), findsWidgets);

      // Card da equipe
      expect(find.byKey(const Key('card_renovacao_part-01')), findsOneWidget);
      expect(find.text('Equipe de Louvor'), findsOneWidget);

      // Botões de escolha explícita
      final btnContinuar = find.byKey(const Key('btn_continuar_part-01'));
      final btnNaoContinuar = find.byKey(const Key('btn_nao_continuar_part-01'));
      expect(btnContinuar, findsOneWidget);
      expect(btnNaoContinuar, findsOneWidget);

      // Botão avançar desabilitado inicialmente (nenhuma ausência é tratada como CONTINUAR)
      final btnAvancar = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Avançar para Revisão'),
      );
      expect(btnAvancar.onPressed, isNull);
    });

    testWidgets('carrega decisão prévia persistida em caso de retomada', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      final partComDecisao = part1.copyWith(
        intencaoRenovacao: 'CONTINUAR',
      );

      final fakeGateway = MockTestParticipacaoGateway(participacoesIniciais: [partComDecisao]);

      await tester.pumpWidget(
        criarTestApp(
          child: RenovacaoScreen(
            participacaoGateway: fakeGateway,
            participacoesIniciais: [partComDecisao],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Registro anterior é exibido
      expect(find.text('Registro anterior: Continuar'), findsOneWidget);

      // Botão avançar já habilitado pois decisão estava preenchida
      final btnAvancar = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Avançar para Revisão'),
      );
      expect(btnAvancar.onPressed, isNotNull);
    });

    testWidgets('fluxo completo: selecionar escolhas mistas -> revisar segregação de consequências -> enviar lote atômico', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      final fakeGateway = MockTestParticipacaoGateway(participacoesIniciais: [part1, part2]);
      bool foiParaInicio = false;
      bool foiParaFicha = false;

      await tester.pumpWidget(
        criarTestApp(
          child: RenovacaoScreen(
            participacaoGateway: fakeGateway,
            participacoesIniciais: [part1, part2],
            onIrParaInicio: () => foiParaInicio = true,
            onIrParaMinhaFicha: () => foiParaFicha = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Seleciona part1 como CONTINUAR
      await _tocar(tester, find.byKey(const Key('btn_continuar_part-01')));

      // Seleciona part2 como NAO_CONTINUAR
      await _tocar(tester, find.byKey(const Key('btn_nao_continuar_part-02')));

      // Agora o botão avançar está habilitado
      await _tocar(tester, find.byKey(const Key('btn_avancar_revisao')));

      // --- ETAPA 1: REVISÃO ---
      expect(find.text('Revise suas manifestações antes de confirmar'), findsOneWidget);
      expect(find.text('Equipes para Renovação (1)'), findsOneWidget);
      expect(find.text('Equipes para Encerramento (1)'), findsOneWidget);

      // Valida consequência contextual de Continuar
      expect(
        find.textContaining('ingressará no processo de aprovação de ciclo anual e aguardará parecer do Pastor Local'),
        findsOneWidget,
      );

      // Valida consequência contextual de Não Continuar
      expect(
        find.textContaining('Você continuará servindo até o final da vigência atual. Após o vencimento, sua participação será concluída'),
        findsOneWidget,
      );

      // Submete manifestação
      await _tocar(tester, find.byKey(const Key('btn_confirmar_envio_manifestacao')));

      // --- ETAPA 2: RESULTADOS ---
      expect(find.text('Manifestação Registrada com Sucesso!'), findsOneWidget);
      expect(fakeGateway.chamadasManifestar, 1);
      expect(fakeGateway.ultimasManifestacoes?.length, 2);
      expect(fakeGateway.ultimoCommandId, isNotNull);

      // Verifica links de acompanhamento
      await _tocar(tester, find.byKey(const Key('btn_ver_minha_ficha')));
      expect(foiParaFicha, isTrue);

      await _tocar(tester, find.byKey(const Key('btn_ir_para_inicio')));
      expect(foiParaInicio, isTrue);
    });

    testWidgets('botão "Voltar para Escolhas" preserva seleções efetuadas pelo voluntário', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      final fakeGateway = MockTestParticipacaoGateway(participacoesIniciais: [part1, part2]);

      await tester.pumpWidget(
        criarTestApp(
          child: RenovacaoScreen(
            participacaoGateway: fakeGateway,
            participacoesIniciais: [part1, part2],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Seleciona opções
      await _tocar(tester, find.byKey(const Key('btn_continuar_part-01')));
      await _tocar(tester, find.byKey(const Key('btn_nao_continuar_part-02')));

      // Avança para revisão
      await _tocar(tester, find.byKey(const Key('btn_avancar_revisao')));
      expect(find.text('Revise suas manifestações antes de confirmar'), findsOneWidget);

      // Clica em "Voltar para Escolhas"
      await _tocar(tester, find.byKey(const Key('btn_voltar_escolhas')));

      // Verifica que está de volta na etapa de escolhas e o botão de avançar continua habilitado
      expect(find.text('Revise suas manifestações antes de confirmar'), findsNothing);
      final btnAvancar = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Avançar para Revisão'),
      );
      expect(btnAvancar.onPressed, isNotNull);
    });

    testWidgets('erro de servidor permite retry com o mesmo commandId idempotente', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      final fakeGateway = MockTestParticipacaoGateway(
        participacoesIniciais: [part1],
        lancarErro: true,
      );

      await tester.pumpWidget(
        criarTestApp(
          child: RenovacaoScreen(
            participacaoGateway: fakeGateway,
            participacoesIniciais: [part1],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tocar(tester, find.byKey(const Key('btn_continuar_part-01')));
      await _tocar(tester, find.byKey(const Key('btn_avancar_revisao')));

      // Envia e falha
      await _tocar(tester, find.byKey(const Key('btn_confirmar_envio_manifestacao')));

      expect(find.text('Falha no envio da manifestação'), findsOneWidget);
      expect(find.text('A janela de renovação para uma ou mais equipes foi encerrada.'), findsOneWidget);

      final primeiroCommandId = fakeGateway.ultimoCommandId;
      expect(primeiroCommandId, isNotNull);

      // Corrige o gateway e clica em Tentar Novamente
      fakeGateway.lancarErro = false;
      await _tocar(tester, find.byKey(const Key('btn_tentar_novamente_envio')));

      // Verifica sucesso e idempotência (mesmo commandId repetido)
      expect(find.text('Manifestação Registrada com Sucesso!'), findsOneWidget);
      expect(fakeGateway.chamadasManifestar, 2);
      expect(fakeGateway.ultimoCommandId, primeiroCommandId);
    });

    testWidgets('exibe mensagem amigável quando não há equipes elegíveis para renovação', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      final fakeGateway = MockTestParticipacaoGateway(participacoesIniciais: []);

      await tester.pumpWidget(
        criarTestApp(
          child: RenovacaoScreen(
            participacaoGateway: fakeGateway,
            participacoesIniciais: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma equipe elegível para renovação no momento'), findsOneWidget);
      expect(find.text('Voltar ao Início'), findsOneWidget);
    });

    testWidgets('renderiza sem overflow em mobile (390x844) e desktop (1280x800)', (tester) async {
      final fakeGateway = MockTestParticipacaoGateway(participacoesIniciais: [part1, part2]);

      // Mobile
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        criarTestApp(
          child: RenovacaoScreen(
            participacaoGateway: fakeGateway,
            participacoesIniciais: [part1, part2],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Desktop
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(
        criarTestApp(
          child: RenovacaoScreen(
            participacaoGateway: fakeGateway,
            participacoesIniciais: [part1, part2],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
