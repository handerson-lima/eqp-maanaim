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

/// Resultado permitido da callable de rascunho, sem PII.
class RascunhoResultado {
  const RascunhoResultado({required this.estado, required this.retomado});
  final String estado;
  final bool retomado;
}

/// Mutação de rascunho, sempre executada no backend autenticado.
abstract interface class RascunhoGateway {
  Future<RascunhoResultado> criarOuRetomar(Map<String, String> dados);
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
  Future<RascunhoResultado> criarOuRetomar(Map<String, String> dados) async {
    final resposta =
        await _functions.httpsCallable('criarOuRetomarRascunho').call(dados);
    final dadosResposta = (resposta.data as Map).cast<String, dynamic>();
    return RascunhoResultado(
      estado: dadosResposta['estado'] as String? ?? 'RASCUNHO',
      retomado: dadosResposta['retomado'] as bool? ?? false,
    );
  }
}

class AuthService {
  AuthService(this._identidade, this._rascunho);
  final IdentidadeGateway _identidade;
  final RascunhoGateway _rascunho;

  /// Só reaproveita a sessão quando ela já é a mesma identidade recém-criada
  /// para este e-mail; uma sessão de outra conta nunca recebe estes dados.
  /// E-mail é comparado sem diferenciar maiúsculas/minúsculas, pois o Firebase
  /// Auth normaliza o endereço armazenado.
  static bool precisaCriarIdentidade(String? emailAtual, String emailAlvo) =>
      emailAtual == null ||
      emailAtual.trim().toLowerCase() != emailAlvo.trim().toLowerCase();

  Future<RascunhoResultado> cadastrar(
      {required String email,
      required String senha,
      required Map<String, String> dados}) async {
    final alvo = email.trim();
    // A primeira chamada pode criar Auth e falhar antes do rascunho. A sessão
    // do mesmo e-mail pode repetir somente a callable idempotente.
    if (precisaCriarIdentidade(_identidade.emailAtual, alvo)) {
      await _identidade.criarConta(alvo, senha);
    }
    return _rascunho.criarOuRetomar(dados);
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
