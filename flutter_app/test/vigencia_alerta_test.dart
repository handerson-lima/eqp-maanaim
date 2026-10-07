import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/historico_service.dart';
import 'package:eqp_maanaim/features/voluntario/minha_ficha_screen.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:eqp_maanaim/ui/components/vigencia_badge.dart';

import 'fakes.dart';

class MockFichaGateway implements FichaGateway {
  MockFichaGateway({this.ficha});

  FichaModel? ficha;

  @override
  Future<ObterFichaResposta> obterMinhaFicha() async {
    if (ficha == null) {
      return const ObterFichaResposta(existe: false);
    }
    return ObterFichaResposta(existe: true, ficha: ficha);
  }

  @override
  Future<SalvarFichaResposta> salvarMinhaFicha(SalvarFichaEntrada entrada) async {
    final atual = ficha ??
        FichaModel(
          id: 'user-123',
          nomeCompleto: entrada.nomeCompleto,
          cpf: entrada.cpf,
          profissao: entrada.profissao,
          igrejaId: entrada.igrejaId,
          estado: 'RASCUNHO',
          versao: 1,
        );
    return SalvarFichaResposta(sucesso: true, repetido: false, ficha: atual);
  }

  @override
  Future<EnviarFichaResposta> enviarFichaAprovacao({
    required String commandId,
    int? expectedVersion,
  }) async {
    return EnviarFichaResposta(
      sucesso: true,
      repetido: false,
      estado: ficha?.estado ?? 'AGUARDANDO_PASTOR_LOCAL',
      versao: (ficha?.versao ?? 1) + 1,
      proximaAcao: ficha?.proximaAcao ?? 'Em análise',
      igrejaId: ficha?.igrejaId ?? '',
      enviadoEm: '2026-10-06T12:00:00Z',
    );
  }

  @override
  Future<void> cancelarVoluntariado({
    required String fichaId,
    String? motivo,
    int? expectedVersion,
    String? commandId,
  }) async {}
}

class MockParticipacaoGateway implements ParticipacaoGateway {
  MockParticipacaoGateway(this.participacoes);

  final List<ParticipacaoModel> participacoes;

  @override
  Future<List<ParticipacaoModel>> obterMinhasParticipacoes() async =>
      List.unmodifiable(participacoes);

  @override
  Future<List<ParticipacaoModel>> salvarParticipacoesRascunho(
    List<String> equipeIds, {
    String? commandId,
  }) async =>
      List.unmodifiable(participacoes);

  @override
  Future<ParticipacaoModel> solicitarEquipeAdicional(
    String equipeId, {
    String? commandId,
  }) async =>
      participacoes.first;

  @override
  Future<void> cancelarParticipacao({
    required String participacaoId,
    String? motivo,
    int? expectedVersion,
    String? commandId,
  }) async {}

  @override
  Future<ParticipacaoModel> solicitarReativacao({
    required String equipeId,
    String? participacaoId,
    String? justificativa,
    String? commandId,
  }) async =>
      participacoes.first;

  @override
  Future<List<Map<String, dynamic>>> manifestarRenovacao({
    required List<ManifestacaoEquipeInput> manifestacoes,
    String? commandId,
  }) async =>
      const [];
}

