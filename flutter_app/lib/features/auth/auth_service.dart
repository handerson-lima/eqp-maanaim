import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Operações de identidade usadas pelo fluxo público de acesso.
abstract interface class IdentidadeGateway {
  /// E-mail da sessão atual, ou `null` quando não há sessão.
  String? get emailAtual;
  Future<void> criarConta(String email, String senha);
  Future<void> entrar(String email, String senha);
  Future<void> enviarRedefinicao(String email, ActionCodeSettings settings);
}

/// Mutação de rascunho, sempre executada no backend autenticado.
abstract interface class RascunhoGateway {
  Future<void> criarOuRetomar(Map<String, String> dados);
}

class FirebaseIdentidadeGateway implements IdentidadeGateway {
  FirebaseIdentidadeGateway(this._auth);
  final FirebaseAuth _auth;

  @override
  String? get emailAtual => _auth.currentUser?.email;

  @override
  Future<void> criarConta(String email, String senha) =>
      _auth.createUserWithEmailAndPassword(email: email, password: senha);

  @override
  Future<void> entrar(String email, String senha) =>
      _auth.signInWithEmailAndPassword(email: email, password: senha);

  @override
  Future<void> enviarRedefinicao(String email, ActionCodeSettings settings) =>
      _auth.sendPasswordResetEmail(email: email, actionCodeSettings: settings);
}

class FirebaseRascunhoGateway implements RascunhoGateway {
  FirebaseRascunhoGateway(this._functions);
  final FirebaseFunctions _functions;

  @override
  Future<void> criarOuRetomar(Map<String, String> dados) async {
    await _functions.httpsCallable('criarOuRetomarRascunho').call(dados);
  }
}

class AuthService {
  AuthService(this._identidade, this._rascunho);
  final IdentidadeGateway _identidade;
  final RascunhoGateway _rascunho;

  /// Só reaproveita a sessão quando ela já é a mesma identidade recém-criada
  /// para este e-mail; uma sessão de outra conta nunca recebe estes dados.
  static bool precisaCriarIdentidade(String? emailAtual, String emailAlvo) =>
      emailAtual == null || emailAtual != emailAlvo.trim();

  Future<void> cadastrar(
      {required String email,
      required String senha,
      required Map<String, String> dados}) async {
    final alvo = email.trim();
    // A primeira chamada pode criar Auth e falhar antes do rascunho. A sessão
    // do mesmo e-mail pode repetir somente a callable idempotente.
    if (precisaCriarIdentidade(_identidade.emailAtual, alvo)) {
      await _identidade.criarConta(alvo, senha);
    }
    await _rascunho.criarOuRetomar(dados);
  }

  Future<void> entrar(String email, String senha) =>
      _identidade.entrar(email.trim(), senha);

  Future<void> recuperar(String email) => _identidade.enviarRedefinicao(
      email.trim(),
      ActionCodeSettings(
          url: const String.fromEnvironment('PASSWORD_RESET_CONTINUE_URL'),
          handleCodeInApp: false));

  static const mensagemRecuperacaoNeutra =
      'Se houver uma conta elegível, as instruções para definir nova senha foram enviadas.';
}
