import 'package:cloud_functions/cloud_functions.dart';

/// Representação imutável de uma versão específica do termo de voluntariado.
class VersaoTermo {
  const VersaoTermo({
    required this.id,
    required this.termoId,
    required this.numeroVersao,
    required this.titulo,
    required this.conteudo,
    required this.hashSha256,
    required this.publicadoEm,
    required this.publicadoPorUid,
    this.versaoAnteriorId,
    this.imutavel = true,
    this.universoRegistrado = false,
    this.totalAfetados = 0,
    this.aceitosHistorico = 0,
    this.pendentesHistorico = 0,
    this.criterio,
    this.instanteSnapshot,
    this.completo = true,
  });

  factory VersaoTermo.fromMap(Map<String, dynamic> map) {
    final uSnap = map['universoSnapshot'] as Map<dynamic, dynamic>?;
    final universoRegistrado = uSnap != null && uSnap['registrado'] == true;
    final totalAfetados = (uSnap?['totalAfetados'] as num?)?.toInt() ?? 0;
    final aceitosHistorico = (uSnap?['aceitosCount'] as num?)?.toInt() ?? 0;
    final pendentesHistorico = (uSnap?['pendentesCount'] as num?)?.toInt() ?? 0;
    final criterio = uSnap?['criterio'] as String?;
    final instanteSnapshot = uSnap?['instante'] != null
        ? DateTime.tryParse(uSnap!['instante'] as String)
        : null;
    final completo = uSnap?['completo'] as bool? ?? true;

    return VersaoTermo(
      id: map['id'] as String? ?? '',
      termoId: map['termoId'] as String? ?? '',
      numeroVersao: (map['numeroVersao'] as num?)?.toInt() ?? 0,
      titulo: map['titulo'] as String? ?? '',
      conteudo: map['conteudo'] as String? ?? '',
      hashSha256: map['hashSha256'] as String? ?? '',
      publicadoEm: map['publicadoEm'] != null
          ? DateTime.tryParse(map['publicadoEm'] as String)
          : null,
      publicadoPorUid: map['publicadoPorUid'] as String? ?? '',
      versaoAnteriorId: map['versaoAnteriorId'] as String?,
      imutavel: map['imutavel'] as bool? ?? true,
      universoRegistrado: universoRegistrado,
      totalAfetados: totalAfetados,
      aceitosHistorico: aceitosHistorico,
      pendentesHistorico: pendentesHistorico,
      criterio: criterio,
      instanteSnapshot: instanteSnapshot,
      completo: completo,
    );
  }

  final String id;
  final String termoId;
  final int numeroVersao;
  final String titulo;
  final String conteudo;
  final String hashSha256;
  final DateTime? publicadoEm;
  final String publicadoPorUid;
  final String? versaoAnteriorId;
  final bool imutavel;
  final bool universoRegistrado;
  final int totalAfetados;
  final int aceitosHistorico;
  final int pendentesHistorico;
  final String? criterio;
  final DateTime? instanteSnapshot;
  final bool completo;

  String get rotuloVersao => 'v$numeroVersao';

  String get hashResumido =>
      hashSha256.length >= 12 ? '${hashSha256.substring(0, 12)}...' : hashSha256;

  String get descricaoHistoricoAceites {
    if (!universoRegistrado) {
      return 'Indisponível — universo histórico não registrado';
    }
    return '$aceitosHistorico de $totalAfetados aceitaram ($pendentesHistorico pendentes)';
  }
}

/// Representação agregada do termo pai com sua versão vigente e histórico.
class TermoVigente {
  const TermoVigente({
    required this.id,
    required this.tipoTermo,
    required this.titulo,
    required this.versaoVigenteId,
    required this.versaoVigenteNumero,
    required this.hashSha256,
    required this.totalVersoes,
    this.publicadoEm,
    this.atualizadoEm,
    this.ativo = true,
    this.versoes = const [],
    this.totalAtivosAtuais = 0,
    this.ativosComAceiteVigentePendente = 0,
    this.calculadoEm,
  });

  factory TermoVigente.fromMap(Map<String, dynamic> map) {
    final versoesRaw = (map['versoes'] as List<dynamic>?) ?? [];
    final pendencia = map['pendenciaOperacional'] as Map<dynamic, dynamic>?;
    final totalAtivos = (pendencia?['totalAtivos'] as num?)?.toInt() ?? 0;
    final pendentes = (pendencia?['pendentesVigente'] as num?)?.toInt() ?? 0;
    final calculado = pendencia?['calculadoEm'] != null
        ? DateTime.tryParse(pendencia!['calculadoEm'] as String)
        : null;

    return TermoVigente(
      id: map['id'] as String? ?? '',
      tipoTermo: map['tipoTermo'] as String? ?? 'ADESAO_VOLUNTARIADO',
      titulo: map['titulo'] as String? ?? '',
      versaoVigenteId: map['versaoVigenteId'] as String? ?? '',
      versaoVigenteNumero: (map['versaoVigenteNumero'] as num?)?.toInt() ?? 0,
      hashSha256: map['hashSha256'] as String? ?? '',
      totalVersoes: (map['totalVersoes'] as num?)?.toInt() ?? 0,
      publicadoEm: map['publicadoEm'] != null
          ? DateTime.tryParse(map['publicadoEm'] as String)
          : null,
      atualizadoEm: map['atualizadoEm'] != null
          ? DateTime.tryParse(map['atualizadoEm'] as String)
          : null,
      ativo: map['ativo'] as bool? ?? true,
      versoes: versoesRaw
          .whereType<Map>()
          .map((v) => VersaoTermo.fromMap(v.cast<String, dynamic>()))
          .toList(),
      totalAtivosAtuais: totalAtivos,
      ativosComAceiteVigentePendente: pendentes,
      calculadoEm: calculado,
    );
  }

