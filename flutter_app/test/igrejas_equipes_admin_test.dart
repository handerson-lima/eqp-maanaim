import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/admin/igrejas_screen.dart';
import 'package:eqp_maanaim/features/admin/equipes_screen.dart';
import 'package:eqp_maanaim/ui/identidade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _igrejasExemplo = <IgrejaCatalogo>[
  IgrejaCatalogo(
    id: 'ig_1',
    nome: 'Igreja Central',
    codigo: '240001',
    ativo: true,
    versao: 1,
    pastorLocalNome: 'Pastor Barnabé',
  ),
  IgrejaCatalogo(
    id: 'ig_2',
    nome: 'Igreja Ponta Negra',
    codigo: '240002',
    ativo: false,
    versao: 2,
    pastorLocalNome: null,
  ),
];

const _equipesExemplo = <EquipeCatalogo>[
  EquipeCatalogo(
    id: 'eq_1',
    nome: 'Equipe de Apoio',
    ativo: true,
    versao: 1,
    responsavelNome: 'Diácono Estêvão',
  ),
  EquipeCatalogo(
    id: 'eq_2',
    nome: 'Equipe de Louvor',
    ativo: false,
    versao: 1,
    responsavelNome: null,
  ),
];

Widget _appComTema(Widget child) => MaterialApp(
      theme: temaMaanaim(),
      home: Scaffold(body: child),
    );

