import 'package:eqp_maanaim/features/admin/admin_shell.dart';
import 'package:eqp_maanaim/features/auth/auth_service.dart';
import 'package:eqp_maanaim/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('login bem-sucedido encerra o Login e mostra a área administrativa',
      (tester) async {
    final identidade = IdentidadeFake(admin: true);
    final auth = AuthService(identidade, RascunhoFake());

    await tester.pumpWidget(MaterialApp(
        home: RaizSessao(auth,
            catalogo: CatalogoFake(), seed: SeedFake())));

    // Sem sessão: a raiz mostra a tela inicial.
    identidade.simularLogout();
    await tester.pump();
    expect(find.byType(Inicio), findsOneWidget);

    // Abrir o Login a partir da tela inicial.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.byType(Login), findsOneWidget);

    // Enviar credenciais válidas.
    await tester.enterText(
        find.byType(TextFormField).at(0), 'admin@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'segredo123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pumpAndSettle();

    // O Login foi removido da pilha e a área autenticada assumiu.
    expect(find.byType(Login), findsNothing);
    expect(find.byType(AreaAutenticada), findsOneWidget);
    expect(find.byType(AdminShell), findsOneWidget);
  });
}
