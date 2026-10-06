import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/minha_ficha_screen.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class FichaMockGateway implements FichaGateway {
  FichaMockGateway({this.ficha});

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
    final nova = FichaModel(
      id: 'uid-teste',
      nomeCompleto: entrada.nomeCompleto,
      profissao: entrada.profissao,
      cpf: entrada.cpf,
      igrejaId: entrada.igrejaId,
      estado: 'RASCUNHO',
      versao: 1,
    );
    ficha = nova;
    return SalvarFichaResposta(sucesso: true, repetido: false, ficha: nova);
  }

  @override
  Future<EnviarFichaResposta> enviarFichaAprovacao({
    required String commandId,
    int? expectedVersion,
  }) async {
    final novaVersao = (ficha?.versao ?? 1) + 1;
    ficha = ficha?.copyWith(
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      versao: novaVersao,
    );
    return EnviarFichaResposta(
      sucesso: true,
      repetido: false,
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      versao: novaVersao,
      proximaAcao: 'Aguardando avaliação do Pastor Local',
      igrejaId: ficha?.igrejaId ?? '',
      enviadoEm: '2026-10-06T12:00:00Z',
    );
  }
}

class ParticipacaoMockGateway implements ParticipacaoGateway {
  ParticipacaoMockGateway({
    List<ParticipacaoModel>? participacoesIniciais,
    this.falharSalvar = false,
    this.mensagemErro,
  }) : participacoes = List.of(participacoesIniciais ?? []);

  List<ParticipacaoModel> participacoes;
  bool falharSalvar;
  String? mensagemErro;
  List<String>? ultimasEquipesSalvas;
  int chamadasSalvar = 0;

  @override
  Future<List<ParticipacaoModel>> obterMinhasParticipacoes() async {
    return List.unmodifiable(participacoes);
  }

  @override
  Future<List<ParticipacaoModel>> salvarParticipacoesRascunho(
    List<String> equipeIds, {
    String? commandId,
  }) async {
    chamadasSalvar++;
    ultimasEquipesSalvas = equipeIds;

    if (falharSalvar) {
      throw Exception(mensagemErro ?? 'Erro ao salvar participações');
    }

    participacoes.removeWhere((p) => p.isRascunho && !equipeIds.contains(p.equipeId));

    for (final eqId in equipeIds) {
      if (!participacoes.any((p) => p.equipeId == eqId && p.isRascunho)) {
        participacoes.add(
          ParticipacaoModel(
            id: 'part-$eqId',
            fichaId: 'uid-voluntario',
            equipeId: eqId,
            nomeEquipe: eqId == 'eq-cozinha'
                ? 'Cozinha'
                : eqId == 'eq-louvor'
                    ? 'Louvor'
                    : eqId == 'eq-apoio'
                        ? 'Apoio'
                        : eqId,
            estado: 'RASCUNHO',
            ciclo: 'INICIAL',
            proximaAcao: 'Aguardando envio da ficha',
          ),
        );
      }
    }

    return List.unmodifiable(participacoes);
  }
}