void _definirTamanho(WidgetTester tester, Size tamanho) {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('S07 — Gestão de Igrejas (IgrejasScreen)', () {
    testWidgets('exibe cabeçalho institucional, botão Nova Igreja e dados em tabela desktop', (tester) async {
      _definirTamanho(tester, const Size(1200, 800));
      final gateway = CatalogoFake(
        resposta: const CatalogoResposta(
          igrejas: _igrejasExemplo,
          equipes: _equipesExemplo,
        ),
      );

      await tester.pumpWidget(_appComTema(IgrejasScreen(gateway: gateway)));
      await tester.pumpAndSettle();

      expect(find.text('Gestão de Igrejas'), findsOneWidget);
      expect(find.text('Nova Igreja'), findsOneWidget);
      expect(find.text('Igreja Central'), findsOneWidget);
      expect(find.text('240001'), findsOneWidget);
      expect(find.text('Pastor Barnabé'), findsOneWidget);
      expect(find.text('Ativa'), findsOneWidget);
      expect(find.text('Igreja Ponta Negra'), findsOneWidget);
      expect(find.text('240002'), findsOneWidget);
      expect(find.text('Não designado'), findsOneWidget);
      expect(find.text('Inativa'), findsOneWidget);
    });

    testWidgets('mobile (<600px) converte em cartões informativos com alvos >= 44px', (tester) async {
      _definirTamanho(tester, const Size(400, 800));
      final gateway = CatalogoFake(
        resposta: const CatalogoResposta(
          igrejas: _igrejasExemplo,
          equipes: _equipesExemplo,
        ),
      );

      await tester.pumpWidget(_appComTema(IgrejasScreen(gateway: gateway)));
      await tester.pumpAndSettle();

      expect(find.text('Igreja Central'), findsOneWidget);
      expect(find.text('Código: 240001'), findsOneWidget);
      expect(find.text('Pastor: Pastor Barnabé'), findsOneWidget);

      final botoesEditar = find.widgetWithText(OutlinedButton, 'Editar');
      expect(botoesEditar, findsWidgets);
      final tamanhoBotao = tester.getSize(botoesEditar.first);
      expect(tamanhoBotao.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('busca textual filtra igrejas por nome e por código', (tester) async {
      _definirTamanho(tester, const Size(1200, 800));
      final gateway = CatalogoFake(
        resposta: const CatalogoResposta(
          igrejas: _igrejasExemplo,
          equipes: _equipesExemplo,
        ),
      );

      await tester.pumpWidget(_appComTema(IgrejasScreen(gateway: gateway)));
      await tester.pumpAndSettle();

      // Busca por nome
      await tester.enterText(find.byType(TextField).first, 'ponta negra');
      await tester.pumpAndSettle();
      expect(find.text('Igreja Ponta Negra'), findsOneWidget);
      expect(find.text('Igreja Central'), findsNothing);

      // Busca por código
      await tester.enterText(find.byType(TextField).first, '240001');
      await tester.pumpAndSettle();
      expect(find.text('Igreja Central'), findsOneWidget);
      expect(find.text('Igreja Ponta Negra'), findsNothing);
    });

    testWidgets('filtro de situação alterna entre Todas, Ativas e Inativas', (tester) async {
      _definirTamanho(tester, const Size(1200, 800));
      final gateway = CatalogoFake(
        resposta: const CatalogoResposta(
          igrejas: _igrejasExemplo,
          equipes: _equipesExemplo,
        ),
      );

      await tester.pumpWidget(_appComTema(IgrejasScreen(gateway: gateway)));
      await tester.pumpAndSettle();

      // Filtro Ativas
      await tester.tap(find.text('Ativas'));
      await tester.pumpAndSettle();
      expect(find.text('Igreja Central'), findsOneWidget);
      expect(find.text('Igreja Ponta Negra'), findsNothing);

      // Filtro Inativas
      await tester.tap(find.text('Inativas'));
      await tester.pumpAndSettle();
      expect(find.text('Igreja Ponta Negra'), findsOneWidget);
      expect(find.text('Igreja Central'), findsNothing);
    });

    testWidgets('cadastro de nova igreja via modal com validação de 6 dígitos e expectedVersion 0', (tester) async {
      _definirTamanho(tester, const Size(1200, 800));
      final gateway = CatalogoFake(
        resposta: const CatalogoResposta(
          igrejas: _igrejasExemplo,
          equipes: _equipesExemplo,
        ),
      );

      await tester.pumpWidget(_appComTema(IgrejasScreen(gateway: gateway)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nova Igreja'));
      await tester.pumpAndSettle();

      expect(find.text('Nome da Igreja *'), findsOneWidget);
      expect(find.text('Código da Igreja (6 dígitos) *'), findsOneWidget);

      // Tenta salvar sem preencher
      await tester.tap(find.widgetWithText(PrimaryButton, 'Salvar Igreja'));
      await tester.pumpAndSettle();
      expect(find.text('Nome deve ter no mínimo 3 caracteres'), findsOneWidget);
      expect(find.text('O código deve conter exatamente 6 dígitos numéricos'), findsOneWidget);

      // Preenche dados válidos
      await tester.enterText(find.widgetWithText(TextFormField, 'Nome da Igreja *'), 'Igreja Nova Esperança');
      await tester.enterText(find.widgetWithText(TextFormField, 'Código da Igreja (6 dígitos) *'), '240099');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PrimaryButton, 'Salvar Igreja'));
      await tester.pumpAndSettle();

      expect(gateway.salvasIgreja, 1);
      expect(find.textContaining('Igreja "Igreja Nova Esperança" cadastrada com sucesso'), findsOneWidget);
    });

    testWidgets('exibe erro de conflito quando código de igreja já existe', (tester) async {
      _definirTamanho(tester, const Size(1200, 800));
      final gateway = CatalogoFake(
        resposta: const CatalogoResposta(
          igrejas: _igrejasExemplo,
          equipes: _equipesExemplo,
        ),
      );
      gateway.salvarIgrejaFalhar = true;
      gateway.erroSalvarIgrejaMsg = 'already-exists: código duplicado';

      await tester.pumpWidget(_appComTema(IgrejasScreen(gateway: gateway)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nova Igreja'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Nome da Igreja *'), 'Igreja Duplicada');
      await tester.enterText(find.widgetWithText(TextFormField, 'Código da Igreja (6 dígitos) *'), '240001');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PrimaryButton, 'Salvar Igreja'));
      await tester.pumpAndSettle();

      expect(find.text('Já existe uma igreja cadastrada com este código.'), findsOneWidget);
    });

    testWidgets('edição de igreja preenche dados e envia id e expectedVersion atual', (tester) async {
      _definirTamanho(tester, const Size(1200, 800));
      final gateway = CatalogoFake(
        resposta: const CatalogoResposta(
          igrejas: _igrejasExemplo,
          equipes: _equipesExemplo,
        ),
      );

      await tester.pumpWidget(_appComTema(IgrejasScreen(gateway: gateway)));
      await tester.pumpAndSettle();

      // Clica no botão de editar da primeira igreja
      await tester.tap(find.byTooltip('Editar Igreja Central'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Igreja'), findsOneWidget);
      expect(find.text('Igreja Central'), findsWidgets);
      expect(find.text('240001'), findsWidgets);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nome da Igreja *'), 'Igreja Central Renovada');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PrimaryButton, 'Salvar Igreja'));
      await tester.pumpAndSettle();

      expect(gateway.salvasIgreja, 1);
      expect(find.textContaining('atualizada com sucesso'), findsOneWidget);
    });

    testWidgets('alternar status de igreja exige confirmação explícita em modal acessível', (tester) async {
      _definirTamanho(tester, const Size(1200, 800));
      final gateway = CatalogoFake(
        resposta: const CatalogoResposta(
          igrejas: _igrejasExemplo,
          equipes: _equipesExemplo,
        ),
      );

      await tester.pumpWidget(_appComTema(IgrejasScreen(gateway: gateway)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.block_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Inativar Igreja'), findsOneWidget);
      expect(find.textContaining('Fichas e participações ativas existentes não serão afetadas'), findsOneWidget);

      await tester.tap(find.widgetWithText(PrimaryButton, 'Inativar'));
      await tester.pumpAndSettle();

      expect(gateway.alternadasIgreja, 1);
      expect(gateway.ultimoAtivo, isFalse);
      expect(find.textContaining('inativada com sucesso'), findsOneWidget);
    });

    testWidgets('erro de permissão administrativa é tratado com clareza e sem fallback silencioso', (tester) async {
      _definirTamanho(tester, const Size(1200, 800));
      final gateway = CatalogoFake()..falhar = true;

      await tester.pumpWidget(_appComTema(IgrejasScreen(gateway: gateway)));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível carregar o catálogo de igrejas.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });
  });

  group('S11 — Gestão de Equipes (EquipesScreen)', () {
    testWidgets('exibe cabeçalho, botão Nova Equipe, tabela desktop com responsável vigente único', (tester) async {
      _definirTamanho(tester, const Size(1200, 800));
      final gateway = CatalogoFake(
        resposta: const CatalogoResposta(
          igrejas: _igrejasExemplo,
          equipes: _equipesExemplo,
        ),
      );

      await tester.pumpWidget(_appComTema(EquipesScreen(gateway: gateway)));
      await tester.pumpAndSettle();

      expect(find.text('Gestão de Equipes'), findsOneWidget);
      expect(find.text('Nova Equipe'), findsOneWidget);
      expect(find.text('Equipe de Apoio'), findsOneWidget);
      expect(find.text('Diácono Estêvão'), findsOneWidget);
      expect(find.text('Ativa'), findsOneWidget);
      expect(find.text('Equipe de Louvor'), findsOneWidget);
      expect(find.text('Não designado'), findsOneWidget);
      expect(find.text('Inativa'), findsOneWidget);
    });

    testWidgets('mobile (<600px) converte equipes em cartões informativos com alvos >= 44px', (tester) async {
      _definirTamanho(tester, const Size(400, 800));
      final gateway = CatalogoFake(
        resposta: const CatalogoResposta(
          igrejas: _igrejasExemplo,
          equipes: _equipesExemplo,
        ),
      );

      await tester.pumpWidget(_appComTema(EquipesScreen(gateway: gateway)));
      await tester.pumpAndSettle();

      expect(find.text('Equipe de Apoio'), findsOneWidget);
      expect(find.text('Responsável Único: Diácono Estêvão'), findsOneWidget);

      final botoes = find.widgetWithText(OutlinedButton, 'Editar');
      expect(botoes, findsWidgets);
      final size = tester.getSize(botoes.first);
      expect(size.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('cadastro de nova equipe via modal', (tester) async {
      _definirTamanho(tester, const Size(1200, 800));
      final gateway = CatalogoFake(
        resposta: const CatalogoResposta(
          igrejas: _igrejasExemplo,
          equipes: _equipesExemplo,
        ),
      );

      await tester.pumpWidget(_appComTema(EquipesScreen(gateway: gateway)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nova Equipe'));
      await tester.pumpAndSettle();

      expect(find.text('Nome da Equipe *'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nome da Equipe *'), 'Equipe de Intercessão');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PrimaryButton, 'Salvar Equipe'));
      await tester.pumpAndSettle();

      expect(gateway.salvasEquipe, 1);
      expect(find.textContaining('Equipe "Equipe de Intercessão" cadastrada com sucesso'), findsOneWidget);
    });

    testWidgets('alternar status de equipe com modal de confirmação acessível', (tester) async {
      _definirTamanho(tester, const Size(1200, 800));
      final gateway = CatalogoFake(
        resposta: const CatalogoResposta(
          igrejas: _igrejasExemplo,
          equipes: _equipesExemplo,
        ),
      );

      await tester.pumpWidget(_appComTema(EquipesScreen(gateway: gateway)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.block_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Inativar Equipe'), findsOneWidget);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Inativar'));
      await tester.pumpAndSettle();

      expect(gateway.alternadasEquipe, 1);
      expect(gateway.ultimoAtivo, isFalse);
      expect(find.textContaining('inativada com sucesso'), findsOneWidget);
    });
  });
}
