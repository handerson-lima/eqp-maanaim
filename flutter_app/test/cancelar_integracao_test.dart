import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/minha_ficha_screen.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:eqp_maanaim/features/voluntario/solicitar_equipe_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class _FichaGatewayFake implements FichaGateway {
  _FichaGatewayFake(this.ficha);

  FichaModel? ficha;
  int cancelamentos = 0;
  String? ultimaFichaId;
  String? ultimoMotivo;
  int? ultimaVersao;
  String? ultimoCommandId;

  @override
  Future<ObterFichaResposta> obterMinhaFicha() async =>
      ObterFichaResposta(existe: true, ficha: ficha);

  @override
  Future<SalvarFichaResposta> salvarMinhaFicha(SalvarFichaEntrada entrada) async =>
      SalvarFichaResposta(sucesso: true, repetido: false, ficha: ficha!);

  @override
  Future<EnviarFichaResposta> enviarFichaAprovacao({
    required String commandId,
    int? expectedVersion,
  }) async =>
      EnviarFichaResposta(
        sucesso: true,
        repetido: false,
        estado: 'ATIVA',
        versao: ficha!.versao,
        proximaAcao: 'Voluntariado ativo',
        igrejaId: ficha!.igrejaId,
        enviadoEm: '',
      );

  @override
  Future<void> cancelarVoluntariado({
    required String fichaId,
    String? motivo,
    int? expectedVersion,
    String? commandId,
  }) async {
    cancelamentos++;
    ultimaFichaId = fichaId;
    ultimoMotivo = motivo;
    ultimaVersao = expectedVersion;
    ultimoCommandId = commandId;
  }
}

class _ParticipacaoGatewayFake implements ParticipacaoGateway {
  _ParticipacaoGatewayFake(this.participacoes);

  List<ParticipacaoModel> participacoes;
  int cargas = 0;
  int cancelamentos = 0;
  String? ultimoParticipacaoId;
  int? ultimaVersao;
  String? ultimoCommandId;

  @override
  Future<List<ParticipacaoModel>> obterMinhasParticipacoes() async {
    cargas++;
    return List.unmodifiable(participacoes);
  }

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
      throw UnimplementedError();

  @override
  Future<void> cancelarParticipacao({
    required String participacaoId,
    String? motivo,
    int? expectedVersion,
    String? commandId,
  }) async {
    cancelamentos++;
    ultimoParticipacaoId = participacaoId;
    ultimaVersao = expectedVersion;
    ultimoCommandId = commandId;
    participacoes = participacoes
        .map((p) => p.id == participacaoId ? p.copyWith(estado: 'CANCELADA') : p)
        .toList();
  }

