import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:eqp_maanaim/features/termo/pdf_termo_service.dart';
import 'package:eqp_maanaim/features/voluntario/minha_ficha_screen.dart';

import 'fakes.dart';

class TesteFichaMockGateway implements FichaGateway {
  TesteFichaMockGateway({this.ficha});

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
    final novaFicha = FichaModel(
      id: ficha?.id ?? 'user-123',
      nomeCompleto: entrada.nomeCompleto,
      profissao: entrada.profissao,
      cpf: entrada.cpf,
      igrejaId: entrada.igrejaId,
      telefone: entrada.telefone,
      estado: ficha?.estado ?? 'RASCUNHO',
      versao: (ficha?.versao ?? 1) + 1,
      atualizadoEm: DateTime.now().toUtc().toIso8601String(),
    );
    ficha = novaFicha;
    return SalvarFichaResposta(
      sucesso: true,
      repetido: false,
      ficha: novaFicha,
    );
  }

  @override
  Future<EnviarFichaResposta> enviarFichaAprovacao({
    required String commandId,
    int? expectedVersion,
  }) async {
    return EnviarFichaResposta(
      sucesso: true,
      repetido: false,
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      versao: (ficha?.versao ?? 1) + 1,
      proximaAcao: 'Aguardando avaliação',
      igrejaId: ficha?.igrejaId ?? '',
      enviadoEm: DateTime.now().toUtc().toIso8601String(),
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
    return participacoes;
  }

  @override
  Future<ParticipacaoModel> solicitarEquipeAdicional(
    String equipeId, {
    String? commandId,
  }) async {
    throw UnimplementedError();
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
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> manifestarRenovacao({
    required List<ManifestacaoEquipeInput> manifestacoes,
    String? commandId,
  }) async =>
      const [];
}

void main() {
  late CatalogoFake catalogoGateway;
  late MemoriaPdfTermoGateway pdfGateway;

  setUp(() {
    catalogoGateway = CatalogoFake();
    pdfGateway = MemoriaPdfTermoGateway();
  });

  Widget criarAppTeste({
    required Widget child,
    Size tamanho = const Size(1200, 800),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: tamanho),
        child: SizedBox(
          width: tamanho.width,
          height: tamanho.height,
          child: child,
        ),
      ),
    );
  }

  group('Story 8.10 - Minha Ficha e Documentos Privados (S09)', () {
    testWidgets('1. Separação de Leitura e Edição: exibe resumo e permite alternar para edição',
        (tester) async {
      final ficha = FichaModel(
        id: 'user-123',
        nomeCompleto: 'Gabriel Silva',
        profissao: 'Analista de Sistemas',
        cpf: '123.456.789-00',
        telefone: '(27) 99999-8888',
        igrejaId: 'igreja-1',
        estado: 'ATIVA',
        versao: 1,
        atualizadoEm: '2026-10-01T10:00:00Z',
      );
      final fichaGateway = TesteFichaMockGateway(ficha: ficha);

      await tester.pumpWidget(
        criarAppTeste(
          child: MinhaFichaScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Em modo de leitura:
      expect(find.byKey(const Key('card_resumo_cadastral')), findsOneWidget);
      expect(find.byKey(const Key('btn_editar_dados')), findsOneWidget);
      expect(find.text('Gabriel Silva'), findsOneWidget);
      expect(find.text('(27) 99999-8888'), findsOneWidget);

      // O campo "Número da Ficha" não deve existir (omissão fidedigna)
      expect(find.text('Número da Ficha'), findsNothing);

      // Clicar em "Editar dados"
      await tester.tap(find.byKey(const Key('btn_editar_dados')));
      await tester.pumpAndSettle();

      // Agora deve estar no modo de formulário de edição
      expect(find.byKey(const Key('form_edicao_cadastral')), findsOneWidget);
      expect(find.byKey(const Key('btn_cancelar_edicao')), findsOneWidget);
      expect(find.byKey(const Key('btn_salvar_dados')), findsOneWidget);

      // Cancelar edição deve retornar para leitura sem alterar
      await tester.tap(find.byKey(const Key('btn_cancelar_edicao')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_resumo_cadastral')), findsOneWidget);
      expect(find.byKey(const Key('btn_editar_dados')), findsOneWidget);
      expect(find.byKey(const Key('form_edicao_cadastral')), findsNothing);
    });

    testWidgets('2. Documento Privado por Participação (AD-13): alterna PDF conforme equipe selecionada',
        (tester) async {
      final ficha = FichaModel(
        id: 'user-123',
        nomeCompleto: 'Gabriel Silva',
        profissao: 'Analista de Sistemas',
        cpf: '123.456.789-00',
        telefone: '(27) 99999-8888',
        igrejaId: 'igreja-1',
        estado: 'ATIVA',
        versao: 1,
        atualizadoEm: '2026-10-01T10:00:00Z',
      );
      final fichaGateway = TesteFichaMockGateway(ficha: ficha);

      const part1 = ParticipacaoModel(
        id: 'part-louvor',
        fichaId: 'user-123',
        equipeId: 'eq-louvor',
        nomeEquipe: 'Música e Louvor',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
        versao: 1,
      );
      const part2 = ParticipacaoModel(
        id: 'part-intercessao',
        fichaId: 'user-123',
        equipeId: 'eq-intercessao',
        nomeEquipe: 'Intercessão',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
        versao: 1,
      );
      final participacaoGateway = TesteParticipacaoMockGateway([part1, part2]);

      await tester.pumpWidget(
        criarAppTeste(
          child: MinhaFichaScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deve renderizar seletor com chips de equipe
      expect(find.byKey(const Key('chip_participacao_part-louvor')), findsOneWidget);
      expect(find.byKey(const Key('chip_participacao_part-intercessao')), findsOneWidget);

      // Por padrão, a primeira participação está selecionada
      expect(find.byKey(const Key('pdf_preview_panel')), findsOneWidget);
      expect(find.text('Documento de Voluntariado — Música e Louvor'), findsOneWidget);

      // Alternar para a segunda equipe
      await tester.tap(find.byKey(const Key('chip_participacao_part-intercessao')));
      await tester.pumpAndSettle();

      // Agora deve exibir o documento de Intercessão
      expect(find.text('Documento de Voluntariado — Intercessão'), findsOneWidget);
    });

    testWidgets('3. Indisponibilidade Contextual: participação não aprovada não forja documento',
        (tester) async {
      final ficha = FichaModel(
        id: 'user-123',
        nomeCompleto: 'Gabriel Silva',
        profissao: 'Analista de Sistemas',
        cpf: '123.456.789-00',
        telefone: '(27) 99999-8888',
        igrejaId: 'igreja-1',
        estado: 'EM_ANALISE',
        versao: 1,
        atualizadoEm: '2026-10-01T10:00:00Z',
      );
      final fichaGateway = TesteFichaMockGateway(ficha: ficha);

      const partPendente = ParticipacaoModel(
        id: 'part-pendente',
        fichaId: 'user-123',
        equipeId: 'eq-logistica',
        nomeEquipe: 'Logística',
        estado: 'AGUARDANDO_PASTOR_LOCAL',
        ciclo: 'INICIAL',
        proximaAcao: 'Aguardando parecer pastoral',
        versao: 1,
      );
      final participacaoGateway = TesteParticipacaoMockGateway([partPendente]);

      await tester.pumpWidget(
        criarAppTeste(
          child: MinhaFichaScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card contextual de indisponibilidade
      expect(find.byKey(const Key('card_documento_indisponivel')), findsOneWidget);
      expect(find.text('Documento oficial em processamento'), findsOneWidget);
      // Não exibe botão de download nem forja documento
      expect(find.byKey(const Key('btn_baixar_pdf_principal')), findsNothing);
    });

    testWidgets('4. URL Expirada: detecta link expirado e oferece renovação graciosa',
        (tester) async {
      final ficha = FichaModel(
        id: 'user-123',
        nomeCompleto: 'Gabriel Silva',
        profissao: 'Analista de Sistemas',
        cpf: '123.456.789-00',
        telefone: '(27) 99999-8888',
        igrejaId: 'igreja-1',
        estado: 'ATIVA',
        versao: 1,
        atualizadoEm: '2026-10-01T10:00:00Z',
      );
      final fichaGateway = TesteFichaMockGateway(ficha: ficha);

      const part = ParticipacaoModel(
        id: 'part-1',
        fichaId: 'user-123',
        equipeId: 'eq-louvor',
        nomeEquipe: 'Louvor',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
        versao: 1,
      );
      final participacaoGateway = TesteParticipacaoMockGateway([part]);

      // Simula URL expirada no passado
      pdfGateway.expiraEmRetorno =
          DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String();

      await tester.pumpWidget(
        criarAppTeste(
          child: MinhaFichaScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deve alertar sobre link expirado
      expect(find.byKey(const Key('card_link_expirado')), findsOneWidget);
      expect(find.byKey(const Key('btn_renovar_url_pdf')), findsOneWidget);
      expect(find.text('Link de acesso expirado'), findsOneWidget);

      // Ao clicar em renovar link
      pdfGateway.expiraEmRetorno =
          DateTime.now().toUtc().add(const Duration(minutes: 30)).toIso8601String();
      await tester.tap(find.byKey(const Key('btn_renovar_url_pdf')));
      await tester.pumpAndSettle();

      // Não deve mais constar como expirado
      expect(find.byKey(const Key('card_link_expirado')), findsNothing);
      expect(find.byKey(const Key('btn_baixar_pdf_principal')), findsOneWidget);
    });

    testWidgets('5. Responsividade: adapta layout para mobile empilhado e desktop em duas colunas',
        (tester) async {
      final ficha = FichaModel(
        id: 'user-123',
        nomeCompleto: 'Gabriel Silva',
        profissao: 'Analista de Sistemas',
        cpf: '123.456.789-00',
        telefone: '(27) 99999-8888',
        igrejaId: 'igreja-1',
        estado: 'ATIVA',
        versao: 1,
        atualizadoEm: '2026-10-01T10:00:00Z',
      );
      final fichaGateway = TesteFichaMockGateway(ficha: ficha);

      const part = ParticipacaoModel(
        id: 'part-1',
        fichaId: 'user-123',
        equipeId: 'eq-louvor',
        nomeEquipe: 'Louvor',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
        versao: 1,
      );
      final participacaoGateway = TesteParticipacaoMockGateway([part]);

      // Teste Desktop (1200 x 800)
      await tester.pumpWidget(
        criarAppTeste(
          tamanho: const Size(1200, 800),
          child: MinhaFichaScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('layout_desktop_colunas')), findsOneWidget);

      // Teste Mobile (390 x 844)
      await tester.pumpWidget(
        criarAppTeste(
          tamanho: const Size(390, 844),
          child: MinhaFichaScreen(
            fichaGateway: fichaGateway,
            catalogoGateway: catalogoGateway,
            participacaoGateway: participacaoGateway,
            pdfTermoGateway: pdfGateway,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('layout_mobile_empilhado')), findsOneWidget);

      // Verifica altura mínima de botões no mobile (WCAG 2.2 AA >= 44px)
      final btnEditar = tester.getRect(find.byKey(const Key('btn_editar_dados')));
      expect(btnEditar.height, greaterThanOrEqualTo(44.0));
    });
  });
}