void main() {
  final equipesCatalogo = [
    const EquipeCatalogo(id: 'eq-cozinha', nome: 'Cozinha', ativo: true),
    const EquipeCatalogo(id: 'eq-louvor', nome: 'Louvor', ativo: true),
    const EquipeCatalogo(id: 'eq-apoio', nome: 'Apoio', ativo: true),
    const EquipeCatalogo(id: 'eq-inativa', nome: 'Equipe Inativa', ativo: false),
  ];

  final igrejasCatalogo = [
    const IgrejaCatalogo(id: 'ig-1', nome: 'Igreja Central', codigo: '001', ativo: true),
  ];

  Widget criarApp({
    required FichaGateway fichaGateway,
    required CatalogoGateway catalogoGateway,
    required ParticipacaoGateway participacaoGateway,
  }) {
    return MaterialApp(
      home: MinhaFichaScreen(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoGateway,
        participacaoGateway: participacaoGateway,
        userName: 'Voluntário de Teste',
      ),
    );
  }

  group('ParticipacaoModel e MemoriaParticipacaoGateway', () {
    test('MemoriaParticipacaoGateway sincroniza rascunho e remove desmarcadas', () async {
      final gateway = MemoriaParticipacaoGateway(
        participacoesIniciais: [
          const ParticipacaoModel(
            id: 'part-hist-1',
            fichaId: 'uid-vol',
            equipeId: 'eq-antiga',
            nomeEquipe: 'Histórica',
            estado: 'ATIVA',
            ciclo: 'ANTERIOR',
            proximaAcao: 'Concluído',
          ),
        ],
      );
      gateway.nomesEquipes = {'eq-1': 'Cozinha', 'eq-2': 'Louvor'};

      final res1 = await gateway.salvarParticipacoesRascunho(['eq-1', 'eq-2']);
      expect(res1, hasLength(3)); // 1 ativa + 2 rascunhos

      final res2 = await gateway.salvarParticipacoesRascunho(['eq-1']);
      expect(res2, hasLength(2)); // eq-2 em rascunho removida, eq-1 e histórica mantidas
      expect(res2.any((p) => p.equipeId == 'eq-antiga'), isTrue);
      expect(res2.any((p) => p.equipeId == 'eq-1'), isTrue);
      expect(res2.any((p) => p.equipeId == 'eq-2'), isFalse);
    });
  });

  group('MinhaFichaScreen - Seleção de Equipes e Participações de Rascunho', () {
    testWidgets('exibe apenas equipes ativas do catálogo administrável', (tester) async {
      final ficha = FichaMockGateway();
      final catalogo = CatalogoFake(
        resposta: CatalogoResposta(igrejas: igrejasCatalogo, equipes: equipesCatalogo),
      );
      final participacao = ParticipacaoMockGateway();

      await tester.pumpWidget(criarApp(
        fichaGateway: ficha,
        catalogoGateway: catalogo,
        participacaoGateway: participacao,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Equipes de Interesse'), findsOneWidget);
      expect(find.text('Cozinha'), findsOneWidget);
      expect(find.text('Louvor'), findsOneWidget);
      expect(find.text('Apoio'), findsOneWidget);
      // Equipe inativa NÃO deve ser exibida
      expect(find.text('Equipe Inativa'), findsNothing);
    });

    testWidgets('filtra equipes pelo campo de busca', (tester) async {
      final ficha = FichaMockGateway();
      final catalogo = CatalogoFake(
        resposta: CatalogoResposta(igrejas: igrejasCatalogo, equipes: equipesCatalogo),
      );
      final participacao = ParticipacaoMockGateway();

      await tester.pumpWidget(criarApp(
        fichaGateway: ficha,
        catalogoGateway: catalogo,
        participacaoGateway: participacao,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('campo_busca_equipes')), 'Coz');
      await tester.pumpAndSettle();

      expect(find.text('Cozinha'), findsOneWidget);
      expect(find.text('Louvor'), findsNothing);
      expect(find.text('Apoio'), findsNothing);
    });

    testWidgets(
        'permite seleção múltipla, exibe cartões com estado, ciclo e próxima ação, e salva rascunho',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final ficha = FichaMockGateway();
      final catalogo = CatalogoFake(
        resposta: CatalogoResposta(igrejas: igrejasCatalogo, equipes: equipesCatalogo),
      );
      final participacao = ParticipacaoMockGateway();

      await tester.pumpWidget(criarApp(
        fichaGateway: ficha,
        catalogoGateway: catalogo,
        participacaoGateway: participacao,
      ));
      await tester.pumpAndSettle();

      // Inicialmente não há equipes selecionadas
      expect(find.text('Nenhuma equipe selecionada ainda. Marque uma ou mais equipes acima para adicionar ao seu rascunho.'), findsOneWidget);

      final chipCozinha = find.byKey(const Key('chip_equipe_eq-cozinha'));
      await tester.ensureVisible(chipCozinha);
      await tester.tap(chipCozinha);
      await tester.pumpAndSettle();

      final chipLouvor = find.byKey(const Key('chip_equipe_eq-louvor'));
      await tester.ensureVisible(chipLouvor);
      await tester.tap(chipLouvor);
      await tester.pumpAndSettle();

      // Verifica exibição dos cartões de rascunho
      expect(find.byKey(const Key('card_participacao_eq-cozinha')), findsOneWidget);
      expect(find.byKey(const Key('card_participacao_eq-louvor')), findsOneWidget);
      expect(find.text('Ciclo: INICIAL'), findsNWidgets(2));
      expect(find.text('Aguardando envio da ficha'), findsNWidgets(2));

      // Clica no botão de salvar equipes
      final botaoSalvar = find.byKey(const Key('botao_salvar_equipes'));
      await tester.ensureVisible(botaoSalvar);
      await tester.tap(botaoSalvar);
      await tester.pumpAndSettle();

      expect(participacao.chamadasSalvar, equals(1));
      expect(participacao.ultimasEquipesSalvas, containsAll(['eq-cozinha', 'eq-louvor']));
      expect(find.text('Equipes de rascunho salvas com sucesso.'), findsWidgets);
    });

    testWidgets('remove equipe do rascunho pelo botão de lixeira', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final ficha = FichaMockGateway();
      final catalogo = CatalogoFake(
        resposta: CatalogoResposta(igrejas: igrejasCatalogo, equipes: equipesCatalogo),
      );
      final participacao = ParticipacaoMockGateway(
        participacoesIniciais: [
          const ParticipacaoModel(
            id: 'part-1',
            fichaId: 'uid-vol',
            equipeId: 'eq-cozinha',
            nomeEquipe: 'Cozinha',
            estado: 'RASCUNHO',
            ciclo: 'INICIAL',
            proximaAcao: 'Aguardando envio da ficha',
          ),
          const ParticipacaoModel(
            id: 'part-2',
            fichaId: 'uid-vol',
            equipeId: 'eq-louvor',
            nomeEquipe: 'Louvor',
            estado: 'RASCUNHO',
            ciclo: 'INICIAL',
            proximaAcao: 'Aguardando envio da ficha',
          ),
        ],
      );

      await tester.pumpWidget(criarApp(
        fichaGateway: ficha,
        catalogoGateway: catalogo,
        participacaoGateway: participacao,
      ));
      await tester.pumpAndSettle();

      // Ambos cartões devem estar visíveis
      expect(find.byKey(const Key('card_participacao_eq-cozinha')), findsOneWidget);
      expect(find.byKey(const Key('card_participacao_eq-louvor')), findsOneWidget);

      // Clica no botão de remover Cozinha
      final botaoRemoverCozinha = find.byKey(const Key('botao_remover_equipe_eq-cozinha'));
      await tester.ensureVisible(botaoRemoverCozinha);
      await tester.tap(botaoRemoverCozinha);
      await tester.pumpAndSettle();

      // Cozinha não está mais no rascunho, Louvor continua
      expect(find.byKey(const Key('card_participacao_eq-cozinha')), findsNothing);
      expect(find.byKey(const Key('card_participacao_eq-louvor')), findsOneWidget);

      // Salva a alteração
      final botaoSalvar = find.byKey(const Key('botao_salvar_equipes'));
      await tester.ensureVisible(botaoSalvar);
      await tester.tap(botaoSalvar);
      await tester.pumpAndSettle();

      expect(participacao.chamadasSalvar, equals(1));
      expect(participacao.ultimasEquipesSalvas, equals(['eq-louvor']));
    });

    testWidgets('exibe mensagem de erro quando backend recusa salvamento das equipes', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final ficha = FichaMockGateway();
      final catalogo = CatalogoFake(
        resposta: CatalogoResposta(igrejas: igrejasCatalogo, equipes: equipesCatalogo),
      );
      final participacao = ParticipacaoMockGateway(
        falharSalvar: true,
        mensagemErro: 'Equipe inválida ou inativa',
      );

      await tester.pumpWidget(criarApp(
        fichaGateway: ficha,
        catalogoGateway: catalogo,
        participacaoGateway: participacao,
      ));
      await tester.pumpAndSettle();

      final chipCozinha = find.byKey(const Key('chip_equipe_eq-cozinha'));
      await tester.ensureVisible(chipCozinha);
      await tester.tap(chipCozinha);
      await tester.pumpAndSettle();

      final botaoSalvar = find.byKey(const Key('botao_salvar_equipes'));
      await tester.ensureVisible(botaoSalvar);
      await tester.tap(botaoSalvar);
      await tester.pumpAndSettle();

      expect(find.text('Uma das equipes selecionadas é inválida ou está inativa.'), findsWidgets);
    });

    testWidgets('renderiza sem overflow em mobile (390x844) e desktop (1024x768)', (tester) async {
      final ficha = FichaMockGateway(
        ficha: const FichaModel(
          id: 'uid-vol',
          nomeCompleto: 'Ana Maria Braga',
          profissao: 'Apresentadora',
          cpf: '52998224725',
          igrejaId: 'ig-1',
          estado: 'RASCUNHO',
          versao: 1,
        ),
      );
      final catalogo = CatalogoFake(
        resposta: CatalogoResposta(igrejas: igrejasCatalogo, equipes: equipesCatalogo),
      );
      final participacao = ParticipacaoMockGateway();

      // Viewport mobile
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(criarApp(
        fichaGateway: ficha,
        catalogoGateway: catalogo,
        participacaoGateway: participacao,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Equipes de Interesse'), findsOneWidget);

      // Viewport desktop
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpWidget(criarApp(
        fichaGateway: ficha,
        catalogoGateway: catalogo,
        participacaoGateway: participacao,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Equipes de Interesse'), findsOneWidget);
    });
  });
}
