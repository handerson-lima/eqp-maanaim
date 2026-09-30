import 'package:eqp_maanaim/features/admin/admin_shell.dart';
import 'package:eqp_maanaim/features/admin/pessoas_papeis.dart';
import 'package:eqp_maanaim/features/admin/pessoas_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _pessoas = <PessoaAdministrativa>[
  PessoaAdministrativa(
    uid: '1',
    nomeCompleto: 'Ana Lima',
    email: 'ana@exemplo.com',
    papeis: ['ADMINISTRADOR'],
    versao: 2,
    coordenador: false,
  ),
  PessoaAdministrativa(
    uid: '2',
    nomeCompleto: 'Carlos Souza',
    email: 'carlos@exemplo.com',
    papeis: [],
    versao: 0,
    coordenador: false,
  ),
  PessoaAdministrativa(
    uid: '3',
    nomeCompleto: 'Dora Reis',
    email: 'dora@exemplo.com',
    papeis: ['COORDENADOR'],
    versao: 1,
    coordenador: true,
  ),
];

const _resposta = PessoasResposta(
  pessoas: _pessoas,
  contextoPapeis: ['ADMINISTRADOR', 'COORDENADOR'],
);

Future<void> _abrir(WidgetTester tester, PessoasFake gateway) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: PessoasPapeis(gateway))),
  );
}

void main() {
  testWidgets('lista pessoas com papéis efetivos apenas como leitura', (
    tester,
  ) async {
    await _abrir(tester, PessoasFake(resposta: _resposta));
    await tester.pumpAndSettle();
    expect(find.text('Ana Lima'), findsOneWidget);
    expect(find.text('Carlos Souza'), findsOneWidget);
    expect(find.text('Dora Reis'), findsOneWidget);
    expect(find.text('Papéis: Administrador'), findsOneWidget);
    expect(find.text('Papéis: Coordenador'), findsOneWidget);
    expect(find.text('Papéis: Sem papel de sistema'), findsOneWidget);
    expect(find.text('Coordenador do Maanaim'), findsOneWidget);
    expect(find.text('Contexto ativo (somente leitura)'), findsOneWidget);
    expect(find.text('Administrador · Coordenador'), findsOneWidget);
  });

  testWidgets('estado vazio é anunciado acessivelmente', (tester) async {
    await _abrir(tester, PessoasFake());
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma pessoa cadastrada.'), findsOneWidget);
  });

  testWidgets('erro mostra mensagem e retentativa recarrega', (tester) async {
    final gateway = PessoasFake()..falhar = true;
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar pessoas e papéis.'),
      findsOneWidget,
    );

    gateway
      ..falhar = false
      ..resposta = _resposta;
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Lima'), findsOneWidget);
    expect(gateway.consultas, 2);
  });

  testWidgets('pesquisa por nome sem acento e por e-mail', (tester) async {
    await _abrir(tester, PessoasFake(resposta: _resposta));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'carlos');
    await tester.pump();
    expect(find.text('Carlos Souza'), findsOneWidget);
    expect(find.text('Ana Lima'), findsNothing);

    await tester.enterText(find.byType(TextField), 'dora@');
    await tester.pump();
    expect(find.text('Dora Reis'), findsOneWidget);
    expect(find.text('Carlos Souza'), findsNothing);
  });

  testWidgets('concessão exige confirmação antes de chamar o gateway', (
    tester,
  ) async {
    final gateway = PessoasFake(resposta: _resposta);
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Conceder Administrador').first);
    await tester.pumpAndSettle();
    expect(find.text('Confirmar'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(gateway.alteracoes, 0);

    await tester.tap(find.text('Conceder Administrador').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(gateway.alteracoes, 1);
    expect(gateway.ultimoAlvo, '2');
    expect(gateway.ultimoPapel, 'ADMINISTRADOR');
    expect(gateway.ultimoConceder, isTrue);
    expect(gateway.ultimaVersao, 0);
    expect(find.textContaining('Papel concedido'), findsOneWidget);
  });

  testWidgets('revogação confirma e envia o sentido correto', (tester) async {
    final gateway = PessoasFake(resposta: _resposta);
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revogar Administrador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(gateway.ultimoAlvo, '1');
    expect(gateway.ultimoConceder, isFalse);
    expect(gateway.ultimaVersao, 2);
  });

  testWidgets('edição salva os dados do Coordenador com CPF', (tester) async {
    final gateway = PessoasFake(resposta: _resposta);
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Editar').first);
    await tester.pumpAndSettle();
    expect(find.text('Editar pessoa'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'CPF'),
      '52998224725',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(gateway.salvamentos, 1);
    expect(gateway.ultimoCoordenador, isTrue);
    expect(gateway.ultimoCpf, '52998224725');
  });

  testWidgets('cadastro abre formulário e envia os dados mínimos', (
    tester,
  ) async {
    final gateway = PessoasFake(resposta: _resposta);
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cadastrar pessoa'));
    await tester.pumpAndSettle();
    expect(find.text('Cadastrar pessoa'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome completo'),
      'Nova Pessoa',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'nova@exemplo.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(gateway.salvamentos, 1);
    expect(gateway.ultimoNome, 'Nova Pessoa');
    expect(gateway.ultimoCoordenador, isFalse);
    expect(find.text('Pessoa cadastrada.'), findsOneWidget);
  });

  testWidgets('falha de mutação é anunciada sem recarregar em loop', (
    tester,
  ) async {
    final gateway = PessoasFake(resposta: _resposta)..alterarFalhar = true;
    await _abrir(tester, gateway);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revogar Administrador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não foi possível atualizar o papel'),
      findsOneWidget,
    );
    expect(gateway.consultas, 1);
  });

  testWidgets('AdminShell conecta a superfície de Pessoas e Papéis', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminShell(
          onSair: () {},
          catalogo: CatalogoFake(),
          seed: SeedFake(),
          pessoas: PessoasFake(resposta: _resposta),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pessoas e Papéis'));
    await tester.pumpAndSettle();
    expect(find.byType(PessoasPapeis), findsOneWidget);
    expect(find.text('Ana Lima'), findsOneWidget);
  });
}
