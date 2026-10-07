import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/minha_ficha_screen.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class FichaAtivaMockGateway implements FichaGateway {
  FichaAtivaMockGateway({this.ficha});

  FichaModel? ficha;

  @override
  Future<ObterFichaResposta> obterMinhaFicha() async {
    return ObterFichaResposta(existe: true, ficha: ficha);
  }

  @override
  Future<SalvarFichaResposta> salvarMinhaFicha(SalvarFichaEntrada entrada) async {
    return SalvarFichaResposta(sucesso: true, repetido: false, ficha: ficha!);
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
      proximaAcao: 'Voluntariado ativo',
      igrejaId: ficha?.igrejaId ?? '',
      enviadoEm: '2026-10-06T12:00:00Z',
    );
  }

  @override
  Future<void> cancelarVoluntariado({
    required String fichaId,
    String? motivo,
    String? commandId,
  }) async {}
}

class ParticipacaoMockGateway implements ParticipacaoGateway {
  ParticipacaoMockGateway(this.participacoes, {this.deveFalhar = false});

  final List<ParticipacaoModel> participacoes;
  bool deveFalhar;
  int chamadasSolicitar = 0;
  String? ultimaEquipeSolicitada;

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
    chamadasSolicitar++;
    ultimaEquipeSolicitada = equipeId;

    if (deveFalhar) {
      throw Exception('Erro de teste ao solicitar equipe adicional');
    }

