import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

class ItemFilaResponsavelEquipe {
  const ItemFilaResponsavelEquipe({
    required this.participacaoId,
    required this.fichaId,
    required this.voluntarioUid,
    required this.voluntarioNome,
    required this.igrejaId,
    this.nomeIgreja,
    required this.equipeId,
    required this.nomeEquipe,
    required this.estado,
    required this.proximaAcao,
    required this.versao,
    required this.enviadoEm,
    this.isRenovacaoAnual = false,
    this.cicloId,
    this.anoVigencia,
  });

  final String participacaoId;
  final String fichaId;
  final String voluntarioUid;
  final String voluntarioNome;
  final String igrejaId;
  final String? nomeIgreja;
  final String equipeId;
  final String nomeEquipe;
  final String estado;
  final String proximaAcao;
  final int versao;
  final String enviadoEm;
  final bool isRenovacaoAnual;
  final String? cicloId;
  final int? anoVigencia;

  factory ItemFilaResponsavelEquipe.fromMap(Map<String, dynamic> map) {
    final isRenovacao = map['isRenovacaoAnual'] == true ||
        (map['tipo'] ?? '').toString() == 'RENOVACAO_ANUAL' ||
        (map['proximaAcao'] ?? '').toString().contains('Ciclo Anual');

    return ItemFilaResponsavelEquipe(
      participacaoId: (map['participacaoId'] ?? map['id'] ?? '').toString(),
      fichaId: (map['fichaId'] ?? '').toString(),
      voluntarioUid: (map['voluntarioUid'] ?? map['fichaId'] ?? '').toString(),
      voluntarioNome: (map['voluntarioNome'] ?? 'Voluntário').toString(),
      igrejaId: (map['igrejaId'] ?? '').toString(),
      nomeIgreja: map['nomeIgreja']?.toString(),
      equipeId: (map['equipeId'] ?? '').toString(),
      nomeEquipe: (map['nomeEquipe'] ?? 'Equipe').toString(),
      estado: (map['estado'] ?? 'AGUARDANDO_RESPONSAVEL_EQUIPE').toString(),
      proximaAcao: (map['proximaAcao'] ?? 'Aguardando avaliação do Responsável de Equipe').toString(),
      versao: map['versao'] is num ? (map['versao'] as num).toInt() : 1,
      enviadoEm: (map['enviadoEm'] ?? '').toString(),
      isRenovacaoAnual: isRenovacao,
      cicloId: map['cicloId']?.toString(),
      anoVigencia: map['anoVigencia'] is num ? (map['anoVigencia'] as num).toInt() : null,
    );
  }

  ItemFilaResponsavelEquipe copyWith({
    String? participacaoId,
    String? fichaId,
    String? voluntarioUid,
    String? voluntarioNome,
    String? igrejaId,
    String? nomeIgreja,
    String? equipeId,
    String? nomeEquipe,
    String? estado,
    String? proximaAcao,
    int? versao,
    String? enviadoEm,
  }) {
    return ItemFilaResponsavelEquipe(
      participacaoId: participacaoId ?? this.participacaoId,
      fichaId: fichaId ?? this.fichaId,
      voluntarioUid: voluntarioUid ?? this.voluntarioUid,
      voluntarioNome: voluntarioNome ?? this.voluntarioNome,
      igrejaId: igrejaId ?? this.igrejaId,
      nomeIgreja: nomeIgreja ?? this.nomeIgreja,
      equipeId: equipeId ?? this.equipeId,
      nomeEquipe: nomeEquipe ?? this.nomeEquipe,
      estado: estado ?? this.estado,
      proximaAcao: proximaAcao ?? this.proximaAcao,
      versao: versao ?? this.versao,
      enviadoEm: enviadoEm ?? this.enviadoEm,
    );
  }
}

class EquipeEscopoResponsavel {
  const EquipeEscopoResponsavel({
    required this.id,
    required this.nome,
  });

  final String id;
  final String nome;

  factory EquipeEscopoResponsavel.fromMap(Map<String, dynamic> map) =>
      EquipeEscopoResponsavel(
        id: (map['id'] ?? '').toString(),
        nome: (map['nome'] ?? '').toString(),
      );
}

class ResultadoFilaResponsavelEquipe {
  const ResultadoFilaResponsavelEquipe({
    required this.pendencias,
    required this.equipes,
  });

  final List<ItemFilaResponsavelEquipe> pendencias;
  final List<EquipeEscopoResponsavel> equipes;
}

class EntradaDecidirParticipacaoResponsavel {
  const EntradaDecidirParticipacaoResponsavel({
    required this.commandId,
    this.correlationId,
    required this.participacaoId,
    required this.decisao,
    this.justificativa,
    required this.expectedVersion,
    this.cicloId,
  });

  final String commandId;
  final String? correlationId;
  final String participacaoId;
  final String decisao; // 'APROVADO' | 'DESFAVORAVEL'
  final String? justificativa;
  final int expectedVersion;
  final String? cicloId;

  Map<String, dynamic> toMap() => {
        'commandId': commandId,
        if (correlationId != null) 'correlationId': correlationId,
        'participacaoId': participacaoId,
        if (cicloId != null) 'cicloId': cicloId,
        'decisao': decisao,
        if (justificativa != null) 'justificativa': justificativa,
        'expectedVersion': expectedVersion,
      };
}

class ResultadoDecisaoResponsavelEquipe {
  const ResultadoDecisaoResponsavelEquipe({
    required this.sucesso,
    required this.repetido,
    required this.participacaoId,
    required this.decisao,
    required this.estado,
    required this.versao,
    required this.proximaAcao,
    required this.decididoEm,
  });

