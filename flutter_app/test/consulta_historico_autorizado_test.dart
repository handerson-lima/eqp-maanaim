import 'package:eqp_maanaim/features/voluntario/consulta_ficha_screen.dart';
import 'package:eqp_maanaim/features/voluntario/historico_service.dart';
import 'package:eqp_maanaim/features/voluntario/linha_tempo_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHistoricoService extends HistoricoService {
  FakeHistoricoService({
    this.resultadoFicha,
    this.eventos = const [],
    this.simularErro = false,
  });

  final ResultadoConsultaFichaModel? resultadoFicha;
  final List<EventoLinhaDoTempoModel> eventos;
  final bool simularErro;

  @override
  Future<ResultadoConsultaFichaModel> consultarFichaAutorizada({String? fichaId}) async {
    if (simularErro) {
      throw Exception('permission-denied: Acesso não autorizado.');
    }
    return resultadoFicha ??
        const ResultadoConsultaFichaModel(
          existe: true,
          ficha: FichaConsultaModel(
            id: 'vol-1',
            ownerUid: 'vol-1',
            nomeCompleto: 'Gabriel Silva',
            profissao: 'Engenheiro',
            cpfMascarado: '***.456.789-**',
            igrejaId: 'igreja-1',
            nomeIgreja: 'Igreja Central',
            estado: 'ATIVA',
            versao: 3,
            proximaAcao: 'Voluntariado ativo',
          ),
          participacoes: [
            ParticipacaoConsultaModel(
              id: 'part-1',
              fichaId: 'vol-1',
              equipeId: 'eq-louvor',
              nomeEquipe: 'Louvor',
              estado: 'ATIVA',
              ciclo: 'INICIAL',
              proximaAcao: 'Voluntariado ativo',
              vigenciaInicio: '2026-10-01T00:00:00Z',
              vigenciaFim: '2027-10-01T00:00:00Z',
            ),
          ],
          papel: 'VOLUNTARIO',
          equipesFiltradas: false,
        );
  }

  @override
  Future<List<EventoLinhaDoTempoModel>> consultarLinhaDoTempoAutorizada({
    String? fichaId,
    String? participacaoId,
  }) async {
    if (simularErro) {
      throw Exception('permission-denied: Histórico não autorizado.');
    }
    return eventos;
  }
}

