import 'dart:async';

import 'package:eqp_maanaim/features/admin/catalogo_service.dart';
import 'package:eqp_maanaim/features/admin/pessoas_service.dart';
import 'package:eqp_maanaim/features/admin/vinculos_service.dart';
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
  final StreamController<User?> _authController =
      StreamController<User?>.broadcast();

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
  Future<void> enviarRedefinicao(
    String email,
    ActionCodeSettings settings,
  ) async {
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
  Future<void> recuperar(String email) async =>
      throw Exception('falha simulada');
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
        const CatalogoResposta(
          igrejas: <IgrejaCatalogo>[],
          equipes: <EquipeCatalogo>[],
        );
  }
}

class PessoasFake implements PessoasGateway {
  PessoasFake({this.resposta});
  PessoasResposta? resposta;
  bool falhar = false;
  bool salvarFalhar = false;
  bool alterarFalhar = false;
  int consultas = 0;
  int salvamentos = 0;
  int alteracoes = 0;
  String? termo;
  String? ultimoCommandId;
  String? ultimoAlvo;
  String? ultimoPapel;
  bool? ultimoConceder;
  int? ultimaVersao;
  int? ultimaVersaoPessoa;
  String? ultimoNome;
  String? ultimoCpf;
  bool? ultimoCoordenador;

  PessoasResposta _base() =>
      resposta ?? const PessoasResposta(pessoas: <PessoaAdministrativa>[]);

  @override
  Future<PessoasResposta> consultar({String? termo}) async {
    consultas++;
    this.termo = termo;
    if (falhar) throw Exception('falha simulada');
    return _base();
  }

  @override
  Future<PessoaSalva> salvarPessoa({
    required String commandId,
    String? uid,
    required int versao,
    required String nomeCompleto,
    required String email,
    required bool coordenador,
    String? cpf,
  }) async {
    salvamentos++;
    ultimoCommandId = commandId;
    ultimaVersaoPessoa = versao;
    ultimoNome = nomeCompleto;
    ultimoCpf = cpf;
    ultimoCoordenador = coordenador;
    if (salvarFalhar) throw Exception('falha simulada');
    return PessoaSalva(
      uid: uid ?? 'novo-uid',
      coordenador: coordenador,
      repetido: false,
    );
  }

  @override
  Future<PapeisResultado> alterarPapeis({
    required String commandId,
    required String alvoUid,
    required int versao,
    required String papel,
    required bool conceder,
  }) async {
    alteracoes++;
    ultimoCommandId = commandId;
    ultimoAlvo = alvoUid;
    ultimoPapel = papel;
    ultimoConceder = conceder;
    ultimaVersao = versao;
    if (alterarFalhar) throw Exception('falha simulada');
    return const PapeisResultado(papeis: <String>[], repetido: false);
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
    return SeedResultado(
      dados: {
        'repetido': repetido,
        'datasetVersao': datasetVersao,
        'igrejasCriadas': igrejasCriadas,
        'equipesCriadas': equipesCriadas,
      },
    );
  }
}

class VinculosFake implements VinculosGateway {
  VinculosFake({this.resposta, this.pessoas = const []});
  VinculosResposta? resposta;
  List<PessoaAdministrativa> pessoas;
  bool falhar = false;
  bool gerenciarFalhar = false;
  int consultas = 0;
  int buscas = 0;
  int gerenciamentos = 0;
  String? ultimoCommandId;
  String? ultimoTipoEntidade;
  String? ultimoEntidadeId;
  String? ultimoAcao;
  String? ultimoPessoaId;
  DateTime? ultimaData;
  int? ultimaVersao;
  String? ultimaJustificativa;

  @override
  Future<VinculosResposta> consultar({String? termo}) async {
    consultas++;
    if (falhar) throw Exception('falha simulada');
    return resposta ?? const VinculosResposta(igrejas: [], equipes: []);
  }

  @override
  Future<List<PessoaAdministrativa>> buscarPessoas({String? termo}) async {
    buscas++;
    return pessoas;
  }

  @override
  Future<VinculoResultado> gerenciar({
    required String commandId,
    required String tipoEntidade,
    required String entidadeId,
    required String acao,
    String? pessoaId,
    required DateTime dataEfetiva,
    required int versao,
    String? justificativa,
  }) async {
    gerenciamentos++;
    ultimoCommandId = commandId;
    ultimoTipoEntidade = tipoEntidade;
    ultimoEntidadeId = entidadeId;
    ultimoAcao = acao;
    ultimoPessoaId = pessoaId;
    ultimaData = dataEfetiva;
    ultimaVersao = versao;
    ultimaJustificativa = justificativa;
    if (gerenciarFalhar) throw Exception('falha simulada');
    return const VinculoResultado(
      vinculoId: 'vinculo-fake',
      pessoaId: 'pessoa-fake',
      versaoVinculo: 1,
      repetido: false,
    );
  }
}
