import 'package:eqp_maanaim/features/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IdentidadeFake implements IdentidadeGateway {
  IdentidadeFake({this.email});
  String? email;
  int criadas = 0;
  int redefinicoes = 0;

  @override
  String? get emailAtual => email;

  @override
  Future<void> criarConta(String email, String senha) async {
    criadas++;
    this.email = email;
  }

  @override
  Future<void> entrar(String email, String senha) async {
    this.email = email;
  }

  @override
  Future<void> enviarRedefinicao(String email, ActionCodeSettings settings) async {
    redefinicoes++;
  }
}

class RascunhoFake implements RascunhoGateway {
  int chamadas = 0;
  Map<String, String>? ultimo;
  bool falhar = false;

  @override
  Future<void> criarOuRetomar(Map<String, String> dados) async {
    chamadas++;
    ultimo = dados;
    if (falhar) throw Exception('falha simulada');
  }
}

/// Serviço com recuperação que sempre falha, para exercitar a resposta neutra.
class AuthRecuperacaoFalha extends AuthService {
  AuthRecuperacaoFalha() : super(IdentidadeFake(), RascunhoFake());

  @override
  Future<void> recuperar(String email) async => throw Exception('falha simulada');
}
