import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/termo/pdf_termo_service.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:eqp_maanaim/ui/components/layout_elements.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_documento_viewer_widget.dart';
import 'package:eqp_maanaim/features/voluntario/minha_ficha_screen.dart';

import 'documentos_privados_s09_test.dart';
import 'fakes.dart';

void main() {
  late CatalogoFake catalogoGateway;
  late MemoriaPdfTermoGateway pdfGateway;

  setUp(() {
    catalogoGateway = CatalogoFake(
      resposta: const CatalogoResposta(
        igrejas: [
          IgrejaCatalogo(
            id: 'igreja-1',
            nome: 'Igreja Central',
            codigo: '001',
            ativo: true,
          ),
        ],
        equipes: [
          EquipeCatalogo(
            id: 'eq-louvor',
            nome: 'Música e Louvor',
            ativo: true,
          ),
          EquipeCatalogo(
            id: 'eq-intercessao',
            nome: 'Intercessão',
            ativo: true,
          ),
        ],
      ),
    );
    pdfGateway = MemoriaPdfTermoGateway();
  });

  Widget criarAppTeste({required Widget child}) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  final fichaAtiva = FichaModel(
    id: 'user-123',
    nomeCompleto: 'Gabriel Silva',
    profissao: 'Engenheiro',
    cpf: '123.456.789-00',
    telefone: '(11) 98765-4321',
    igrejaId: 'igreja-1',
    estado: 'ATIVA',
    versao: 1,
    atualizadoEm: '2026-01-15T10:00:00Z',
    termoAceito: const TermoAceitoModel(
      termoId: 'termo-2026',
      versaoId: 'v1',
      numeroVersao: 2026,
      hashSha256: 'abc123hash',
      aceitoEm: '2026-01-12T14:30:00Z',
      commandId: 'cmd-1',
    ),
  );

  const participacaoAtiva = ParticipacaoModel(
    id: 'part-1',
    fichaId: 'user-123',
    equipeId: 'eq-louvor',
    nomeEquipe: 'Música e Louvor',
    estado: 'ATIVA',
    ciclo: 'INICIAL',
    proximaAcao: 'Voluntariado ativo',
    versao: 1,
    criadoEm: '2026-01-01T00:00:00Z',
  );

  const participacaoEmAprovacao = ParticipacaoModel(
    id: 'part-2',
    fichaId: 'user-123',
    equipeId: 'eq-intercessao',
    nomeEquipe: 'Intercessão',
    estado: 'AGUARDANDO_COORDENADOR',
    ciclo: 'INICIAL',
    proximaAcao: 'Aguardando validação',
    versao: 1,
    criadoEm: '2026-01-10T00:00:00Z',
  );

  group('S09 — FichaDocumentoViewerWidget Component Tests', () {
    testWidgets('1. Renderiza moldura institucional, toolbar com controles e folha A4', (tester) async {
      bool downloadDisparado = false;

      await tester.pumpWidget(
        criarAppTeste(
          child: SingleChildScrollView(
            child: FichaDocumentoViewerWidget(
              ficha: fichaAtiva,
              participacoes: const [participacaoAtiva, participacaoEmAprovacao],
              nomeIgreja: 'Igreja Central',
              codigoIgreja: '001',
              emailVoluntario: 'gabriel@maanaim.org',
              termoVersao: '2026',
              aceiteEm: '2026-01-12T14:30:00Z',
              onBaixarPdf: () => downloadDisparado = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toolbar de controles do documento
      expect(find.byKey(const Key('toolbar_documento_viewer')), findsOneWidget);
      expect(find.byKey(const Key('btn_doc_zoom_out')), findsOneWidget);
      expect(find.byKey(const Key('btn_doc_zoom_in')), findsOneWidget);
      expect(find.byKey(const Key('btn_doc_zoom_fit')), findsOneWidget);
      expect(find.byKey(const Key('btn_doc_imprimir')), findsOneWidget);
      expect(find.byKey(const Key('btn_doc_baixar')), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // Testar interação de zoom
      await tester.tap(find.byKey(const Key('btn_doc_zoom_in')));
      await tester.pumpAndSettle();
      expect(find.text('125%'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_doc_zoom_out')));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);

      // Botão de download na toolbar
      await tester.tap(find.byKey(const Key('btn_doc_baixar')));
      expect(downloadDisparado, isTrue);

      // Cabeçalho do documento na folha estilizada
      expect(find.text('FICHA DE VOLUNTÁRIO'), findsOneWidget);
      expect(find.byKey(const Key('texto_id_documento_fv')), findsOneWidget);
      expect(find.text('ATIVA'), findsWidgets);

      // Bloco 1 — Dados do Voluntário
      expect(find.text('Gabriel Silva'), findsOneWidget);
      expect(find.text('(11) 98765-4321'), findsOneWidget);
      expect(find.text('gabriel@maanaim.org'), findsOneWidget);
      expect(find.text('Igreja Central - 001'), findsOneWidget);
      expect(find.text('Versão 2026'), findsOneWidget);

      // Bloco 2 — Tabela de Equipes
      expect(find.text('Música e Louvor'), findsOneWidget);
      expect(find.text('Intercessão'), findsOneWidget);
      expect(find.text('EM APROVAÇÃO'), findsOneWidget);
    });

    testWidgets('2. Preserva neutralidade de orientações para cancelamento / decisão negativa', (tester) async {
      const participacaoCancelada = ParticipacaoModel(
        id: 'part-3',
        fichaId: 'user-123',
        equipeId: 'eq-louvor',
        nomeEquipe: 'Música e Louvor',
        estado: 'CANCELADA_COORDENADOR',
        ciclo: 'INICIAL',
        proximaAcao: 'Procure o Pastor da igreja local para mais informações',
        versao: 1,
        criadoEm: '2026-01-01T00:00:00Z',
      );

      await tester.pumpWidget(
        criarAppTeste(
          child: SingleChildScrollView(
            child: FichaDocumentoViewerWidget(
              ficha: fichaAtiva,
              participacoes: const [participacaoCancelada],
              nomeIgreja: 'Igreja Central',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Invariante canônica: nunca exibe "Rejeitada", exibe traço para aprovação não realizada e chip neutro
      expect(find.text('REJEITADA'), findsNothing);
      expect(find.text('Rejeitado'), findsNothing);
      expect(find.text('—'), findsWidgets);
      expect(find.text('Informação'), findsOneWidget);
    });
  });

  group('S09 — MinhaFichaScreen Integration Tests', () {
    testWidgets('3. Exibe cabeçalho S09 com título, subtítulo e botão primário Baixar PDF', (tester) async {
      final fichaGateway = TesteFichaMockGateway(ficha: fichaAtiva);
      final participacaoGateway = TesteParticipacaoMockGateway([participacaoAtiva]);

      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        criarAppTeste(
          child: MinhaFichaScreen(
            fichaGateway: fichaGateway,
            participacaoGateway: participacaoGateway,
            catalogoGateway: catalogoGateway,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cabeçalho da página
      expect(find.widgetWithText(PageHeader, 'Minha Ficha'), findsOneWidget);
      expect(find.text('Visualize e baixe sua ficha de voluntário'), findsOneWidget);

      // Botão primário Baixar PDF presente quando há participação ativa
      expect(find.byKey(const Key('btn_baixar_pdf_principal')), findsOneWidget);

      // Menu de ações secundárias presente
      expect(find.byKey(const Key('btn_menu_acoes_secundarias')), findsOneWidget);

      // Viewer do documento no layout desktop
      expect(find.byKey(const Key('ficha_documento_viewer')), findsOneWidget);
    });

    testWidgets('4. Botão primário Baixar PDF não aparece quando voluntário não possui equipe ativa', (tester) async {
      final fichaPendente = fichaAtiva.copyWith(estado: 'AGUARDANDO_PASTOR_LOCAL');
      final fichaGateway = TesteFichaMockGateway(ficha: fichaPendente);
      final participacaoGateway = TesteParticipacaoMockGateway([participacaoEmAprovacao]);

      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        criarAppTeste(
          child: MinhaFichaScreen(
            fichaGateway: fichaGateway,
            participacaoGateway: participacaoGateway,
            catalogoGateway: catalogoGateway,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Botão de download no topo omitido para quem não tem participação ativa
      expect(find.byKey(const Key('btn_baixar_pdf_principal')), findsNothing);
    });

    testWidgets('5. Renderização mobile (390x844) sem overflow de layout', (tester) async {
      final fichaGateway = TesteFichaMockGateway(ficha: fichaAtiva);
      final participacaoGateway = TesteParticipacaoMockGateway([participacaoAtiva, participacaoEmAprovacao]);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        criarAppTeste(
          child: MinhaFichaScreen(
            fichaGateway: fichaGateway,
            participacaoGateway: participacaoGateway,
            catalogoGateway: catalogoGateway,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('layout_mobile_empilhado')), findsOneWidget);
      expect(find.byKey(const Key('ficha_documento_viewer_mobile')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. Renderização desktop (1280x800) sem overflow de layout', (tester) async {
      final fichaGateway = TesteFichaMockGateway(ficha: fichaAtiva);
      final participacaoGateway = TesteParticipacaoMockGateway([participacaoAtiva]);

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        criarAppTeste(
          child: MinhaFichaScreen(
            fichaGateway: fichaGateway,
            participacaoGateway: participacaoGateway,
            catalogoGateway: catalogoGateway,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('layout_desktop_colunas')), findsOneWidget);
      expect(find.byKey(const Key('ficha_documento_viewer')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
