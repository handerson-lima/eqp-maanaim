import 'package:eqp_maanaim/main.dart';
import 'package:eqp_maanaim/ui/identidade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  for (final tamanho in [const Size(320, 568), const Size(1440, 900)]) {
    testWidgets('acesso sem overflow em $tamanho com texto ampliado', (
      tester,
    ) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: temaMaanaim(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Login(AuthRecuperacaoFalha()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Esqueci minha senha'));
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();
      expect(
        find.text('Informe um e-mail válido para continuar.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
