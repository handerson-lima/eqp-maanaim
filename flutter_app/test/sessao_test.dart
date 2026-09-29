import 'package:eqp_maanaim/features/auth/auth_service.dart';
import 'package:eqp_maanaim/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('sessão ativa restaura área autenticada (admin)', (tester) async {
    final identidade = IdentidadeFake(email: 'admin@test.com', admin: true);
    final auth = AuthService(identidade, RascunhoFake());

    await tester.pumpWidget(MaterialApp(
        home: RaizSessao(auth,
            catalogo: CatalogoFake(), seed: SeedFake())));

    // O stream ainda não emitiu — deve mostrar "Verificando sessão".
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Simular login: o stream emite um usuário e a sessão é restaurada.
    identidade.simularLogin();
    await tester.pump();
    await tester.pump();

    expect(find.byType(AreaAutenticada), findsOneWidget);
  });

  testWidgets('sem sessão mostra tela inicial', (tester) async {
    final identidade = IdentidadeFake();
    final auth = AuthService(identidade, RascunhoFake());

    await tester.pumpWidget(MaterialApp(home: RaizSessao(auth)));

    // Emitir null (sem sessão).
    identidade.simularLogout();
    await tester.pump();

    expect(find.byType(Inicio), findsOneWidget);
    expect(find.text('Maanaim'), findsOneWidget);
  });

  testWidgets('sign-out no AreaAutenticada executa sair', (tester) async {
    final identidade = IdentidadeFake(email: 'admin@test.com');
    final auth = AuthService(identidade, RascunhoFake());

    await tester.pumpWidget(MaterialApp(home: AreaAutenticada(auth)));
    await tester.pump();

    // Usuário sem admin vê tela de rascunho com botão de sair.
    expect(find.textContaining('rascunho'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();
    expect(identidade.email, isNull);
    expect(identidade.logouts, 1);
  });
}
