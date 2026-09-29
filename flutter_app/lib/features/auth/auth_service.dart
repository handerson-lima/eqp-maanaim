import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService(this._auth, this._functions);
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  /// Mantém a retentativa no mesmo UID depois de uma falha da callable.
  static bool deveCriarIdentidade(Object? usuarioAtual) => usuarioAtual == null;

  Future<void> cadastrar(
      {required String email,
      required String senha,
      required Map<String, String> dados}) async {
    // A primeira chamada pode criar Auth e falhar antes do rascunho. A sessão
    // existente pode repetir somente a callable idempotente.
    if (deveCriarIdentidade(_auth.currentUser)) {
      await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: senha);
    }
    await _functions.httpsCallable('criarOuRetomarRascunho').call(dados);
  }

  Future<void> entrar(String email, String senha) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: senha);

  Future<void> recuperar(String email) => _auth.sendPasswordResetEmail(
      email: email.trim(),
      actionCodeSettings: ActionCodeSettings(
          url: const String.fromEnvironment('PASSWORD_RESET_CONTINUE_URL'),
          handleCodeInApp: false));

  static const mensagemRecuperacaoNeutra =
      'Se houver uma conta elegível, as instruções para definir nova senha foram enviadas.';
}
