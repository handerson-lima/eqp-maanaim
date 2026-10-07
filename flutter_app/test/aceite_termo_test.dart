import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/termo/termo_service.dart';
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

  @override
  Future<void> cancelarVoluntariado({
    required String fichaId,
    String? motivo,
    int? expectedVersion,
    String? commandId,
  }) async {}
}

class ParticipacaoMockGateway implements ParticipacaoGateway {
  ParticipacaoMockGateway({
    List<ParticipacaoModel>? participacoesIniciais,
  }) : participacoes = List.of(participacoesIniciais ?? []);

  List<ParticipacaoModel> participacoes;

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
}

Widget criarAppTeste({
  required FichaGateway fichaGateway,
  required CatalogoGateway catalogoGateway,
  required ParticipacaoGateway participacaoGateway,
  required TermoGateway termoGateway,
}) {
  return MaterialApp(
    home: MinhaFichaScreen(
      fichaGateway: fichaGateway,
      catalogoGateway: catalogoGateway,
      participacaoGateway: participacaoGateway,
      termoGateway: termoGateway,
      userName: 'Voluntário Teste',
    ),
  );
}

void main() {
  const fichaCadastrada = FichaModel(
    id: 'uid-voluntario-1',
    nomeCompleto: 'João da Silva',
    profissao: 'Engenheiro',
    cpf: '12345678909',
    igrejaId: 'igreja-1',
    estado: 'RASCUNHO',
    versao: 1,
  );

  const participacaoValida = ParticipacaoModel(
    id: 'part-1',
    fichaId: 'uid-voluntario-1',
    equipeId: 'eq-1',
    nomeEquipe: 'Apoio e Recepção',
    estado: 'RASCUNHO',
    ciclo: 'INICIAL',
    proximaAcao: 'Aguardando envio da ficha',
  );

  final catalogoFake = CatalogoFake(
    resposta: const CatalogoResposta(
      igrejas: [
        IgrejaCatalogo(
          id: 'igreja-1',
          codigo: '001',
          nome: 'Igreja Central',
          ativo: true,
        ),
      ],
      equipes: [
        EquipeCatalogo(id: 'eq-1', nome: 'Apoio e Recepção', ativo: true),
      ],
    ),
  );

  group('Story 2.3: MinhaFichaScreen - Aceite do Termo Vigente', () {
    testWidgets('exibe etapa bloqueada se não houver ficha ou não houver equipes', (tester) async {
      final fichaGateway = FichaMockGateway(ficha: null);
      final participacaoGateway = ParticipacaoMockGateway(participacoesIniciais: []);
      final termoGateway = MemoriaTermoGateway();

      await tester.pumpWidget(criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoFake,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Termo de Adesão ao Serviço Voluntário'), findsOneWidget);
      expect(find.text('Etapa bloqueada'), findsOneWidget);
      expect(
        find.text('Complete e salve sua ficha permanente para habilitar o Termo de Adesão.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('botao_aceitar_termo')), findsNothing);
    });

    testWidgets('exibe resumo do termo vigente e botão de ler termo quando apto', (tester) async {
      final fichaGateway = FichaMockGateway(ficha: fichaCadastrada);
      final participacaoGateway = ParticipacaoMockGateway(
        participacoesIniciais: [participacaoValida],
      );
      final termoGateway = MemoriaTermoGateway();

      await tester.pumpWidget(criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoFake,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Versão 1 (Vigente)'), findsOneWidget);
      expect(find.byKey(const Key('botao_ler_termo_completo')), findsOneWidget);
      expect(find.byKey(const Key('checkbox_declaracao_termo')), findsOneWidget);

      final botaoAceitar = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const Key('botao_aceitar_termo')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(botaoAceitar.onPressed, isNull); // Desabilitado sem consentimento
    });

    testWidgets('botão Ler Termo abre o diálogo oficial com o documento', (tester) async {
      final fichaGateway = FichaMockGateway(ficha: fichaCadastrada);
      final participacaoGateway = ParticipacaoMockGateway(
        participacoesIniciais: [participacaoValida],
      );
      final termoGateway = MemoriaTermoGateway();

      await tester.pumpWidget(criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoFake,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('botao_ler_termo_completo')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('botao_ler_termo_completo')));
      await tester.pumpAndSettle();

      expect(find.text('Termo de Adesão de Voluntário'), findsOneWidget);
      expect(find.byTooltip('Fechar'), findsOneWidget);

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      expect(find.text('Termo de Adesão de Voluntário'), findsNothing);
    });

    testWidgets('marcar checkbox de declaração habilita botão e registra aceite com sucesso', (tester) async {
      final fichaGateway = FichaMockGateway(ficha: fichaCadastrada);
      final participacaoGateway = ParticipacaoMockGateway(
        participacoesIniciais: [participacaoValida],
      );
      final termoGateway = MemoriaTermoGateway();

      await tester.pumpWidget(criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoFake,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ));
      await tester.pumpAndSettle();

      // Rola até o checkbox
      await tester.ensureVisible(find.byKey(const Key('checkbox_declaracao_termo')));
      await tester.pumpAndSettle();

      // Marca o checkbox
      await tester.tap(find.byKey(const Key('checkbox_declaracao_termo')));
      await tester.pumpAndSettle();

      // Rola até o botão se necessário
      await tester.ensureVisible(find.byKey(const Key('botao_aceitar_termo')));
      await tester.pumpAndSettle();

      // Botão agora está habilitado
      final botaoHabilitado = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const Key('botao_aceitar_termo')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(botaoHabilitado.onPressed, isNotNull);

      // Clica para aceitar
      await tester.tap(find.byKey(const Key('botao_aceitar_termo')));
      await tester.pumpAndSettle();

      // Exibe estado de comprovante de sucesso
      expect(find.text('Termo Aceito e Válido'), findsOneWidget);
      expect(find.text('Versão do Termo'), findsOneWidget);
      expect(find.text('Versão 1'), findsWidgets);
      expect(find.text('Hash SHA-256'), findsOneWidget);
      expect(find.byKey(const Key('botao_visualizar_termo_aceito')), findsOneWidget);
    });

    testWidgets('exibe aviso de nova versão quando termo publicado supera aceite anterior', (tester) async {
      final fichaComAceiteV1 = fichaCadastrada.copyWith(
        termoAceito: const TermoAceitoModel(
          termoId: 'termo-adesao-voluntariado',
          versaoId: 'versao-v1',
          numeroVersao: 1,
          hashSha256: '1111111111111111111111111111111111111111111111111111111111111111',
          aceitoEm: '2026-10-01T12:00:00Z',
          commandId: 'cmd-aceite-v1',
        ),
      );

      final fichaGateway = FichaMockGateway(ficha: fichaComAceiteV1);
      final participacaoGateway = ParticipacaoMockGateway(
        participacoesIniciais: [participacaoValida],
      );
      final termoGateway = MemoriaTermoGateway(
        termoVigenteInicial: const TermoVigenteModel(
          id: 'versao-v2',
          termoId: 'termo-adesao-voluntariado',
          numeroVersao: 2,
          titulo: 'Termo de Adesão ao Serviço Voluntário - Revisão 2026',
          conteudo: 'Novo conteúdo canônico oficial atualizado.',
          hashSha256: '2222222222222222222222222222222222222222222222222222222222222222',
          publicadoEm: '2026-10-06T12:00:00Z',
        ),
      );

      await tester.pumpWidget(criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoFake,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Nova versão do termo publicada'), findsOneWidget);
      expect(
        find.textContaining('Você aceitou anteriormente a Versão 1. Uma nova versão (Versão 2) foi publicada'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('checkbox_declaracao_termo')), findsOneWidget);
      expect(find.byKey(const Key('botao_aceitar_termo')), findsOneWidget);
    });

    testWidgets('exibe mensagem de erro quando backend rejeita o aceite', (tester) async {
      final fichaGateway = FichaMockGateway(ficha: fichaCadastrada);
      final participacaoGateway = ParticipacaoMockGateway(
        participacoesIniciais: [participacaoValida],
      );
      final termoGateway = MemoriaTermoGateway(
        lancarErroAoAceitar: 'A versão do termo informada não corresponde à versão vigente.',
      );

      await tester.pumpWidget(criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoFake,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('checkbox_declaracao_termo')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('checkbox_declaracao_termo')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('botao_aceitar_termo')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('botao_aceitar_termo')));
      await tester.pumpAndSettle();

      expect(
        find.text('A versão do termo informada não corresponde à versão vigente.'),
        findsOneWidget,
      );
    });

    testWidgets('renderiza sem overflow em mobile (390x844) e desktop (1024x768)', (tester) async {
      final fichaGateway = FichaMockGateway(ficha: fichaCadastrada);
      final participacaoGateway = ParticipacaoMockGateway(
        participacoesIniciais: [participacaoValida],
      );
      final termoGateway = MemoriaTermoGateway();

      // Teste Mobile
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoFake,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Teste Desktop
      tester.view.physicalSize = const Size(1024 * 2, 768 * 2);
      await tester.pumpWidget(criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoFake,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('resiliência: falha no gateway de termos não derruba o carregamento da ficha', (tester) async {
      final fichaGateway = FichaMockGateway(ficha: fichaCadastrada);
      final participacaoGateway = ParticipacaoMockGateway(
        participacoesIniciais: [participacaoValida],
      );
      final termoGateway = MemoriaTermoGateway(
        lancarErroAoObter: 'Falha simulada no serviço de termos',
      );

      await tester.pumpWidget(criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoFake,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ));
      await tester.pumpAndSettle();

      // Tela carrega com sucesso os dados da ficha e não exibe erro global
      expect(find.text('Nome Completo'), findsOneWidget);
      expect(find.text('João da Silva'), findsWidgets);
      expect(find.text('Não foi possível carregar os dados da ficha. Tente novamente.'), findsNothing);
    });

    testWidgets('exibe aviso e não inventa dados quando não houver termo vigente cadastrado', (tester) async {
      final fichaGateway = FichaMockGateway(ficha: fichaCadastrada);
      final participacaoGateway = ParticipacaoMockGateway(
        participacoesIniciais: [participacaoValida],
      );
      final termoGateway = MemoriaTermoGateway(
        semTermoVigente: true, // Sem termo cadastrado
      );

      await tester.pumpWidget(criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoFake,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ));
      await tester.pumpAndSettle();

      final avisoFinder = find.text('Nenhum termo de adesão vigente publicado no momento. Entre em contato com a administração.');
      await tester.ensureVisible(avisoFinder);
      await tester.pumpAndSettle();

      expect(avisoFinder, findsOneWidget);
      expect(find.byKey(const Key('botao_aceitar_termo')), findsNothing);
    });

    testWidgets('botão Histórico de Aceites abre diálogo com histórico do voluntário', (tester) async {
      final fichaComAceite = fichaCadastrada.copyWith(
        termoAceito: const TermoAceitoModel(
          termoId: 'termo-adesao-voluntariado',
          versaoId: 'versao-v1',
          numeroVersao: 1,
          hashSha256: '1111111111111111111111111111111111111111111111111111111111111111',
          aceitoEm: '2026-10-01T12:00:00Z',
          commandId: 'cmd-aceite-v1',
        ),
      );

      final fichaGateway = FichaMockGateway(ficha: fichaComAceite);
      final participacaoGateway = ParticipacaoMockGateway(
        participacoesIniciais: [participacaoValida],
      );
      final termoGateway = MemoriaTermoGateway(
        aceitesIniciais: const [
          ComprovanteAceiteModel(
            id: 'versao-v1',
            uid: 'uid-voluntario-1',
            fichaId: 'uid-voluntario-1',
            termoId: 'termo-adesao-voluntariado',
            versaoId: 'versao-v1',
            numeroVersao: 1,
            hashSha256: '1111111111111111111111111111111111111111111111111111111111111111',
            titulo: 'Termo de Adesão ao Serviço Voluntário Maanaim',
            declaracaoLidoEConcordo: true,
            aceitoEm: '2026-10-01T12:00:00Z',
            commandId: 'cmd-aceite-v1',
          ),
        ],
      );

      await tester.pumpWidget(criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoFake,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('botao_historico_aceites')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('botao_historico_aceites')));
      await tester.pumpAndSettle();

      expect(find.text('Histórico de Aceites Eletrônicos'), findsOneWidget);
      expect(find.text('Versão 1 - Termo de Adesão ao Serviço Voluntário Maanaim'), findsOneWidget);
    });

    test('Round-trip de serialização do TermoAceitoModel em FichaModel', () {
      const termoModel = TermoAceitoModel(
        termoId: 'termo-1',
        versaoId: 'v-1',
        numeroVersao: 1,
        hashSha256: '1111111111111111111111111111111111111111111111111111111111111111',
        titulo: 'Termo Teste',
        aceitoEm: '2026-10-06T12:00:00Z',
        commandId: 'cmd-1',
      );

      final ficha = FichaModel(
        id: 'uid-1',
        nomeCompleto: 'Fulano',
        profissao: 'Dev',
        cpf: '12345678901',
        igrejaId: 'igreja-1',
        estado: 'RASCUNHO',
        versao: 1,
        termoAceito: termoModel,
      );

      final map = ficha.toMap();
      final reconstruida = FichaModel.fromMap(map);

      expect(reconstruida.termoAceito, isNotNull);
      expect(reconstruida.termoAceito!.termoId, 'termo-1');
      expect(reconstruida.termoAceito!.versaoId, 'v-1');
      expect(reconstruida.termoAceito!.numeroVersao, 1);
      expect(reconstruida.termoAceito!.hashSha256, '1111111111111111111111111111111111111111111111111111111111111111');
      expect(reconstruida.termoAceito!.commandId, 'cmd-1');
    });
  });
}
