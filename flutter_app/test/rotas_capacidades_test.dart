import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/auth/acesso_negado_screen.dart';
import 'package:eqp_maanaim/features/auth/contexto_acesso_model.dart';
import 'package:eqp_maanaim/features/auth/contexto_acesso_service.dart';
import 'package:eqp_maanaim/features/auth/seletor_destino_capacidades.dart';
import 'package:eqp_maanaim/routes/app_router.dart';
import 'package:eqp_maanaim/features/auth/auth_service.dart';
import 'package:eqp_maanaim/main.dart';

import 'package:firebase_auth/firebase_auth.dart';

class MockContextoGateway implements ContextoAcessoGateway {
  MockContextoGateway(this.contexto);
  final ContextoAcesso contexto;

  @override
  Future<ContextoAcesso> obterContextoAcesso() async => contexto;
}

class FakeIdentidade implements IdentidadeGateway {
  @override
  String? get emailAtual => 'teste@maanaim.org';
  @override
  Future<void> criarConta(String email, String senha) async {}
  @override
  Future<void> entrar(String email, String senha) async {}
  @override
  Future<void> enviarRedefinicao(String email, dynamic settings) async {}
  @override
  Future<bool> possuiAdministracao() async => false;
  @override
  Future<bool> possuiCoordenacao() async => false;
  @override
  Future<void> sair() async {}
  @override
  Stream<User?> authStateChanges() => Stream.value(null);
}

class FakeRascunho implements RascunhoGateway {
  @override
  Future<RascunhoResultado> criarOuRetomar(Map<String, String> dados) async {
    return const RascunhoResultado(estado: 'RASCUNHO', retomado: false);
  }
}