  final bool sucesso;
  final bool repetido;
  final String participacaoId;
  final String decisao;
  final String estado;
  final int versao;
  final String proximaAcao;
  final String decididoEm;

  factory ResultadoDecisaoResponsavelEquipe.fromMap(Map<String, dynamic> map) {
    return ResultadoDecisaoResponsavelEquipe(
      sucesso: map['sucesso'] == true,
      repetido: map['repetido'] == true,
      participacaoId: (map['participacaoId'] ?? '').toString(),
      decisao: (map['decisao'] ?? '').toString(),
      estado: (map['estado'] ?? map['estadoCiclo'] ?? '').toString(),
      versao: map['versao'] is num ? (map['versao'] as num).toInt() : 1,
      proximaAcao: (map['proximaAcao'] ?? '').toString(),
      decididoEm: (map['decididoEm'] ?? '').toString(),
    );
  }
}

abstract class ResponsavelEquipeGateway {
  Future<ResultadoFilaResponsavelEquipe> obterFila();
  Future<ResultadoDecisaoResponsavelEquipe> decidirParticipacao(
    EntradaDecidirParticipacaoResponsavel entrada,
  );
  Future<ResultadoDecisaoResponsavelEquipe> decidirCicloAnual(
    EntradaDecidirParticipacaoResponsavel entrada,
  );
}

class FirebaseResponsavelEquipeGateway implements ResponsavelEquipeGateway {
  FirebaseResponsavelEquipeGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<ResultadoFilaResponsavelEquipe> obterFila() async {
    final callable = _functions.httpsCallable('obterFilaResponsavelEquipe');
    final response = await callable.call<Map<String, dynamic>>();
    final data = response.data;

    final pendenciasRaw = data['pendencias'] as List<dynamic>? ?? [];
    final equipesRaw = data['equipes'] as List<dynamic>? ?? [];

    final pendencias = pendenciasRaw
        .map((p) => ItemFilaResponsavelEquipe.fromMap(
            (p as Map).cast<String, dynamic>()))
        .toList();

    final equipes = equipesRaw
        .map((e) => EquipeEscopoResponsavel.fromMap(
            (e as Map).cast<String, dynamic>()))
        .toList();

    return ResultadoFilaResponsavelEquipe(
      pendencias: pendencias,
      equipes: equipes,
    );
  }

  @override
  Future<ResultadoDecisaoResponsavelEquipe> decidirParticipacao(
    EntradaDecidirParticipacaoResponsavel entrada,
  ) async {
    final callable =
        _functions.httpsCallable('decidirParticipacaoResponsavelEquipe');
    final response =
        await callable.call<Map<String, dynamic>>(entrada.toMap());
    return ResultadoDecisaoResponsavelEquipe.fromMap(response.data);
  }

  @override
  Future<ResultadoDecisaoResponsavelEquipe> decidirCicloAnual(
    EntradaDecidirParticipacaoResponsavel entrada,
  ) async {
    final callable =
        _functions.httpsCallable('decidirCicloAnualResponsavel');
    final response =
        await callable.call<Map<String, dynamic>>(entrada.toMap());
    return ResultadoDecisaoResponsavelEquipe.fromMap(response.data);
  }
}

class MemoriaResponsavelEquipeGateway implements ResponsavelEquipeGateway {
  MemoriaResponsavelEquipeGateway({
    List<ItemFilaResponsavelEquipe>? pendenciasIniciais,
    List<EquipeEscopoResponsavel>? equipesIniciais,
  })  : _pendencias = List.of(pendenciasIniciais ?? []),
        _equipes = List.of(equipesIniciais ?? []);

  final List<ItemFilaResponsavelEquipe> _pendencias;
  final List<EquipeEscopoResponsavel> _equipes;
  final List<EntradaDecidirParticipacaoResponsavel> chamadasDecisao = [];

  @override
  Future<ResultadoFilaResponsavelEquipe> obterFila() async {
    return ResultadoFilaResponsavelEquipe(
      pendencias: List.unmodifiable(_pendencias),
      equipes: List.unmodifiable(_equipes),
    );
  }

  @override
  Future<ResultadoDecisaoResponsavelEquipe> decidirParticipacao(
    EntradaDecidirParticipacaoResponsavel entrada,
  ) async {
    chamadasDecisao.add(entrada);

    final index = _pendencias
        .indexWhere((p) => p.participacaoId == entrada.participacaoId);
    if (index == -1) {
      throw Exception('Participação de equipe não encontrada.');
    }

    final pendencia = _pendencias[index];
    if (pendencia.versao != entrada.expectedVersion) {
      throw Exception('Conflito de versão: a participação foi alterada concorrentemente.');
    }

    final novoEstado = entrada.decisao == 'APROVADO'
        ? 'AGUARDANDO_COORDENADOR'
        : 'REJEITADA';

    final proximaAcao = entrada.decisao == 'APROVADO'
        ? 'Aguardando conclusão do Coordenador'
        : 'Procure o Pastor da igreja local para mais informações';

    final novaVersao = pendencia.versao + 1;

    // Remove da fila pendente após decisão (já não está aguardando responsável)
    _pendencias.removeAt(index);

    return ResultadoDecisaoResponsavelEquipe(
      sucesso: true,
      repetido: false,
      participacaoId: entrada.participacaoId,
      decisao: entrada.decisao,
      estado: novoEstado,
      versao: novaVersao,
      proximaAcao: proximaAcao,
      decididoEm: DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  Future<ResultadoDecisaoResponsavelEquipe> decidirCicloAnual(
    EntradaDecidirParticipacaoResponsavel entrada,
  ) async {
    return decidirParticipacao(entrada);
  }
}
