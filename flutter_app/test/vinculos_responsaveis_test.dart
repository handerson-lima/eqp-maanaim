import 'package:eqp_maanaim/features/admin/admin_shell.dart';
import 'package:eqp_maanaim/features/admin/pessoas_service.dart';
import 'package:eqp_maanaim/features/admin/vinculos_responsaveis.dart';
import 'package:eqp_maanaim/features/admin/vinculos_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _pessoas = <PessoaAdministrativa>[
  PessoaAdministrativa(
    uid: 'p2',
    nomeCompleto: 'Maria Souza',
    email: 'maria@exemplo.com',
    papeis: [],
    versao: 0,
    coordenador: false,
  ),
  PessoaAdministrativa(
    uid: 'p3',
    nomeCompleto: 'Pedro Alves',
    email: 'pedro@exemplo.com',
    papeis: [],
    versao: 0,
    coordenador: false,
  ),
];

final _igrejas = <ItemVinculo>[
  ItemVinculo(
    id: 'ig1',
    tipoEntidade: 'IGREJA',
    rotulo: 'Goianinha - 240008',
    codigo: '240008',
    ativo: true,
    versaoVinculo: 2,
    responsavel: const ResponsavelVigente(
      pessoaId: 'p1',
      nome: 'João Batista',
    ),
    historico: [
      EventoHistoricoVinculo(
        acao: 'SUBSTITUIR',
        papel: 'PASTOR_LOCAL',
        estado: 'VIGENTE',
        atorUid: 'admin1',
        atorNome: 'Administrador',
        inicioVigencia: DateTime.utc(2020, 1, 5),
        justificativa: 'troca pastoral',
      ),
    ],
  ),
  const ItemVinculo(
    id: 'ig2',
    tipoEntidade: 'IGREJA',
    rotulo: 'Mossoró - 240006',
    codigo: '240006',
    ativo: true,
    versaoVinculo: 0,
  ),
];

const _equipes = <ItemVinculo>[
  ItemVinculo(
    id: 'eq1',
    tipoEntidade: 'EQUIPE',
    rotulo: 'Apoio',
    ativo: true,
    versaoVinculo: 0,
  ),
];

final _resposta = VinculosResposta(igrejas: _igrejas, equipes: _equipes);

Future<void> _abrir(WidgetTester tester, VinculosFake gateway) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: VinculosResponsaveis(gateway))),
  );
}