  @override
  Future<ParticipacaoModel> solicitarReativacao({
    required String equipeId,
    String? participacaoId,
    String? justificativa,
    String? commandId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> manifestarRenovacao({
    required List<ManifestacaoEquipeInput> manifestacoes,
    String? commandId,
  }) async =>
      const [];
}

void main() {
  final equipesCatalogo = [
    const EquipeCatalogo(id: 'eq-som', nome: 'Som e Mídia', ativo: true),
    const EquipeCatalogo(id: 'eq-louvor', nome: 'Louvor', ativo: true),
  ];
  final igrejasCatalogo = [
    const IgrejaCatalogo(id: 'ig-1', nome: 'Igreja Central', codigo: '001', ativo: true),
  ];

  FichaModel fichaAtiva({int versao = 3}) => FichaModel(
        id: 'vol-01',
        nomeCompleto: 'Irmão Voluntário Ativo',
        cpf: '123.456.789-00',
        profissao: 'Engenheiro',
        igrejaId: 'ig-1',
        estado: 'ATIVA',
        proximaAcao: 'Voluntariado ativo',
        versao: versao,
      );

  Widget criarTela({
    required FichaGateway fichaGateway,
    required ParticipacaoGateway participacaoGateway,
  }) {
    return MaterialApp(
      home: MinhaFichaScreen(
        fichaGateway: fichaGateway,
        catalogoGateway: CatalogoFake(
          resposta: CatalogoResposta(igrejas: igrejasCatalogo, equipes: equipesCatalogo),
        ),
        participacaoGateway: participacaoGateway,
        userName: 'Irmão Voluntário Ativo',
      ),
    );
  }

  testWidgets('Story 4.3: tela envia o cancelamento da participação ao gateway e recarrega',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fichaGateway = _FichaGatewayFake(fichaAtiva());
    final partGateway = _ParticipacaoGatewayFake([
      const ParticipacaoModel(
        id: 'part-som',
        fichaId: 'vol-01',
        equipeId: 'eq-som',
        nomeEquipe: 'Som e Mídia',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
        versao: 5,
      ),
    ]);

    await tester.pumpWidget(
      criarTela(fichaGateway: fichaGateway, participacaoGateway: partGateway),
    );
    await tester.pumpAndSettle();

    final cargasAntes = partGateway.cargas;
    final botaoCancelar = find.byKey(const Key('btn_cancelar_participacao_part-som'));
    await tester.ensureVisible(botaoCancelar);
    await tester.tap(botaoCancelar);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('btn_confirmar_cancelamento_participacao')));
    await tester.pumpAndSettle();

    expect(partGateway.cancelamentos, 1);
    expect(partGateway.ultimoParticipacaoId, 'part-som');
    expect(partGateway.ultimaVersao, 5);
    expect(partGateway.ultimoCommandId, isNotNull);
    expect(partGateway.cargas, greaterThan(cargasAntes));
  });

  testWidgets('Story 4.3: tela envia o encerramento total ao gateway de ficha',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fichaGateway = _FichaGatewayFake(fichaAtiva(versao: 7));
    final partGateway = _ParticipacaoGatewayFake([
      const ParticipacaoModel(
        id: 'part-som',
        fichaId: 'vol-01',
        equipeId: 'eq-som',
        nomeEquipe: 'Som e Mídia',
        estado: 'ATIVA',
        ciclo: 'INICIAL',
        proximaAcao: 'Voluntariado ativo',
        versao: 2,
      ),
    ]);

    await tester.pumpWidget(
      criarTela(fichaGateway: fichaGateway, participacaoGateway: partGateway),
    );
    await tester.pumpAndSettle();

    final botaoEncerrar = find.byKey(const Key('btn_cancelar_voluntariado'));
    await tester.ensureVisible(botaoEncerrar);
    await tester.tap(botaoEncerrar);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('btn_confirmar_cancelamento_voluntariado')));
    await tester.pumpAndSettle();

    expect(fichaGateway.cancelamentos, 1);
    expect(fichaGateway.ultimaFichaId, 'vol-01');
    expect(fichaGateway.ultimaVersao, 7);
    expect(fichaGateway.ultimoCommandId, isNotNull);
  });

  testWidgets('Story 4.3: estado terminal libera a equipe para nova solicitação no modal',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final partGateway = _ParticipacaoGatewayFake([]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SolicitarEquipeModal(
            equipesCatalogo: equipesCatalogo,
            participacoesAtuais: [
              const ParticipacaoModel(
                id: 'part-som-antiga',
                fichaId: 'vol-01',
                equipeId: 'eq-som',
                nomeEquipe: 'Som e Mídia',
                estado: 'CANCELADA',
                ciclo: 'INICIAL',
                proximaAcao: 'Cancelada',
              ),
            ],
            participacaoGateway: partGateway,
            onSucesso: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('item_equipe_eq-som')));
    await tester.pumpAndSettle();

    final btnConfirmar = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('btn_confirmar_solicitar_equipe')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(btnConfirmar.onPressed, isNotNull);
  });

  testWidgets('Story 4.3: participação ativa continua bloqueando a equipe no modal',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final partGateway = _ParticipacaoGatewayFake([]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SolicitarEquipeModal(
            equipesCatalogo: equipesCatalogo,
            participacoesAtuais: [
              const ParticipacaoModel(
                id: 'part-som-atual',
                fichaId: 'vol-01',
                equipeId: 'eq-som',
                nomeEquipe: 'Som e Mídia',
                estado: 'ATIVA',
                ciclo: 'INICIAL',
                proximaAcao: 'Voluntariado ativo',
              ),
            ],
            participacaoGateway: partGateway,
            onSucesso: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('item_equipe_eq-som')));
    await tester.pumpAndSettle();

    final btnConfirmar = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const Key('btn_confirmar_solicitar_equipe')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(btnConfirmar.onPressed, isNull);
  });
}