void main() {
  group('Story 4.1: Componente LinhaDoTempoWidget (UX Sally + A11y WCAG 2.2 AA)', () {
    testWidgets('renderiza marcos históricos com ícones, status textual e timestamps formatados', (tester) async {
      final eventos = [
        const EventoLinhaDoTempoModel(
          id: 'ev-1',
          tipo: 'HOMOLOGACAO_COORDENACAO',
          etapa: 'COORDENADOR_GERAL',
          titulo: 'Homologação e ativação anual',
          descricao: 'Voluntariado ativo homologado para vigência de 2026 a 2027.',
          estadoVisual: 'CONCLUIDO',
          timestamp: '2026-10-06T15:30:00Z',
          atorNome: 'Coordenador Geral',
          atorPapel: 'COORDENADOR_GERAL',
        ),
        const EventoLinhaDoTempoModel(
          id: 'ev-2',
          tipo: 'DECISAO_RESPONSAVEL_EQUIPE',
          etapa: 'RESPONSAVEL_EQUIPE',
          titulo: 'Aprovação da equipe Louvor',
          descricao: 'Participação aprovada pelo Responsável de Equipe.',
          estadoVisual: 'CONCLUIDO',
          timestamp: '2026-10-05T14:00:00Z',
          atorNome: 'Líder Louvor',
          atorPapel: 'RESPONSAVEL_EQUIPE',
          nomeEquipe: 'Louvor',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LinhaDoTempoWidget(eventos: eventos),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Linha do Tempo e Histórico'), findsOneWidget);
      expect(find.text('Homologação e ativação anual'), findsOneWidget);
      expect(find.text('Aprovação da equipe Louvor'), findsOneWidget);
      expect(find.text('Concluído'), findsNWidgets(2));
      expect(find.text('Coordenador Geral'), findsOneWidget);
      expect(find.text('Líder Louvor'), findsOneWidget);
    });

    testWidgets('decisão desfavorável/orientação pastoral renderiza mensagem neutra canônica e oculta avaliador', (tester) async {
      final eventos = [
        const EventoLinhaDoTempoModel(
          id: 'ev-negativo',
          tipo: 'DECISAO_PASTORAL',
          etapa: 'PASTOR_LOCAL',
          titulo: 'Avaliação pastoral concluída',
          descricao: 'Procure o Pastor da igreja local para mais informações',
          estadoVisual: 'ORIENTACAO_PASTORAL',
          timestamp: '2026-10-06T10:00:00Z',
          atorNome: null, // Mascarado para o voluntário
          justificativaInterna: null, // Mascarado para o voluntário
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LinhaDoTempoWidget(eventos: eventos),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Avaliação pastoral concluída'), findsOneWidget);
      expect(find.text('Procure o Pastor da igreja local para mais informações'), findsOneWidget);
      expect(find.text('Orientações'), findsOneWidget);

      // Não pode exibir a palavra rejeitado
      expect(find.textContaining('rejeitado'), findsNothing);
      expect(find.textContaining('desfavorável'), findsNothing);
    });

    testWidgets('exibe justificativa interna quando visualizado por liderança autorizada', (tester) async {
      final eventos = [
        const EventoLinhaDoTempoModel(
          id: 'ev-lideranca',
          tipo: 'DECISAO_PASTORAL',
          etapa: 'PASTOR_LOCAL',
          titulo: 'Avaliação pastoral',
          descricao: 'Decisão pastoral desfavorável registrada.',
          estadoVisual: 'ORIENTACAO_PASTORAL',
          timestamp: '2026-10-06T10:00:00Z',
          atorNome: 'Pastor João Silva',
          atorPapel: 'PASTOR_LOCAL',
          justificativaInterna: 'Falta assiduidade nos cultos dominicais.',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LinhaDoTempoWidget(eventos: eventos),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pastor João Silva'), findsOneWidget);
      expect(find.text('Justificativa interna (autorizada):'), findsOneWidget);
      expect(find.text('Falta assiduidade nos cultos dominicais.'), findsOneWidget);
    });

    testWidgets('renderiza estado vazio acolhedor quando não há eventos', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LinhaDoTempoWidget(eventos: []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum evento registrado no histórico até o momento.'), findsOneWidget);
    });

    testWidgets('renderiza estado de erro e botão de tentar novamente com altura acessível >= 44px', (tester) async {
      bool tentouNovamente = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinhaDoTempoWidget(
              eventos: const [],
              errorMessage: 'Falha na conexão.',
              onRetry: () => tentouNovamente = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Falha na conexão.'), findsOneWidget);
      final botaoRetry = find.text('Tentar novamente');
      expect(botaoRetry, findsOneWidget);

      // Verificar tamanho do alvo de toque (WCAG 2.2 AA)
      final size = tester.getSize(find.ancestor(of: botaoRetry, matching: find.byType(ConstrainedBox)).first);
      expect(size.height, greaterThanOrEqualTo(44.0));

      await tester.tap(botaoRetry);
      await tester.pump();
      expect(tentouNovamente, isTrue);
    });
  });

  group('Story 4.1: Tela ConsultaFichaAutorizadaScreen', () {
    testWidgets('carrega e exibe ficha autorizada, participações e timeline', (tester) async {
      final fakeService = FakeHistoricoService(
        eventos: [
          const EventoLinhaDoTempoModel(
            id: 'ev-1',
            tipo: 'ENVIO_APROVACAO',
            etapa: 'CADASTRO',
            titulo: 'Ficha enviada para aprovação',
            descricao: 'Termo aceito e solicitação encaminhada.',
            estadoVisual: 'CONCLUIDO',
            timestamp: '2026-10-06T12:00:00Z',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ConsultaFichaAutorizadaScreen(
            fichaId: 'vol-1',
            historicoService: fakeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gabriel Silva'), findsNWidgets(2));
      expect(find.text('Engenheiro'), findsOneWidget);
      expect(find.text('***.456.789-**'), findsOneWidget);
      expect(find.text('Louvor'), findsOneWidget);
      expect(find.text('Ficha enviada para aprovação'), findsOneWidget);
    });

    testWidgets('exibe banner de isolamento de equipe quando o ator é Responsável de Equipe com equipesFiltradas', (tester) async {
      final fakeService = FakeHistoricoService(
        resultadoFicha: const ResultadoConsultaFichaModel(
          existe: true,
          ficha: FichaConsultaModel(
            id: 'vol-1',
            ownerUid: 'vol-1',
            nomeCompleto: 'Lucas Martins',
            profissao: 'Designer',
            cpfMascarado: '***.111.222-**',
            igrejaId: 'ig-1',
            nomeIgreja: 'Igreja Sul',
            estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
            versao: 1,
          ),
          participacoes: [
            ParticipacaoConsultaModel(
              id: 'part-som',
              fichaId: 'vol-1',
              equipeId: 'eq-som',
              nomeEquipe: 'Sonoplastia',
              estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
              ciclo: 'INICIAL',
              proximaAcao: 'Aguardando avaliação',
            ),
          ],
          papel: 'RESPONSAVEL_EQUIPE',
          equipesFiltradas: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ConsultaFichaAutorizadaScreen(
            fichaId: 'vol-1',
            historicoService: fakeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lucas Martins'), findsNWidgets(2));
      expect(find.text('Sonoplastia'), findsOneWidget);
      expect(
        find.textContaining('Visualização restrita: exibindo exclusivamente as participações e eventos sob sua gestão de equipe'),
        findsOneWidget,
      );
    });

    testWidgets('exibe feedback de Acesso Restrito quando serviço rejeita por falta de vínculo vigente', (tester) async {
      final fakeService = FakeHistoricoService(simularErro: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ConsultaFichaAutorizadaScreen(
            fichaId: 'vol-bloqueado',
            historicoService: fakeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acesso Restrito'), findsOneWidget);
      expect(
        find.text('Acesso não autorizado para a ficha solicitada ou vínculo não vigente.'),
        findsOneWidget,
      );
    });

    testWidgets('renderiza sem overflow em mobile (390x844) e desktop (1024x768)', (tester) async {
      final fakeService = FakeHistoricoService(
        eventos: [
          const EventoLinhaDoTempoModel(
            id: 'ev-1',
            tipo: 'HOMOLOGACAO_COORDENACAO',
            etapa: 'COORDENADOR_GERAL',
            titulo: 'Homologação e ativação anual',
            descricao: 'Voluntariado ativo homologado com vigência anual.',
            estadoVisual: 'CONCLUIDO',
            timestamp: '2026-10-06T15:30:00Z',
          ),
        ],
      );

      // Mobile
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        MaterialApp(
          home: ConsultaFichaAutorizadaScreen(
            fichaId: 'vol-1',
            historicoService: fakeService,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Desktop
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        MaterialApp(
          home: ConsultaFichaAutorizadaScreen(
            fichaId: 'vol-1',
            historicoService: fakeService,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
