import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eqp_maanaim/features/termo/pdf_termo_service.dart';
import 'package:eqp_maanaim/features/voluntario/consulta_ficha_screen.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/historico_service.dart';
import 'package:eqp_maanaim/features/voluntario/minha_ficha_screen.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';

import 'fakes.dart';

class TesteFichaMockGateway implements FichaGateway {
  TesteFichaMockGateway({this.ficha});

  FichaModel? ficha;

  @override
  Future<ObterFichaResposta> obterMinhaFicha() async {
    if (ficha == null) return const ObterFichaResposta(existe: false);
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
      proximaAcao: ficha?.proximaAcao ?? 'Avaliação pelo Pastor Local',
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

class TesteParticipacaoMockGateway implements ParticipacaoGateway {
  TesteParticipacaoMockGateway(this.participacoes);

  final List<ParticipacaoModel> participacoes;

  @override
  Future<List<ParticipacaoModel>> obterMinhasParticipacoes() async {
    return List.unmodifiable(participacoes);
  }

  @override
  Future<List<ParticipacaoModel>> salvarParticipacoesRascunho(
    List<String> equipeIds, {
    String? commandId,
  }) async {
    return List.unmodifiable(participacoes);
  }

  @override
  Future<ParticipacaoModel> solicitarEquipeAdicional(
    String equipeId, {
    String? commandId,
  }) async {
    final nova = ParticipacaoModel(
      id: 'mock-$equipeId',
      fichaId: 'mock-ficha',
      equipeId: equipeId,
      nomeEquipe: equipeId,
      estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
      ciclo: 'INICIAL',
      proximaAcao: 'Aguardando avaliação',
    );
    participacoes.add(nova);
    return nova;
  }

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
  }) async {
    final nova = ParticipacaoModel(
      id: 'mock-reativacao-$equipeId',
      fichaId: 'mock-ficha',
      equipeId: equipeId,
      nomeEquipe: equipeId,
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      ciclo: 'REATIVACAO',
      proximaAcao: 'Aguardando avaliação',
    );
    participacoes.add(nova);
    return nova;
  }

  @override
  Future<List<Map<String, dynamic>>> manifestarRenovacao({
    required List<ManifestacaoEquipeInput> manifestacoes,
    String? commandId,
  }) async =>
      const [];
}

class TesteHistoricoServiceMock extends HistoricoService {
  TesteHistoricoServiceMock({
    required this.fichaRetorno,
    required this.eventosRetorno,
  });

  final ResultadoConsultaFichaModel fichaRetorno;
  final List<EventoLinhaDoTempoModel> eventosRetorno;

  @override
  Future<ResultadoConsultaFichaModel> consultarFichaAutorizada({String? fichaId}) async {
    return fichaRetorno;
  }

  @override
  Future<List<EventoLinhaDoTempoModel>> consultarLinhaDoTempoAutorizada({
    String? fichaId,
    String? participacaoId,
    int? limite,
  }) async {
    return eventosRetorno;
  }
}