void main() {
  final catalogoFake = CatalogoFake(
    resposta: const CatalogoResposta(
      equipes: [
        EquipeCatalogo(id: 'eq-transmissao', nome: 'Transmissão', ativo: true),
      ],
      igrejas: [
        IgrejaCatalogo(id: 'ig-centro', nome: 'Igreja Central', codigo: '001', ativo: true),
      ],
    ),
  );

  Widget criarAppTeste({required Widget child, Size? tamanho}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: tamanho ?? const Size(390, 844),
        ),
        child: Scaffold(body: child),
      ),
    );
  }

  group('Story 5.1: VigenciaBadge - Componente e WCAG 2.2 AA (Sally)', () {
    testWidgets('renderiza estado NORMAL com período formatado e ícone de sucesso', (tester) async {
      await tester.pumpWidget(
        criarAppTeste(
          child: const VigenciaBadge(
            vigenciaInicio: '2026-05-10T12:00:00Z',
            vigenciaFim: '2027-05-10T12:00:00Z',
            situacaoVigencia: 'VIGENTE',
            diasParaVencimento: 180,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vigência: 10/05/2026 até 10/05/2027'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('renderiza estado ALERTA 60 DIAS (aviso prévio de renovação)', (tester) async {
      await tester.pumpWidget(
        criarAppTeste(
          child: const VigenciaBadge(
            vigenciaInicio: '2025-11-20T12:00:00Z',
            vigenciaFim: '2026-11-20T12:00:00Z',
            situacaoVigencia: 'ALERTA_PREVIO_60D',
            diasParaVencimento: 45,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aviso de renovação: vence em 45 dias'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('renderiza estado ALERTA 30 DIAS (renovação necessária/iminente)', (tester) async {
      await tester.pumpWidget(
        criarAppTeste(
          child: const VigenciaBadge(
            vigenciaInicio: '2025-10-25T12:00:00Z',
            vigenciaFim: '2026-10-25T12:00:00Z',
            situacaoVigencia: 'RENOVACAO_IMINENTE_30D',
            diasParaVencimento: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Renovação necessária: vence em 18 dias'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('renderiza singular para exatamente 1 dia restante', (tester) async {
      await tester.pumpWidget(
        criarAppTeste(
          child: const VigenciaBadge(
            vigenciaInicio: '2025-10-08T12:00:00Z',
            vigenciaFim: '2026-10-08T12:00:00Z',
            situacaoVigencia: 'RENOVACAO_IMINENTE_30D',
            diasParaVencimento: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Renovação necessária: vence em 1 dia'), findsOneWidget);
    });

    testWidgets('renderiza estado EXPIRADA com ícone de cancelamento e cor semântica', (tester) async {
      await tester.pumpWidget(
        criarAppTeste(
          child: const VigenciaBadge(
            vigenciaInicio: '2025-10-01T12:00:00Z',
            vigenciaFim: '2026-10-01T12:00:00Z',
            situacaoVigencia: 'EXPIRADA',
            diasParaVencimento: -6,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vigência expirada'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    });

    testWidgets('renderiza rótulo compacto de vigência VIGENTE ("Válido até ...")', (tester) async {
      await tester.pumpWidget(
        criarAppTeste(
          child: const VigenciaBadge(
            vigenciaInicio: '2026-05-10T12:00:00Z',
            vigenciaFim: '2027-05-10T12:00:00Z',
            situacaoVigencia: 'VIGENTE',
            diasParaVencimento: 180,
            compact: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Válido até 10/05/2027'), findsOneWidget);
    });

    testWidgets('renderiza badge quando apenas a mensagem de alerta é informada', (tester) async {
      await tester.pumpWidget(
        criarAppTeste(
          child: const VigenciaBadge(alertaVigencia: 'Atenção à renovação anual'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('renderiza sem overflow em mobile (390x844) e desktop (1024x768)', (tester) async {
      for (final tamanho in [const Size(390, 844), const Size(1024, 768)]) {
        tester.view.physicalSize = tamanho;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          criarAppTeste(
            tamanho: tamanho,
            child: const VigenciaBadge(
              vigenciaInicio: '2025-10-25T12:00:00Z',
              vigenciaFim: '2026-10-25T12:00:00Z',
              situacaoVigencia: 'RENOVACAO_IMINENTE_30D',
              diasParaVencimento: 18,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });
  });

  group('Story 5.1: Integração de Alertas de Vigência em MinhaFichaScreen', () {
    testWidgets('exibe VigenciaBadge quando participação ativa está em janela de renovação', (tester) async {
      final ficha = FichaModel(
        id: 'user-vigencia-1',
        nomeCompleto: 'Lucas Medeiros',
        cpf: '12345678901',
        profissao: 'Engenheiro',
        igrejaId: 'ig-centro',
        estado: 'ATIVA',
        versao: 1,
      );

      final participacoes = [
        ParticipacaoModel(
          id: 'part-alerta-30',
          fichaId: 'user-vigencia-1',
          equipeId: 'eq-transmissao',
          nomeEquipe: 'Transmissão',
          estado: 'ATIVA',
          ciclo: 'INICIAL',
          proximaAcao: 'Voluntariado ativo',
          vigenciaInicio: '2025-10-27T12:00:00Z',
          vigenciaFim: '2026-10-27T12:00:00Z',
          situacaoVigencia: 'RENOVACAO_IMINENTE_30D',
          diasParaVencimento: 20,
          emAlertaRenovacao: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MinhaFichaScreen(
              fichaGateway: MockFichaGateway(ficha: ficha),
              participacaoGateway: MockParticipacaoGateway(participacoes),
              catalogoGateway: catalogoFake,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirma dados da equipe e vigência
      expect(find.text('Transmissão'), findsWidgets);
      expect(find.text('Vigência: 27/10/2025 até 27/10/2026'), findsOneWidget);

      // Confirma exibição do badge de alerta
      expect(find.byKey(const Key('badge_vigencia_part-alerta-30')), findsOneWidget);
      expect(find.text('Renovação necessária: vence em 20 dias'), findsOneWidget);
    });
  });

  group('Story 5.1: Mapeamento dos modelos de participação', () {
    test('ParticipacaoModel.fromMap interpreta os campos de vigência', () {
      final model = ParticipacaoModel.fromMap({
        'id': 'part-1',
        'fichaId': 'ficha-1',
        'equipeId': 'eq-1',
        'nomeEquipe': 'Apoio',
        'estado': 'ATIVA',
        'ciclo': 'INICIAL',
        'proximaAcao': 'Voluntariado ativo',
        'vigenciaInicio': '2025-10-27T12:00:00.000Z',
        'vigenciaFim': '2026-10-27T12:00:00.000Z',
        'situacaoVigencia': 'RENOVACAO_IMINENTE_30D',
        'diasParaVencimento': 20,
        'alertaVigencia': 'Renovação necessária: vence em 20 dias',
        'emAlertaRenovacao': true,
      });

      expect(model.vigenciaInicio, '2025-10-27T12:00:00.000Z');
      expect(model.vigenciaFim, '2026-10-27T12:00:00.000Z');
      expect(model.situacaoVigencia, 'RENOVACAO_IMINENTE_30D');
      expect(model.diasParaVencimento, 20);
      expect(model.alertaVigencia, 'Renovação necessária: vence em 20 dias');
      expect(model.emAlertaRenovacao, isTrue);
    });

    test('ParticipacaoConsultaModel.fromMap interpreta os campos de vigência', () {
      final model = ParticipacaoConsultaModel.fromMap({
        'id': 'part-2',
        'fichaId': 'ficha-1',
        'equipeId': 'eq-2',
        'nomeEquipe': 'Som',
        'estado': 'ATIVA',
        'ciclo': 'INICIAL',
        'proximaAcao': 'Voluntariado ativo',
        'vigenciaInicio': '2025-10-27T12:00:00.000Z',
        'vigenciaFim': '2026-10-27T12:00:00.000Z',
        'situacaoVigencia': 'ALERTA_PREVIO_60D',
        'diasParaVencimento': 45,
        'alertaVigencia': 'Aviso de renovação: vence em 45 dias',
        'emAlertaRenovacao': true,
      });

      expect(model.situacaoVigencia, 'ALERTA_PREVIO_60D');
      expect(model.diasParaVencimento, 45);
      expect(model.alertaVigencia, 'Aviso de renovação: vence em 45 dias');
      expect(model.emAlertaRenovacao, isTrue);
    });
  });
}
