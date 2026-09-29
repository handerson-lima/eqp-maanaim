import 'package:eqp_maanaim/features/auth/auth_service.dart';
import 'package:eqp_maanaim/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('recuperação com falha ainda mostra a resposta neutra',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Login(AuthRecuperacaoFalha())));
    await tester.enterText(
        find.byType(TextFormField).first, 'talvez@x.com');
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    expect(find.text(AuthService.mensagemRecuperacaoNeutra), findsOneWidget);
    expect(find.textContaining('falha'), findsNothing);
  });
}