void main() {
  group('Story 6.3 - PdfTermoService (Gateway)', () {
    test('MemoriaPdfTermoGateway gera e obtém URL de download assinada', () async {
      final gateway = MemoriaPdfTermoGateway(
        urlDownloadRetorno: 'https://storage.googleapis.com/signed-url-test',
      );

      final resultado = await gateway.gerarPdfParticipacao(
        fichaId: 'ficha-123',
        participacaoId: 'part-456',
        commandId: 'cmd-001',
      );

      expect(resultado.caminhoStorage, 'pdfs/ficha-123/part-456.pdf');
      expect(resultado.urlDownload, 'https://storage.googleapis.com/signed-url-test');
      expect(gateway.geracoesRegistradas, contains('ficha-123/part-456'));

      final download = await gateway.obterUrlDownloadPdf(
        fichaId: 'ficha-123',
        participacaoId: 'part-456',
      );
      expect(download.urlDownload, 'https://storage.googleapis.com/signed-url-test');
    });

    test('trata erros simulados no gateway de PDF', () async {
      final gateway = MemoriaPdfTermoGateway(
        lancarErroAoGerar: 'Acesso negado para gerar documento.',
      );

      expect(
        () => gateway.gerarPdfParticipacao(
          fichaId: 'f1',
          participacaoId: 'p1',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Story 6.3 - MinhaFichaScreen (Download de PDF do Termo)', () {
    testWidgets('exibe botão de download de PDF para participação ativa (aprovada)', (tester) async {
      final fichaAtiva = FichaModel(
        id: 'user-123',
        nomeCompleto: 'Voluntário Ativo Teste',
        profissao: 'Engenheiro',
        cpf: '123.456.789-00',
        igrejaId: 'igreja-1',
        estado: 'ATIVA',
        versao: 2,
        atualizadoEm: '2026-10-02T10:00:00.000Z',
      );

      const participacaoAtiva = ParticipacaoModel(
        id: 'part-ativa-1',
        fichaId: 'user-123',
        equipeId: 'eq-musica',
        nomeEquipe: 'Música e Louvor',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
        versao: 2,
      );

      final fichaGateway = TesteFichaMockGateway(ficha: fichaAtiva);
      final catalogoGateway = CatalogoFake();
      final participacaoGateway = TesteParticipacaoMockGateway([participacaoAtiva]);
      final pdfGateway = MemoriaPdfTermoGateway();

      await tester.pumpWidget(
        MaterialApp(
          home: MinhaFichaScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final btnPdf = find.byKey(const Key('btn_baixar_termo_pdf_part-ativa-1'));
      await tester.ensureVisible(btnPdf);
      expect(btnPdf, findsOneWidget);
      expect(find.text('Baixar Termo em PDF'), findsOneWidget);

      // Validação de acessibilidade WCAG 2.2 AA: touch target >= 44px
      final btnSize = tester.getSize(btnPdf);
      expect(btnSize.height, greaterThanOrEqualTo(44.0));

      // Dispara download do PDF
      await tester.tap(btnPdf);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('pronto para download'), findsOneWidget);
    });

    testWidgets('NÃO exibe botão de PDF para participação em rascunho ou pendente', (tester) async {
      final fichaRascunho = FichaModel(
        id: 'user-456',
        nomeCompleto: 'Voluntário Rascunho',
        profissao: 'Estudante',
        cpf: '123.456.789-00',
        igrejaId: 'igreja-1',
        estado: 'RASCUNHO',
        versao: 1,
        atualizadoEm: '2026-10-01T10:00:00.000Z',
      );

      const participacaoPendente = ParticipacaoModel(
        id: 'part-pendente-1',
        fichaId: 'user-456',
        equipeId: 'eq-apoio',
        nomeEquipe: 'Apoio Geral',
        estado: 'AGUARDANDO_PASTOR_LOCAL',
        ciclo: 'INICIAL',
        proximaAcao: 'Aguardando avaliação do Pastor Local',
        versao: 1,
      );

      final fichaGateway = TesteFichaMockGateway(ficha: fichaRascunho);
      final catalogoGateway = CatalogoFake();
      final participacaoGateway = TesteParticipacaoMockGateway([participacaoPendente]);
      final pdfGateway = MemoriaPdfTermoGateway();

      await tester.pumpWidget(
        MaterialApp(
          home: MinhaFichaScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final btnPdf = find.byKey(const Key('btn_baixar_termo_pdf_part-pendente-1'));
      expect(btnPdf, findsNothing);
    });

    testWidgets('exibe tratamento de erro com retry ao falhar download do PDF', (tester) async {
      final fichaAtiva = FichaModel(
        id: 'user-789',
        nomeCompleto: 'Voluntário Com Erro',
        profissao: 'Designer',
        cpf: '123.456.789-00',
        igrejaId: 'igreja-1',
        estado: 'ATIVA',
        versao: 2,
        atualizadoEm: '2026-10-02T10:00:00.000Z',
      );

      const participacaoAtiva = ParticipacaoModel(
        id: 'part-erro-1',
        fichaId: 'user-789',
        equipeId: 'eq-som',
        nomeEquipe: 'Equipe Som',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
        versao: 2,
      );

      final fichaGateway = TesteFichaMockGateway(ficha: fichaAtiva);
      final catalogoGateway = CatalogoFake();
      final participacaoGateway = TesteParticipacaoMockGateway([participacaoAtiva]);
      final pdfGateway = MemoriaPdfTermoGateway(
        lancarErroAoObterDownload: 'Falha temporária ao gerar documento.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MinhaFichaScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final btnPdf = find.byKey(const Key('btn_baixar_termo_pdf_part-erro-1'));
      await tester.ensureVisible(btnPdf);
      await tester.tap(btnPdf);
      await tester.pumpAndSettle();

      expect(find.text('Falha temporária ao gerar documento.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });
  });

  group('Story 6.3 - ConsultaFichaAutorizadaScreen (Download de PDF por Pastores/Gestores)', () {
    testWidgets('exibe botão de download de PDF para participações ativas na consulta autorizada', (tester) async {
      final historicoMock = TesteHistoricoServiceMock(
        fichaRetorno: ResultadoConsultaFichaModel(
          existe: true,
          papel: 'COORDENADOR_GERAL',
          equipesFiltradas: false,
          ficha: const FichaConsultaModel(
            id: 'ficha-voluntario-1',
            ownerUid: 'voluntario-1',
            nomeCompleto: 'Voluntário Consultado',
            profissao: 'Médico',
            cpfCompleto: '111.222.333-44',
            igrejaId: 'igreja-1',
            nomeIgreja: 'Igreja Central',
            estado: 'ATIVA',
            versao: 2,
          ),
          participacoes: const [
            ParticipacaoConsultaModel(
              id: 'part-consulta-1',
              fichaId: 'ficha-voluntario-1',
              equipeId: 'equipe-saude',
              nomeEquipe: 'Equipe de Saúde',
              estado: 'ATIVA',
              ciclo: 'INICIAL',
              proximaAcao: 'Voluntariado ativo',
            ),
          ],
        ),
        eventosRetorno: const [],
      );

      final pdfGateway = MemoriaPdfTermoGateway();

      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ConsultaFichaAutorizadaScreen(
            fichaId: 'ficha-voluntario-1',
            historicoService: historicoMock,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final btnPdf = find.byKey(const Key('btn_baixar_pdf_consulta_part-consulta-1'));
      expect(btnPdf, findsOneWidget);
      expect(find.text('Baixar Termo em PDF'), findsOneWidget);

      final btnSize = tester.getSize(btnPdf);
      expect(btnSize.height, greaterThanOrEqualTo(44.0));

      await tester.tap(btnPdf);
      await tester.pumpAndSettle();

      expect(find.textContaining('pronto para download'), findsOneWidget);
    });
  });
}
