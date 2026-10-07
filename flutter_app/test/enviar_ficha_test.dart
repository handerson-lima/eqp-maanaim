import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/termo/termo_service.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/minha_ficha_screen.dart';
import 'package:eqp_maanaim/features/voluntario/participacao_service.dart';
import 'package:eqp_maanaim/ui/components/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FichaMockGateway implements FichaGateway {
  FichaMockGateway({
    this.ficha,
    this.falharEnviar = false,
    this.mensagemErroEnviar,
  });

  FichaModel? ficha;
  bool falharEnviar;
  String? mensagemErroEnviar;
  int chamadasEnvio = 0;

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
      estado: ficha?.estado ?? 'RASCUNHO',
      versao: (ficha?.versao ?? 0) + 1,
      termoAceito: ficha?.termoAceito,
    );
    ficha = nova;
    return SalvarFichaResposta(sucesso: true, repetido: false, ficha: nova);
  }

  @override
  Future<EnviarFichaResposta> enviarFichaAprovacao({
    required String commandId,
    int? expectedVersion,
  }) async {
    chamadasEnvio++;
    if (falharEnviar) {
      throw Exception(
        mensagemErroEnviar ?? 'Não foi possível enviar a ficha para aprovação.',
      );
    }
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
  Future<List<ParticipacaoModel>> obterMinhasParticipacoes() async => participacoes;

  @override
  Future<List<ParticipacaoModel>> salvarParticipacoesRascunho(
    List<String> equipeIds, {
    String? commandId,
  }) async {
    return participacoes;
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

class CatalogoMockGateway implements CatalogoGateway {
  @override
  Future<CatalogoResposta> consultar({String? termo}) async {
    return const CatalogoResposta(
      igrejas: [
        IgrejaCatalogo(id: 'igreja-1', nome: 'Igreja Central', codigo: 'IC01', ativo: true),
      ],
      equipes: [
        EquipeCatalogo(id: 'equipe-1', nome: 'Música e Louvor', ativo: true),
      ],
    );
  }
}

void main() {
  final termoVigentePadrao = TermoVigenteModel(
    id: 'versao-1',
    termoId: 'adesao-voluntariado',
    numeroVersao: 1,
    titulo: 'Termo de Adesão ao Serviço Voluntário',
    conteudo: 'Conteúdo institucional do termo de adesão...',
    hashSha256: 'a' * 64,
    publicadoEm: '2026-09-30T10:00:00Z',
  );

  final fichaPronta = FichaModel(
    id: 'uid-teste',
    nomeCompleto: 'Manoel da Silva',
    profissao: 'Engenheiro de Software',
    cpf: '52998224725',
    igrejaId: 'igreja-1',
    estado: 'RASCUNHO',
    versao: 1,
    termoAceito: TermoAceitoModel(
      termoId: 'adesao-voluntariado',
      versaoId: 'versao-1',
      numeroVersao: 1,
      hashSha256: 'a' * 64,
      titulo: 'Termo de Adesão',
      aceitoEm: '2026-10-06T10:30:00Z',
      commandId: 'cmd-aceite-1',
    ),
  );

  final participacaoPronta = [
    const ParticipacaoModel(
      id: 'part-1',
      fichaId: 'uid-teste',
      equipeId: 'equipe-1',
      nomeEquipe: 'Música e Louvor',
      estado: 'RASCUNHO',
      ciclo: 'INICIAL',
      proximaAcao: 'Aguardando envio da ficha',
    ),
  ];

  Widget criarAppTeste({
    required FichaMockGateway fichaGateway,
    required CatalogoMockGateway catalogoGateway,
    required ParticipacaoMockGateway participacaoGateway,
    required TermoGateway termoGateway,
    Size tamanho = const Size(390, 844),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: tamanho),
        child: MinhaFichaScreen(
          fichaGateway: fichaGateway,
          catalogoGateway: catalogoGateway,
          participacaoGateway: participacaoGateway,
          termoGateway: termoGateway,
        ),
      ),
    );
  }

  testWidgets(
      'Story 2.4: Botão de envio permanece desabilitado quando há pendências (sem termo aceito)',
      (tester) async {
    const fichaSemTermo = FichaModel(
      id: 'uid-teste',
      nomeCompleto: 'Manoel da Silva',
      profissao: 'Engenheiro de Software',
      cpf: '52998224725',
      igrejaId: 'igreja-1',
      estado: 'RASCUNHO',
      versao: 1,
    );
    final fichaGateway = FichaMockGateway(ficha: fichaSemTermo);
    final catalogoGateway = CatalogoMockGateway();
    final participacaoGateway = ParticipacaoMockGateway(
      participacoesIniciais: participacaoPronta,
    );
    final termoGateway = MemoriaTermoGateway(termoVigenteInicial: termoVigentePadrao);

    await tester.pumpWidget(
      criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoGateway,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ),
    );
    await tester.pumpAndSettle();

    final botaoFinder = find.byKey(const Key('botao_enviar_ficha_aprovacao'));
    await tester.ensureVisible(botaoFinder);
    await tester.pumpAndSettle();

    expect(find.text('Enviar Ficha para Aprovação'), findsOneWidget);
    final botaoEnvio = tester.widget<PrimaryButton>(botaoFinder);
    expect(botaoEnvio.onPressed, isNull);
  });

  testWidgets(
      'Story 2.4: Botão de envio habilitado com todas as pré-condições satisfeitas; abre diálogo com resumo',
      (tester) async {
    final fichaGateway = FichaMockGateway(ficha: fichaPronta);
    final catalogoGateway = CatalogoMockGateway();
    final participacaoGateway = ParticipacaoMockGateway(
      participacoesIniciais: participacaoPronta,
    );
    final termoGateway = MemoriaTermoGateway(termoVigenteInicial: termoVigentePadrao);

    await tester.pumpWidget(
      criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoGateway,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ),
    );
    await tester.pumpAndSettle();

    final botaoFinder = find.byKey(const Key('botao_enviar_ficha_aprovacao'));
    await tester.ensureVisible(botaoFinder);
    await tester.pumpAndSettle();

    final botaoEnvio = tester.widget<PrimaryButton>(botaoFinder);
    expect(botaoEnvio.onPressed, isNotNull);

    // Clica no botão para abrir o diálogo
    await tester.tap(botaoFinder);
    await tester.pumpAndSettle();

    expect(find.text('Confirmar Envio da Ficha'), findsOneWidget);
    expect(find.text('Manoel da Silva'), findsWidgets);
    expect(find.textContaining('Igreja Central'), findsWidgets);
    expect(find.text('Música e Louvor'), findsWidgets);
    expect(find.text('Versão 1'), findsWidgets);
    expect(find.text('Confirmar e Enviar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    // Clica em Cancelar fecha o diálogo sem enviar
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar Envio da Ficha'), findsNothing);
    expect(fichaGateway.chamadasEnvio, equals(0));
  });

  testWidgets(
      'Story 2.4: Envio com sucesso atualiza para AGUARDANDO_PASTOR_LOCAL, bloqueia formulário e equipes',
      (tester) async {
    final fichaGateway = FichaMockGateway(ficha: fichaPronta);
    final catalogoGateway = CatalogoMockGateway();
    final participacaoGateway = ParticipacaoMockGateway(
      participacoesIniciais: participacaoPronta,
    );
    final termoGateway = MemoriaTermoGateway(termoVigenteInicial: termoVigentePadrao);

    await tester.pumpWidget(
      criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoGateway,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ),
    );
    await tester.pumpAndSettle();

    final botaoFinder = find.byKey(const Key('botao_enviar_ficha_aprovacao'));
    await tester.ensureVisible(botaoFinder);
    await tester.pumpAndSettle();

    // Abre diálogo e confirma envio
    await tester.tap(botaoFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('botao_confirmar_envio_dialogo')));
    await tester.pumpAndSettle();

    expect(fichaGateway.chamadasEnvio, equals(1));

    // SnackBar de sucesso
    expect(
      find.text('Ficha enviada com sucesso para aprovação do Pastor Local!'),
      findsOneWidget,
    );

    // Status consolidado exibido na seção dedicada
    expect(find.text('Status da Solicitação'), findsWidgets);
    expect(find.text('Ficha Enviada com Sucesso'), findsOneWidget);
    expect(find.text('Avaliação e manifestação pastoral'), findsWidgets);

    // Verifica campos em modo somente leitura
    final campoNome = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('campo_nome_completo')),
        matching: find.byType(TextField),
      ),
    );
    expect(campoNome.readOnly, isTrue);

    final campoProfissao = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('campo_profissao')),
        matching: find.byType(TextField),
      ),
    );
    expect(campoProfissao.readOnly, isTrue);

    final campoCpf = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('campo_cpf')),
        matching: find.byType(TextField),
      ),
    );
    expect(campoCpf.readOnly, isTrue);

    // Botão de salvar ficha desabilitado
    final botaoSalvar = tester.widget<PrimaryButton>(
      find.byKey(const Key('botao_salvar_ficha')),
    );
    expect(botaoSalvar.onPressed, isNull);

    // Botão de remover equipe NÃO deve estar presente
    expect(find.byKey(const Key('botao_remover_equipe_equipe-1')), findsNothing);

    // Botão de salvar equipes desabilitado
    final botaoSalvarEq = tester.widget<PrimaryButton>(
      find.byKey(const Key('botao_salvar_equipes')),
    );
    expect(botaoSalvarEq.onPressed, isNull);

    // Participação exibindo próxima ação atualizada
    expect(
      find.text('Aguardando avaliação do Pastor Local'),
      findsWidgets,
    );
  });

  testWidgets(
      'Story 2.4: Trata erro do backend ao enviar e apresenta feedback ao voluntário',
      (tester) async {
    final fichaGateway = FichaMockGateway(
      ficha: fichaPronta,
      falharEnviar: true,
      mensagemErroEnviar: 'O termo de voluntariado vigente precisa ser aceito antes do envio.',
    );
    final catalogoGateway = CatalogoMockGateway();
    final participacaoGateway = ParticipacaoMockGateway(
      participacoesIniciais: participacaoPronta,
    );
    final termoGateway = MemoriaTermoGateway(termoVigenteInicial: termoVigentePadrao);

    await tester.pumpWidget(
      criarAppTeste(
        fichaGateway: fichaGateway,
        catalogoGateway: catalogoGateway,
        participacaoGateway: participacaoGateway,
        termoGateway: termoGateway,
      ),
    );
    await tester.pumpAndSettle();

    final botaoFinder = find.byKey(const Key('botao_enviar_ficha_aprovacao'));
    await tester.ensureVisible(botaoFinder);
    await tester.pumpAndSettle();

    await tester.tap(botaoFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('botao_confirmar_envio_dialogo')));
    await tester.pumpAndSettle();

    expect(
      find.text('O termo de voluntariado vigente precisa ser aceito antes do envio.'),
      findsWidgets,
    );
  });

  testWidgets(
      'Story 2.4: Renderiza sem overflow em mobile (390x844) e desktop (1024x768)',
      (tester) async {
    final fichaGateway = FichaMockGateway(ficha: fichaPronta);
    final catalogoGateway = CatalogoMockGateway();
    final participacaoGateway = ParticipacaoMockGateway(
      participacoesIniciais: participacaoPronta,
    );
    final termoGateway = MemoriaTermoGateway(termoVigenteInicial: termoVigentePadrao);

    for (final size in const [Size(390, 844), Size(1024, 768)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        criarAppTeste(
          fichaGateway: fichaGateway,
          catalogoGateway: catalogoGateway,
          participacaoGateway: participacaoGateway,
          termoGateway: termoGateway,
          tamanho: size,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }
  });
}