  final String id;
  final String tipoTermo;
  final String titulo;
  final String versaoVigenteId;
  final int versaoVigenteNumero;
  final String hashSha256;
  final int totalVersoes;
  final DateTime? publicadoEm;
  final DateTime? atualizadoEm;
  final bool ativo;
  final List<VersaoTermo> versoes;
  final int totalAtivosAtuais;
  final int ativosComAceiteVigentePendente;
  final DateTime? calculadoEm;

  int get ativosComAceiteVigenteConcluido =>
      totalAtivosAtuais - ativosComAceiteVigentePendente;

  VersaoTermo? get versaoAtual =>
      versoes.cast<VersaoTermo?>().firstWhere(
            (v) => v?.id == versaoVigenteId,
            orElse: () => versoes.isNotEmpty ? versoes.first : null,
          );
}

/// Resultado do comando atômico de publicação de termo.
class ResultadoPublicarTermo {
  const ResultadoPublicarTermo({
    required this.concluido,
    required this.repetido,
    required this.termoId,
    required this.versaoId,
    required this.numeroVersao,
    required this.hashSha256,
    required this.totalVoluntariosImpactados,
  });

  factory ResultadoPublicarTermo.fromMap(Map<String, dynamic> map) {
    return ResultadoPublicarTermo(
      concluido: map['concluido'] as bool? ?? false,
      repetido: map['repetido'] as bool? ?? false,
      termoId: map['termoId'] as String? ?? '',
      versaoId: map['versaoId'] as String? ?? '',
      numeroVersao: (map['numeroVersao'] as num?)?.toInt() ?? 0,
      hashSha256: map['hashSha256'] as String? ?? '',
      totalVoluntariosImpactados:
          (map['totalVoluntariosImpactados'] as num?)?.toInt() ?? 0,
    );
  }

  final bool concluido;
  final bool repetido;
  final String termoId;
  final String versaoId;
  final int numeroVersao;
  final String hashSha256;
  final int totalVoluntariosImpactados;
}

/// Contrato para o gateway de termos utilizado pela interface administrativa.
abstract class TermosGateway {
  Future<TermoVigente?> consultarTermos({String? termoId});

  Future<VersaoTermo?> obterTermoVigente({String? termoId});

  Future<ResultadoPublicarTermo> publicarTermo({
    required String commandId,
    String? correlationId,
    String? termoId,
    required String titulo,
    required String conteudo,
    required int expectedVersion,
  });
}

/// Implementação do gateway de termos via Firebase Cloud Functions.
class FirebaseTermosService implements TermosGateway {
  FirebaseTermosService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<TermoVigente?> consultarTermos({String? termoId}) async {
    final payload = <String, dynamic>{};
    if (termoId != null) payload['termoId'] = termoId;

    final resposta = await _functions
        .httpsCallable('consultarTermos')
        .call(payload);

    final dados = (resposta.data as Map?)?.cast<String, dynamic>();
    final termoMap = dados?['termo'] as Map<dynamic, dynamic>?;
    if (termoMap == null) return null;

    return TermoVigente.fromMap(termoMap.cast<String, dynamic>());
  }

  @override
  Future<VersaoTermo?> obterTermoVigente({String? termoId}) async {
    final payload = <String, dynamic>{};
    if (termoId != null) payload['termoId'] = termoId;

    final resposta = await _functions
        .httpsCallable('obterTermoVigente')
        .call(payload);

    final dados = (resposta.data as Map?)?.cast<String, dynamic>();
    final versaoMap = dados?['versaoVigente'] as Map<dynamic, dynamic>?;
    if (versaoMap == null) return null;

    return VersaoTermo.fromMap(versaoMap.cast<String, dynamic>());
  }

  @override
  Future<ResultadoPublicarTermo> publicarTermo({
    required String commandId,
    String? correlationId,
    String? termoId,
    required String titulo,
    required String conteudo,
    required int expectedVersion,
  }) async {
    final payload = <String, dynamic>{
      'commandId': commandId,
      'titulo': titulo.trim(),
      'conteudo': conteudo.trim(),
      'expectedVersion': expectedVersion,
    };
    if (correlationId != null) payload['correlationId'] = correlationId;
    if (termoId != null) payload['termoId'] = termoId;

    final resposta = await _functions
        .httpsCallable('publicarTermo')
        .call(payload);

    final dados = (resposta.data as Map).cast<String, dynamic>();
    return ResultadoPublicarTermo.fromMap(dados);
  }
}
