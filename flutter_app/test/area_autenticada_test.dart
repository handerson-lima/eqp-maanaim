import 'dart:async';
import 'package:eqp_maanaim/features/auth/auth_service.dart';
import 'package:eqp_maanaim/features/admin/admin_shell.dart';
import 'package:eqp_maanaim/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class _AuthAdmin extends AuthService {
  _AuthAdmin(this._resposta) : super(IdentidadeFake(), RascunhoFake());
  Future<bool> Function() _resposta;
  int consultas = 0;

  void proximaResposta(Future<bool> Function() resposta) => _resposta = resposta;

  @override
  Future<bool> possuiAdministracao() {
    consultas++;
    return _resposta();
  }

  @override
  Future<void> sair() async {}

  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();
}

void main() {
  testWidgets('administrador autorizado vê o shell administrativo',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: AreaAutenticada(_AuthAdmin(() async => true))));
    await tester.pump();
    expect(find.byType(AdminShell), findsOneWidget);
  });

  testWidgets('sessão sem privilégio não vê o shell administrativo',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: AreaAutenticada(_AuthAdmin(() async => false))));
    await tester.pump();
    expect(find.byType(AdminShell), findsNothing);
    expect(find.textContaining('rascunho'), findsOneWidget);
  });

  testWidgets('falha transitória é anunciada com retentativa acessível',
      (tester) async {
    final auth = _AuthAdmin(() async => throw Exception('rede'));
    await tester.pumpWidget(MaterialApp(home: AreaAutenticada(auth)));
    await tester.pump();
    expect(find.textContaining('Não foi possível confirmar'), findsOneWidget);
    expect(find.byType(AdminShell), findsNothing);

    auth.proximaResposta(() async => true);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tentar novamente'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(AdminShell), findsOneWidget);
    expect(auth.consultas, 2);
  });

  testWidgets('a autorização não é recoletada a cada reconstrução',
      (tester) async {
    final auth = _AuthAdmin(() async => true);
    await tester.pumpWidget(MaterialApp(home: AreaAutenticada(auth)));
    await tester.pump();
    await tester.pump();
    expect(auth.consultas, 1);
  });
}
