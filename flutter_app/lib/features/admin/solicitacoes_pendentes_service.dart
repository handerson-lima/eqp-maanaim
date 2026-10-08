import 'package:cloud_functions/cloud_functions.dart';

/// Item de solicitação pendente retornado pelo backend.
class SolicitacaoPendenteItemModel {
  const SolicitacaoPendenteItemModel({
    required this.participacaoId,
    required this.fichaId,
    required this.equipeId,
    required this.equipeNome,
    required this.estado,
    required this.proximaAcao,
    required this.enviadoEm,
    required this.nomeVoluntario,
    required this.profissao,
    required this.cpfMascarado,
    required this.cpfDigitos,
    required this.igrejaId,
    required this.igrejaNome,
    required this.igrejaCodigo,
    this.pastorAprovou = false,
    this.responsavelAprovou = false,
  });

  factory SolicitacaoPendenteItemModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseData(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
      return null;
    }

    return SolicitacaoPendenteItemModel(
      participacaoId: (map['participacaoId'] ?? '') as String,
      fichaId: (map['fichaId'] ?? '') as String,
      equipeId: (map['equipeId'] ?? '') as String,
      equipeNome: (map['equipeNome'] ?? '') as String,
      estado: (map['estado'] ?? '') as String,
      proximaAcao: (map['proximaAcao'] ?? '') as String,
      enviadoEm: parseData(map['enviadoEm']),
      nomeVoluntario: (map['nomeVoluntario'] ?? '') as String,
      profissao: (map['profissao'] ?? '') as String,
      cpfMascarado: (map['cpfMascarado'] ?? '***.***.***-**') as String,
      cpfDigitos: (map['cpfDigitos'] ?? '') as String,
      igrejaId: (map['igrejaId'] ?? '') as String,
      igrejaNome: (map['igrejaNome'] ?? '') as String,
      igrejaCodigo: (map['igrejaCodigo'] ?? '') as String,
      pastorAprovou: map['pastorAprovou'] == true,
      responsavelAprovou: map['responsavelAprovou'] == true,
    );
  }

  final String participacaoId;
  final String fichaId;
  final String equipeId;
  final String equipeNome;
  final String estado;
  final String proximaAcao;
  final DateTime? enviadoEm;
  final String nomeVoluntario;
  final String profissao;
  final String cpfMascarado;
  final String cpfDigitos;
  final String igrejaId;
  final String igrejaNome;
  final String igrejaCodigo;
  final bool pastorAprovou;
  final bool responsavelAprovou;

  String get rotuloEstado {
    switch (estado) {
      case 'AGUARDANDO_PASTOR_LOCAL':
        return 'Aguardando Pastor Local';
      case 'AGUARDANDO_RESPONSAVEL_EQUIPE':
        return 'Aguardando Responsável';
      case 'AGUARDANDO_COORDENADOR':
        return 'Aguardando Coordenação';
      default:
        return estado;
    }
  }
}

/// Resultado consolidado retornado pelo backend.
class ResultadoSolicitacoesPendentesModel {
  const ResultadoSolicitacoesPendentesModel({
    required this.solicitacoes,
    required this.totalGeral,
    required this.geradoEm,
  });

  final List<SolicitacaoPendenteItemModel> solicitacoes;
  final int totalGeral;
  final DateTime? geradoEm;
}

/// Contrato para o gateway de solicitações pendentes administrativas.
abstract class SolicitacoesPendentesGateway {
  Future<ResultadoSolicitacoesPendentesModel> consultarSolicitacoesPendentesGlobal();
}

/// Implementação do gateway conectada ao Firebase Functions.
class FirebaseSolicitacoesPendentesGateway implements SolicitacoesPendentesGateway {
  FirebaseSolicitacoesPendentesGateway({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<ResultadoSolicitacoesPendentesModel> consultarSolicitacoesPendentesGlobal() async {
    final callable = _functions.httpsCallable('consultarSolicitacoesPendentesGlobal');
    final response = await callable.call<Map<String, dynamic>>();
    final data = Map<String, dynamic>.from(response.data);

    final listaRaw = (data['solicitacoes'] as List<dynamic>?) ?? [];
    final solicitacoes = listaRaw
        .map((e) => SolicitacaoPendenteItemModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    DateTime? geradoEm;
    if (data['geradoEm'] is String) {
      geradoEm = DateTime.tryParse(data['geradoEm'] as String);
    }

    return ResultadoSolicitacoesPendentesModel(
      solicitacoes: solicitacoes,
      totalGeral: (data['totalGeral'] as num?)?.toInt() ?? solicitacoes.length,
      geradoEm: geradoEm,
    );
  }
}

/// Mock in-memory para testes e desenvolvimento offline.
class MockSolicitacoesPendentesGateway implements SolicitacoesPendentesGateway {
  MockSolicitacoesPendentesGateway({List<SolicitacaoPendenteItemModel>? initialItems})
      : _items = initialItems ?? [];

  final List<SolicitacaoPendenteItemModel> _items;

  @override
  Future<ResultadoSolicitacoesPendentesModel> consultarSolicitacoesPendentesGlobal() async {
    return ResultadoSolicitacoesPendentesModel(
      solicitacoes: List.unmodifiable(_items),
      totalGeral: _items.length,
      geradoEm: DateTime.now(),
    );
  }
}
