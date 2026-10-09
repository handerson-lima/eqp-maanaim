import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/analise/detalhe_solicitacao_model.dart';
import 'package:eqp_maanaim/features/analise/detalhe_solicitacao_screen.dart';
import 'package:eqp_maanaim/features/analise/detalhe_solicitacao_service.dart';
import 'package:eqp_maanaim/features/coordenador/coordenador_service.dart';
import 'package:eqp_maanaim/features/coordenador/fila_coordenador_screen.dart';
import 'package:eqp_maanaim/features/pastor/fila_pastor_screen.dart';
import 'package:eqp_maanaim/features/pastor/pastor_service.dart';
import 'package:eqp_maanaim/features/responsavel_equipe/fila_responsavel_equipe_screen.dart';
import 'package:eqp_maanaim/features/responsavel_equipe/responsavel_equipe_service.dart';
import 'package:eqp_maanaim/ui/tokens.dart';

class MockDetalheSolicitacaoGateway implements DetalheSolicitacaoGateway {
  MockDetalheSolicitacaoGateway({
    required this.dados,
    this.lancarConflitoConcorrencia = false,
  });

  DetalheSolicitacaoDados dados;
  bool lancarConflitoConcorrencia;

  EntradaDecisaoPastor? ultimaEntradaPastor;
  EntradaDecidirParticipacaoResponsavel? ultimaEntradaResponsavel;
  EntradaDecisaoCoordenadorContextual? ultimaEntradaCoordenador;

  int chamadasObterDetalhe = 0;

  @override
  Future<DetalheSolicitacaoDados> obterDetalhe({
    required String fichaId,
    String? cicloId,
  }) async {
    chamadasObterDetalhe++;
    return dados;
  }

  @override
  Future<void> decidirPastor(
    EntradaDecisaoPastor entrada, {
    bool isRenovacao = false,
  }) async {
    if (lancarConflitoConcorrencia) {
      throw const ConflitoConcorrenciaException();
    }
    ultimaEntradaPastor = entrada;
  }

  @override
  Future<void> decidirResponsavel(
    EntradaDecidirParticipacaoResponsavel entrada, {
    bool isRenovacao = false,
  }) async {
    if (lancarConflitoConcorrencia) {
      throw const ConflitoConcorrenciaException();
    }
    ultimaEntradaResponsavel = entrada;
  }

  @override
  Future<void> decidirCoordenador({
    required EntradaDecisaoCoordenadorContextual entrada,
    bool isRenovacao = false,
  }) async {
    if (lancarConflitoConcorrencia) {
      throw const ConflitoConcorrenciaException();
    }
    ultimaEntradaCoordenador = entrada;
  }
}

DetalheSolicitacaoDados _criarDadosExemplo({
  bool elegivelPdf = false,
  bool multiEquipe = true,
  String estadoFicha = 'AGUARDANDO_PASTOR_LOCAL',
}) {
  return DetalheSolicitacaoDados(
    fichaId: 'ficha-123',
    voluntarioUid: 'user-456',
    voluntarioNome: 'Carlos Silva',
    cpfMascarado: '12345678900',
    profissao: 'Engenheiro Civil',
    igrejaId: 'igreja-1',
    nomeIgreja: 'Igreja Central',
    estadoFicha: estadoFicha,
    versao: 2,
    enviadoEm: '2026-10-09T10:00:00Z',
    participacoes: [
      ItemParticipacaoDetalhe(
        id: 'part-1',
        equipeId: 'eq-louvor',
        nomeEquipe: 'Grupo de Louvor',
        estado: elegivelPdf ? 'APROVADA' : 'AGUARDANDO_RESPONSAVEL_EQUIPE',
        ciclo: 'INICIAL',
      ),
      if (multiEquipe)
        const ItemParticipacaoDetalhe(
          id: 'part-2',
          equipeId: 'eq-recepcao',
          nomeEquipe: 'Equipe de Recepção',
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          ciclo: 'INICIAL',
        ),
    ],
    documentos: [
      const DocumentoEvidenciaModel(
        tipo: 'TERMO_ADESAO',
        titulo: 'Termo de Adesão ao Voluntariado',
        descricao: 'Aceite registrado',
        disponivel: true,
      ),
      DocumentoEvidenciaModel(
        tipo: 'PDF_APROVACAO',
        titulo: 'Ficha de Aprovação Homologada (PDF Privado)',
        descricao: elegivelPdf
            ? 'Documento assinado digitalmente'
            : 'Disponível exclusivamente após homologação',
        disponivel: elegivelPdf,
      ),
    ],
  );
}

