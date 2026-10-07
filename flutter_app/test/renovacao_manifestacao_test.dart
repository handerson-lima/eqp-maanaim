import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/manifestar_renovacao_dialog.dart';
import 'package:eqp_maanaim/features/voluntario/minha_ficha_screen.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class MockFichaGateway implements FichaGateway {
  MockFichaGateway({this.ficha});

  FichaModel? ficha;

  @override
  Future<ObterFichaResposta> obterMinhaFicha() async {
    if (ficha == null) return const ObterFichaResposta(existe: false);
    return ObterFichaResposta(existe: true, ficha: ficha);
  }

  @override
  Future<SalvarFichaResposta> salvarMinhaFicha(SalvarFichaEntrada entrada) async {
    final f = ficha ??
        FichaModel(
          id: 'user-001',
          nomeCompleto: entrada.nomeCompleto,
          cpf: entrada.cpf,
          profissao: entrada.profissao,
          igrejaId: entrada.igrejaId,
          estado: 'RASCUNHO',
          versao: 1,
        );
    return SalvarFichaResposta(sucesso: true, repetido: false, ficha: f);
  }

  @override
  Future<EnviarFichaResposta> enviarFichaAprovacao({
    required String commandId,
    int? expectedVersion,
  }) async {
    return EnviarFichaResposta(
      sucesso: true,
      repetido: false,
      estado: 'ATIVA',
      versao: (ficha?.versao ?? 1) + 1,
      proximaAcao: 'Ativa',
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
  List<ManifestacaoEquipeInput>? ultimasManifestacoes;
  int chamadasManifestar = 0;

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
  }) async {
    chamadasManifestar++;
    ultimasManifestacoes = manifestacoes;
    for (final m in manifestacoes) {
      final idx = participacoes.indexWhere((p) => p.id == m.participacaoId);
      if (idx != -1) {
        participacoes[idx] = participacoes[idx].copyWith(
          intencaoRenovacao: m.decisao,
          proximaAcao: m.decisao == 'CONTINUAR'
              ? 'Aguardando avaliação do Pastor Local (Ciclo Anual)'
              : 'Encerramento programado ao término da vigência',
        );
      }
    }
    return [
      for (final m in manifestacoes)
        {
          'participacaoId': m.participacaoId,
          'decisao': m.decisao,
        }
    ];
  }
}

