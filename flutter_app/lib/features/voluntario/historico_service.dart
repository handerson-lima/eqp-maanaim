import 'package:cloud_functions/cloud_functions.dart';

/// Modelo de dados de evento da linha do tempo histórica.
class EventoLinhaDoTempoModel {
  const EventoLinhaDoTempoModel({
    required this.id,
    required this.tipo,
    required this.etapa,
    required this.titulo,
    required this.descricao,
    required this.estadoVisual,
    required this.timestamp,
    this.atorNome,
    this.atorPapel,
    this.atorVinculoId,
    this.equipeId,
    this.nomeEquipe,
    this.justificativaInterna,
  });

  final String id;
  final String tipo;
  final String etapa;
  final String titulo;
  final String descricao;
  final String estadoVisual; // 'CONCLUIDO', 'EM_ANDAMENTO', 'ORIENTACAO_PASTORAL'
  final String timestamp;
  final String? atorNome;
  final String? atorPapel;
  final String? atorVinculoId;
  final String? equipeId;
  final String? nomeEquipe;
  final String? justificativaInterna;

  bool get isConcluido => estadoVisual == 'CONCLUIDO';
  bool get isEmAndamento => estadoVisual == 'EM_ANDAMENTO';
  bool get isOrientacaoPastoral => estadoVisual == 'ORIENTACAO_PASTORAL';

  factory EventoLinhaDoTempoModel.fromMap(Map<String, dynamic> map) {
    final atorMap = map['ator'] as Map<String, dynamic>?;
    return EventoLinhaDoTempoModel(
      id: map['id'] as String? ?? '',
      tipo: map['tipo'] as String? ?? 'OUTRO',
      etapa: map['etapa'] as String? ?? 'CADASTRO',
      titulo: map['titulo'] as String? ?? 'Evento',
      descricao: map['descricao'] as String? ?? '',
      estadoVisual: map['estadoVisual'] as String? ?? '',
      timestamp: map['timestamp'] as String? ?? '',
      atorNome: atorMap?['nome'] as String?,
      atorPapel: atorMap?['papel'] as String?,
      atorVinculoId: atorMap?['vinculoId'] as String?,
      equipeId: map['equipeId'] as String?,
      nomeEquipe: map['nomeEquipe'] as String?,
      justificativaInterna: map['justificativaInterna'] as String?,
    );
  }
}

/// Modelo da ficha autorizada com projeção e minimização de dados.
class FichaConsultaModel {
  const FichaConsultaModel({
    required this.id,
    required this.ownerUid,
    required this.nomeCompleto,
    required this.profissao,
    this.cpfMascarado,
    this.cpfCompleto,
    required this.igrejaId,
    this.nomeIgreja,
    required this.estado,
    required this.versao,
    this.proximaAcao,
    this.mensagemVoluntario,
    this.atualizadoEm,
    this.criadoEm,
  });

  final String id;
  final String ownerUid;
  final String nomeCompleto;
  final String profissao;
  final String? cpfMascarado;
  final String? cpfCompleto;
  final String igrejaId;
  final String? nomeIgreja;
  final String estado;
  final int versao;
  final String? proximaAcao;
  final String? mensagemVoluntario;
  final String? atualizadoEm;
  final String? criadoEm;

  String get cpfExibicao => cpfCompleto ?? cpfMascarado ?? '***.***.***-**';

  factory FichaConsultaModel.fromMap(Map<String, dynamic> map) {
    return FichaConsultaModel(
      id: map['id'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      nomeCompleto: map['nomeCompleto'] as String? ?? '',
      profissao: map['profissao'] as String? ?? '',
      cpfMascarado: map['cpfMascarado'] as String?,
      cpfCompleto: map['cpfCompleto'] as String?,
      igrejaId: map['igrejaId'] as String? ?? '',
      nomeIgreja: map['nomeIgreja'] as String?,
      estado: map['estado'] as String? ?? 'RASCUNHO',
      versao: (map['versao'] as num?)?.toInt() ?? 1,
      proximaAcao: map['proximaAcao'] as String?,
      mensagemVoluntario: map['mensagemVoluntario'] as String?,
      atualizadoEm: map['atualizadoEm'] as String?,
      criadoEm: map['criadoEm'] as String?,
    );
  }
}

/// Modelo de participação projetada na consulta autorizada.
class ParticipacaoConsultaModel {
  const ParticipacaoConsultaModel({
    required this.id,
    required this.fichaId,
    required this.equipeId,
    required this.nomeEquipe,
    required this.estado,
    required this.ciclo,
    required this.proximaAcao,
    this.vigenciaInicio,
    this.vigenciaFim,
    this.cicloAtualId,
    this.atualizadoEm,
  });

