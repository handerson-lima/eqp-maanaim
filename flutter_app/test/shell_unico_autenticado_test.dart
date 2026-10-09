import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/auth/auth_service.dart';
import 'package:eqp_maanaim/features/auth/contexto_acesso_model.dart';
import 'package:eqp_maanaim/features/auth/contexto_acesso_service.dart';
import 'package:eqp_maanaim/routes/app_router.dart';
import 'package:eqp_maanaim/ui/components/app_shell.dart';
import 'package:eqp_maanaim/features/pastor/fila_pastor_screen.dart';
import 'package:eqp_maanaim/features/pastor/pastor_service.dart';
import 'package:eqp_maanaim/features/responsavel_equipe/fila_responsavel_equipe_screen.dart';
import 'package:eqp_maanaim/features/responsavel_equipe/responsavel_equipe_service.dart';
import 'package:eqp_maanaim/features/coordenador/fila_coordenador_screen.dart';
import 'package:eqp_maanaim/features/coordenador/coordenador_service.dart';
import 'package:eqp_maanaim/features/perfil/editar_perfil_screen.dart';
import 'package:eqp_maanaim/main.dart';
import 'package:eqp_maanaim/features/voluntario/ficha_service.dart';
import 'package:eqp_maanaim/features/perfil/perfil_service.dart';
import 'fakes.dart';

class MockContextoGateway implements ContextoAcessoGateway {
  MockContextoGateway(this.contexto);
  final ContextoAcesso contexto;

  @override
  Future<ContextoAcesso> obterContextoAcesso() async => contexto;
}

