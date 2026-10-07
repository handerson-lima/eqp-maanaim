import 'dart:async';

import 'package:eqp_maanaim/features/auth/auth_service.dart';
import 'package:eqp_maanaim/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class IdentidadeEntrarPendente implements IdentidadeGateway {
  int entradas = 0;
  final _pendente = Completer<void>();

  @override
  String? get emailAtual => null;

  @override
  Future<void> criarConta(String email, String senha) async {}

  @override
  Future<void> entrar(String email, String senha) {
    entradas++;
    return _pendente.future;
  }

  @override
  Future<void> enviarRedefinicao(
      String email, ActionCodeSettings settings) async {}

  @override
  Future<bool> possuiAdministracao() async => false;

  @override
  Future<bool> possuiCoordenacao() async => false;

  @override
  Future<void> sair() async {}

  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();
}

void main() {
  testWidgets('o botão Entrar não aceita envios concorrentes', (tester) async {
    final identidade = IdentidadeEntrarPendente();
    await tester.pumpWidget(
        MaterialApp(home: Login(AuthService(identidade, RascunhoFake()))));
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'ana@x.com');
    await tester.enterText(campos.at(1), 'segredo123');
    final entrar = find.widgetWithText(ElevatedButton, 'Entrar');
    await tester.tap(entrar);
    await tester.pump();
    await tester.tap(entrar);
    await tester.pump();
    expect(identidade.entradas, 1);
  });
}
