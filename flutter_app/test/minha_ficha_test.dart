import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/voluntario/minha_ficha_screen.dart';
import 'package:eqp_maanaim/ui/components/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class FichaFake implements FichaGateway {
  FichaFake({
    this.fichaInicial,
    this.falharObter = false,
    this.falharSalvar = false,
    this.erroSalvarMensagem,
  });

  FichaModel? fichaInicial;
  bool falharObter;
  bool falharSalvar;
  String? erroSalvarMensagem;
  SalvarFichaEntrada? ultimaEntrada;
  int chamadasSalvar = 0;
  int chamadasObter = 0;

  @override
  Future<ObterFichaResposta> obterMinhaFicha() async {
    chamadasObter++;
    if (falharObter) {
      throw Exception('Falha simulada ao obter ficha');
    }
    if (fichaInicial == null) {
      return const ObterFichaResposta(existe: false);
    }
    return ObterFichaResposta(existe: true, ficha: fichaInicial);
  }

  @override
  Future<SalvarFichaResposta> salvarMinhaFicha(SalvarFichaEntrada entrada) async {
    chamadasSalvar++;
    ultimaEntrada = entrada;
    if (falharSalvar) {
      throw Exception(erroSalvarMensagem ?? 'Erro ao salvar ficha');
    }
    final novaFicha = FichaModel(
      id: 'uid-voluntario-123',
      nomeCompleto: entrada.nomeCompleto,
      profissao: entrada.profissao,
      cpf: entrada.cpf,
      igrejaId: entrada.igrejaId,
      estado: fichaInicial?.estado ?? 'RASCUNHO',
      versao: (fichaInicial?.versao ?? 0) + 1,
      atualizadoEm: '2026-09-30T18:00:00Z',
    );
    fichaInicial = novaFicha;
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
    final novaVersao = (fichaInicial?.versao ?? 1) + 1;
    fichaInicial = fichaInicial?.copyWith(
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      versao: novaVersao,
    );
    return EnviarFichaResposta(
      sucesso: true,
      repetido: false,
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      versao: novaVersao,
      proximaAcao: 'Aguardando avaliação do Pastor Local',
      igrejaId: fichaInicial?.igrejaId ?? '',
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

void main() {
  final igrejasPadrao = [
    const IgrejaCatalogo(
      id: 'ig-central',
      nome: 'Igreja Central',
      codigo: '001',
      ativo: true,
    ),
    const IgrejaCatalogo(
      id: 'ig-norte',
      nome: 'Igreja Norte',
      codigo: '002',
      ativo: true,
    ),
  ];

  Widget criarApp(FichaFake fichaFake, CatalogoFake catalogoFake) {
    return MaterialApp(
      home: MinhaFichaScreen(
        fichaGateway: fichaFake,
        catalogoGateway: catalogoFake,
        userName: 'Voluntário Teste',
      ),
    );
  }

  testWidgets(
      'exibe estado inicial de rascunho com campos pendentes quando não há ficha cadastrada',
      (tester) async {
    final fichaFake = FichaFake();
    final catalogoFake = CatalogoFake(
      resposta: CatalogoResposta(igrejas: igrejasPadrao, equipes: const []),
    );

    await tester.pumpWidget(criarApp(fichaFake, catalogoFake));
    await tester.pumpAndSettle();

    expect(find.text('Minha Ficha'), findsWidgets);
    expect(find.text('RASCUNHO'), findsWidgets);
    expect(find.text('Campos pendentes para avanço futuro:'), findsOneWidget);
    expect(find.textContaining('Nome Completo'), findsWidgets);
    expect(find.textContaining('Profissão'), findsWidgets);
    expect(find.textContaining('CPF válido'), findsOneWidget);
    expect(find.textContaining('Igreja Local'), findsWidgets);
    // Aviso de privacidade/retenção (AD-12) visível na ficha do voluntário.
    expect(find.byKey(const Key('politica_privacidade_card')), findsOneWidget);
  });

  testWidgets(
      'carrega dados existentes da ficha permanente e mostra banner de pronto quando todos campos são válidos',
      (tester) async {
    final fichaInicial = const FichaModel(
      id: 'uid-vol-01',
      nomeCompleto: 'Gabriel Souza',
      profissao: 'Eletricista',
      cpf: '52998224725',
      igrejaId: 'ig-central',
      estado: 'RASCUNHO',
      versao: 1,
      atualizadoEm: '2026-09-30T15:30:00Z',
    );

    final fichaFake = FichaFake(fichaInicial: fichaInicial);
    final catalogoFake = CatalogoFake(
      resposta: CatalogoResposta(igrejas: igrejasPadrao, equipes: const []),
    );

    await tester.pumpWidget(criarApp(fichaFake, catalogoFake));
    await tester.pumpAndSettle();

    expect(find.text('Gabriel Souza'), findsWidgets);
    expect(find.text('Eletricista'), findsOneWidget);
    expect(find.text('52998224725'), findsOneWidget);
    expect(find.text('Ficha pronta para avanço'), findsOneWidget);
    expect(find.text('Versão: 1'), findsOneWidget);
  });

  testWidgets('rejeita salvamento se CPF for inválido', (tester) async {
    final fichaFake = FichaFake();
    final catalogoFake = CatalogoFake(
      resposta: CatalogoResposta(igrejas: igrejasPadrao, equipes: const []),
    );

    await tester.pumpWidget(criarApp(fichaFake, catalogoFake));
    await tester.pumpAndSettle();

    // Preenche nome e profissão válidos, mas CPF inválido
    await tester.enterText(find.byKey(const Key('campo_nome_completo')), 'Gabriel Souza');
    await tester.enterText(find.byKey(const Key('campo_profissao')), 'Eletricista');
    await tester.enterText(find.byKey(const Key('campo_cpf')), '111.111.111-11');
    await tester.pumpAndSettle();

    // Seleciona igreja no dropdown
    final campoIgreja = find.byKey(const Key('campo_igreja'));
    await tester.ensureVisible(campoIgreja);
    await tester.tap(campoIgreja);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Igreja Central - 001').last);
    await tester.pumpAndSettle();

    // Clica em salvar
    final botaoSalvar = find.byKey(const Key('botao_salvar_ficha'));
    await tester.ensureVisible(botaoSalvar);
    await tester.tap(botaoSalvar);
    await tester.pumpAndSettle();

    // Deve mostrar mensagem de CPF inválido e não chamar o backend
    expect(find.text('Informe um CPF válido.'), findsOneWidget);
    expect(fichaFake.chamadasSalvar, 0);
  });

  testWidgets('salva rascunho com sucesso e atualiza versão e estado',
      (tester) async {
    final fichaFake = FichaFake();
    final catalogoFake = CatalogoFake(
      resposta: CatalogoResposta(igrejas: igrejasPadrao, equipes: const []),
    );

    await tester.pumpWidget(criarApp(fichaFake, catalogoFake));
    await tester.pumpAndSettle();

    // Preenche todos os campos com dados válidos
    await tester.enterText(find.byKey(const Key('campo_nome_completo')), 'Manoel da Silva');
    await tester.enterText(find.byKey(const Key('campo_profissao')), 'Carpinteiro');
    await tester.enterText(find.byKey(const Key('campo_cpf')), '529.982.247-25');
    await tester.pumpAndSettle();

    // Seleciona igreja
    final campoIgreja = find.byKey(const Key('campo_igreja'));
    await tester.ensureVisible(campoIgreja);
    await tester.tap(campoIgreja);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Igreja Central - 001').last);
    await tester.pumpAndSettle();

    // Clica em salvar ficha
    final botaoSalvar = find.byKey(const Key('botao_salvar_ficha'));
    await tester.ensureVisible(botaoSalvar);
    await tester.tap(botaoSalvar);
    await tester.pumpAndSettle();

    expect(fichaFake.chamadasSalvar, 1);
    expect(fichaFake.ultimaEntrada?.nomeCompleto, 'Manoel da Silva');
    expect(fichaFake.ultimaEntrada?.profissao, 'Carpinteiro');
    expect(fichaFake.ultimaEntrada?.cpf, '529.982.247-25');
    expect(fichaFake.ultimaEntrada?.igrejaId, 'ig-central');

    // Confirma feedback de sucesso e incremento de versão
    expect(find.text('Ficha salva com sucesso.'), findsWidgets);
    expect(find.text('Versão: 1'), findsOneWidget);
    expect(find.text('Ficha pronta para avanço'), findsOneWidget);
  });

  testWidgets('trata erro retornado pelo backend ao salvar', (tester) async {
    final fichaFake = FichaFake(
      falharSalvar: true,
      erroSalvarMensagem: 'CPF inválido',
    );
    final catalogoFake = CatalogoFake(
      resposta: CatalogoResposta(igrejas: igrejasPadrao, equipes: const []),
    );

    await tester.pumpWidget(criarApp(fichaFake, catalogoFake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('campo_nome_completo')), 'Manoel da Silva');
    await tester.enterText(find.byKey(const Key('campo_profissao')), 'Carpinteiro');
    await tester.enterText(find.byKey(const Key('campo_cpf')), '529.982.247-25');
    await tester.pumpAndSettle();

    final campoIgreja = find.byKey(const Key('campo_igreja'));
    await tester.ensureVisible(campoIgreja);
    await tester.tap(campoIgreja);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Igreja Central - 001').last);
    await tester.pumpAndSettle();

    final botaoSalvar = find.byKey(const Key('botao_salvar_ficha'));
    await tester.ensureVisible(botaoSalvar);
    await tester.tap(botaoSalvar);
    await tester.pumpAndSettle();

    expect(find.textContaining('CPF inválido'), findsWidgets);
  });

  testWidgets(
      'trata falha no carregamento inicial com tela de erro e botão de tentar novamente',
      (tester) async {
    final fichaFake = FichaFake(falharObter: true);
    final catalogoFake = CatalogoFake(
      resposta: CatalogoResposta(igrejas: igrejasPadrao, equipes: const []),
    );

    await tester.pumpWidget(criarApp(fichaFake, catalogoFake));
    await tester.pumpAndSettle();

    expect(find.text('Erro ao carregar ficha'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    // Corrige a falha e tenta novamente
    fichaFake.falharObter = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Minha Ficha'), findsWidgets);
    expect(find.byKey(const Key('campo_nome_completo')), findsOneWidget);
  });

  testWidgets('renderiza sem overflow em mobile (390x844) e desktop (1024x768)',
      (tester) async {
    final fichaFake = FichaFake();
    final catalogoFake = CatalogoFake(
      resposta: CatalogoResposta(igrejas: igrejasPadrao, equipes: const []),
    );

    // Mobile
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(criarApp(fichaFake, catalogoFake));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Minha Ficha'), findsWidgets);

    // Desktop
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'permite alterar e salvar a igreja local mesmo quando a ficha está em avaliação',
      (tester) async {
    final fichaFake = FichaFake(
      fichaInicial: const FichaModel(
        id: 'ficha-01',
        nomeCompleto: 'Gabriel Silva',
        profissao: 'Engenheiro',
        cpf: '529.982.247-25',
        igrejaId: 'ig-central',
        estado: 'AGUARDANDO_PASTOR_LOCAL',
        versao: 1,
      ),
    );
    final catalogoFake = CatalogoFake(
      resposta: CatalogoResposta(
        igrejas: [
          ...igrejasPadrao,
          const IgrejaCatalogo(
            id: 'ig-bairro',
            nome: 'Igreja do Bairro',
            codigo: '002',
            ativo: true,
          ),
        ],
        equipes: const [],
      ),
    );

    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    await tester.pumpWidget(criarApp(fichaFake, catalogoFake));
    await tester.pumpAndSettle();

    // Campos de nome, profissão e CPF devem estar em modo somente leitura
    final campoNome = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('campo_nome_completo')),
        matching: find.byType(TextField),
      ),
    );
    expect(campoNome.readOnly, isTrue);

    // Dropdown de igreja está habilitado
    final campoIgreja = find.byKey(const Key('campo_igreja'));
    expect(campoIgreja, findsOneWidget);

    // Botão de salvar inicialmente desabilitado enquanto não alterar a igreja
    final botaoSalvar = tester.widget<PrimaryButton>(
      find.byKey(const Key('botao_salvar_ficha')),
    );
    expect(botaoSalvar.onPressed, isNull);

    // Altera a igreja local
    await tester.ensureVisible(campoIgreja);
    await tester.tap(campoIgreja);
    await tester.pumpAndSettle();
    final opcaoIgreja = find.text('Igreja do Bairro - 002').last;
    await tester.ensureVisible(opcaoIgreja);
    await tester.tap(opcaoIgreja);
    await tester.pumpAndSettle();

    // Agora o botão de salvar está habilitado
    final botaoSalvarHabilitado = tester.widget<PrimaryButton>(
      find.byKey(const Key('botao_salvar_ficha')),
    );
    expect(botaoSalvarHabilitado.onPressed, isNotNull);

    // Clica em salvar
    final btnSalvar = find.byKey(const Key('botao_salvar_ficha'));
    await tester.ensureVisible(btnSalvar);
    await tester.tap(btnSalvar);
    await tester.pumpAndSettle();

    // Verifica que salvou com a nova igreja mantendo os demais dados
    expect(fichaFake.chamadasSalvar, 1);
    expect(fichaFake.ultimaEntrada?.igrejaId, 'ig-bairro');
    expect(fichaFake.ultimaEntrada?.nomeCompleto, 'Gabriel Silva');
    expect(find.text('Ficha salva com sucesso.'), findsWidgets);
  });

  testWidgets('organiza igrejas em ordem alfabética no dropdown de seleção',
      (tester) async {
    final igrejasDesordenadas = [
      const IgrejaCatalogo(
        id: 'ig-z',
        nome: 'Zumbi',
        codigo: '003',
        ativo: true,
      ),
      const IgrejaCatalogo(
        id: 'ig-a',
        nome: 'Alecrim',
        codigo: '001',
        ativo: true,
      ),
      const IgrejaCatalogo(
        id: 'ig-m',
        nome: 'Mirassol',
        codigo: '002',
        ativo: true,
      ),
    ];
    final fichaFake = FichaFake();
    final catalogoFake = CatalogoFake(
      resposta: CatalogoResposta(
        igrejas: igrejasDesordenadas,
        equipes: const [],
      ),
    );

    await tester.pumpWidget(criarApp(fichaFake, catalogoFake));
    await tester.pumpAndSettle();

    final campoIgreja = find.byKey(const Key('campo_igreja'));
    await tester.ensureVisible(campoIgreja);
    await tester.tap(campoIgreja);
    await tester.pumpAndSettle();

    final itens = tester
        .widgetList<DropdownMenuItem<String>>(
          find.byType(DropdownMenuItem<String>),
        )
        .toList();

    expect(itens.map((i) => i.value).toList(), ['ig-a', 'ig-m', 'ig-z']);
  });
}

