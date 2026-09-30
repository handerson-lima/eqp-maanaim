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
        inicioVigencia: DateTime(2020, 1, 5, 14, 30),
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
    expect(find.text('Sem responsável vigente'), findsOneWidget);
    expect(find.text('Substituir responsável'), findsOneWidget);

    await tester.tap(find.text('Linha do tempo (somente leitura)').first);
    await tester.pumpAndSettle();
    expect(find.text('Substituição · Pastor Local'), findsOneWidget);
    expect(find.textContaining('Ator: Administrador'), findsOneWidget);
    expect(find.textContaining('Início: 05/01/2020 14:30'), findsOneWidget);
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
}