class FakePerfilService implements IPerfilService {
  @override
  Future<PerfilUsuario> obterPerfil() async => const PerfilUsuario(
        uid: 'vol-1',
        nome: 'Voluntário Teste',
        email: 'voluntario@test.com',
        telefone: '(11) 98765-4321',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFichaGateway implements FichaGateway {
  @override
  Future<ObterFichaResposta> obterMinhaFicha() async =>
      const ObterFichaResposta(existe: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  void definirDimensoes(WidgetTester tester, Size tamanho) {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('Story 8.4: Shell Único e Eliminação de Barras Duplicadas', () {
    testWidgets('Pastor Local na rota /pastor renderiza EXATAMENTE UM AppShell e zero AppBars aninhados', (tester) async {
      definirDimensoes(tester, const Size(1280, 800));

      final contextoPastor = ContextoAcesso.fromJson({
        'uid': 'pastor-1',
        'capacidades': ['voluntario', 'pastor_local'],
        'ehPastorLocal': true,
        'ehVoluntario': true,
        'igrejas': [{'id': 'ig-1', 'nome': 'Igreja Central'}],
      });

      final auth = AuthService(IdentidadeFake(), RascunhoFake());

      await tester.pumpWidget(
        MaterialApp(
          home: AreaAutenticada(
            auth,
            contextoAcesso: MockContextoGateway(contextoPastor),
            pastor: MemoriaPastorLocalGateway(),
            rotaInicial: AppRotas.pastor,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Um único AppShell
      expect(find.byType(AppShell), findsOneWidget);

      // Fila do Pastor está no body
      expect(find.byType(FilaPastorScreen), findsOneWidget);

      // Não há AppBar duplicado na árvore (FilaPastorScreen está em modo dentroDeShell)
      expect(find.byType(AppBar), findsNothing);

      // TopBar institucional clara com nome, papel e status
      expect(find.text('Pastor Local'), findsWidgets);
      expect(find.text('ATIVA'), findsOneWidget);
    });

    testWidgets('Responsável de Equipe na rota /equipe renderiza EXATAMENTE UM AppShell e zero AppBars aninhados', (tester) async {
      definirDimensoes(tester, const Size(1280, 800));

      final contextoEquipe = ContextoAcesso.fromJson({
        'uid': 'resp-1',
        'capacidades': ['voluntario', 'responsavel_equipe'],
        'ehResponsavelEquipe': true,
        'ehVoluntario': true,
        'equipes': [{'id': 'eq-1', 'nome': 'Equipe Apoio'}],
      });

      final auth = AuthService(IdentidadeFake(), RascunhoFake());

      await tester.pumpWidget(
        MaterialApp(
          home: AreaAutenticada(
            auth,
            contextoAcesso: MockContextoGateway(contextoEquipe),
            responsavelEquipe: MemoriaResponsavelEquipeGateway(),
            rotaInicial: AppRotas.equipe,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(FilaResponsavelEquipeScreen), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Responsável de Equipe'), findsWidgets);
    });

    testWidgets('Coordenador Geral na rota /coordenador renderiza EXATAMENTE UM AppShell e zero AppBars aninhados', (tester) async {
      definirDimensoes(tester, const Size(1280, 800));

      final contextoCoord = ContextoAcesso.fromJson({
        'uid': 'coord-1',
        'capacidades': ['voluntario', 'coordenador'],
        'ehCoordenador': true,
        'ehVoluntario': true,
      });

      final auth = AuthService(IdentidadeFake(), RascunhoFake());

      await tester.pumpWidget(
        MaterialApp(
          home: AreaAutenticada(
            auth,
            contextoAcesso: MockContextoGateway(contextoCoord),
            coordenador: MemoriaCoordenadorGateway(),
            rotaInicial: AppRotas.coordenador,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(FilaCoordenadorScreen), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Coordenador Geral'), findsWidgets);
    });

    testWidgets('Rota /perfil renderiza EditarPerfilScreen dentro do shell sem AppBar duplicado', (tester) async {
      definirDimensoes(tester, const Size(1280, 800));

      final contextoVoluntario = ContextoAcesso.fromJson({
        'uid': 'vol-1',
        'capacidades': ['voluntario'],
        'ehVoluntario': true,
      });

      final auth = AuthService(IdentidadeFake(), RascunhoFake());

      await tester.pumpWidget(
        MaterialApp(
          home: AreaAutenticada(
            auth,
            contextoAcesso: MockContextoGateway(contextoVoluntario),
            ficha: FakeFichaGateway(),
            catalogo: CatalogoFake(),
            perfilService: FakePerfilService(),
            rotaInicial: AppRotas.perfil,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(EditarPerfilScreen), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('Usuário com múltiplos vínculos (Pastor + Equipe) vê itens de ambos os papéis no menu sem duplicatas', (tester) async {
      definirDimensoes(tester, const Size(1280, 800));

      final contextoDuplo = ContextoAcesso.fromJson({
        'uid': 'duplo-1',
        'capacidades': ['voluntario', 'pastor_local', 'responsavel_equipe'],
        'ehPastorLocal': true,
        'ehResponsavelEquipe': true,
        'ehVoluntario': true,
        'igrejas': [{'id': 'ig-1', 'nome': 'Igreja Central'}],
        'equipes': [{'id': 'eq-1', 'nome': 'Equipe Som'}],
      });

      final auth = AuthService(IdentidadeFake(), RascunhoFake());

      await tester.pumpWidget(
        MaterialApp(
          home: AreaAutenticada(
            auth,
            contextoAcesso: MockContextoGateway(contextoDuplo),
            pastor: MemoriaPastorLocalGateway(),
            responsavelEquipe: MemoriaResponsavelEquipeGateway(),
            rotaInicial: AppRotas.pastor,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);

      // Ambos os itens devem estar na sidebar
      expect(find.text('Fila do Pastor'), findsWidgets);
      expect(find.text('Fila da Equipe'), findsWidgets);
      expect(find.text('Renovações'), findsWidgets);
      expect(find.text('Minha Ficha'), findsWidgets);
      expect(find.text('Meu Perfil'), findsWidgets);

      // Alternar direto pelo clique no menu lateral para a Fila da Equipe
      await tester.tap(find.text('Fila da Equipe').first);
      await tester.pumpAndSettle();

      expect(find.byType(FilaResponsavelEquipeScreen), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('Em tela mobile (<600px), a navegação é feita por Drawer acionado pelo botão hambúrguer', (tester) async {
      definirDimensoes(tester, const Size(390, 844));

      final contextoPastor = ContextoAcesso.fromJson({
        'uid': 'pastor-1',
        'capacidades': ['voluntario', 'pastor_local'],
        'ehPastorLocal': true,
        'ehVoluntario': true,
      });

      final auth = AuthService(IdentidadeFake(), RascunhoFake());

      await tester.pumpWidget(
        MaterialApp(
          home: AreaAutenticada(
            auth,
            contextoAcesso: MockContextoGateway(contextoPastor),
            pastor: MemoriaPastorLocalGateway(),
            rotaInicial: AppRotas.pastor,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // No mobile, sidebar não fica visível inicialmente, mas o botão menu existe
      expect(find.byIcon(Icons.menu), findsOneWidget);

      // Abrir o Drawer
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Gaveta com os itens de navegação
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('Fila do Pastor'), findsWidgets);
    });
  });
}
