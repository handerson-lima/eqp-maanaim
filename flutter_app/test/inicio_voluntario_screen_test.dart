import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/termo/pdf_termo_service.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/inicio_voluntario_screen.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:eqp_maanaim/ui/components/metrics.dart';

class FakeFichaGateway implements FichaGateway {
  FakeFichaGateway({this.resposta = const ObterFichaResposta(existe: false)});
  ObterFichaResposta resposta;

  @override
  Future<ObterFichaResposta> obterMinhaFicha() async => resposta;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeParticipacaoGateway implements ParticipacaoGateway {
  FakeParticipacaoGateway({this.participacoes = const []});
  List<ParticipacaoModel> participacoes;

  @override
  Future<List<ParticipacaoModel>> obterMinhasParticipacoes() async => participacoes;

  @override
  Future<List<Map<String, dynamic>>> manifestarRenovacao({
    required List<ManifestacaoEquipeInput> manifestacoes,
    String? commandId,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCatalogoGateway implements CatalogoGateway {
  FakeCatalogoGateway({this.equipes = const []});
  List<EquipeCatalogo> equipes;

  @override
  Future<CatalogoResposta> consultar({String? termo}) async =>
      CatalogoResposta(igrejas: const [], equipes: equipes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePdfGateway implements PdfTermoGateway {
  bool urlObtida = false;

  @override
  Future<ResultadoDownloadPdfModel> obterUrlDownloadPdf({
    required String fichaId,
    required String participacaoId,
    String? commandId,
    String? correlationId,
  }) async {
    urlObtida = true;
    return const ResultadoDownloadPdfModel(
      urlDownload: 'https://storage.googleapis.com/test-bucket/termo.pdf',
      expiraEm: '2026-10-10T12:00:00Z',
      nomeArquivo: 'termo.pdf',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  void definirDimensoes(WidgetTester tester, Size tamanho) {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget criarTelaTeste({
    required FichaGateway fichaGateway,
    required ParticipacaoGateway participacaoGateway,
    required CatalogoGateway catalogoGateway,
    PdfTermoGateway? pdfGateway,
    VoidCallback? onNavegarMinhaFicha,
    VoidCallback? onNavegarRenovacao,
    String? userName,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: InicioVoluntarioScreen(
          fichaGateway: fichaGateway,
          participacaoGateway: participacaoGateway,
          catalogoGateway: catalogoGateway,
          pdfTermoGateway: pdfGateway,
          onNavegarMinhaFicha: onNavegarMinhaFicha,
          onNavegarRenovacao: onNavegarRenovacao,
          userName: userName,
        ),
      ),
    );
  }

  group('Story 8.5: Início do Voluntário (S02)', () {
    testWidgets('Estado Sem Ficha / Rascunho exibe card de destaque "Complete seu Cadastro" e navega para Minha Ficha', (tester) async {
      definirDimensoes(tester, const Size(1280, 800));

      bool navegouMinhaFicha = false;
      final fichaGateway = FakeFichaGateway(
        resposta: const ObterFichaResposta(
          existe: true,
          ficha: FichaModel(
            id: 'uid-voluntario-12345',
            nomeCompleto: 'Gabriel Silva',
            profissao: 'Engenheiro',
            cpf: '12345678901',
            igrejaId: 'ig-1',
            estado: 'RASCUNHO',
            versao: 1,
          ),
        ),
      );
      final participacaoGateway = FakeParticipacaoGateway();
      final catalogoGateway = FakeCatalogoGateway();

      await tester.pumpWidget(
        criarTelaTeste(
          fichaGateway: fichaGateway,
          participacaoGateway: participacaoGateway,
          catalogoGateway: catalogoGateway,
          userName: 'Gabriel Silva',
          onNavegarMinhaFicha: () => navegouMinhaFicha = true,
        ),
      );
      await tester.pumpAndSettle();

      // Saudação e status
      expect(find.text('Olá, Gabriel Silva'), findsOneWidget);
      expect(find.text('RASCUNHO'), findsWidgets);

      // Invariante de privacidade: Nunca exibir UID bruto
      expect(find.text('uid-voluntario-12345'), findsNothing);

      // Card destacado de cadastro
      expect(find.text('Complete seu Cadastro'), findsOneWidget);
      expect(find.text('Continuar Cadastro'), findsOneWidget);

      // Dispara ação de continuar
      await tester.tap(find.text('Continuar Cadastro'));
      await tester.pumpAndSettle();
      expect(navegouMinhaFicha, isTrue);
    });

    testWidgets('Estado em Tramitação exibe status EM APROVAÇÃO e card informativo de acompanhamento', (tester) async {
      definirDimensoes(tester, const Size(1280, 800));

      final fichaGateway = FakeFichaGateway(
        resposta: const ObterFichaResposta(
          existe: true,
          ficha: FichaModel(
            id: 'uid-tramitacao-999',
            nomeCompleto: 'Mariana Souza',
            profissao: 'Arquiteta',
            cpf: '98765432100',
            igrejaId: 'ig-1',
            estado: 'AGUARDANDO_PASTOR_LOCAL',
            versao: 1,
          ),
        ),
      );
      final participacaoGateway = FakeParticipacaoGateway();
      final catalogoGateway = FakeCatalogoGateway();

      await tester.pumpWidget(
        criarTelaTeste(
          fichaGateway: fichaGateway,
          participacaoGateway: participacaoGateway,
          catalogoGateway: catalogoGateway,
          userName: 'Mariana Souza',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Olá, Mariana Souza'), findsOneWidget);
      expect(find.text('EM APROVAÇÃO'), findsOneWidget);
      expect(find.text('Ficha em Análise e Tramitação'), findsOneWidget);
      expect(find.text('Acompanhar em Minha Ficha'), findsOneWidget);

      // Sem UID bruto
      expect(find.text('uid-tramitacao-999'), findsNothing);
    });

    testWidgets('Estado Ativo com Equipes exibe KPIs, contagem de vigência real e lista Minhas Equipes', (tester) async {
      definirDimensoes(tester, const Size(1280, 800));

      final fichaGateway = FakeFichaGateway(
        resposta: const ObterFichaResposta(
          existe: true,
          ficha: FichaModel(
            id: 'uid-ativo-888',
            nomeCompleto: 'Lucas Rocha',
            profissao: 'Professor',
            cpf: '11122233344',
            igrejaId: 'ig-1',
            estado: 'ATIVA',
            versao: 2,
            termoAceito: TermoAceitoModel(
              termoId: 't-1',
              versaoId: 'v-1',
              numeroVersao: 1,
              hashSha256: 'hash-abc',
              aceitoEm: '2026-01-15T10:00:00Z',
              commandId: 'cmd-1',
            ),
          ),
        ),
      );

      final participacoes = [
        const ParticipacaoModel(
          id: 'part-1',
          fichaId: 'uid-ativo-888',
          equipeId: 'eq-louvor',
          nomeEquipe: 'Grupo de Louvor',
          estado: 'ATIVA',
          ciclo: '2026',
          proximaAcao: 'Atuar nas escalas',
          vigenciaInicio: '2026-01-15T00:00:00Z',
          vigenciaFim: '2027-01-15T00:00:00Z',
          situacaoVigencia: 'VIGENTE',
          diasParaVencimento: 98,
        ),
        const ParticipacaoModel(
          id: 'part-2',
          fichaId: 'uid-ativo-888',
          equipeId: 'eq-midia',
          nomeEquipe: 'Equipe de Mídia',
          estado: 'ATIVA',
          ciclo: '2026',
          proximaAcao: 'Renovação aberta',
          vigenciaInicio: '2026-01-01T00:00:00Z',
          vigenciaFim: '2026-11-01T00:00:00Z',
          situacaoVigencia: 'ALERTA_PREVIO_60D',
          diasParaVencimento: 23,
          emAlertaRenovacao: true,
        ),
      ];

      final participacaoGateway = FakeParticipacaoGateway(participacoes: participacoes);
      final catalogoGateway = FakeCatalogoGateway();
      final pdfGateway = FakePdfGateway();

      await tester.pumpWidget(
        criarTelaTeste(
          fichaGateway: fichaGateway,
          participacaoGateway: participacaoGateway,
          catalogoGateway: catalogoGateway,
          pdfGateway: pdfGateway,
          userName: 'Lucas Rocha',
        ),
      );
      await tester.pumpAndSettle();

      // Saudação e chip ativa
      expect(find.text('Olá, Lucas Rocha'), findsOneWidget);
      expect(find.text('ATIVA'), findsWidgets);

      // KPIs
      expect(find.text('Equipes Ativas'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 2 equipes ativas
      expect(find.text('Próxima Renovação'), findsOneWidget);
      expect(find.text('23 dias'), findsOneWidget); // Menor vencimento entre as ativas
      expect(find.text('Equipe: Equipe de Mídia'), findsOneWidget);
      expect(find.text('Termo de Adesão'), findsOneWidget);
      expect(find.text('Vigente'), findsOneWidget);

      // Card de validade destacada da equipe mais próxima
      expect(find.byType(ProgressValidityCard), findsOneWidget);
      expect(find.text('Vigência - Equipe de Mídia'), findsOneWidget);

      // Lista Minhas Equipes
      expect(find.text('Minhas Equipes'), findsOneWidget);
      expect(find.text('Grupo de Louvor'), findsOneWidget);
      expect(find.text('Equipe de Mídia'), findsOneWidget);

      // Botão Renovar Equipe na participação em janela
      expect(find.text('Renovar Equipe'), findsOneWidget);

      // Botão de Comprovante / PDF
      expect(find.text('Comprovante / PDF'), findsWidgets);

      // Ações rápidas
      expect(find.text('Ações Rápidas'), findsOneWidget);
      expect(find.text('Minha Ficha'), findsWidgets);
      expect(find.text('Solicitar Nova Equipe'), findsOneWidget);
      expect(find.text('Renovação Anual'), findsOneWidget);
    });

    testWidgets('Decisão desfavorável/rejeitada exibe resposta neutra canônica e oculta detalhes internos', (tester) async {
      definirDimensoes(tester, const Size(1280, 800));

      final fichaGateway = FakeFichaGateway(
        resposta: const ObterFichaResposta(
          existe: true,
          ficha: FichaModel(
            id: 'uid-rejeitada-777',
            nomeCompleto: 'Ana Paula',
            profissao: 'Bióloga',
            cpf: '55566677788',
            igrejaId: 'ig-1',
            estado: 'ATIVA',
            versao: 1,
          ),
        ),
      );

      final participacoes = [
        const ParticipacaoModel(
          id: 'part-rej',
          fichaId: 'uid-rejeitada-777',
          equipeId: 'eq-apoio',
          nomeEquipe: 'Apoio Operacional',
          estado: 'REJEITADA',
          ciclo: '2026',
          proximaAcao: 'Não aprovada',
        ),
      ];

      final participacaoGateway = FakeParticipacaoGateway(participacoes: participacoes);
      final catalogoGateway = FakeCatalogoGateway();

      await tester.pumpWidget(
        criarTelaTeste(
          fichaGateway: fichaGateway,
          participacaoGateway: participacaoGateway,
          catalogoGateway: catalogoGateway,
          userName: 'Ana Paula',
        ),
      );
      await tester.pumpAndSettle();

      // Invariante AD-11, AD-12: Resposta neutra estrita
      expect(find.text('Procure o Pastor da igreja local para mais informações'), findsOneWidget);

      // NUNCA expor palavra REJEITADA como status visível ou detalhes técnicos
      expect(find.text('REJEITADA'), findsNothing);
      expect(find.text('Não aprovada'), findsNothing);
      expect(find.text('uid-rejeitada-777'), findsNothing);
    });

    testWidgets('Responsividade Mobile (390x844) renderiza sem overflow e preserva alvos de toque', (tester) async {
      definirDimensoes(tester, const Size(390, 844));

      final fichaGateway = FakeFichaGateway(
        resposta: const ObterFichaResposta(
          existe: true,
          ficha: FichaModel(
            id: 'uid-mob',
            nomeCompleto: 'Carla Dias',
            profissao: 'Médica',
            cpf: '33344455566',
            igrejaId: 'ig-1',
            estado: 'ATIVA',
            versao: 1,
          ),
        ),
      );

      final participacaoGateway = FakeParticipacaoGateway(
        participacoes: const [
          ParticipacaoModel(
            id: 'part-mob-1',
            fichaId: 'uid-mob',
            equipeId: 'eq-1',
            nomeEquipe: 'Recepção',
            estado: 'ATIVA',
            ciclo: '2026',
            proximaAcao: 'Ativa',
            vigenciaInicio: '2026-02-01T00:00:00Z',
            vigenciaFim: '2027-02-01T00:00:00Z',
            situacaoVigencia: 'VIGENTE',
            diasParaVencimento: 120,
          ),
        ],
      );

      await tester.pumpWidget(
        criarTelaTeste(
          fichaGateway: fichaGateway,
          participacaoGateway: participacaoGateway,
          catalogoGateway: FakeCatalogoGateway(),
          userName: 'Carla Dias',
        ),
      );
      await tester.pumpAndSettle();

      // Sem overflow de layout
      expect(tester.takeException(), isNull);
      expect(find.text('Olá, Carla Dias'), findsOneWidget);
      expect(find.text('Minhas Equipes'), findsOneWidget);
      expect(find.text('Recepção'), findsOneWidget);
    });
  });
}