  final String id;
  final String fichaId;
  final String equipeId;
  final String nomeEquipe;
  final String estado;
  final String ciclo;
  final String proximaAcao;
  final String? vigenciaInicio;
  final String? vigenciaFim;
  final String? cicloAtualId;
  final String? atualizadoEm;

  bool get isAtiva => estado == 'ATIVA';
  bool get isRejeitada => estado == 'REJEITADA';

  factory ParticipacaoConsultaModel.fromMap(Map<String, dynamic> map) {
    return ParticipacaoConsultaModel(
      id: map['id'] as String? ?? '',
      fichaId: map['fichaId'] as String? ?? '',
      equipeId: map['equipeId'] as String? ?? '',
      nomeEquipe: map['nomeEquipe'] as String? ?? '',
      estado: map['estado'] as String? ?? 'RASCUNHO',
      ciclo: map['ciclo'] as String? ?? 'INICIAL',
      proximaAcao: map['proximaAcao'] as String? ?? '',
      vigenciaInicio: map['vigenciaInicio'] as String?,
      vigenciaFim: map['vigenciaFim'] as String?,
      cicloAtualId: map['cicloAtualId'] as String?,
      atualizadoEm: map['atualizadoEm'] as String?,
    );
  }
}

/// Resultado consolidado da consulta de ficha autorizada.
class ResultadoConsultaFichaModel {
  const ResultadoConsultaFichaModel({
    required this.existe,
    this.ficha,
    required this.participacoes,
    required this.papel,
    required this.equipesFiltradas,
  });

  final bool existe;
  final FichaConsultaModel? ficha;
  final List<ParticipacaoConsultaModel> participacoes;
  final String papel;
  final bool equipesFiltradas;

  factory ResultadoConsultaFichaModel.fromMap(Map<String, dynamic> map) {
    final fichaMap = map['ficha'] as Map<String, dynamic>?;
    final partList = (map['participacoes'] as List<dynamic>?) ?? [];
    final escopoMap = map['escopo'] as Map<String, dynamic>?;

    return ResultadoConsultaFichaModel(
      existe: map['existe'] as bool? ?? false,
      ficha: fichaMap != null ? FichaConsultaModel.fromMap(fichaMap) : null,
      participacoes: partList
          .map((p) => ParticipacaoConsultaModel.fromMap(p as Map<String, dynamic>))
          .toList(),
      papel: escopoMap?['papel'] as String? ?? 'VOLUNTARIO',
      equipesFiltradas: escopoMap?['equipesFiltradas'] as bool? ?? false,
    );
  }
}

/// Serviço de consulta autorizada de ficha e linha do tempo histórica.
class HistoricoService {
  HistoricoService({FirebaseFunctions? functions}) : _functions = functions;

  final FirebaseFunctions? _functions;

  FirebaseFunctions get _resolvedFunctions =>
      _functions ?? FirebaseFunctions.instance;

  /// Consulta a ficha cadastral e participações autorizadas no escopo do ator.
  Future<ResultadoConsultaFichaModel> consultarFichaAutorizada({String? fichaId}) async {
    final callable = _resolvedFunctions.httpsCallable('consultarFichaAutorizada');
    final response = await callable.call<Map<String, dynamic>>({
      if (fichaId != null && fichaId.trim().isNotEmpty) 'fichaId': fichaId.trim(),
    });

    return ResultadoConsultaFichaModel.fromMap(
      Map<String, dynamic>.from(response.data),
    );
  }

  /// Consulta a linha do tempo autorizada e cronológica com sanitização de escopo.
  Future<List<EventoLinhaDoTempoModel>> consultarLinhaDoTempoAutorizada({
    String? fichaId,
    String? participacaoId,
  }) async {
    final callable = _resolvedFunctions.httpsCallable('consultarLinhaDoTempoAutorizada');
    final response = await callable.call<Map<String, dynamic>>({
      if (fichaId != null && fichaId.trim().isNotEmpty) 'fichaId': fichaId.trim(),
      if (participacaoId != null && participacaoId.trim().isNotEmpty)
        'participacaoId': participacaoId.trim(),
    });

    final data = Map<String, dynamic>.from(response.data);
    final eventosRaw = (data['eventos'] as List<dynamic>?) ?? [];

    return eventosRaw
        .map((e) => EventoLinhaDoTempoModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
