import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eqp_maanaim/features/auth/auth_service.dart';
import 'package:eqp_maanaim/main.dart';
import 'package:eqp_maanaim/ui/identidade.dart';
import 'fakes.dart';

void main() {
  void definirDimensoes(WidgetTester tester, Size tamanho) {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('Story 8.4: S01 Login e Acesso Público', () {
    testWidgets(
      'S01 Login desktop (1280x800) exibe PainelAcesso 50/50 com painel esquerdo navy-900 sólido e LogoMaanaim, sem botão Google e sem divisor',
      (tester) async {
        definirDimensoes(tester, const Size(1280, 800));

        final auth = AuthService(IdentidadeFake(), RascunhoFake());
        await tester.pumpWidget(
          MaterialApp(
            theme: temaMaanaim(),
            home: Login(auth),
          ),
        );
        await tester.pumpAndSettle();

        // Verifica presença do PainelAcesso
        expect(find.byType(PainelAcesso), findsOneWidget);

        // Painel institucional navy-900 à esquerda
        expect(find.text('Gestão de Voluntários'), findsWidgets);
        expect(find.textContaining('Servindo juntos no Reino de Deus'), findsOneWidget);
        expect(find.textContaining('1 Pedro 4:10'), findsOneWidget);

        // Formulário à direita com Bem-vindo e campos
        expect(find.text('Bem-vindo'), findsOneWidget);
        expect(find.text('Acesse sua conta para continuar'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2)); // email e senha

        // Botão Entrar e botão Cadastre-se
        expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Cadastre-se'), findsOneWidget);

        // Crítico: Remoção de Google e divisor sem integração
        expect(find.text('Entrar com Google'), findsNothing);
        expect(find.text('ou'), findsNothing);
        expect(find.byIcon(Icons.login), findsNothing);
      },
    );

    testWidgets(
      'S01 Login mobile (390x844) exibe composição compacta sem overflow',
      (tester) async {
        definirDimensoes(tester, const Size(390, 844));

        final auth = AuthService(IdentidadeFake(), RascunhoFake());
        await tester.pumpWidget(
          MaterialApp(
            theme: temaMaanaim(),
            home: Login(auth),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bem-vindo'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Cadastre-se'), findsOneWidget);

        // Sem botão Google
        expect(find.text('Entrar com Google'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Recuperação de senha exibe feedback neutro contra enumeração de contas',
      (tester) async {
        final identidade = IdentidadeFake();
        final auth = AuthService(identidade, RascunhoFake());

        await tester.pumpWidget(
          MaterialApp(
            theme: temaMaanaim(),
            home: Login(auth),
          ),
        );
        await tester.pumpAndSettle();

        // Tentar recuperar sem email exibe validação
        await tester.tap(find.text('Esqueci minha senha'));
        await tester.pump();
        expect(find.text('Informe um e-mail válido para continuar.'), findsOneWidget);

        // Informar email e recuperar
        await tester.enterText(find.byType(TextFormField).first, 'usuario@qualquer.com');
        await tester.tap(find.text('Esqueci minha senha'));
        await tester.pumpAndSettle();

        // Resposta estritamente neutra (AD-12)
        expect(find.text(AuthService.mensagemRecuperacaoNeutra), findsOneWidget);
      },
    );

    testWidgets(
      'Navega para tela de Cadastro e permite retornar ao Login',
      (tester) async {
        definirDimensoes(tester, const Size(1280, 800));
        final auth = AuthService(IdentidadeFake(), RascunhoFake());

        await tester.pumpWidget(
          MaterialApp(
            theme: temaMaanaim(),
            home: Login(auth),
          ),
        );
        await tester.pumpAndSettle();

        // Clicar em Cadastre-se
        await tester.tap(find.widgetWithText(OutlinedButton, 'Cadastre-se'));
        await tester.pumpAndSettle();

        // Abre tela Cadastro
        expect(find.byType(Cadastro), findsOneWidget);
        expect(find.text('Crie seu acesso'), findsOneWidget);

        // Voltar
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(Login), findsOneWidget);
      },
    );
  });
}