void main() {
  group('Story 8.3: Sanitização de Rotas e Guarda de Capacidades', () {
    test('AppRotas.sanitizarRota remove PII, CPFs e tokens da URL', () {
      const rotaInsegura = '/pastor?igrejaId=ig_123&token=secret123&cpf=12345678900&email=a@b.com';
      final limpa = AppRotas.sanitizarRota(rotaInsegura);

      expect(limpa, contains('igrejaId=ig_123'));
      expect(limpa, isNot(contains('secret123')));
      expect(limpa, isNot(contains('12345678900')));
      expect(limpa, isNot(contains('a@b.com')));
    });

    test('AppRouteGuard autoriza voluntário simples apenas em rotas permitidas', () {
      final contextoVoluntario = ContextoAcesso.fromJson({
        'uid': 'vol-1',
        'capacidades': ['voluntario'],
        'ehVoluntario': true,
      });

      const guard = AppRouteGuard();

      // Permitidas
      expect(guard.avaliar(AppRotas.inicio, contextoVoluntario), isA<RotaAutorizada>());
      expect(guard.avaliar(AppRotas.minhaFicha, contextoVoluntario), isA<RotaAutorizada>());

      // Bloqueadas
      final resPastor = guard.avaliar(AppRotas.pastor, contextoVoluntario);
      expect(resPastor, isA<RotaNaoAutorizada>());
      expect((resPastor as RotaNaoAutorizada).capacidadeFaltante, equals('Pastor Local'));

      final resAdmin = guard.avaliar(AppRotas.admin, contextoVoluntario);
      expect(resAdmin, isA<RotaNaoAutorizada>());
      expect((resAdmin as RotaNaoAutorizada).capacidadeFaltante, equals('Administrador'));
    });

    test('AppRouteGuard autoriza Pastor Local na rota /pastor', () {
      final contextoPastor = ContextoAcesso.fromJson({
        'uid': 'pastor-1',
        'capacidades': ['voluntario', 'pastor_local'],
        'ehPastorLocal': true,
        'igrejas': [
          {'id': 'ig-1', 'nome': 'Igreja Central'},
        ],
      });

      const guard = AppRouteGuard();
      expect(guard.avaliar(AppRotas.pastor, contextoPastor), isA<RotaAutorizada>());
      expect(guard.avaliar(AppRotas.equipe, contextoPastor), isA<RotaNaoAutorizada>());
    });

    test('AppRouteGuard autoriza múltiplos vínculos (Pastor + Responsável)', () {
      final contextoDuplo = ContextoAcesso.fromJson({
        'uid': 'duplo-1',
        'capacidades': ['voluntario', 'pastor_local', 'responsavel_equipe'],
        'ehPastorLocal': true,
        'ehResponsavelEquipe': true,
      });

      const guard = AppRouteGuard();
      expect(guard.avaliar(AppRotas.pastor, contextoDuplo), isA<RotaAutorizada>());
      expect(guard.avaliar(AppRotas.equipe, contextoDuplo), isA<RotaAutorizada>());
      expect(guard.avaliar(AppRotas.admin, contextoDuplo), isA<RotaNaoAutorizada>());
    });
  });

  group('Story 8.3: Telas de Navegação e Guarda por Capacidades', () {
    testWidgets('AcessoNegadoScreen renderiza mensagem explicativa e botão de retorno', (tester) async {
      bool clicouVoltar = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AcessoNegadoScreen(
            capacidadeNecessaria: 'Pastor Local',
            onVoltar: () => clicouVoltar = true,
          ),
        ),
      );

      expect(find.text('Acesso não autorizado'), findsOneWidget);
      expect(find.textContaining('Pastor Local'), findsOneWidget);

      await tester.tap(find.text('Voltar para área permitida'));
      await tester.pump();

      expect(clicouVoltar, isTrue);
    });

    testWidgets('SeletorDestinoCapacidades renderiza destinos disponíveis para múltiplos vínculos', (tester) async {
      final contextoDuplo = ContextoAcesso.fromJson({
        'uid': 'duplo-1',
        'capacidades': ['voluntario', 'pastor_local', 'responsavel_equipe'],
        'ehPastorLocal': true,
        'ehResponsavelEquipe': true,
        'igrejas': [
          {'id': 'ig-1', 'nome': 'Igreja Central'},
        ],
        'equipes': [
          {'id': 'eq-1', 'nome': 'Equipe de Som'},
        ],
      });

      bool navegouPastor = false;
      bool navegouEquipe = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SeletorDestinoCapacidades(
            contexto: contextoDuplo,
            onNavegarPastor: () => navegouPastor = true,
            onNavegarEquipe: () => navegouEquipe = true,
            onNavegarCoordenador: () {},
            onNavegarAdmin: () {},
            onNavegarVoluntario: () {},
            onNavegarRenovacao: () {},
          ),
        ),
      );

      expect(find.text('Suas Áreas e Vínculos Autorizados'), findsOneWidget);
      expect(find.text('Fila do Pastor Local'), findsOneWidget);
      expect(find.text('Fila do Responsável de Equipe'), findsOneWidget);

      await tester.tap(find.text('Acessar Fila Pastoral'));
      await tester.pump();
      expect(navegouPastor, isTrue);

      await tester.tap(find.text('Acessar Fila da Equipe'));
      await tester.pump();
      expect(navegouEquipe, isTrue);
    });

    testWidgets('AreaAutenticada renderiza AcessoNegadoScreen para rota não autorizada', (tester) async {
      final contextoVoluntario = ContextoAcesso.fromJson({
        'uid': 'vol-1',
        'capacidades': ['voluntario'],
        'ehVoluntario': true,
      });

      final authService = AuthService(FakeIdentidade(), FakeRascunho());

      await tester.pumpWidget(
        MaterialApp(
          home: AreaAutenticada(
            authService,
            contextoAcesso: MockContextoGateway(contextoVoluntario),
            rotaInicial: AppRotas.pastor,
          ),
        ),
      );

      // Aguarda resolução do Future
      await tester.pumpAndSettle();

      expect(find.text('Acesso não autorizado'), findsOneWidget);
      expect(find.textContaining('Pastor Local'), findsOneWidget);
    });

    testWidgets('AreaAutenticada renderiza SeletorDestinoCapacidades quando usuário possui múltiplos destinos na raiz', (tester) async {
      final contextoDuplo = ContextoAcesso.fromJson({
        'uid': 'duplo-1',
        'capacidades': ['voluntario', 'pastor_local', 'responsavel_equipe'],
        'ehPastorLocal': true,
        'ehResponsavelEquipe': true,
      });

      final authService = AuthService(FakeIdentidade(), FakeRascunho());

      await tester.pumpWidget(
        MaterialApp(
          home: AreaAutenticada(
            authService,
            contextoAcesso: MockContextoGateway(contextoDuplo),
            rotaInicial: AppRotas.raiz,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Suas Áreas e Vínculos Autorizados'), findsOneWidget);
      expect(find.text('Fila do Pastor Local'), findsOneWidget);
      expect(find.text('Fila do Responsável de Equipe'), findsOneWidget);
    });
  });
}
