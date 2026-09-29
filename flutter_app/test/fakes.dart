import 'dart:async';

import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Usuário mínimo para o stream de sessão; apenas a identidade não-nula
/// importa para o roteamento, então os demais membros são encaminhados.
class UsuarioFake implements User {
  UsuarioFake({this.uid = 'uid-teste'});

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class IdentidadeFake implements IdentidadeGateway {
  IdentidadeFake({this.email, this.admin = false});
  String? email;
  int criadas = 0;
  int redefinicoes = 0;
  int logouts = 0;
  bool admin;
  final StreamController<User?> _authController = StreamController<User?>.broadcast();

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
    _authController.add(UsuarioFake());
  }

  @override
  Future<void> enviarRedefinicao(String email, ActionCodeSettings settings) async {
    redefinicoes++;
  }

  @override
  Future<bool> possuiAdministracao() async => admin;

  @override
  Future<void> sair() async {
    logouts++;
    email = null;
    _authController.add(null);
  }

  @override
  Stream<User?> authStateChanges() => _authController.stream;

  /// Simula um login: marca a sessão e emite um usuário no stream.
  void simularLogin({String? email}) {
    this.email = email ?? this.email ?? 'usuario@test.com';
    _authController.add(UsuarioFake());
  }

  /// Simula um logout.
  void simularLogout() {
    email = null;
    _authController.add(null);
  }

  void dispose() => _authController.close();
}

class RascunhoFake implements RascunhoGateway {
  int chamadas = 0;
  Map<String, String>? ultimo;
  bool falhar = false;
  bool retomado = false;

  @override
  Future<RascunhoResultado> criarOuRetomar(Map<String, String> dados) async {
    chamadas++;
    ultimo = dados;
    if (falhar) throw Exception('falha simulada');
    return RascunhoResultado(estado: 'RASCUNHO', retomado: retomado);
  }
}

/// Serviço com recuperação que sempre falha, para exercitar a resposta neutra.
class AuthRecuperacaoFalha extends AuthService {
  AuthRecuperacaoFalha() : super(IdentidadeFake(), RascunhoFake());

  @override
  Future<void> recuperar(String email) async => throw Exception('falha simulada');
}

class CatalogoFake implements CatalogoGateway {
  CatalogoFake({this.resposta});
  CatalogoResposta? resposta;
  bool falhar = false;
  int chamadas = 0;
  Completer<void>? pendente;

  @override
  Future<CatalogoResposta> consultar({String? termo}) async {
    chamadas++;
    if (pendente != null) await pendente!.future;
    if (falhar) throw Exception('falha simulada');
    return resposta ??
        const CatalogoResposta(igrejas: <IgrejaCatalogo>[], equipes: <EquipeCatalogo>[]);
  }
}

class SeedFake implements SeedGateway {
  int chamadas = 0;
  String? ultimoCommandId;
  bool falhar = false;
  bool repetido = false;
  int igrejasCriadas = 25;
  int equipesCriadas = 14;
  String datasetVersao = '1';

  @override
  Future<SeedResultado> semearCatalogo(String commandId) async {
    chamadas++;
    ultimoCommandId = commandId;
    if (falhar) throw Exception('falha simulada');
    return SeedResultado(dados: {
      'repetido': repetido,
      'datasetVersao': datasetVersao,
      'igrejasCriadas': igrejasCriadas,
      'equipesCriadas': equipesCriadas,
    });
  }
}
