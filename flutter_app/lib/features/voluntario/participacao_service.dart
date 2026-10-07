import 'package:cloud_functions/cloud_functions.dart';

import '../../comando.dart';

/// Modelo de dados da participação do voluntário em uma equipe.
class ParticipacaoModel {
  const ParticipacaoModel({
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
    this.criadoEm,
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
  final String? criadoEm;
  final String? atualizadoEm;

  bool get isRascunho => estado == 'RASCUNHO';
  bool get isAtiva => estado == 'ATIVA';
  bool get isRejeitada => estado == 'REJEITADA';
  bool get isPendente => !isRascunho && !isAtiva && !isRejeitada;

  factory ParticipacaoModel.fromMap(Map<String, dynamic> map) {
    return ParticipacaoModel(
      id: map['id'] as String? ?? '',
      fichaId: map['fichaId'] as String? ?? '',
      equipeId: map['equipeId'] as String? ?? '',
      nomeEquipe: map['nomeEquipe'] as String? ?? '',
      estado: map['estado'] as String? ?? 'RASCUNHO',
      ciclo: map['ciclo'] as String? ?? 'INICIAL',
      proximaAcao: map['proximaAcao'] as String? ?? 'Aguardando envio da ficha',
      vigenciaInicio: map['vigenciaInicio'] as String?,
      vigenciaFim: map['vigenciaFim'] as String?,
      cicloAtualId: map['cicloAtualId'] as String?,
      criadoEm: map['criadoEm'] as String?,
      atualizadoEm: map['atualizadoEm'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'fichaId': fichaId,
        'equipeId': equipeId,
        'nomeEquipe': nomeEquipe,
        'estado': estado,
        'ciclo': ciclo,
        'proximaAcao': proximaAcao,
        if (vigenciaInicio != null) 'vigenciaInicio': vigenciaInicio,
        if (vigenciaFim != null) 'vigenciaFim': vigenciaFim,
        if (cicloAtualId != null) 'cicloAtualId': cicloAtualId,
        if (criadoEm != null) 'criadoEm': criadoEm,
        if (atualizadoEm != null) 'atualizadoEm': atualizadoEm,
      };

  ParticipacaoModel copyWith({
    String? id,
    String? fichaId,
    String? equipeId,
    String? nomeEquipe,
    String? estado,
    String? ciclo,
    String? proximaAcao,
    String? vigenciaInicio,
    String? vigenciaFim,
    String? cicloAtualId,
    String? criadoEm,
    String? atualizadoEm,
  }) {
    return ParticipacaoModel(
      id: id ?? this.id,
      fichaId: fichaId ?? this.fichaId,
      equipeId: equipeId ?? this.equipeId,
      nomeEquipe: nomeEquipe ?? this.nomeEquipe,
      estado: estado ?? this.estado,
      ciclo: ciclo ?? this.ciclo,
      proximaAcao: proximaAcao ?? this.proximaAcao,
      vigenciaInicio: vigenciaInicio ?? this.vigenciaInicio,
      vigenciaFim: vigenciaFim ?? this.vigenciaFim,
      cicloAtualId: cicloAtualId ?? this.cicloAtualId,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }
}

/// Contrato para comunicação com o backend de participações.
abstract interface class ParticipacaoGateway {
  Future<List<ParticipacaoModel>> obterMinhasParticipacoes();
  Future<List<ParticipacaoModel>> salvarParticipacoesRascunho(
    List<String> equipeIds, {
    String? commandId,
  });
}

/// Implementação Firebase Cloud Functions do gateway de participações.
class FirebaseParticipacaoGateway implements ParticipacaoGateway {
  FirebaseParticipacaoGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<List<ParticipacaoModel>> obterMinhasParticipacoes() async {
    final resposta = await _functions.httpsCallable('obterMinhasParticipacoes').call();
    final dados = (resposta.data as Map).cast<String, dynamic>();
    final lista = (dados['participacoes'] as List? ?? const [])
        .map((p) => ParticipacaoModel.fromMap((p as Map).cast<String, dynamic>()))
        .toList(growable: false);
    return lista;
  }

  @override
  Future<List<ParticipacaoModel>> salvarParticipacoesRascunho(
    List<String> equipeIds, {
    String? commandId,
  }) async {
    final cid = commandId ?? comandoOpaco();
    final resposta = await _functions.httpsCallable('salvarParticipacoesRascunho').call({
      'commandId': cid,
      'equipeIds': equipeIds,
    });
    final dados = (resposta.data as Map).cast<String, dynamic>();
    final lista = (dados['participacoes'] as List? ?? const [])
        .map((p) => ParticipacaoModel.fromMap((p as Map).cast<String, dynamic>()))
        .toList(growable: false);
    return lista;
  }
}

/// Implementação em memória para testes e fallback.
class MemoriaParticipacaoGateway implements ParticipacaoGateway {
  MemoriaParticipacaoGateway({List<ParticipacaoModel>? participacoesIniciais})
      : _participacoes = List.of(participacoesIniciais ?? []);

  final List<ParticipacaoModel> _participacoes;
  Map<String, String> nomesEquipes = {};

  @override
  Future<List<ParticipacaoModel>> obterMinhasParticipacoes() async {
    return List.unmodifiable(_participacoes);
  }

  @override
  Future<List<ParticipacaoModel>> salvarParticipacoesRascunho(
    List<String> equipeIds, {
    String? commandId,
  }) async {
    // Remove as que estão em RASCUNHO e não estão na lista
    _participacoes.removeWhere((p) => p.isRascunho && !equipeIds.contains(p.equipeId));

    // Adiciona as novas
    for (final eqId in equipeIds) {
      if (!_participacoes.any((p) => p.equipeId == eqId && p.isRascunho)) {
        _participacoes.add(
          ParticipacaoModel(
            id: 'mem-$eqId-${_participacoes.length}',
            fichaId: 'mem-uid',
            equipeId: eqId,
            nomeEquipe: nomesEquipes[eqId] ?? eqId,
            estado: 'RASCUNHO',
            ciclo: 'INICIAL',
            proximaAcao: 'Aguardando envio da ficha',
          ),
        );
      }
    }

    _participacoes.sort((a, b) => a.nomeEquipe.compareTo(b.nomeEquipe));
    return List.unmodifiable(_participacoes);
  }
}