    final nova = ParticipacaoModel(
      id: 'part-$equipeId',
      fichaId: 'vol-01',
      equipeId: equipeId,
      nomeEquipe: equipeId == 'eq-som'
          ? 'Som e Mídia'
          : equipeId == 'eq-louvor'
              ? 'Louvor'
              : 'Nova Equipe',
      estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
      ciclo: 'INICIAL',
      proximaAcao: 'Aguardando avaliação do Responsável de Equipe',
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
}

void main() {
  final equipesCatalogo = [
    const EquipeCatalogo(id: 'eq-recepcao', nome: 'Recepção', ativo: true),
    const EquipeCatalogo(id: 'eq-som', nome: 'Som e Mídia', ativo: true),
    const EquipeCatalogo(id: 'eq-louvor', nome: 'Louvor', ativo: true),
    const EquipeCatalogo(id: 'eq-desativada', nome: 'Equipe Desativada', ativo: false),
  ];

  final igrejasCatalogo = [
    const IgrejaCatalogo(id: 'ig-1', nome: 'Igreja Central', codigo: '001', ativo: true),
  ];

  final fichaAtiva = FichaModel(
    id: 'vol-01',
    nomeCompleto: 'Irmão Voluntário Ativo',
    cpf: '123.456.789-00',
    profissao: 'Engenheiro',
    igrejaId: 'ig-1',
    estado: 'ATIVA',
    proximaAcao: 'Voluntariado ativo',
    versao: 3,
    termoAceito: const TermoAceitoModel(
      termoId: 'termo-padrao',
      versaoId: 'v1',
      numeroVersao: 1,
      hashSha256: 'hash-abc',
      aceitoEm: '2026-10-06T10:00:00Z',
      commandId: 'cmd-termo-01',
    ),
  );

  Widget criarAppTeste({
    required FichaGateway fichaGateway,
    required ParticipacaoGateway participacaoGateway,
  }) {
    return MaterialApp(
      home: MinhaFichaScreen(
        fichaGateway: fichaGateway,
        catalogoGateway: CatalogoFake(
          resposta: CatalogoResposta(
            igrejas: igrejasCatalogo,
            equipes: equipesCatalogo,
          ),
        ),
        participacaoGateway: participacaoGateway,
        userName: 'Irmão Voluntário Ativo',
      ),
    );
  }

  testWidgets('Story 4.2: Exibe botão "Solicitar Nova Equipe" quando ficha está ATIVA', (tester) async {
    tester.view.physicalSize = const Size(1024, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fichaGateway = FichaAtivaMockGateway(ficha: fichaAtiva);
    final partGateway = ParticipacaoMockGateway([
      const ParticipacaoModel(
        id: 'part-recepcao',
        fichaId: 'vol-01',
        equipeId: 'eq-recepcao',
        nomeEquipe: 'Recepção',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
        vigenciaInicio: '2026-10-06T10:00:00Z',
        vigenciaFim: '2027-10-06T10:00:00Z',
      ),
    ]);

    await tester.pumpWidget(criarAppTeste(
      fichaGateway: fichaGateway,
      participacaoGateway: partGateway,
    ));
    await tester.pumpAndSettle();

    final btnFinder = find.byKey(const Key('btn_solicitar_nova_equipe'));
    await tester.ensureVisible(btnFinder);
    expect(btnFinder, findsOneWidget);
    expect(find.text('Solicitar Nova Equipe'), findsOneWidget);
  });

  testWidgets('Story 4.2: Abre modal, bloqueia equipes já ativas e permite selecionar equipe elegível', (tester) async {
    tester.view.physicalSize = const Size(1024, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fichaGateway = FichaAtivaMockGateway(ficha: fichaAtiva);
    final partGateway = ParticipacaoMockGateway([
      const ParticipacaoModel(
        id: 'part-recepcao',
        fichaId: 'vol-01',
        equipeId: 'eq-recepcao',
        nomeEquipe: 'Recepção',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
      ),
    ]);

    await tester.pumpWidget(criarAppTeste(
      fichaGateway: fichaGateway,
      participacaoGateway: partGateway,
    ));
    await tester.pumpAndSettle();

    // Scroll e clica no botão para abrir modal
    final btnFinder = find.byKey(const Key('btn_solicitar_nova_equipe'));
    await tester.ensureVisible(btnFinder);
    await tester.tap(btnFinder);
    await tester.pumpAndSettle();

    // Modal aberto
    expect(find.text('Solicitar Equipe Adicional'), findsOneWidget);

    // Recepção está na lista com badge 'Ativa'
    expect(find.text('Recepção'), findsWidgets);
    expect(find.text('Ativa'), findsWidgets);

    // Tentar clicar em equipe inelegível (Recepção) não habilita o botão de confirmação
    await tester.tap(find.byKey(const Key('item_equipe_eq-recepcao')));
    await tester.pumpAndSettle();

    final btnConfirmar = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('btn_confirmar_solicitar_equipe')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(btnConfirmar.onPressed, isNull); // Desabilitado

    // Clica em equipe elegível (Som e Mídia)
    await tester.tap(find.byKey(const Key('item_equipe_eq-som')));
    await tester.pumpAndSettle();

    final btnConfirmarHabilitado = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('btn_confirmar_solicitar_equipe')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(btnConfirmarHabilitado.onPressed, isNotNull); // Habilitado

    // Submete a solicitação
    await tester.tap(find.byKey(const Key('btn_confirmar_solicitar_equipe')));
    await tester.pumpAndSettle();

    // Modal fecha e gateway foi acionado
    expect(partGateway.chamadasSolicitar, 1);
    expect(partGateway.ultimaEquipeSolicitada, 'eq-som');

    // Mensagem de sucesso exibida
    expect(find.text('Solicitação enviada com sucesso! A equipe está em análise.'), findsOneWidget);

    // A tela agora exibe a nova participação e mantém a equipe ativa
    expect(find.byKey(const Key('card_participacao_part-eq-som')), findsOneWidget);
    expect(find.text('Aguardando Responsável'), findsOneWidget);
    expect(find.text('Recepção'), findsWidgets);
  });

  testWidgets('Story 4.2: Exibe mensagem de erro no modal em caso de falha', (tester) async {
    tester.view.physicalSize = const Size(1024, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fichaGateway = FichaAtivaMockGateway(ficha: fichaAtiva);
    final partGateway = ParticipacaoMockGateway([
      const ParticipacaoModel(
        id: 'part-recepcao',
        fichaId: 'vol-01',
        equipeId: 'eq-recepcao',
        nomeEquipe: 'Recepção',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
      ),
    ], deveFalhar: true);

    await tester.pumpWidget(criarAppTeste(
      fichaGateway: fichaGateway,
      participacaoGateway: partGateway,
    ));
    await tester.pumpAndSettle();

    final btnFinder = find.byKey(const Key('btn_solicitar_nova_equipe'));
    await tester.ensureVisible(btnFinder);
    await tester.tap(btnFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('item_equipe_eq-som')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('btn_confirmar_solicitar_equipe')));
    await tester.pumpAndSettle();

    // Modal continua aberto com mensagem de erro
    expect(find.text('Solicitar Equipe Adicional'), findsOneWidget);
    expect(find.textContaining('Não foi possível solicitar a equipe'), findsOneWidget);
  });

  testWidgets('Story 4.2: Responsividade Desktop (1024x768) abre em Dialog e preserva alvos >= 44px', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fichaGateway = FichaAtivaMockGateway(ficha: fichaAtiva);
    final partGateway = ParticipacaoMockGateway([
      const ParticipacaoModel(
        id: 'part-recepcao',
        fichaId: 'vol-01',
        equipeId: 'eq-recepcao',
        nomeEquipe: 'Recepção',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
      ),
    ]);

    await tester.pumpWidget(criarAppTeste(
      fichaGateway: fichaGateway,
      participacaoGateway: partGateway,
    ));
    await tester.pumpAndSettle();

    final btnFinder = find.byKey(const Key('btn_solicitar_nova_equipe'));
    await tester.ensureVisible(btnFinder);
    expect(btnFinder, findsOneWidget);

    await tester.tap(btnFinder);
    await tester.pumpAndSettle();

    // No desktop é exibido como Dialog
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Solicitar Equipe Adicional'), findsOneWidget);

    // Validação de alvos de toque >= 44px
    final sizeConfirmar = tester.getSize(find.byKey(const Key('btn_confirmar_solicitar_equipe')));
    expect(sizeConfirmar.height, greaterThanOrEqualTo(44.0));
  });

  testWidgets('Story 4.2: Responsividade Mobile (390x844) abre em BottomSheet e preserva alvos >= 44px', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fichaGateway = FichaAtivaMockGateway(ficha: fichaAtiva);
    final partGateway = ParticipacaoMockGateway([
      const ParticipacaoModel(
        id: 'part-recepcao',
        fichaId: 'vol-01',
        equipeId: 'eq-recepcao',
        nomeEquipe: 'Recepção',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
      ),
    ]);

    await tester.pumpWidget(criarAppTeste(
      fichaGateway: fichaGateway,
      participacaoGateway: partGateway,
    ));
    await tester.pumpAndSettle();

    final btnFinder = find.byKey(const Key('btn_solicitar_nova_equipe'));
    await tester.ensureVisible(btnFinder);
    await tester.tap(btnFinder);
    await tester.pumpAndSettle();

    // No mobile é exibido como BottomSheet (não Dialog)
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Solicitar Equipe Adicional'), findsOneWidget);

    // Validação de alvos de toque >= 44px
    final sizeConfirmar = tester.getSize(find.byKey(const Key('btn_confirmar_solicitar_equipe')));
    expect(sizeConfirmar.height, greaterThanOrEqualTo(44.0));
  });
}