void main() {
  testWidgets('lista responsável vigente e linha do tempo read-only', (
    tester,
  ) async {
    await _abrir(
      tester,
      VinculosFake(resposta: _resposta, pessoas: _pessoas),
    );
    await tester.pumpAndSettle();
    expect(find.text('Goianinha - 240008'), findsOneWidget);
    expect(find.text('Vigente: João Batista'), findsOneWidget);
    expect(find.textContaining('Data da troca: 05/01/2020'), findsOneWidget);
    expect(find.text('Sem responsável vigente'), findsOneWidget);
    expect(find.text('Substituir responsável'), findsOneWidget);

    await tester.tap(find.text('Linha do tempo (somente leitura)').first);
    await tester.pumpAndSettle();
    expect(find.text('Substituição · Pastor Local'), findsOneWidget);
    expect(find.textContaining('Ator: Administrador'), findsOneWidget);
    expect(find.textContaining('Início: 05/01/2020 (vigente)'), findsOneWidget);
    expect(find.textContaining('Justificativa: troca pastoral'), findsOneWidget);
  });

  testWidgets('estado vazio é anunciado acessivelmente', (tester) async {
    await _abrir(tester, VinculosFake());
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma igreja cadastrada.'), findsOneWidget);
  });

  testWidgets('erro mostra mensagem e retentativa recarrega', (tester) async {
    final gateway = VinculosFake()..falhar = true;
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar os vínculos.'),
      findsOneWidget,
    );

    gateway
      ..falhar = false
      ..resposta = _resposta;
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Goianinha - 240008'), findsOneWidget);
    expect(gateway.consultas, 2);
  });

  testWidgets('atribuição exige pessoa, data efetiva e confirmação', (
    tester,
  ) async {
    final gateway = VinculosFake(resposta: _resposta, pessoas: _pessoas);
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atribuir responsável'));
    await tester.pumpAndSettle();
    expect(find.text('Selecionar pessoa'), findsOneWidget);
    await tester.tap(find.text('Maria Souza'));
    await tester.pumpAndSettle();

    expect(find.text('Atribuir responsável'), findsWidgets);
    expect(find.text('Nova pessoa: Maria Souza'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar Pastor Local'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(gateway.gerenciamentos, 1);
    expect(gateway.ultimoAcao, 'ATRIBUIR');
    expect(gateway.ultimoTipoEntidade, 'IGREJA');
    expect(gateway.ultimoEntidadeId, 'ig2');
    expect(gateway.ultimoPessoaId, 'p2');
    expect(gateway.ultimaVersao, 0);
    expect(gateway.ultimaData, isNotNull);
    expect(find.text('Responsável atribuído.'), findsOneWidget);
  });

  testWidgets('substituição mostra responsável atual e envia a versão', (
    tester,
  ) async {
    final gateway = VinculosFake(resposta: _resposta, pessoas: _pessoas);
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Substituir responsável'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedro Alves'));
    await tester.pumpAndSettle();
    expect(find.text('Responsável atual: João Batista'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar Pastor Local'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(gateway.gerenciamentos, 1);
    expect(gateway.ultimoAcao, 'SUBSTITUIR');
    expect(gateway.ultimoEntidadeId, 'ig1');
    expect(gateway.ultimoPessoaId, 'p3');
    expect(gateway.ultimaVersao, 2);
  });

  testWidgets('encerramento não pede pessoa e confirma o vínculo', (
    tester,
  ) async {
    final gateway = VinculosFake(resposta: _resposta, pessoas: _pessoas);
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Encerrar vínculo'));
    await tester.pumpAndSettle();
    expect(find.text('Selecionar pessoa'), findsNothing);
    expect(find.text('Responsável atual: João Batista'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(gateway.gerenciamentos, 1);
    expect(gateway.ultimoAcao, 'ENCERRAR');
    expect(gateway.ultimoPessoaId, isNull);
    expect(find.text('Vínculo encerrado.'), findsOneWidget);
  });

  testWidgets('falha de mutação é anunciada sem recarregar em loop', (
    tester,
  ) async {
    final gateway = VinculosFake(resposta: _resposta, pessoas: _pessoas)
      ..gerenciarFalhar = true;
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Encerrar vínculo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Não foi possível concluir a operação'),
      findsOneWidget,
    );
    expect(gateway.consultas, 1);

    await tester.tap(find.widgetWithText(TextButton, 'Recarregar'));
    await tester.pumpAndSettle();
    expect(gateway.consultas, 2);
  });

  testWidgets('pesquisa filtra por nome sem acento e por código', (tester) async {
    await _abrir(
      tester,
      VinculosFake(resposta: _resposta, pessoas: _pessoas),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'goianinha');
    await tester.pumpAndSettle();
    expect(find.text('Goianinha - 240008'), findsOneWidget);
    expect(find.text('Mossoró - 240006'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '240006');
    await tester.pumpAndSettle();
    expect(find.text('Mossoró - 240006'), findsOneWidget);
    expect(find.text('Goianinha - 240008'), findsNothing);
  });

  testWidgets('seletor de data limita ao início vigente e a hoje', (tester) async {
    final vigentes = <ItemVinculo>[
      ItemVinculo(
        id: 'ig9',
        tipoEntidade: 'IGREJA',
        rotulo: 'Recente - 240009',
        codigo: '240009',
        ativo: true,
        versaoVinculo: 1,
        responsavel: const ResponsavelVigente(
          pessoaId: 'p1',
          nome: 'João Batista',
        ),
        historico: [
          EventoHistoricoVinculo(
            acao: 'ATRIBUIR',
            papel: 'PASTOR_LOCAL',
            estado: 'VIGENTE',
            atorUid: 'admin1',
            atorNome: 'Administrador',
            inicioVigencia: DateTime.utc(2025, 6, 1),
          ),
        ],
      ),
    ];
    await _abrir(
      tester,
      VinculosFake(
        resposta: VinculosResposta(igrejas: vigentes, equipes: const []),
        pessoas: _pessoas,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Substituir responsável'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedro Alves'));
    await tester.pumpAndSettle();

    final textoData = tester
        .widget<Text>(find.textContaining('Data efetiva:'))
        .data!;
    final partes = textoData.replaceFirst('Data efetiva: ', '').split('/');
    final ultimaEsperada = DateTime(
      int.parse(partes[2]),
      int.parse(partes[1]),
      int.parse(partes[0]),
    );
    await tester.tap(find.textContaining('Data efetiva'));
    await tester.pumpAndSettle();

    final calendario = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(calendario.firstDate, DateTime(2025, 6, 1));
    expect(calendario.lastDate, ultimaEsperada);
  });

  testWidgets('entidade inativa desabilita ações e explica acessivelmente', (
    tester,
  ) async {
    final inativa = <ItemVinculo>[
      ItemVinculo(
        id: 'ig3',
        tipoEntidade: 'IGREJA',
        rotulo: 'Inativa - 240003',
        codigo: '240003',
        ativo: false,
        versaoVinculo: 1,
        responsavel: const ResponsavelVigente(
          pessoaId: 'p1',
          nome: 'João Batista',
        ),
        historico: [
          EventoHistoricoVinculo(
            acao: 'ATRIBUIR',
            papel: 'PASTOR_LOCAL',
            estado: 'VIGENTE',
            atorUid: 'admin1',
            atorNome: 'Administrador',
            inicioVigencia: DateTime.utc(2025, 6, 1),
          ),
        ],
      ),
    ];
    await _abrir(
      tester,
      VinculosFake(
        resposta: VinculosResposta(igrejas: inativa, equipes: const []),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Igreja/equipe inativa: as ações de vínculo estão indisponíveis.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Substituir responsável'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Encerrar vínculo'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('atribuição em equipe usa o papel de responsável', (
    tester,
  ) async {
    final gateway = VinculosFake(resposta: _resposta, pessoas: _pessoas);
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atribuir responsável'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maria Souza'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar Responsável'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(gateway.ultimoTipoEntidade, 'EQUIPE');
    expect(gateway.ultimoEntidadeId, 'eq1');
    expect(gateway.ultimoAcao, 'ATRIBUIR');
  });

  testWidgets('linha do tempo mostra o fim de um vínculo encerrado', (
    tester,
  ) async {
    final comEncerrado = <ItemVinculo>[
      ItemVinculo(
        id: 'ig4',
        tipoEntidade: 'IGREJA',
        rotulo: 'Com histórico - 240004',
        codigo: '240004',
        ativo: true,
        versaoVinculo: 1,
        responsavel: const ResponsavelVigente(
          pessoaId: 'p1',
          nome: 'João Batista',
        ),
        historico: [
          EventoHistoricoVinculo(
            acao: 'ENCERRAR',
            papel: 'PASTOR_LOCAL',
            estado: 'ENCERRADO',
            atorUid: 'admin1',
            atorNome: 'Administrador',
            inicioVigencia: DateTime.utc(2024, 1, 1),
            fimVigencia: DateTime.utc(2024, 6, 1),
          ),
        ],
      ),
    ];
    await _abrir(
      tester,
      VinculosFake(
        resposta: VinculosResposta(igrejas: comEncerrado, equipes: const []),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Linha do tempo (somente leitura)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fim: 01/06/2024'), findsOneWidget);
  });

  testWidgets('busca sem resultado é anunciada', (tester) async {
    await _abrir(
      tester,
      VinculosFake(resposta: _resposta, pessoas: _pessoas),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'zzz-inexistente');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum resultado encontrado.'), findsOneWidget);
  });

  testWidgets('catálogo de equipes vazio é anunciado', (tester) async {
    await _abrir(
      tester,
      VinculosFake(
        resposta: VinculosResposta(igrejas: _igrejas, equipes: const []),
        pessoas: _pessoas,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipes'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma equipe cadastrada.'), findsOneWidget);
  });

  testWidgets('falha ao carregar pessoas é anunciada no seletor', (
    tester,
  ) async {
    final gateway = VinculosFake(resposta: _resposta, pessoas: _pessoas)
      ..buscarPessoasFalhar = true;
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atribuir responsável'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar as pessoas.'), findsOneWidget);
  });

  testWidgets('troca para a aba de equipes', (tester) async {
    await _abrir(
      tester,
      VinculosFake(resposta: _resposta, pessoas: _pessoas),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipes'));
    await tester.pumpAndSettle();
    expect(find.text('Apoio'), findsOneWidget);
    expect(find.text('Atribuir responsável'), findsOneWidget);
  });

  testWidgets('AdminShell conecta a superfície de Vínculos e Responsáveis', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminShell(
          onSair: () {},
          catalogo: CatalogoFake(),
          seed: SeedFake(),
          pessoas: PessoasFake(),
          vinculos: VinculosFake(resposta: _resposta, pessoas: _pessoas),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vínculos e Responsáveis'));
    await tester.pumpAndSettle();
    expect(find.byType(VinculosResponsaveis), findsOneWidget);
    expect(find.text('Goianinha - 240008'), findsOneWidget);
  });

  group('Story 8.12 — Modo Centrado no Pastor / Responsável', () {
    const pastorMaria = PessoaAdministrativa(
      uid: 'p2',
      nomeCompleto: 'Maria Souza',
      email: 'maria@exemplo.com',
      papeis: [],
      versao: 0,
      coordenador: false,
    );

    final igrejasMultiplas = <ItemVinculo>[
      ItemVinculo(
        id: 'ig1',
        tipoEntidade: 'IGREJA',
        rotulo: 'Goianinha - 240008',
        codigo: '240008',
        ativo: true,
        versaoVinculo: 2,
        responsavel: const ResponsavelVigente(
          pessoaId: 'p1',
          nome: 'João Batista',
        ),
      ),
      const ItemVinculo(
        id: 'ig2',
        tipoEntidade: 'IGREJA',
        rotulo: 'Mossoró - 240006',
        codigo: '240006',
        ativo: true,
        versaoVinculo: 1,
      ),
      const ItemVinculo(
        id: 'ig3',
        tipoEntidade: 'IGREJA',
        rotulo: 'Caicó - 240005',
        codigo: '240005',
        ativo: true,
        versaoVinculo: 3,
      ),
    ];

    Future<void> abrirModoPastor(
      WidgetTester tester,
      VinculosFake gateway, {
      PessoaAdministrativa? pastorInicial,
      Size size = const Size(1200, 900),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VinculosResponsaveis(
              gateway,
              pastorInicial: pastorInicial,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('ativa modo centrado no pastor pelo botão da tela inicial', (
      tester,
    ) async {
      final gateway = VinculosFake(
        resposta: VinculosResposta(
          igrejas: igrejasMultiplas,
          equipes: const [],
        ),
        pessoas: _pessoas,
      );
      await abrirModoPastor(tester, gateway);

      expect(find.text('Gestão Centrada no Pastor / Responsável'), findsOneWidget);
      await tester.tap(find.text('Vincular por pastor'));
      await tester.pumpAndSettle();

      expect(find.text('Selecionar pessoa'), findsOneWidget);
      await tester.tap(find.text('Maria Souza'));
      await tester.pumpAndSettle();

      expect(find.text('Maria Souza'), findsWidgets);
      expect(find.text('Pastor Local'), findsWidgets);
      expect(find.textContaining('0 igreja(s)'), findsOneWidget);
      expect(find.text('Painel de Revisão e Ações'), findsOneWidget);
    });

    testWidgets('layout desktop exibe 2 colunas e mobile exibe empilhado', (
      tester,
    ) async {
      final gateway = VinculosFake(
        resposta: VinculosResposta(
          igrejas: igrejasMultiplas,
          equipes: const [],
        ),
        pessoas: _pessoas,
      );

      // Desktop
      await abrirModoPastor(
        tester,
        gateway,
        pastorInicial: pastorMaria,
        size: const Size(1200, 900),
      );
      expect(find.text('Painel de Revisão e Ações'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(3));

      // Mobile
      await abrirModoPastor(
        tester,
        gateway,
        pastorInicial: pastorMaria,
        size: const Size(500, 900),
      );
      expect(find.text('Painel de Revisão e Ações'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
    });

    testWidgets('duas inclusões no lote executam comandos individuais com commandId e expectedVersion', (
      tester,
    ) async {
      final gateway = VinculosFake(
        resposta: VinculosResposta(
          igrejas: igrejasMultiplas,
          equipes: const [],
        ),
        pessoas: _pessoas,
      );
      await abrirModoPastor(tester, gateway, pastorInicial: pastorMaria);

      // Marca Mossoró (ig2) e Caicó (ig3)
      final cbMossoro = find.widgetWithText(CheckboxListTile, 'Mossoró - 240006');
      final cbCaico = find.widgetWithText(CheckboxListTile, 'Caicó - 240005');
      await tester.tap(cbMossoro);
      await tester.pumpAndSettle();
      await tester.tap(cbCaico);
      await tester.pumpAndSettle();

      expect(find.text('Revisar e Salvar Vínculos (2)'), findsOneWidget);

      await tester.tap(find.text('Revisar e Salvar Vínculos (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Revisão de Vínculos em Lote'), findsOneWidget);
      expect(find.text('2 inclusão(ões)'), findsOneWidget);

      await tester.tap(find.text('Confirmar e Salvar Vínculos'));
      await tester.pumpAndSettle();

      expect(gateway.chamadasGerenciar.length, 2);
      expect(gateway.chamadasGerenciar[0]['acao'], 'ATRIBUIR');
      expect(gateway.chamadasGerenciar[0]['pessoaId'], 'p2');
      expect(gateway.chamadasGerenciar[0]['entidadeId'], 'ig2');
      expect(gateway.chamadasGerenciar[0]['versao'], 1);

      expect(gateway.chamadasGerenciar[1]['acao'], 'ATRIBUIR');
      expect(gateway.chamadasGerenciar[1]['pessoaId'], 'p2');
      expect(gateway.chamadasGerenciar[1]['entidadeId'], 'ig3');
      expect(gateway.chamadasGerenciar[1]['versao'], 3);

      // Comandos possuem commandIds distintos
      expect(
        gateway.chamadasGerenciar[0]['commandId'],
        isNot(equals(gateway.chamadasGerenciar[1]['commandId'])),
      );

      expect(find.textContaining('2 concluído(s) com sucesso'), findsOneWidget);
    });

    testWidgets('substituição contextual destaca responsável atual e redirecionamento de pendências', (
      tester,
    ) async {
      final gateway = VinculosFake(
        resposta: VinculosResposta(
          igrejas: igrejasMultiplas,
          equipes: const [],
        ),
        pessoas: _pessoas,
      );
      await abrirModoPastor(tester, gateway, pastorInicial: pastorMaria);

      // Goianinha já tem João Batista como responsável
      final cbGoianinha = find.widgetWithText(CheckboxListTile, 'Goianinha - 240008');
      await tester.tap(cbGoianinha);
      await tester.pumpAndSettle();

      expect(find.textContaining('Substitui João Batista'), findsWidgets);
      await tester.tap(find.text('Revisar e Salvar Vínculos (1)'));
      await tester.pumpAndSettle();

      expect(find.text('1 substituição(ões)'), findsOneWidget);
      expect(find.textContaining('apenas pendências não decididas serão redirecionadas'), findsOneWidget);

      await tester.tap(find.text('Confirmar e Salvar Vínculos'));
      await tester.pumpAndSettle();

      expect(gateway.chamadasGerenciar.length, 1);
      expect(gateway.chamadasGerenciar[0]['acao'], 'SUBSTITUIR');
      expect(gateway.chamadasGerenciar[0]['pessoaId'], 'p2');
      expect(gateway.chamadasGerenciar[0]['entidadeId'], 'ig1');
      expect(gateway.chamadasGerenciar[0]['versao'], 2);
    });

    testWidgets('desmarcar igreja já vinculada exige confirmação explícita; cancelar mantém marcada', (
      tester,
    ) async {
      final comMariaVinculada = <ItemVinculo>[
        ItemVinculo(
          id: 'ig1',
          tipoEntidade: 'IGREJA',
          rotulo: 'Goianinha - 240008',
          codigo: '240008',
          ativo: true,
          versaoVinculo: 4,
          responsavel: const ResponsavelVigente(
            pessoaId: 'p2',
            nome: 'Maria Souza',
          ),
        ),
      ];

      final gateway = VinculosFake(
        resposta: VinculosResposta(
          igrejas: comMariaVinculada,
          equipes: const [],
        ),
        pessoas: _pessoas,
      );
      await abrirModoPastor(tester, gateway, pastorInicial: pastorMaria);

      final cb = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Goianinha - 240008'),
      );
      expect(cb.value, isTrue);

      // Clica para desmarcar
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Goianinha - 240008'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar encerramento de vínculo'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Mantém marcado e não há intenção
      final cbApos = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Goianinha - 240008'),
      );
      expect(cbApos.value, isTrue);
      expect(
        find.textContaining('Nenhuma alteração selecionada para este pastor'),
        findsOneWidget,
      );
    });

    testWidgets('desmarcar igreja vigente com confirmação registra encerramento e executa ENCERRAR', (
      tester,
    ) async {
      final comMariaVinculada = <ItemVinculo>[
        ItemVinculo(
          id: 'ig1',
          tipoEntidade: 'IGREJA',
          rotulo: 'Goianinha - 240008',
          codigo: '240008',
          ativo: true,
          versaoVinculo: 4,
          responsavel: const ResponsavelVigente(
            pessoaId: 'p2',
            nome: 'Maria Souza',
          ),
        ),
      ];

      final gateway = VinculosFake(
        resposta: VinculosResposta(
          igrejas: comMariaVinculada,
          equipes: const [],
        ),
        pessoas: _pessoas,
      );
      await abrirModoPastor(tester, gateway, pastorInicial: pastorMaria);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Goianinha - 240008'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Encerramento programado');
      await tester.tap(find.text('Confirmar encerramento'));
      await tester.pumpAndSettle();

      // Checkbox agora é false e aparece como Encerramento
      final cbApos = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Goianinha - 240008'),
      );
      expect(cbApos.value, isFalse);
      expect(find.text('Revisar e Salvar Vínculos (1)'), findsOneWidget);

      await tester.tap(find.text('Revisar e Salvar Vínculos (1)'));
      await tester.pumpAndSettle();

      expect(find.text('1 encerramento(s)'), findsOneWidget);
      await tester.tap(find.text('Confirmar e Salvar Vínculos'));
      await tester.pumpAndSettle();

      expect(gateway.chamadasGerenciar.length, 1);
      expect(gateway.chamadasGerenciar[0]['acao'], 'ENCERRAR');
      expect(gateway.chamadasGerenciar[0]['pessoaId'], isNull);
      expect(gateway.chamadasGerenciar[0]['entidadeId'], 'ig1');
      expect(gateway.chamadasGerenciar[0]['versao'], 4);
      expect(gateway.chamadasGerenciar[0]['justificativa'], 'Encerramento programado');
    });

    testWidgets('item inalterado mantido marcado não gera comando de mutação', (
      tester,
    ) async {
      final dados = <ItemVinculo>[
        ItemVinculo(
          id: 'ig1',
          tipoEntidade: 'IGREJA',
          rotulo: 'Goianinha - 240008',
          codigo: '240008',
          ativo: true,
          versaoVinculo: 4,
          responsavel: const ResponsavelVigente(
            pessoaId: 'p2',
            nome: 'Maria Souza',
          ),
        ),
        const ItemVinculo(
          id: 'ig2',
          tipoEntidade: 'IGREJA',
          rotulo: 'Mossoró - 240006',
          codigo: '240006',
          ativo: true,
          versaoVinculo: 1,
        ),
      ];

      final gateway = VinculosFake(
        resposta: VinculosResposta(igrejas: dados, equipes: const []),
        pessoas: _pessoas,
      );
      await abrirModoPastor(tester, gateway, pastorInicial: pastorMaria);

      // ig1 está marcado (pertence a Maria). Não mexemos nele.
      // Marcamos apenas ig2.
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Mossoró - 240006'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Revisar e Salvar Vínculos (1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar e Salvar Vínculos'));
      await tester.pumpAndSettle();

      // Somente ig2 foi enviado! ig1 não gerou comando de mutação.
      expect(gateway.chamadasGerenciar.length, 1);
      expect(gateway.chamadasGerenciar[0]['entidadeId'], 'ig2');
    });

    testWidgets('falha parcial exibe resumo quantitativo e retentativa atua estritamente sobre a falha', (
      tester,
    ) async {
      final gateway = VinculosFake(
        resposta: VinculosResposta(
          igrejas: igrejasMultiplas,
          equipes: const [],
        ),
        pessoas: _pessoas,
      );
      // Configura falha apenas para ig3
      gateway.falhasPorEntidade['ig3'] = true;

      await abrirModoPastor(tester, gateway, pastorInicial: pastorMaria);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Mossoró - 240006'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Caicó - 240005'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Revisar e Salvar Vínculos (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar e Salvar Vínculos'));
      await tester.pumpAndSettle();

      // Resumo quantitativo
      expect(find.textContaining('1 concluído(s) com sucesso · 1 falha(s)'), findsOneWidget);
      expect(find.text('Tentar novamente falhas (1)'), findsOneWidget);

      final cmdIdOriginalIg3 = gateway.chamadasGerenciar.firstWhere((c) => c['entidadeId'] == 'ig3')['commandId'];

      // Corrige a falha
      gateway.falhasPorEntidade['ig3'] = false;
      await tester.tap(find.text('Tentar novamente falhas (1)'));
      await tester.pumpAndSettle();

      // Agora foram 3 chamadas no total (ig2, ig3 que falhou, e ig3 reenviado)
      expect(gateway.chamadasGerenciar.length, 3);
      // Reenvio usou o MESMO commandId para ig3
      expect(gateway.chamadasGerenciar[2]['commandId'], cmdIdOriginalIg3);
      expect(gateway.chamadasGerenciar[2]['entidadeId'], 'ig3');
      // ig2 NÃO foi reenviado!
      expect(find.textContaining('2 concluído(s) com sucesso · 0 falha(s)'), findsOneWidget);
    });

    testWidgets('conflito de versão aborted permite atualizar e reavaliar com novo commandId', (
      tester,
    ) async {
      final gateway = VinculosFake(
        resposta: VinculosResposta(
          igrejas: igrejasMultiplas,
          equipes: const [],
        ),
        pessoas: _pessoas,
      );
      gateway.conflitosPorEntidade['ig2'] = true;

      await abrirModoPastor(tester, gateway, pastorInicial: pastorMaria);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Mossoró - 240006'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Revisar e Salvar Vínculos (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar e Salvar Vínculos'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 conflito(s)'), findsOneWidget);
      expect(find.text('Atualizar e reavaliar'), findsOneWidget);

      final cmdIdPrimeiro = gateway.chamadasGerenciar[0]['commandId'];

      // Atualiza os dados do servidor (simulando que versao mudou para 5)
      gateway.resposta = VinculosResposta(
        igrejas: [
          const ItemVinculo(
            id: 'ig2',
            tipoEntidade: 'IGREJA',
            rotulo: 'Mossoró - 240006',
            codigo: '240006',
            ativo: true,
            versaoVinculo: 5,
          ),
        ],
        equipes: const [],
      );
      gateway.conflitosPorEntidade['ig2'] = false;

      await tester.ensureVisible(find.text('Atualizar e reavaliar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Atualizar e reavaliar'));
      await tester.pumpAndSettle();

      expect(find.text('Conflito concorrente detectado'), findsOneWidget);
      expect(find.textContaining('Versão atual: 5'), findsOneWidget);

      await tester.tap(find.text('Reconfirmar e Enviar'));
      await tester.pumpAndSettle();

      expect(gateway.chamadasGerenciar.length, 2);
      expect(gateway.chamadasGerenciar[1]['versao'], 5);
      // Gerou um NOVO commandId
      expect(gateway.chamadasGerenciar[1]['commandId'], isNot(equals(cmdIdPrimeiro)));
      expect(find.textContaining('1 concluído(s) com sucesso'), findsOneWidget);
    });

    testWidgets('voltar ao modo individual com alterações pendentes pede confirmação', (
      tester,
    ) async {
      final gateway = VinculosFake(
        resposta: VinculosResposta(
          igrejas: igrejasMultiplas,
          equipes: const [],
        ),
        pessoas: _pessoas,
      );
      await abrirModoPastor(tester, gateway, pastorInicial: pastorMaria);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Mossoró - 240006'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Voltar ao modo individual'));
      await tester.pumpAndSettle();

      expect(find.text('Descartar alterações?'), findsOneWidget);
      await tester.tap(find.text('Descartar e voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Gestão Centrada no Pastor / Responsável'), findsOneWidget);
      expect(find.text('Atribuir responsável'), findsWidgets);
    });
  });
}
