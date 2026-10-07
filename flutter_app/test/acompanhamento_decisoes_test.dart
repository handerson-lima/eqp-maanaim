import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/minha_ficha_screen.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class AcompanhamentoFichaMockGateway implements FichaGateway {
  AcompanhamentoFichaMockGateway({this.ficha});

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

class AcompanhamentoParticipacaoMockGateway implements ParticipacaoGateway {
  AcompanhamentoParticipacaoMockGateway(this.participacoes);

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
      proximaAcao: 'Aguardando avaliação do Pastor Local',
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

void main() {
  final catalogoFake = CatalogoFake(
    resposta: const CatalogoResposta(
      equipes: [
        EquipeCatalogo(id: 'eq-louvor', nome: 'Louvor', ativo: true),
        EquipeCatalogo(id: 'eq-apoio', nome: 'Apoio e Segurança', ativo: true),
        EquipeCatalogo(id: 'eq-som', nome: 'Sonoplastia', ativo: true),
      ],
      igrejas: [
        IgrejaCatalogo(id: 'ig-centro', nome: 'Igreja Central', codigo: '001', ativo: true),
      ],
    ),
  );

  Widget criarAppTeste({
    required FichaModel ficha,
    required List<ParticipacaoModel> participacoes,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MinhaFichaScreen(
          fichaGateway: AcompanhamentoFichaMockGateway(ficha: ficha),
          participacaoGateway: AcompanhamentoParticipacaoMockGateway(participacoes),
          catalogoGateway: catalogoFake,
        ),
      ),
    );
  }

  group('Story 3.4 - Acompanhamento de Decisões pelo Voluntário', () {
    testWidgets('exibe equipe ativa com período de vigência anual formatado (DD/MM/AAAA)', (tester) async {
      final ficha = FichaModel(
        id: 'user-123',
        nomeCompleto: 'Gabriel Oliveira',
        cpf: '12345678901',
        profissao: 'Músico',
        igrejaId: 'ig-centro',
        estado: 'ATIVA',
        versao: 3,
        proximaAcao: 'Ciclo anual ativo',
      );

      final List<ParticipacaoModel> participacoes = [
        const ParticipacaoModel(
          id: 'part-1',
          fichaId: 'user-123',
          equipeId: 'eq-louvor',
          nomeEquipe: 'Louvor',
          ciclo: '2026',
          estado: 'ATIVA',
          proximaAcao: 'Ciclo anual ativo',
          vigenciaInicio: '2026-10-06T12:00:00Z',
          vigenciaFim: '2027-10-06T12:00:00Z',
          cicloAtualId: 'ciclo-2026-louvor',
        ),
      ];

      await tester.pumpWidget(criarAppTeste(ficha: ficha, participacoes: participacoes));
      await tester.pumpAndSettle();

      // Confirma o status consolidado de ficha ativa na seção dedicada
      expect(find.text('Status da Solicitação'), findsWidgets);
      expect(find.text('Voluntariado Ativo no Maanaim'), findsWidgets);

      // Confirma equipe e indicador de vigência anual formatado
      expect(find.text('Louvor'), findsWidgets);
      expect(find.text('Ativa'), findsWidgets);
      expect(find.text('Vigência: 06/10/2026 até 06/10/2027'), findsOneWidget);
    });

    testWidgets('exibe equipe em tramitação com indicação clara da etapa', (tester) async {
      final ficha = FichaModel(
        id: 'user-123',
        nomeCompleto: 'Gabriel Oliveira',
        cpf: '12345678901',
        profissao: 'Músico',
        igrejaId: 'ig-centro',
        estado: 'AGUARDANDO_COORDENADOR',
        versao: 2,
        proximaAcao: 'Aguardando validação e homologação do Coordenador Geral',
      );

      final List<ParticipacaoModel> participacoes = [
        const ParticipacaoModel(
          id: 'part-1',
          fichaId: 'user-123',
          equipeId: 'eq-som',
          nomeEquipe: 'Sonoplastia',
          ciclo: '2026',
          estado: 'AGUARDANDO_COORDENADOR',
          proximaAcao: 'Aguardando validação do Coordenador Geral',
        ),
      ];

      await tester.pumpWidget(criarAppTeste(ficha: ficha, participacoes: participacoes));
      await tester.pumpAndSettle();

      // Confirma banner e card com indicação da etapa
      expect(find.text('Sonoplastia'), findsWidgets);
      expect(find.text('Aguardando Coordenador'), findsWidgets);
    });

    testWidgets('rotula etapa do responsável sem expor o estado interno cru', (tester) async {
      final ficha = FichaModel(
        id: 'user-123',
        nomeCompleto: 'Gabriel Oliveira',
        cpf: '12345678901',
        profissao: 'Músico',
        igrejaId: 'ig-centro',
        estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
        versao: 2,
        proximaAcao: 'Análise pelos Responsáveis de Equipe',
      );

      final List<ParticipacaoModel> participacoes = [
        const ParticipacaoModel(
          id: 'part-1',
          fichaId: 'user-123',
          equipeId: 'eq-louvor',
          nomeEquipe: 'Louvor',
          ciclo: '2026',
          estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
          proximaAcao: 'Aguardando avaliação do Responsável de Equipe',
        ),
      ];

      await tester.pumpWidget(criarAppTeste(ficha: ficha, participacoes: participacoes));
      await tester.pumpAndSettle();

      expect(find.text('Aguardando Responsável'), findsWidgets);
      // Não expõe o estado técnico bruto ao usuário
      expect(find.text('AGUARDANDO_RESPONSAVEL_EQUIPE'), findsNothing);
    });

    testWidgets('exibe mensagem canônica neutra OBRIGATÓRIA e NUNCA expõe "rejeitado" ou justificativas internas', (tester) async {
      final ficha = FichaModel(
        id: 'user-123',
        nomeCompleto: 'Gabriel Oliveira',
        cpf: '12345678901',
        profissao: 'Músico',
        igrejaId: 'ig-centro',
        estado: 'REJEITADA',
        versao: 3,
        proximaAcao: 'Consulte o Pastor da igreja local',
        mensagemVoluntario: 'Procure o Pastor da igreja local para mais informações',
      );

      final List<ParticipacaoModel> participacoes = [
        const ParticipacaoModel(
          id: 'part-1',
          fichaId: 'user-123',
          equipeId: 'eq-apoio',
          nomeEquipe: 'Apoio e Segurança',
          ciclo: '2026',
          estado: 'REJEITADA',
          proximaAcao: 'Procure o Pastor da igreja local para mais informações',
        ),
      ];

      await tester.pumpWidget(criarAppTeste(ficha: ficha, participacoes: participacoes));
      await tester.pumpAndSettle();

      const mensagemCanonica = 'Procure o Pastor da igreja local para mais informações';

      // 1. Deve exibir a mensagem neutra canônica obrigatória, sem pontuação extra
      expect(find.text(mensagemCanonica), findsWidgets);
      expect(find.text('$mensagemCanonica.'), findsNothing);

      // 2. NUNCA expor "rejeitado", "rejeitada", "indeferido" ou justificativas internas na árvore de UI
      expect(find.textContaining(RegExp(r'rejeitad', caseSensitive: false), findRichText: true), findsNothing);
      expect(find.textContaining(RegExp(r'indeferid', caseSensitive: false), findRichText: true), findsNothing);
      expect(find.textContaining(RegExp(r'motivo', caseSensitive: false), findRichText: true), findsNothing);
      expect(find.textContaining(RegExp(r'justificativa', caseSensitive: false), findRichText: true), findsNothing);
    });

    testWidgets('exibe independência entre equipes: uma ativa com vigência e uma com mensagem neutra', (tester) async {
      final ficha = FichaModel(
        id: 'user-123',
        nomeCompleto: 'Gabriel Oliveira',
        cpf: '12345678901',
        profissao: 'Músico',
        igrejaId: 'ig-centro',
        estado: 'ATIVA',
        versao: 3,
        proximaAcao: 'Ciclo anual ativo',
      );

      final List<ParticipacaoModel> participacoes = [
        const ParticipacaoModel(
          id: 'part-1',
          fichaId: 'user-123',
          equipeId: 'eq-louvor',
          nomeEquipe: 'Louvor',
          ciclo: '2026',
          estado: 'ATIVA',
          proximaAcao: 'Ciclo anual ativo',
          vigenciaInicio: '2026-10-06T12:00:00Z',
          vigenciaFim: '2027-10-06T12:00:00Z',
        ),
        const ParticipacaoModel(
          id: 'part-2',
          fichaId: 'user-123',
          equipeId: 'eq-apoio',
          nomeEquipe: 'Apoio e Segurança',
          ciclo: '2026',
          estado: 'REJEITADA',
          proximaAcao: 'Procure o Pastor da igreja local para mais informações',
        ),
      ];

      await tester.pumpWidget(criarAppTeste(ficha: ficha, participacoes: participacoes));
      await tester.pumpAndSettle();

      // Equipe 1 ativa com vigência
      expect(find.text('Louvor'), findsWidgets);
      expect(find.text('Vigência: 06/10/2026 até 06/10/2027'), findsOneWidget);

      // Equipe 2 com mensagem neutra
      expect(find.text('Apoio e Segurança'), findsWidgets);
      expect(find.text('Procure o Pastor da igreja local para mais informações'), findsOneWidget);

      // Sem menção a rejeitado
      expect(find.textContaining(RegExp(r'rejeitad', caseSensitive: false), findRichText: true), findsNothing);
    });

    testWidgets('renderiza sem overflow em mobile (390x844) e desktop (1024x768)', (tester) async {
      final ficha = FichaModel(
        id: 'user-123',
        nomeCompleto: 'Gabriel Oliveira',
        cpf: '12345678901',
        profissao: 'Músico',
        igrejaId: 'ig-centro',
        estado: 'ATIVA',
        versao: 3,
        proximaAcao: 'Ciclo anual ativo',
      );

      final List<ParticipacaoModel> participacoes = [
        const ParticipacaoModel(
          id: 'part-1',
          fichaId: 'user-123',
          equipeId: 'eq-louvor',
          nomeEquipe: 'Louvor',
          ciclo: '2026',
          estado: 'ATIVA',
          proximaAcao: 'Ciclo anual ativo',
          vigenciaInicio: '2026-10-06T12:00:00Z',
          vigenciaFim: '2027-10-06T12:00:00Z',
        ),
        const ParticipacaoModel(
          id: 'part-2',
          fichaId: 'user-123',
          equipeId: 'eq-apoio',
          nomeEquipe: 'Apoio e Segurança',
          ciclo: '2026',
          estado: 'REJEITADA',
          proximaAcao: 'Procure o Pastor da igreja local para mais informações',
        ),
      ];

      // Mobile
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(criarAppTeste(ficha: ficha, participacoes: participacoes));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Desktop
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpWidget(criarAppTeste(ficha: ficha, participacoes: participacoes));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
