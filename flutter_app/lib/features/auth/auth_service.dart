import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Operações de identidade usadas pelo fluxo público de acesso.
abstract interface class IdentidadeGateway {
  /// E-mail da sessão atual, ou `null` quando não há sessão.
  String? get emailAtual;
  Future<void> criarConta(String email, String senha);
  Future<void> entrar(String email, String senha);
  Future<void> enviarRedefinicao(String email, ActionCodeSettings settings);
  Future<bool> possuiAdministracao();

  /// Encerra a sessão autenticada.
  Future<void> sair();

  /// Stream que emite o estado de autenticação (login/logout).
  Stream<User?> authStateChanges();
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

/// Resultado do seed de catálogo, sem PII.
class SeedResultado {
  const SeedResultado({required this.dados});
  final Map<String, dynamic> dados;

  int _inteiro(List<String> chaves) {
    for (final chave in chaves) {
      final valor = dados[chave];
      if (valor is num) return valor.toInt();
      if (valor is String) {
        final convertido = int.tryParse(valor);
        if (convertido != null) return convertido;
      }
    }
    return 0;
  }

  int get igrejasCriadas => _inteiro(const ['igrejasCriadas', 'igrejasCreated']);
  int get equipesCriadas => _inteiro(const ['equipesCriadas', 'equipesCreated']);

  /// `true` quando o backend reconheceu o `commandId` e devolveu o recibo já
  /// gravado, sem reexecutar a mutação (idempotência).
  bool get repetido => dados['repetido'] == true;

  String get versaoDataset => (dados['datasetVersao'] ?? '').toString();

  String get resumo {
    final estado =
        repetido ? 'Recibo idempotente (já executado)' : 'Execução concluída';
    final versao = versaoDataset.isEmpty ? '' : ' · Dataset: $versaoDataset';
    return 'Igrejas criadas: $igrejasCriadas · Equipes criadas: '
        '$equipesCriadas · $estado$versao';
  }
}

/// Disparo do seed de catálogo, sempre executado no backend autenticado.
abstract interface class SeedGateway {
  Future<SeedResultado> semearCatalogo(String commandId);
}

/// Nome da Custom Claim administrativa; espelha o backend.
const String claimAdministrativa = 'maanaimAdmin';

/// Lê a claim administrativa do mapa de claims, aceitando apenas `true`.
bool claimAdministrativaAtiva(Map<String, dynamic>? claims) =>
    claims?[claimAdministrativa] == true;

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

  @override
  Future<bool> possuiAdministracao() async {
    final usuario = _auth.currentUser;
    if (usuario == null) return false;
    final token = await usuario.getIdTokenResult(true);
    return claimAdministrativaAtiva(token.claims);
  }

  @override
  Future<void> sair() => _auth.signOut();

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();
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

class FirebaseSeedGateway implements SeedGateway {
  FirebaseSeedGateway(this._functions);
  final FirebaseFunctions _functions;

  @override
  Future<SeedResultado> semearCatalogo(String commandId) async {
    final resposta = await _functions
        .httpsCallable('semearCatalogoInicial')
        .call(<String, dynamic>{'commandId': commandId});
    final dados = (resposta.data as Map).cast<String, dynamic>();
    return SeedResultado(dados: dados);
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

  String? get emailAtual => _identidade.emailAtual;

  /// Renovar token evita que a UI mantenha uma concessão/revogação antiga.
  Future<bool> possuiAdministracao() => _identidade.possuiAdministracao();

  Future<void> sair() => _identidade.sair();

  Stream<User?> authStateChanges() => _identidade.authStateChanges();

  Future<void> recuperar(String email) => _identidade.enviarRedefinicao(
      email.trim(),
      ActionCodeSettings(
          url: const String.fromEnvironment('PASSWORD_RESET_CONTINUE_URL'),
          handleCodeInApp: false));

  static const mensagemRecuperacaoNeutra =
      'Se houver uma conta elegível, as instruções para definir nova senha foram enviadas.';
}

