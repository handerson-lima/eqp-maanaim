import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Igreja do catálogo administrável; exibida como "Nome - Código".
class IgrejaCatalogo {
  const IgrejaCatalogo({
    required this.id,
    required this.nome,
    required this.codigo,
    required this.ativo,
    this.versao = 1,
    this.pastorLocalNome,
  });

  final String id;
  final String nome;
  final String codigo;
  final bool ativo;
  final int versao;
  final String? pastorLocalNome;

  String get rotulo => '$nome - $codigo';

  IgrejaCatalogo copyWith({
    String? id,
    String? nome,
    String? codigo,
    bool? ativo,
    int? versao,
    String? pastorLocalNome,
  }) =>
      IgrejaCatalogo(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        codigo: codigo ?? this.codigo,
        ativo: ativo ?? this.ativo,
        versao: versao ?? this.versao,
        pastorLocalNome: pastorLocalNome ?? this.pastorLocalNome,
      );
}

/// Equipe do catálogo administrável; sem código próprio no PRD.
class EquipeCatalogo {
  const EquipeCatalogo({
    required this.id,
    required this.nome,
    required this.ativo,
    this.versao = 1,
    this.responsavelNome,
  });

  final String id;
  final String nome;
  final bool ativo;
  final int versao;
  final String? responsavelNome;

  EquipeCatalogo copyWith({
    String? id,
    String? nome,
    bool? ativo,
    int? versao,
    String? responsavelNome,
  }) =>
      EquipeCatalogo(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        ativo: ativo ?? this.ativo,
        versao: versao ?? this.versao,
        responsavelNome: responsavelNome ?? this.responsavelNome,
      );
}

class CatalogoResposta {
  const CatalogoResposta({required this.igrejas, required this.equipes});

  final List<IgrejaCatalogo> igrejas;
  final List<EquipeCatalogo> equipes;
}

/// Operações autorizadas do catálogo no backend.
abstract interface class CatalogoGateway {
  Future<CatalogoResposta> consultar({String? termo});

  Future<void> alternarStatusIgreja({
    required String commandId,
    required String igrejaId,
    required bool ativo,
    String? correlationId,
  });

  Future<void> alternarStatusEquipe({
    required String commandId,
    required String equipeId,
    required bool ativo,
    String? correlationId,
  });

  Future<void> salvarIgreja({
    required String commandId,
    String? igrejaId,
    required String codigo,
    required String nome,
    required int expectedVersion,
    String? correlationId,
  });

  Future<void> salvarEquipe({
    required String commandId,
    String? equipeId,
    required String nome,
    required int expectedVersion,
    String? correlationId,
  });
}

const Map<String, String> _semAcento = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Normaliza para busca: sem acento e sem caixa, espelhando o backend.
String normalizarBusca(String valor) {
  final colapsado = valor.trim().replaceAll(RegExp(r'\s+'), ' ');
  final buffer = StringBuffer();
  for (final caractere in colapsado.toLowerCase().split('')) {
    buffer.write(_semAcento[caractere] ?? caractere);
  }
  return buffer.toString();
}

bool _corresponde(String nome, String? codigo, String termo) {
  final alvo = normalizarBusca(termo).trim();
  if (alvo.isEmpty) return true;
  if (normalizarBusca(nome).contains(alvo)) return true;
  return (codigo ?? '').contains(termo.trim());
}

List<IgrejaCatalogo> filtrarIgrejas(
  List<IgrejaCatalogo> igrejas,
  String termo,
) =>
    igrejas
        .where((i) => _corresponde(i.nome, i.codigo, termo))
        .toList(growable: false);

List<EquipeCatalogo> filtrarEquipes(
  List<EquipeCatalogo> equipes,
  String termo,
) =>
    equipes
        .where((e) => _corresponde(e.nome, null, termo))
        .toList(growable: false);

