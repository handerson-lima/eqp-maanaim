import 'package:cloud_functions/cloud_functions.dart';

import 'catalogo_service.dart' show normalizarBusca;

/// Papéis de sistema geridos pela administração (Q2); PASTOR_LOCAL/EQUIPE vêm
/// de vínculo e não são editáveis aqui.
const Map<String, String> rotulosPapeisSistema = {
  'ADMINISTRADOR': 'Administrador',
  'COORDENADOR': 'Coordenador',
};

String rotuloPapel(String papel) => rotulosPapeisSistema[papel] ?? papel;

/// Pessoa com identidade (Auth), perfil e conjunto de papéis separados.
class PessoaAdministrativa {
  const PessoaAdministrativa({
    required this.uid,
    required this.nomeCompleto,
    required this.email,
    required this.papeis,
    required this.versao,
    required this.coordenador,
  });

  final String uid;
  final String nomeCompleto;
  final String email;
  final List<String> papeis;
  final int versao;
  final bool coordenador;

  String get rotulo =>
      nomeCompleto.isNotEmpty ? nomeCompleto : (email.isNotEmpty ? email : uid);

  bool get temAdministrador => papeis.contains('ADMINISTRADOR');
  bool get temCoordenador => papeis.contains('COORDENADOR');

  String get papeisRotulo => papeis.isEmpty
      ? 'Sem papel de sistema'
      : papeis.map(rotuloPapel).join(' · ');
}

class PessoasResposta {
  const PessoasResposta({
    required this.pessoas,
    this.contextoPapeis = const [],
  });

  final List<PessoaAdministrativa> pessoas;

  /// Conjunto efetivo do solicitante, exibido apenas como leitura.
  final List<String> contextoPapeis;

  bool get vazio => pessoas.isEmpty;

  String get contextoRotulo => contextoPapeis.isEmpty
      ? 'Sem papel de sistema'
      : contextoPapeis.map(rotuloPapel).join(' · ');
}

class PessoaSalva {
  const PessoaSalva({
    required this.uid,
    required this.coordenador,
    required this.repetido,
  });

  final String uid;
  final bool coordenador;
  final bool repetido;
}

class PapeisResultado {
  const PapeisResultado({required this.papeis, required this.repetido});

  final List<String> papeis;
  final bool repetido;
}

/// Contrato de leitura e mutação de pessoas e papéis, sempre via Cloud Function.
abstract interface class PessoasGateway {
  Future<PessoasResposta> consultar({String? termo});

  Future<PessoaSalva> salvarPessoa({
    required String commandId,
    String? uid,
    required String nomeCompleto,
    required String email,
    required bool coordenador,
    String? cpf,
  });

  Future<PapeisResultado> alterarPapeis({
    required String commandId,
    required String alvoUid,
    required int versao,
    required String papel,
    required bool conceder,
  });
}

bool _correspondePessoa(PessoaAdministrativa pessoa, String termo) {
  final alvo = normalizarBusca(termo).trim();
  if (alvo.isEmpty) return true;
  if (normalizarBusca(pessoa.nomeCompleto).contains(alvo)) return true;
  return pessoa.email.toLowerCase().contains(termo.trim().toLowerCase());
}

List<PessoaAdministrativa> filtrarPessoas(
  List<PessoaAdministrativa> pessoas,
  String termo,
) => pessoas
    .where((pessoa) => _correspondePessoa(pessoa, termo))
    .toList(growable: false);

class FirebasePessoasGateway implements PessoasGateway {
  FirebasePessoasGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<PessoasResposta> consultar({String? termo}) async {
    final payload = <String, dynamic>{};
    if (termo != null && termo.trim().isNotEmpty) {
      payload['termo'] = termo.trim();
    }
    final resposta = await _functions
        .httpsCallable('consultarPessoas')
        .call(payload);
    final dados = (resposta.data as Map).cast<String, dynamic>();
    final contexto = (dados['contexto'] as Map?)?.cast<String, dynamic>();
    return PessoasResposta(
      pessoas: (dados['pessoas'] as List? ?? const [])
          .map((item) => _mapearPessoa((item as Map).cast<String, dynamic>()))
          .toList(growable: false),
      contextoPapeis: (contexto?['papeis'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  @override
  Future<PessoaSalva> salvarPessoa({
    required String commandId,
    String? uid,
    required String nomeCompleto,
    required String email,
    required bool coordenador,
    String? cpf,
  }) async {
    final payload = <String, dynamic>{
      'commandId': commandId,
      'nomeCompleto': nomeCompleto,
      'email': email,
      'coordenador': coordenador,
    };
    if (uid != null && uid.isNotEmpty) payload['uid'] = uid;
    if (coordenador && cpf != null && cpf.trim().isNotEmpty) {
      payload['cpf'] = cpf.trim();
    }
    final resposta = await _functions
        .httpsCallable('salvarPessoa')
        .call(payload);
    final dados = (resposta.data as Map).cast<String, dynamic>();
    return PessoaSalva(
      uid: dados['uid'] as String? ?? '',
      coordenador: dados['coordenador'] as bool? ?? false,
      repetido: dados['repetido'] as bool? ?? false,
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
    final resposta = await _functions
        .httpsCallable('gerenciarPapeis')
        .call(<String, dynamic>{
          'commandId': commandId,
          'alvoUid': alvoUid,
          'expectedVersion': versao,
          'papel': papel,
          'conceder': conceder,
        });
    final dados = (resposta.data as Map).cast<String, dynamic>();
    return PapeisResultado(
      papeis: (dados['papeis'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      repetido: dados['repetido'] as bool? ?? false,
    );
  }

  PessoaAdministrativa _mapearPessoa(Map<String, dynamic> dados) =>
      PessoaAdministrativa(
        uid: dados['uid'] as String? ?? '',
        nomeCompleto: dados['nomeCompleto'] as String? ?? '',
        email: dados['email'] as String? ?? '',
        papeis: (dados['papeis'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
        versao: (dados['versao'] as num?)?.toInt() ?? 0,
        coordenador: dados['coordenador'] as bool? ?? false,
      );
}