void main() {
  final catalogoFake = CatalogoFake(
    resposta: const CatalogoResposta(
      equipes: [
        EquipeCatalogo(id: 'eq-louvor', nome: 'Equipe de Louvor', ativo: true),
        EquipeCatalogo(id: 'eq-som', nome: 'Som e Mídia', ativo: true),
      ],
      igrejas: [
        IgrejaCatalogo(id: 'ig-1', nome: 'Igreja Central', codigo: '001', ativo: true),
      ],
    ),
  );

  final fichaAtiva = FichaModel(
    id: 'user-001',
    nomeCompleto: 'Voluntário Modelo',
    cpf: '12345678901',
    profissao: 'Músico',
    igrejaId: 'ig-1',
    estado: 'ATIVA',
    versao: 2,
  );

  Widget criarAppParaDialog({
    required Widget child,
    Size tamanho = const Size(390, 844),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: tamanho),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  Widget criarAppParaMinhaFicha({
    required FichaGateway fichaGateway,
    required ParticipacaoGateway participacaoGateway,
    Size tamanho = const Size(390, 844),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: tamanho),
        child: MinhaFichaScreen(
          fichaGateway: fichaGateway,
          catalogoGateway: catalogoFake,
          participacaoGateway: participacaoGateway,
        ),
      ),
    );
  }

  group('Story 5.2: ManifestarRenovacaoDialog (Componente e A11y)', () {
    final participacaoElegivel = ParticipacaoModel(
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

    testWidgets('renderiza diálogo com equipe, vigência e opções claras de escolha', (tester) async {
      await tester.pumpWidget(
        criarAppParaDialog(
          child: ManifestarRenovacaoDialog(
            participacoesElegiveis: [participacaoElegivel],
            onConfirmar: (_) async {},
          ),
        ),
      );

      expect(find.byKey(const Key('dialog_manifestar_renovacao')), findsOneWidget);
      expect(find.text('Renovação Anual'), findsOneWidget);
      expect(find.text('Equipe de Louvor'), findsOneWidget);
      expect(find.byKey(const Key('btn_continuar_part-01')), findsOneWidget);
      expect(find.byKey(const Key('btn_nao_continuar_part-01')), findsOneWidget);
      expect(find.byKey(const Key('btn_confirmar_manifestacao')), findsOneWidget);
      expect(find.byKey(const Key('btn_cancelar_manifestacao')), findsOneWidget);
    });

    testWidgets('seleção "Continuar" envia manifestação diretamente sem dialog secundário', (tester) async {
      List<ManifestacaoEquipeInput>? resultado;

      await tester.pumpWidget(
        criarAppParaDialog(
          child: ManifestarRenovacaoDialog(
            participacoesElegiveis: [participacaoElegivel],
            onConfirmar: (inputs) async {
              resultado = inputs;
            },
          ),
        ),
      );

      // Padrão já é CONTINUAR
      await tester.tap(find.byKey(const Key('btn_confirmar_manifestacao')));
      await tester.pumpAndSettle();

      expect(resultado, isNotNull);
      expect(resultado!.length, 1);
      expect(resultado![0].participacaoId, 'part-01');
      expect(resultado![0].decisao, 'CONTINUAR');
    });

    testWidgets('seleção "Não Continuar" exibe explicação e exige diálogo de confirmação', (tester) async {
      List<ManifestacaoEquipeInput>? resultado;

      await tester.pumpWidget(
        criarAppParaDialog(
          child: ManifestarRenovacaoDialog(
            participacoesElegiveis: [participacaoElegivel],
            onConfirmar: (inputs) async {
              resultado = inputs;
            },
          ),
        ),
      );

      // Toca em Não Continuar
      await tester.tap(find.byKey(const Key('btn_nao_continuar_part-01')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Seu vínculo continuará ativo até o fim do prazo'),
        findsOneWidget,
      );

      // Tenta confirmar
      await tester.tap(find.byKey(const Key('btn_confirmar_manifestacao')));
      await tester.pumpAndSettle();

      // Deve abrir o AlertDialog de confirmação de encerramento
      expect(find.text('Confirmar Encerramento?'), findsOneWidget);
      expect(find.text('Confirmar Envio'), findsOneWidget);

      // Confirma no diálogo
      await tester.tap(find.text('Confirmar Envio'));
      await tester.pumpAndSettle();

      expect(resultado, isNotNull);
      expect(resultado![0].decisao, 'NAO_CONTINUAR');
    });

    testWidgets('garante alvos de toque >= 44x44px nos controles de ação', (tester) async {
      await tester.pumpWidget(
        criarAppParaDialog(
          child: ManifestarRenovacaoDialog(
            participacoesElegiveis: [participacaoElegivel],
            onConfirmar: (_) async {},
          ),
        ),
      );

      final tamanhoContinuar = tester.getSize(find.byKey(const Key('btn_continuar_part-01')));
      expect(tamanhoContinuar.height, greaterThanOrEqualTo(44.0));

      final tamanhoNaoContinuar = tester.getSize(find.byKey(const Key('btn_nao_continuar_part-01')));
      expect(tamanhoNaoContinuar.height, greaterThanOrEqualTo(44.0));

      final tamanhoConfirmar = tester.getSize(find.byKey(const Key('btn_confirmar_manifestacao')));
      expect(tamanhoConfirmar.height, greaterThanOrEqualTo(44.0));
    });
  });

  group('Story 5.2: Integração com MinhaFichaScreen', () {
    testWidgets('exibe banner e botão na equipe quando está na janela de renovação', (tester) async {
      final partNaJanela = ParticipacaoModel(
        id: 'part-01',
        fichaId: 'user-001',
        equipeId: 'eq-louvor',
        nomeEquipe: 'Equipe de Louvor',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
        vigenciaInicio: '2025-11-01T00:00:00Z',
        vigenciaFim: '2026-11-01T00:00:00Z',
        diasParaVencimento: 20,
        situacaoVigencia: 'RENOVACAO_IMINENTE_30D',
        emAlertaRenovacao: true,
      );

      final gateway = MockParticipacaoGateway([partNaJanela]);
      final fichaGateway = MockFichaGateway(ficha: fichaAtiva);

      await tester.pumpWidget(
        criarAppParaMinhaFicha(
          fichaGateway: fichaGateway,
          participacaoGateway: gateway,
        ),
      );
      await tester.pumpAndSettle();

      // Banner destacado deve estar visível
      expect(find.byKey(const Key('banner_renovacao_disponivel')), findsOneWidget);
      expect(find.byKey(const Key('btn_abrir_renovacao_banner')), findsOneWidget);

      // Botão individual no card da equipe também deve estar visível
      expect(find.byKey(const Key('btn_renovar_participacao_part-01')), findsOneWidget);
    });

    testWidgets('não exibe banner de renovação se a equipe estiver fora da janela (> 60 dias)', (tester) async {
      final partForaJanela = ParticipacaoModel(
        id: 'part-02',
        fichaId: 'user-001',
        equipeId: 'eq-som',
        nomeEquipe: 'Som e Mídia',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
        vigenciaInicio: '2026-06-01T00:00:00Z',
        vigenciaFim: '2027-06-01T00:00:00Z',
        diasParaVencimento: 240,
        situacaoVigencia: 'VIGENTE',
        emAlertaRenovacao: false,
      );

      final gateway = MockParticipacaoGateway([partForaJanela]);
      final fichaGateway = MockFichaGateway(ficha: fichaAtiva);

      await tester.pumpWidget(
        criarAppParaMinhaFicha(
          fichaGateway: fichaGateway,
          participacaoGateway: gateway,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('banner_renovacao_disponivel')), findsNothing);
      expect(find.byKey(const Key('btn_renovar_participacao_part-02')), findsNothing);
    });

    testWidgets('acionar botão de renovação abre o modal e processa manifestação com sucesso', (tester) async {
      final partNaJanela = ParticipacaoModel(
        id: 'part-01',
        fichaId: 'user-001',
        equipeId: 'eq-louvor',
        nomeEquipe: 'Equipe de Louvor',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
        vigenciaInicio: '2025-11-01T00:00:00Z',
        vigenciaFim: '2026-11-01T00:00:00Z',
        diasParaVencimento: 20,
        situacaoVigencia: 'RENOVACAO_IMINENTE_30D',
        emAlertaRenovacao: true,
      );

      final gateway = MockParticipacaoGateway([partNaJanela]);
      final fichaGateway = MockFichaGateway(ficha: fichaAtiva);

      await tester.pumpWidget(
        criarAppParaMinhaFicha(
          fichaGateway: fichaGateway,
          participacaoGateway: gateway,
        ),
      );
      await tester.pumpAndSettle();

      // Clica no botão do card garantindo visibilidade na rolagem
      final btnCard = find.byKey(const Key('btn_renovar_participacao_part-01'));
      await tester.ensureVisible(btnCard);
      await tester.pumpAndSettle();
      await tester.tap(btnCard);
      await tester.pumpAndSettle();

      // Modal aberto
      expect(find.byKey(const Key('dialog_manifestar_renovacao')), findsOneWidget);

      // Confirma continuidade
      await tester.tap(find.byKey(const Key('btn_confirmar_manifestacao')));
      await tester.pumpAndSettle();

      // Verifica disparo no gateway
      expect(gateway.chamadasManifestar, 1);
      expect(gateway.ultimasManifestacoes, isNotNull);
      expect(gateway.ultimasManifestacoes![0].decisao, 'CONTINUAR');

      // Verifica feedback na tela
      expect(find.text('Manifestação de renovação registrada com sucesso!'), findsOneWidget);
    });
  });
}