class FirebaseCatalogoGateway implements CatalogoGateway {
  FirebaseCatalogoGateway(this._functions, [FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  @override
  Future<CatalogoResposta> consultar({String? termo}) async {
    try {
      final payload = <String, dynamic>{};
      if (termo != null && termo.trim().isNotEmpty) {
        payload['termo'] = termo.trim();
      }
      final resposta =
          await _functions.httpsCallable('consultarCatalogo').call(payload);
      final dados = (resposta.data as Map).cast<String, dynamic>();
      return CatalogoResposta(
        igrejas: (dados['igrejas'] as List? ?? const [])
            .map((item) => _mapearIgreja((item as Map).cast<String, dynamic>()))
            .toList(growable: false),
        equipes: (dados['equipes'] as List? ?? const [])
            .map((item) => _mapearEquipe((item as Map).cast<String, dynamic>()))
            .toList(growable: false),
      );
    } on FirebaseFunctionsException catch (e) {
      // Proibição canônica de fallback silencioso que mascare falha administrativa
      if (e.code == 'permission-denied') {
        rethrow;
      }
      return _fallbackPublico(termo);
    } catch (_) {
      return _fallbackPublico(termo);
    }
  }

  Future<CatalogoResposta> _fallbackPublico(String? termo) async {
    // Fallback para usuários voluntários (não-administradores) em superfícies públicas:
    // Leitura direta das coleções abertas por firestore.rules para registros ativos.
    final resultados = await Future.wait([
      _firestore.collection('igrejas').where('ativo', isEqualTo: true).get(),
      _firestore.collection('equipes').where('ativo', isEqualTo: true).get(),
    ]);

    final igrejasSnap = resultados[0];
    final equipesSnap = resultados[1];

    final igrejas = igrejasSnap.docs.map((doc) {
      final d = doc.data();
      return IgrejaCatalogo(
        id: doc.id,
        nome: d['nome'] as String? ?? '',
        codigo: d['codigo']?.toString() ?? '',
        ativo: d['ativo'] as bool? ?? true,
        versao: (d['versao'] as num?)?.toInt() ?? 1,
      );
    }).toList();

    final equipes = equipesSnap.docs.map((doc) {
      final d = doc.data();
      return EquipeCatalogo(
        id: doc.id,
        nome: d['nome'] as String? ?? '',
        ativo: d['ativo'] as bool? ?? true,
        versao: (d['versao'] as num?)?.toInt() ?? 1,
      );
    }).toList();

    final igrejasFiltradas = termo != null && termo.trim().isNotEmpty
        ? filtrarIgrejas(igrejas, termo)
        : igrejas;
    final equipesFiltradas = termo != null && termo.trim().isNotEmpty
        ? filtrarEquipes(equipes, termo)
        : equipes;

    return CatalogoResposta(
      igrejas: igrejasFiltradas,
      equipes: equipesFiltradas,
    );
  }

  @override
  Future<void> alternarStatusIgreja({
    required String commandId,
    required String igrejaId,
    required bool ativo,
    String? correlationId,
  }) async {
    await _functions.httpsCallable('alternarStatusIgreja').call({
      'commandId': commandId,
      'igrejaId': igrejaId,
      'ativo': ativo,
      if (correlationId != null) 'correlationId': correlationId,
    });
  }

  @override
  Future<void> alternarStatusEquipe({
    required String commandId,
    required String equipeId,
    required bool ativo,
    String? correlationId,
  }) async {
    await _functions.httpsCallable('alternarStatusEquipe').call({
      'commandId': commandId,
      'equipeId': equipeId,
      'ativo': ativo,
      if (correlationId != null) 'correlationId': correlationId,
    });
  }

  @override
  Future<void> salvarIgreja({
    required String commandId,
    String? igrejaId,
    required String codigo,
    required String nome,
    required int expectedVersion,
    String? correlationId,
  }) async {
    await _functions.httpsCallable('salvarIgreja').call({
      'commandId': commandId,
      if (igrejaId != null) 'igrejaId': igrejaId,
      'codigo': codigo,
      'nome': nome,
      'expectedVersion': expectedVersion,
      if (correlationId != null) 'correlationId': correlationId,
    });
  }

  @override
  Future<void> salvarEquipe({
    required String commandId,
    String? equipeId,
    required String nome,
    required int expectedVersion,
    String? correlationId,
  }) async {
    await _functions.httpsCallable('salvarEquipe').call({
      'commandId': commandId,
      if (equipeId != null) 'equipeId': equipeId,
      'nome': nome,
      'expectedVersion': expectedVersion,
      if (correlationId != null) 'correlationId': correlationId,
    });
  }

  IgrejaCatalogo _mapearIgreja(Map<String, dynamic> dados) {
    String? pastorNome;
    if (dados['pastorLocal'] is Map) {
      pastorNome = (dados['pastorLocal'] as Map)['nome'] as String?;
    }
    return IgrejaCatalogo(
      id: dados['id'] as String? ?? '',
      nome: dados['nome'] as String? ?? '',
      codigo: dados['codigo']?.toString() ?? '',
      ativo: dados['ativo'] as bool? ?? false,
      versao: (dados['versao'] as num?)?.toInt() ?? 1,
      pastorLocalNome: pastorNome,
    );
  }

  EquipeCatalogo _mapearEquipe(Map<String, dynamic> dados) {
    String? respNome;
    if (dados['responsavel'] is Map) {
      respNome = (dados['responsavel'] as Map)['nome'] as String?;
    }
    return EquipeCatalogo(
      id: dados['id'] as String? ?? '',
      nome: dados['nome'] as String? ?? '',
      ativo: dados['ativo'] as bool? ?? false,
      versao: (dados['versao'] as num?)?.toInt() ?? 1,
      responsavelNome: respNome,
    );
  }
}