void main() {
  group('Story 8.7 — Tela S05 Detalhe da Solicitação e Decisão Contextual', () {
    testWidgets('Desktop (1280x800): Renderiza layout em duas colunas (Resumo 1/3 à esquerda e Painel 2/3 à direita)',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final gateway = MockDetalheSolicitacaoGateway(dados: _criarDadosExemplo());

      await tester.pumpWidget(
        MaterialApp(
          home: DetalheSolicitacaoScreen(
            fichaId: 'ficha-123',
            papel: PapelContextualAnalise.pastorLocal,
            gateway: gateway,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cardResumoVoluntario')), findsOneWidget);
      expect(find.byKey(const Key('cardSecaoEquipes')), findsOneWidget);
      expect(find.byKey(const Key('cardSecaoDocumentos')), findsOneWidget);
      expect(find.byKey(const Key('cardPainelDecisao')), findsOneWidget);

      expect(find.text('Carlos Silva'), findsWidgets);
      expect(find.text('Igreja Central'), findsOneWidget);
      expect(find.text('123.456.789-00'), findsOneWidget);
      expect(find.text('Engenheiro Civil'), findsOneWidget);
      expect(find.text('v2'), findsOneWidget);
    });

    testWidgets('Mobile (390x844): Empilha verticalmente sem overflow e respeita alvos de toque >=44px',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final gateway = MockDetalheSolicitacaoGateway(dados: _criarDadosExemplo());

      await tester.pumpWidget(
        MaterialApp(
          home: DetalheSolicitacaoScreen(
            fichaId: 'ficha-123',
            papel: PapelContextualAnalise.pastorLocal,
            gateway: gateway,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('cardResumoVoluntario')), findsOneWidget);
      expect(find.byKey(const Key('cardSecaoEquipes')), findsOneWidget);
      expect(find.byKey(const Key('cardSecaoDocumentos')), findsOneWidget);
      expect(find.byKey(const Key('cardPainelDecisao')), findsOneWidget);

      final btnAprovar = find.byKey(const Key('btnAprovarPastorDetalhe'));
      final sizeAprovar = tester.getSize(btnAprovar);
      expect(sizeAprovar.height, greaterThanOrEqualTo(AppGeometry.minTouchTarget));

      final btnRecusar = find.byKey(const Key('btnRecusarPastorDetalhe'));
      final sizeRecusar = tester.getSize(btnRecusar);
      expect(sizeRecusar.height, greaterThanOrEqualTo(AppGeometry.minTouchTarget));
    });

    testWidgets('Decisão Pastor Local: Aprovar abre modal de confirmação e conclui',
        (tester) async {
      final gateway = MockDetalheSolicitacaoGateway(dados: _criarDadosExemplo());
      bool callbackChamado = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DetalheSolicitacaoScreen(
            fichaId: 'ficha-123',
            papel: PapelContextualAnalise.pastorLocal,
            gateway: gateway,
            onDecisaoConcluida: (res) {
              callbackChamado = true;
              expect(res.decisao, 'APROVADO');
              expect(res.sucesso, isTrue);
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btnAprovarPastorDetalhe')));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar Aprovação Pastoral'), findsOneWidget);
      expect(find.byKey(const Key('btnConfirmarModalAprovacaoPastor')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btnConfirmarModalAprovacaoPastor')));
      await tester.pumpAndSettle();

      expect(gateway.ultimaEntradaPastor?.decisao, 'APROVADO');
      expect(gateway.ultimaEntradaPastor?.expectedVersion, 2);
      expect(callbackChamado, isTrue);
    });

    testWidgets('Decisão Pastor Local: Recusar exige justificativa e exibe aviso canônico neutro',
        (tester) async {
      final gateway = MockDetalheSolicitacaoGateway(dados: _criarDadosExemplo());

      await tester.pumpWidget(
        MaterialApp(
          home: DetalheSolicitacaoScreen(
            fichaId: 'ficha-123',
            papel: PapelContextualAnalise.pastorLocal,
            gateway: gateway,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btnRecusarPastorDetalhe')));
      await tester.pumpAndSettle();

      expect(find.text('Registrar Decisão Desfavorável'), findsOneWidget);
      expect(
        find.textContaining('Procure o Pastor da igreja local para mais informações'),
        findsOneWidget,
      );

      // Tenta submeter vazio -> validação de erro
      await tester.tap(find.byKey(const Key('btnConfirmarModalJustificativa')));
      await tester.pumpAndSettle();

      expect(
        find.text('A justificativa é obrigatória para decisões desfavoráveis.'),
        findsOneWidget,
      );
      expect(gateway.ultimaEntradaPastor, isNull);

      // Preenche justificativa válida
      await tester.enterText(
        find.byKey(const Key('inputJustificativaDecisao')),
        'Necessidade de tempo adicional de membresia.',
      );
      await tester.tap(find.byKey(const Key('btnConfirmarModalJustificativa')));
      await tester.pumpAndSettle();

      expect(gateway.ultimaEntradaPastor?.decisao, 'DESFAVORAVEL');
      expect(
        gateway.ultimaEntradaPastor?.justificativa,
        'Necessidade de tempo adicional de membresia.',
      );
    });

    testWidgets('Responsável de Equipe: Decide estritamente a equipe do escopo sem afetar demais',
        (tester) async {
      final gateway = MockDetalheSolicitacaoGateway(dados: _criarDadosExemplo(multiEquipe: true));

      await tester.pumpWidget(
        MaterialApp(
          home: DetalheSolicitacaoScreen(
            fichaId: 'ficha-123',
            papel: PapelContextualAnalise.responsavelEquipe,
            equipeEscopoId: 'eq-louvor',
            gateway: gateway,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Mostra indicação clara da equipe do responsável
      expect(find.textContaining('Deliberação para: Grupo de Louvor'), findsOneWidget);
      expect(find.textContaining('Outra equipe independente (somente leitura'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btnAprovarResponsavelDetalhe')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btnConfirmarModalAprovacaoResp')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btnConfirmarModalAprovacaoResp')));
      await tester.pumpAndSettle();

      expect(gateway.ultimaEntradaResponsavel?.participacaoId, 'part-1');
      expect(gateway.ultimaEntradaResponsavel?.decisao, 'APROVADO');
    });

    testWidgets('Coordenador Geral: Homologação bloqueada sem confirmação da Reunião de Pastores',
        (tester) async {
      final gateway = MockDetalheSolicitacaoGateway(dados: _criarDadosExemplo());

      await tester.pumpWidget(
        MaterialApp(
          home: DetalheSolicitacaoScreen(
            fichaId: 'ficha-123',
            papel: PapelContextualAnalise.coordenadorGeral,
            gateway: gateway,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Botão desabilitado enquanto checkbox não estiver marcado
      final btnHomologar = tester.widget<ElevatedButton>(
        find.byKey(const Key('btnHomologarCoordenadorDetalhe')),
      );
      expect(btnHomologar.onPressed, isNull);

      // Marca o checkbox
      await tester.tap(find.byKey(const Key('checkConfirmacaoReuniaoPastores')));
      await tester.pumpAndSettle();

      final btnHomologarHabilitado = tester.widget<ElevatedButton>(
        find.byKey(const Key('btnHomologarCoordenadorDetalhe')),
      );
      expect(btnHomologarHabilitado.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('btnHomologarCoordenadorDetalhe')));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar Homologação e Ativação'), findsOneWidget);
      await tester.tap(find.byKey(const Key('btnConfirmarModalHomologacaoCoord')));
      await tester.pumpAndSettle();

      expect(gateway.ultimaEntradaCoordenador?.decisao, 'APROVADO');
      expect(gateway.ultimaEntradaCoordenador?.confirmacaoReuniaoPastores, isTrue);
    });

    testWidgets('Tratamento de Conflito Concorrente (ABORTED): Exibe aviso e botão de recarga',
        (tester) async {
      final gateway = MockDetalheSolicitacaoGateway(
        dados: _criarDadosExemplo(),
        lancarConflitoConcorrencia: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DetalheSolicitacaoScreen(
            fichaId: 'ficha-123',
            papel: PapelContextualAnalise.pastorLocal,
            gateway: gateway,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btnAprovarPastorDetalhe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btnConfirmarModalAprovacaoPastor')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('alertaConcorrencia')), findsOneWidget);
      expect(find.text('Conflito Concorrente Detectado'), findsOneWidget);

      final chamadasIniciais = gateway.chamadasObterDetalhe;
      await tester.tap(find.byKey(const Key('btnRecarregarAposConflito')));
      await tester.pumpAndSettle();

      expect(gateway.chamadasObterDetalhe, chamadasIniciais + 1);
    });

    testWidgets('Exibição Condicional de Documentos: PDF visível apenas se houver participação elegível',
        (tester) async {
      // 1. Sem elegibilidade -> PDF indisponível
      final gatewaySemElegivel = MockDetalheSolicitacaoGateway(
        dados: _criarDadosExemplo(elegivelPdf: false),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DetalheSolicitacaoScreen(
            fichaId: 'ficha-123',
            papel: PapelContextualAnalise.pastorLocal,
            gateway: gatewaySemElegivel,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btnVisualizarDoc_PDF_APROVACAO')), findsNothing);
      expect(find.text('Indisponível'), findsOneWidget);

      // 2. Com elegibilidade -> PDF disponível
      final gatewayComElegivel = MockDetalheSolicitacaoGateway(
        dados: _criarDadosExemplo(elegivelPdf: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DetalheSolicitacaoScreen(
            fichaId: 'ficha-123',
            papel: PapelContextualAnalise.pastorLocal,
            gateway: gatewayComElegivel,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btnVisualizarDoc_PDF_APROVACAO')), findsOneWidget);
    });
  });

  group('Story 8.7 — Integração das Filas com Ação Analisar', () {
    testWidgets('FilaPastorScreen: Botão Analisar abre DetalheSolicitacaoScreen e remove item ao voltar',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockPastorGateway = MockPastorLocalGatewaySimples(
        pendencias: [
          const ItemFilaPastor(
            id: 'item-1',
            fichaId: 'ficha-123',
            voluntarioUid: 'u-1',
            voluntarioNome: 'Maria Joana',
            igrejaId: 'ig-1',
            estado: 'AGUARDANDO_PASTOR_LOCAL',
            proximaAcao: 'Aguardando avaliação pastoral',
            ano: 2026,
            versao: 1,
            enviadoEm: '2026-10-09',
            equipes: [EquipeFilaPastor(equipeId: 'eq-1', nomeEquipe: 'Música')],
          ),
        ],
      );

      final detalheGateway = MockDetalheSolicitacaoGateway(
        dados: _criarDadosExemplo(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FilaPastorScreen(
            gateway: mockPastorGateway,
            detalheGateway: detalheGateway,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btnAnalisar_ficha-123')), findsWidgets);

      await tester.ensureVisible(find.byKey(const Key('btnAnalisar_ficha-123')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btnAnalisar_ficha-123')).first);
      await tester.pumpAndSettle();

      expect(find.byType(DetalheSolicitacaoScreen), findsOneWidget);

      // Aprova na tela de detalhe
      await tester.tap(find.byKey(const Key('btnAprovarPastorDetalhe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btnConfirmarModalAprovacaoPastor')));
      await tester.pumpAndSettle();

      // Voltou para a fila e item foi removido
      expect(find.byType(DetalheSolicitacaoScreen), findsNothing);
      expect(find.text('Nenhuma solicitação pendente'), findsOneWidget);
    });

    testWidgets(
        'FilaResponsavelEquipeScreen: Botão Analisar abre DetalheSolicitacaoScreen e remove item ao voltar',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockResponsavelGateway = MockResponsavelEquipeGatewaySimples(
        pendencias: [
          const ItemFilaResponsavelEquipe(
            participacaoId: 'part-1',
            fichaId: 'ficha-123',
            voluntarioUid: 'u-1',
            voluntarioNome: 'Maria Joana',
            igrejaId: 'ig-1',
            nomeIgreja: 'Igreja Central',
            equipeId: 'eq-louvor',
            nomeEquipe: 'Grupo de Louvor',
            estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
            proximaAcao: 'Aguardando avaliação do Responsável de Equipe',
            versao: 1,
            enviadoEm: '2026-10-09',
          ),
        ],
      );

      final detalheGateway = MockDetalheSolicitacaoGateway(
        dados: _criarDadosExemplo(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FilaResponsavelEquipeScreen(
            gateway: mockResponsavelGateway,
            detalheGateway: detalheGateway,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btnAnalisar_part-1')), findsWidgets);

      await tester.ensureVisible(find.byKey(const Key('btnAnalisar_part-1')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btnAnalisar_part-1')).first);
      await tester.pumpAndSettle();

      expect(find.byType(DetalheSolicitacaoScreen), findsOneWidget);

      // Aprova a participação da equipe sob sua responsabilidade
      await tester.ensureVisible(find.byKey(const Key('btnAprovarResponsavelDetalhe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btnAprovarResponsavelDetalhe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btnConfirmarModalAprovacaoResp')));
      await tester.pumpAndSettle();

      // Voltou para a fila do responsável e pendência part-1 foi removida
      expect(find.byType(DetalheSolicitacaoScreen), findsNothing);
      expect(find.text('Nenhuma pendência na fila!'), findsOneWidget);
    });

    testWidgets(
        'FilaCoordenadorScreen: Botão Analisar abre DetalheSolicitacaoScreen e remove item ao voltar',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockCoordenadorGateway = MockCoordenadorGatewaySimples(
        itens: [
          const ItemFilaCoordenador(
            fichaId: 'ficha-123',
            voluntarioUid: 'u-1',
            voluntarioNome: 'Maria Joana',
            profissao: 'Engenheira',
            cpfMascarado: '***.123.456-**',
            igrejaId: 'ig-1',
            nomeIgreja: 'Igreja Central',
            versaoFicha: 1,
            enviadoEm: '2026-10-09',
            participacoes: [
              ParticipacaoItemCoordenador(
                participacaoId: 'part-1',
                equipeId: 'eq-1',
                nomeEquipe: 'Música',
                estado: 'APROVADO_RESPONSAVEL',
                proximaAcao: 'Aguardando homologação da coordenação geral',
                elegivelAtivacao: true,
              ),
            ],
          ),
        ],
      );

      final detalheGateway = MockDetalheSolicitacaoGateway(
        dados: _criarDadosExemplo(estadoFicha: 'AGUARDANDO_COORDENACAO'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FilaCoordenadorScreen(
            gateway: mockCoordenadorGateway,
            detalheGateway: detalheGateway,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btnAnalisar_ficha-123')), findsWidgets);

      await tester.ensureVisible(find.byKey(const Key('btnAnalisar_ficha-123')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btnAnalisar_ficha-123')).first);
      await tester.pumpAndSettle();

      expect(find.byType(DetalheSolicitacaoScreen), findsOneWidget);

      // Homologa na tela de detalhe com confirmação da reunião de pastores
      await tester.ensureVisible(find.byKey(const Key('checkConfirmacaoReuniaoPastores')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkConfirmacaoReuniaoPastores')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('btnHomologarCoordenadorDetalhe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btnHomologarCoordenadorDetalhe')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btnConfirmarModalHomologacaoCoord')));
      await tester.pumpAndSettle();

      // Voltou para a fila do coordenador e item foi removido
      expect(find.byType(DetalheSolicitacaoScreen), findsNothing);
      expect(find.text('Nenhuma solicitação pendente!'), findsOneWidget);
    });
  });
}

class MockPastorLocalGatewaySimples implements PastorLocalGateway {
  MockPastorLocalGatewaySimples({required this.pendencias});

  final List<ItemFilaPastor> pendencias;

  @override
  Future<ResultadoFilaPastor> obterFila() async {
    return ResultadoFilaPastor(
      pendencias: pendencias,
      igrejas: [const IgrejaEscopoPastor(id: 'ig-1', nome: 'Igreja Central')],
    );
  }

  @override
  Future<ResultadoDecisaoPastor> decidirFicha(EntradaDecisaoPastor entrada) async {
    return const ResultadoDecisaoPastor(
      sucesso: true,
      repetido: false,
      decisao: 'APROVADO',
      estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
      versao: 2,
      proximaAcao: 'Aguardando avaliação dos responsáveis',
      decididoEm: '2026-10-09T10:00:00Z',
    );
  }

  @override
  Future<ResultadoDecisaoPastor> decidirCicloAnual(EntradaDecisaoPastor entrada) async {
    return const ResultadoDecisaoPastor(
      sucesso: true,
      repetido: false,
      decisao: 'APROVADO',
      estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
      versao: 2,
      proximaAcao: 'Aguardando avaliação dos responsáveis',
      decididoEm: '2026-10-09T10:00:00Z',
    );
  }
}

class MockResponsavelEquipeGatewaySimples implements ResponsavelEquipeGateway {
  MockResponsavelEquipeGatewaySimples({required this.pendencias});

  final List<ItemFilaResponsavelEquipe> pendencias;

  @override
  Future<ResultadoFilaResponsavelEquipe> obterFila() async {
    return ResultadoFilaResponsavelEquipe(
      pendencias: pendencias,
      equipes: [const EquipeEscopoResponsavel(id: 'eq-louvor', nome: 'Grupo de Louvor')],
    );
  }

  @override
  Future<ResultadoDecisaoResponsavelEquipe> decidirParticipacao(
      EntradaDecidirParticipacaoResponsavel entrada) async {
    return const ResultadoDecisaoResponsavelEquipe(
      sucesso: true,
      repetido: false,
      participacaoId: 'part-1',
      decisao: 'APROVADO',
      estado: 'APROVADO_RESPONSAVEL',
      versao: 2,
      proximaAcao: 'Aguardando homologação da coordenação geral',
      decididoEm: '2026-10-09T10:00:00Z',
    );
  }

  @override
  Future<ResultadoDecisaoResponsavelEquipe> decidirCicloAnual(
      EntradaDecidirParticipacaoResponsavel entrada) async {
    return const ResultadoDecisaoResponsavelEquipe(
      sucesso: true,
      repetido: false,
      participacaoId: 'part-1',
      decisao: 'APROVADO',
      estado: 'APROVADO_RESPONSAVEL',
      versao: 2,
      proximaAcao: 'Aguardando homologação da coordenação geral',
      decididoEm: '2026-10-09T10:00:00Z',
    );
  }
}

class MockCoordenadorGatewaySimples implements CoordenadorGateway {
  MockCoordenadorGatewaySimples({required this.itens});

  final List<ItemFilaCoordenador> itens;

  @override
  Future<List<ItemFilaCoordenador>> obterFila() async {
    return itens;
  }

  @override
  Future<ResultadoDecisaoCoordenador> decidir({
    required String commandId,
    String? correlationId,
    required String fichaId,
    required String decisao,
    required bool confirmouReuniaoPastores,
    String? observacao,
    required int expectedVersion,
  }) async {
    return const ResultadoDecisaoCoordenador(
      sucesso: true,
      repetido: false,
      fichaId: 'ficha-123',
      decisao: 'APROVADO',
      estadoFicha: 'ATIVA',
      versaoFicha: 2,
      participacoesAtivadas: ['part-1'],
      participacoesRejeitadas: [],
      decididoEm: '2026-10-09T10:00:00Z',
    );
  }

  @override
  Future<ResultadoDecisaoCoordenador> concluirCicloAnual({
    required String commandId,
    String? correlationId,
    required String cicloId,
    required String decisao,
    required bool confirmouReuniaoPastores,
    String? observacao,
    String? justificativa,
    int? expectedVersion,
  }) async {
    return const ResultadoDecisaoCoordenador(
      sucesso: true,
      repetido: false,
      fichaId: 'ficha-123',
      decisao: 'APROVADO',
      estadoFicha: 'ATIVA',
      versaoFicha: 2,
      participacoesAtivadas: ['part-1'],
      participacoesRejeitadas: [],
      decididoEm: '2026-10-09T10:00:00Z',
    );
  }
}
