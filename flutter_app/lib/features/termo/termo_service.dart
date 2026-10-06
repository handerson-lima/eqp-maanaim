import 'package:cloud_functions/cloud_functions.dart';

/// Modelo de dados da versão vigente do termo de voluntariado.
class TermoVigenteModel {
  const TermoVigenteModel({
    required this.id,
    required this.termoId,
    required this.numeroVersao,
    required this.titulo,
    required this.conteudo,
    required this.hashSha256,
    required this.publicadoEm,
  });

  final String id;
  final String termoId;
  final int numeroVersao;
  final String titulo;
  final String conteudo;
  final String hashSha256;
  final String publicadoEm;

  factory TermoVigenteModel.fromMap(Map<String, dynamic> map) {
    return TermoVigenteModel(
      id: map['id'] as String? ?? '',
      termoId: map['termoId'] as String? ?? 'termo-adesao-voluntariado',
      numeroVersao: (map['numeroVersao'] as num?)?.toInt() ?? 1,
      titulo: map['titulo'] as String? ?? '',
      conteudo: map['conteudo'] as String? ?? '',
      hashSha256: map['hashSha256'] as String? ?? '',
      publicadoEm: map['publicadoEm'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'termoId': termoId,
        'numeroVersao': numeroVersao,
        'titulo': titulo,
        'conteudo': conteudo,
        'hashSha256': hashSha256,
        'publicadoEm': publicadoEm,
      };
}

/// Modelo representativo do comprovante / evidência imutável de aceite.
class ComprovanteAceiteModel {
  const ComprovanteAceiteModel({
    required this.id,
    required this.uid,
    required this.fichaId,
    required this.termoId,
    required this.versaoId,
    required this.numeroVersao,
    required this.hashSha256,
    required this.titulo,
    required this.declaracaoLidoEConcordo,
    required this.aceitoEm,
    required this.commandId,
    this.repetido = false,
  });

  final String id;
  final String uid;
  final String fichaId;
  final String termoId;
  final String versaoId;
  final int numeroVersao;
  final String hashSha256;
  final String titulo;
  final bool declaracaoLidoEConcordo;
  final String aceitoEm;
  final String commandId;
  final bool repetido;

  factory ComprovanteAceiteModel.fromMap(Map<String, dynamic> map) {
    return ComprovanteAceiteModel(
      id: map['id'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      fichaId: map['fichaId'] as String? ?? '',
      termoId: map['termoId'] as String? ?? '',
      versaoId: map['versaoId'] as String? ?? '',
      numeroVersao: (map['numeroVersao'] as num?)?.toInt() ?? 1,
      hashSha256: map['hashSha256'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      declaracaoLidoEConcordo: map['declaracaoLidoEConcordo'] as bool? ?? true,
      aceitoEm: map['aceitoEm'] as String? ?? '',
      commandId: map['commandId'] as String? ?? '',
      repetido: map['repetido'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'uid': uid,
        'fichaId': fichaId,
        'termoId': termoId,
        'versaoId': versaoId,
        'numeroVersao': numeroVersao,
        'hashSha256': hashSha256,
        'titulo': titulo,
        'declaracaoLidoEConcordo': declaracaoLidoEConcordo,
        'aceitoEm': aceitoEm,
        'commandId': commandId,
        'repetido': repetido,
      };
}

/// Contrato para operações com termos institucionais e aceites de voluntários.
abstract class TermoGateway {
  Future<TermoVigenteModel?> obterTermoVigente({String? termoId});

  Future<ComprovanteAceiteModel> aceitarTermoVigente({
    required String commandId,
    required String versaoId,
    required String hashSha256,
    required bool declaracaoLidoEConcordo,
    String? correlationId,
    String? termoId,
  });

  Future<List<ComprovanteAceiteModel>> obterHistoricoAceites();
}

/// Implementação real via Cloud Functions autenticadas com App Check.
class FirebaseTermoGateway implements TermoGateway {
  FirebaseTermoGateway({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<TermoVigenteModel?> obterTermoVigente({String? termoId}) async {
    try {
      final callable = _functions.httpsCallable('obterTermoVigente');
      final resposta = await callable.call<Map<String, dynamic>>({
        if (termoId != null) 'termoId': termoId,
      });

      final dados = resposta.data;
      final versaoVigenteRaw = dados['versaoVigente'];
      if (versaoVigenteRaw is Map) {
        return TermoVigenteModel.fromMap(
          Map<String, dynamic>.from(versaoVigenteRaw),
        );
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Não foi possível carregar o termo vigente.');
    } catch (e) {
      throw Exception('Erro de comunicação ao obter o termo: $e');
    }
  }

  @override
  Future<ComprovanteAceiteModel> aceitarTermoVigente({
    required String commandId,
    required String versaoId,
    required String hashSha256,
    required bool declaracaoLidoEConcordo,
    String? correlationId,
    String? termoId,
  }) async {
    try {
      final callable = _functions.httpsCallable('aceitarTermoVigente');
      final resposta = await callable.call<Map<String, dynamic>>({
        'commandId': commandId,
        'versaoId': versaoId,
        'hashSha256': hashSha256,
        'declaracaoLidoEConcordo': declaracaoLidoEConcordo,
        if (correlationId != null) 'correlationId': correlationId,
        if (termoId != null) 'termoId': termoId,
      });

      final dados = resposta.data;
      final comprovanteRaw = dados['comprovante'];
      if (comprovanteRaw is Map) {
        final comprovanteMap = Map<String, dynamic>.from(comprovanteRaw);
        if (dados.containsKey('repetido')) {
          comprovanteMap['repetido'] = dados['repetido'];
        }
        return ComprovanteAceiteModel.fromMap(comprovanteMap);
      }
      throw Exception('Resposta de comprovante em formato inesperado.');
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Falha ao registrar o aceite do termo.');
    } catch (e) {
      throw Exception('Erro ao processar o aceite do termo: $e');
    }
  }

  @override
  Future<List<ComprovanteAceiteModel>> obterHistoricoAceites() async {
    try {
      final callable = _functions.httpsCallable('obterHistoricoAceites');
      final resposta = await callable.call<Map<String, dynamic>>();
      final listaRaw = resposta.data['aceites'] as List<dynamic>? ?? [];
      return listaRaw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => ComprovanteAceiteModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Falha ao obter histórico de aceites.');
    } catch (e) {
      throw Exception('Erro ao buscar histórico de aceites: $e');
    }
  }
}

/// Implementação em memória para testes unitários e visualização offline.
class MemoriaTermoGateway implements TermoGateway {
  MemoriaTermoGateway({
    TermoVigenteModel? termoVigenteInicial,
    bool semTermoVigente = false,
    List<ComprovanteAceiteModel>? aceitesIniciais,
    this.lancarErroAoObter,
    this.lancarErroAoAceitar,
  })  : _termoVigente = semTermoVigente
            ? null
            : (termoVigenteInicial ??
                const TermoVigenteModel(
                  id: 'versao-v1',
                  termoId: 'termo-adesao-voluntariado',
                  numeroVersao: 1,
                  titulo: 'Termo de Adesão ao Serviço Voluntário Maanaim',
                  conteudo:
                      'Pelo presente instrumento particular, o voluntário adere às atividades espirituais e práticas do Maanaim em conformidade à Lei 9.608/1998.',
                  hashSha256:
                      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
                  publicadoEm: '2026-10-01T12:00:00.000Z',
                )),
        _aceites = List.of(aceitesIniciais ?? const []);

  TermoVigenteModel? _termoVigente;
  final List<ComprovanteAceiteModel> _aceites;
  String? lancarErroAoObter;
  String? lancarErroAoAceitar;

  void definirTermoVigente(TermoVigenteModel? termo) {
    _termoVigente = termo;
  }

  @override
  Future<TermoVigenteModel?> obterTermoVigente({String? termoId}) async {
    if (lancarErroAoObter != null) {
      throw Exception(lancarErroAoObter);
    }
    return _termoVigente;
  }

  @override
  Future<ComprovanteAceiteModel> aceitarTermoVigente({
    required String commandId,
    required String versaoId,
    required String hashSha256,
    required bool declaracaoLidoEConcordo,
    String? correlationId,
    String? termoId,
  }) async {
    if (lancarErroAoAceitar != null) {
      throw Exception(lancarErroAoAceitar);
    }

    if (!declaracaoLidoEConcordo) {
      throw Exception(
        'A declaração explícita de leitura e concordância é obrigatória.',
      );
    }

    if (_termoVigente == null) {
      throw Exception('Nenhum termo vigente encontrado.');
    }

    if (_termoVigente!.id != versaoId || _termoVigente!.hashSha256 != hashSha256) {
      throw Exception(
        'A versão do termo informada não corresponde à versão vigente.',
      );
    }

    final existente = _aceites.where((a) => a.commandId == commandId).firstOrNull;
    if (existente != null) {
      return ComprovanteAceiteModel(
        id: existente.id,
        uid: existente.uid,
        fichaId: existente.fichaId,
        termoId: existente.termoId,
        versaoId: existente.versaoId,
        numeroVersao: existente.numeroVersao,
        hashSha256: existente.hashSha256,
        titulo: existente.titulo,
        declaracaoLidoEConcordo: existente.declaracaoLidoEConcordo,
        aceitoEm: existente.aceitoEm,
        commandId: existente.commandId,
        repetido: true,
      );
    }

    final comprovante = ComprovanteAceiteModel(
      id: versaoId,
      uid: 'uid-voluntario',
      fichaId: 'uid-voluntario',
      termoId: _termoVigente!.termoId,
      versaoId: versaoId,
      numeroVersao: _termoVigente!.numeroVersao,
      hashSha256: hashSha256,
      titulo: _termoVigente!.titulo,
      declaracaoLidoEConcordo: true,
      aceitoEm: DateTime.now().toUtc().toIso8601String(),
      commandId: commandId,
      repetido: false,
    );

    _aceites.insert(0, comprovante);
    return comprovante;
  }

  @override
  Future<List<ComprovanteAceiteModel>> obterHistoricoAceites() async {
    return List.unmodifiable(_aceites);
  }
}
