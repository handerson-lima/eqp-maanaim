import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/renovacao/dashboard_renovacao_screen.dart';
import 'package:eqp_maanaim/features/renovacao/dashboard_renovacao_service.dart';

void main() {
  group('Story 5.4: Dashboard de Renovação por Papel', () {
    // -------------------------------------------------------------------------
    // Teste 1: Voluntário
    // -------------------------------------------------------------------------
    testWidgets('Voluntário: exibe KPIs e ações de manifestação de renovação',
        (tester) async {
      final memoriaGateway = MemoriaDashboardRenovacaoGateway(
        respostaPadrao: const ResultadoDashboardRenovacaoModel(
          papelResolvido: PapelDashboard.voluntario,
          metricasVoluntario: MetricasRenovacaoVoluntarioModel(
            totalParticipacoesAtivas: 2,
            emJanelaRenovacao: 1,
            pendentesManifestacao: 1,
            emTramitacao: 0,
            expiradas: 0,
          ),
          itensVoluntario: [
            ItemRenovacaoVoluntarioModel(
              participacaoId: 'part-01',
              equipeId: 'eq-louvor',
              equipeNome: 'Louvor',
              estadoParticipacao: 'ATIVA',
              vigenciaInicio: '2025-10-20T00:00:00Z',
              vigenciaFim: '2026-10-20T00:00:00Z',
              anoVigencia: 2026,
              situacaoVigencia: 'RENOVACAO_IMINENTE_30D',
              diasRestantes: 13,
              emJanelaRenovacao: true,
              podeManifestar: true,
            ),
            ItemRenovacaoVoluntarioModel(
              participacaoId: 'part-02',
              equipeId: 'eq-som',
              equipeNome: 'Sonoplastia',
              estadoParticipacao: 'ATIVA',
              vigenciaInicio: '2026-05-10T00:00:00Z',
              vigenciaFim: '2027-05-10T00:00:00Z',
              anoVigencia: 2026,
              situacaoVigencia: 'VIGENTE',
              diasRestantes: 215,
              emJanelaRenovacao: false,
              podeManifestar: false,
            ),
          ],
          totalItens: 2,
          pagina: 1,
          totalPaginas: 1,
        ),
      );

      bool manifestou = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardRenovacaoScreen(
            gateway: memoriaGateway,
            papelInicial: PapelDashboard.voluntario,
            onManifestarVoluntario: (_) => manifestou = true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica KPIs
      expect(find.text('Equipes Ativas'), findsOneWidget);
      expect(find.text('Em Janela de Renovação'), findsOneWidget);
      expect(find.text('Pendente Manifestação'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // total ativas
      expect(find.text('1'), findsNWidgets(2)); // em janela e pendente

      // Verifica itens
      expect(find.text('Louvor'), findsOneWidget);
      expect(find.text('Sonoplastia'), findsOneWidget);
      expect(find.text('13 dias restantes'), findsOneWidget);
      expect(find.text('Manifestar Interesse de Renovação'), findsOneWidget);

      // Clica no botão de manifestar interesse
      await tester.tap(find.text('Manifestar Interesse de Renovação'));
      await tester.pump();
      expect(manifestou, isTrue);
    });

    // -------------------------------------------------------------------------
    // Teste 2: Pastor Local
    // -------------------------------------------------------------------------
    testWidgets('Pastor Local: exibe métricas da igreja, pendências e botão de análise',
        (tester) async {
      final memoriaGateway = MemoriaDashboardRenovacaoGateway(
        respostaPadrao: const ResultadoDashboardRenovacaoModel(
          papelResolvido: PapelDashboard.pastorLocal,
          metricasPastor: MetricasRenovacaoPastorModel(
            pendentesParecer: 1,
            semManifestacao: 1,
            proximasVencimento: 2,
            expiradas: 0,
            totalSobEscopo: 5,
          ),
          itensPastor: [
            ItemRenovacaoPastorModel(
              participacaoId: 'p-01',
              fichaId: 'f-01',
              voluntarioNome: 'Gabriel Ferreira',
              igrejaId: 'ig-central',
              igrejaNome: 'Igreja Central',
              equipeId: 'eq-portaria',
              equipeNome: 'Portaria',
              vigenciaFim: '2026-10-30T00:00:00Z',
              diasRestantes: 23,
              situacaoVigencia: 'RENOVACAO_IMINENTE_30D',
              estadoRenovacao: 'PENDENTE_PASTOR',
            ),
          ],
          igrejasEscopo: [
            EscopoOpcaoFiltroModel(id: 'ig-central', nome: 'Igreja Central'),
            EscopoOpcaoFiltroModel(id: 'ig-norte', nome: 'Igreja Norte'),
          ],
          totalItens: 1,
          pagina: 1,
          totalPaginas: 1,
        ),
      );

      bool analisou = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardRenovacaoScreen(
            gateway: memoriaGateway,
            papelInicial: PapelDashboard.pastorLocal,
            onAnalisarPastor: (_) => analisou = true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica KPIs do Pastor
      expect(find.text('Pendentes do Pastor'), findsWidgets);
      expect(find.text('Sem Manifestação'), findsWidgets);
      expect(find.text('Vencimento < 30 dias'), findsOneWidget);
      expect(find.text('Expiradas'), findsWidgets);

      // Verifica voluntário sob o escopo
      expect(find.text('Gabriel Ferreira'), findsOneWidget);
      expect(find.textContaining('Igreja Central'), findsWidgets);
      expect(find.textContaining('Portaria'), findsWidgets);
      expect(find.text('Analisar Renovação'), findsOneWidget);

      await tester.ensureVisible(find.text('Analisar Renovação'));
      await tester.tap(find.text('Analisar Renovação'));
      await tester.pump();
      expect(analisou, isTrue);
    });

    // -------------------------------------------------------------------------
    // Teste 3: Responsável de Equipe
    // -------------------------------------------------------------------------
    testWidgets('Responsável de Equipe: exibe pendências da equipe e deliberação',
        (tester) async {
      final memoriaGateway = MemoriaDashboardRenovacaoGateway(
        respostaPadrao: const ResultadoDashboardRenovacaoModel(
          papelResolvido: PapelDashboard.responsavelEquipe,
          metricasResponsavel: MetricasRenovacaoResponsavelModel(
            pendentesEquipe: 1,
            emTramitacao: 1,
            semManifestacao: 0,
            expiradas: 0,
            totalEquipe: 3,
          ),
          itensResponsavel: [
            ItemRenovacaoResponsavelModel(
              participacaoId: 'p-resp-01',
              fichaId: 'f-resp-01',
              voluntarioNome: 'Mariana Lima',
              igrejaId: 'ig-central',
              igrejaNome: 'Igreja Central',
              equipeId: 'eq-diaconia',
              equipeNome: 'Diaconia',
              vigenciaFim: '2026-11-15T00:00:00Z',
              diasRestantes: 39,
              situacaoVigencia: 'ALERTA_PREVIO_60D',
              estadoRenovacao: 'PENDENTE_EQUIPE',
            ),
          ],
          totalItens: 1,
          pagina: 1,
          totalPaginas: 1,
        ),
      );

      bool deliberou = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardRenovacaoScreen(
            gateway: memoriaGateway,
            papelInicial: PapelDashboard.responsavelEquipe,
            onDeliberarResponsavel: (_) => deliberou = true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pendentes da Equipe'), findsWidgets);
      expect(find.text('Em Tramitação'), findsWidgets);
      expect(find.text('Mariana Lima'), findsOneWidget);
      await tester.ensureVisible(find.text('Deliberar Continuacão'));
      await tester.tap(find.text('Deliberar Continuacão'));
      await tester.pump();
      expect(deliberou, isTrue);
    });

    // -------------------------------------------------------------------------
    // Teste 4: Coordenador Geral com paginação estável
    // -------------------------------------------------------------------------
    testWidgets('Coordenador Geral: visão global consolidada com filtros e paginação',
        (tester) async {
      final memoriaGateway = MemoriaDashboardRenovacaoGateway(
        respostaPadrao: const ResultadoDashboardRenovacaoModel(
          papelResolvido: PapelDashboard.coordenador,
          metricasCoordenador: MetricasRenovacaoCoordenadorModel(
            totalAtivos: 120,
            emJanelaRenovacao: 35,
            pendentesPastorLocal: 10,
            pendentesResponsaveis: 8,
            aguardandoCoordenador: 5,
            renovadosConcluidos: 42,
            expirados: 4,
          ),
          itensCoordenador: [
            ItemRenovacaoCoordenadorModel(
              participacaoId: 'p-coord-01',
              fichaId: 'f-coord-01',
              voluntarioNome: 'Lucas Mendes',
              igrejaId: 'ig-central',
              igrejaNome: 'Igreja Central',
              equipeId: 'eq-midia',
              equipeNome: 'Mídia',
              vigenciaFim: '2026-10-18T00:00:00Z',
              diasRestantes: 11,
              situacaoVigencia: 'RENOVACAO_IMINENTE_30D',
              estadoRenovacao: 'AGUARDANDO_COORDENADOR',
            ),
          ],
          totalItens: 45,
          pagina: 1,
          totalPaginas: 3,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardRenovacaoScreen(
            gateway: memoriaGateway,
            papelInicial: PapelDashboard.coordenador,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Métricas globais
      expect(find.text('Total Ativos'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('Aguardando Coordenação'), findsWidgets);
      expect(find.text('Renovados / Concluídos'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);

      // Paginação
      expect(find.textContaining('Página 1 de 3 (45 registros)'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Teste 5: Estados de Vazio e Erro
    // -------------------------------------------------------------------------
    testWidgets('Exibe mensagem contextual de vazio quando não houver itens',
        (tester) async {
      final memoriaGateway = MemoriaDashboardRenovacaoGateway(
        respostaPadrao: const ResultadoDashboardRenovacaoModel(
          papelResolvido: PapelDashboard.voluntario,
          metricasVoluntario: MetricasRenovacaoVoluntarioModel(
            totalParticipacoesAtivas: 0,
            emJanelaRenovacao: 0,
            pendentesManifestacao: 0,
            emTramitacao: 0,
            expiradas: 0,
          ),
          itensVoluntario: [],
          totalItens: 0,
          pagina: 1,
          totalPaginas: 1,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardRenovacaoScreen(
            gateway: memoriaGateway,
            papelInicial: PapelDashboard.voluntario,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Você não possui participações registradas.'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Teste 6: Responsividade mobile e desktop sem overflow
    // -------------------------------------------------------------------------
    testWidgets('Responsividade: renderiza sem overflow em 390x844 e 1024x768',
        (tester) async {
      final memoriaGateway = MemoriaDashboardRenovacaoGateway(
        respostaPadrao: const ResultadoDashboardRenovacaoModel(
          papelResolvido: PapelDashboard.coordenador,
          metricasCoordenador: MetricasRenovacaoCoordenadorModel(
            totalAtivos: 10,
            emJanelaRenovacao: 2,
            pendentesPastorLocal: 1,
            pendentesResponsaveis: 1,
            aguardandoCoordenador: 1,
            renovadosConcluidos: 5,
            expirados: 0,
          ),
          totalItens: 0,
          pagina: 1,
          totalPaginas: 1,
        ),
      );

      // Mobile
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardRenovacaoScreen(
            gateway: memoriaGateway,
            papelInicial: PapelDashboard.coordenador,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Desktop
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardRenovacaoScreen(
            gateway: memoriaGateway,
            papelInicial: PapelDashboard.coordenador,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
