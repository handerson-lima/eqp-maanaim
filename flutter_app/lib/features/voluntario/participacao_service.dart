import 'package:cloud_functions/cloud_functions.dart';

import '../../comando.dart';

/// Mensagem neutra canônica exibida ao voluntário em decisões negativas (AD-12).
const String mensagemNeutraCanonica =
    'Procure o Pastor da igreja local para mais informações';

/// Item de manifestação de renovação por equipe (Story 5.2).
class ManifestacaoEquipeInput {
  const ManifestacaoEquipeInput({
    required this.participacaoId,
    required this.decisao,
    this.justificativa,
  });

  final String participacaoId;
  final String decisao; // 'CONTINUAR' ou 'NAO_CONTINUAR'
  final String? justificativa;

  Map<String, dynamic> toMap() => {
        'participacaoId': participacaoId,
        'decisao': decisao,
        if (justificativa != null) 'justificativa': justificativa,
      };
}

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
    this.versao = 1,
    this.vigenciaInicio,
    this.vigenciaFim,
    this.situacaoVigencia,
    this.diasParaVencimento,
    this.alertaVigencia,
    this.emAlertaRenovacao = false,
    this.cicloAtualId,
    this.intencaoRenovacao,
    this.cicloRenovacaoId,
    this.programadoEncerramentoEm,
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
  final int versao;
  final String? vigenciaInicio;
  final String? vigenciaFim;
  final String? situacaoVigencia;
  final int? diasParaVencimento;
  final String? alertaVigencia;
  final bool emAlertaRenovacao;
  final String? cicloAtualId;
  final String? intencaoRenovacao;
  final String? cicloRenovacaoId;
  final String? programadoEncerramentoEm;
  final String? criadoEm;
  final String? atualizadoEm;

  bool get isRascunho => estado == 'RASCUNHO';
  bool get isAtiva => estado == 'ATIVA';
  bool get isRejeitada => estado == 'REJEITADA';
  bool get isCancelada => estado == 'CANCELADA';
  bool get isExpirada => estado == 'EXPIRADA';
  bool get isInativa => estado == 'INATIVA';

  /// Retorna verdadeiro se a participação estiver ativa e dentro da janela de renovação (AD-7 / Story 5.1).
  bool get isEmJanelaRenovacao =>
      isAtiva &&
      (emAlertaRenovacao ||
          situacaoVigencia == 'ALERTA_PREVIO_60D' ||
          situacaoVigencia == 'RENOVACAO_IMINENTE_30D');

  /// Indica se já houve manifestação prévia registrada nesta vigência.
  bool get isRenovacaoManifestada => intencaoRenovacao != null;

  /// Estados terminais não bloqueiam uma nova solicitação (AD-11). Deve manter
  /// paridade com `ESTADOS_TERMINAIS_PARTICIPACAO` no backend.
  bool get isTerminal =>
      isRejeitada || isCancelada || isExpirada || isInativa;

  bool get isPendente => !isRascunho && !isAtiva && !isTerminal;

  factory ParticipacaoModel.fromMap(Map<String, dynamic> map) {
    return ParticipacaoModel(
      id: map['id'] as String? ?? '',
      fichaId: map['fichaId'] as String? ?? '',
      equipeId: map['equipeId'] as String? ?? '',
      nomeEquipe: map['nomeEquipe'] as String? ?? '',
      estado: map['estado'] as String? ?? 'RASCUNHO',
      ciclo: map['ciclo'] as String? ?? 'INICIAL',
      proximaAcao: map['proximaAcao'] as String? ?? 'Aguardando envio da ficha',
      versao: (map['versao'] as num?)?.toInt() ?? 1,
      vigenciaInicio: map['vigenciaInicio'] as String?,
      vigenciaFim: map['vigenciaFim'] as String?,
      situacaoVigencia: map['situacaoVigencia'] as String?,
      diasParaVencimento: (map['diasParaVencimento'] as num?)?.toInt(),
      alertaVigencia: map['alertaVigencia'] as String?,
      emAlertaRenovacao: map['emAlertaRenovacao'] as bool? ?? false,
      cicloAtualId: map['cicloAtualId'] as String?,
      intencaoRenovacao: map['intencaoRenovacao'] as String?,
      cicloRenovacaoId: map['cicloRenovacaoId'] as String?,
      programadoEncerramentoEm: map['programadoEncerramentoEm'] as String?,
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
        'versao': versao,
        if (vigenciaInicio != null) 'vigenciaInicio': vigenciaInicio,
        if (vigenciaFim != null) 'vigenciaFim': vigenciaFim,
        if (situacaoVigencia != null) 'situacaoVigencia': situacaoVigencia,
        if (diasParaVencimento != null) 'diasParaVencimento': diasParaVencimento,
        if (alertaVigencia != null) 'alertaVigencia': alertaVigencia,
        'emAlertaRenovacao': emAlertaRenovacao,
        if (cicloAtualId != null) 'cicloAtualId': cicloAtualId,
        if (intencaoRenovacao != null) 'intencaoRenovacao': intencaoRenovacao,
        if (cicloRenovacaoId != null) 'cicloRenovacaoId': cicloRenovacaoId,
        if (programadoEncerramentoEm != null)
          'programadoEncerramentoEm': programadoEncerramentoEm,
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
    int? versao,
    String? vigenciaInicio,
    String? vigenciaFim,
    String? situacaoVigencia,
    int? diasParaVencimento,
    String? alertaVigencia,
    bool? emAlertaRenovacao,
    String? cicloAtualId,
    String? intencaoRenovacao,
    String? cicloRenovacaoId,
    String? programadoEncerramentoEm,
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
      versao: versao ?? this.versao,
      vigenciaInicio: vigenciaInicio ?? this.vigenciaInicio,
      vigenciaFim: vigenciaFim ?? this.vigenciaFim,
      situacaoVigencia: situacaoVigencia ?? this.situacaoVigencia,
      diasParaVencimento: diasParaVencimento ?? this.diasParaVencimento,
      alertaVigencia: alertaVigencia ?? this.alertaVigencia,
      emAlertaRenovacao: emAlertaRenovacao ?? this.emAlertaRenovacao,
      cicloAtualId: cicloAtualId ?? this.cicloAtualId,
      intencaoRenovacao: intencaoRenovacao ?? this.intencaoRenovacao,
      cicloRenovacaoId: cicloRenovacaoId ?? this.cicloRenovacaoId,
      programadoEncerramentoEm:
          programadoEncerramentoEm ?? this.programadoEncerramentoEm,
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
  Future<ParticipacaoModel> solicitarEquipeAdicional(
    String equipeId, {
    String? commandId,
  });
  Future<void> cancelarParticipacao({
    required String participacaoId,
    String? motivo,
    int? expectedVersion,
    String? commandId,
  });
  Future<ParticipacaoModel> solicitarReativacao({
    required String equipeId,
    String? participacaoId,
    String? justificativa,
    String? commandId,
  });
  Future<List<Map<String, dynamic>>> manifestarRenovacao({
    required List<ManifestacaoEquipeInput> manifestacoes,
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

  @override
  Future<ParticipacaoModel> solicitarEquipeAdicional(
    String equipeId, {
    String? commandId,
  }) async {
    final cid = commandId ?? comandoOpaco();
    final resposta = await _functions.httpsCallable('solicitarEquipeAdicional').call({
      'commandId': cid,
      'equipeId': equipeId,
    });
    final dados = (resposta.data as Map).cast<String, dynamic>();
    return ParticipacaoModel(
      id: dados['participacaoId'] as String? ?? '',
      fichaId: '',
      equipeId: dados['equipeId'] as String? ?? equipeId,
      nomeEquipe: dados['nomeEquipe'] as String? ?? '',
      estado: dados['estado'] as String? ?? 'AGUARDANDO_RESPONSAVEL_EQUIPE',
      ciclo: 'INICIAL',
      proximaAcao: dados['proximaAcao'] as String? ??
          'Aguardando avaliação do Responsável de Equipe',
      cicloAtualId: dados['cicloId'] as String?,
      criadoEm: dados['criadoEm'] as String?,
    );
  }

  @override
  Future<void> cancelarParticipacao({
    required String participacaoId,
    String? motivo,
    int? expectedVersion,
    String? commandId,
  }) async {
    final cid = commandId ?? comandoOpaco();
    await _functions.httpsCallable('cancelarParticipacao').call({
      'commandId': cid,
      'participacaoId': participacaoId,
      if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
    });
  }

  @override
  Future<ParticipacaoModel> solicitarReativacao({
    required String equipeId,
    String? participacaoId,
    String? justificativa,
    String? commandId,
  }) async {
    final cid = commandId ?? comandoOpaco();
    final resposta = await _functions.httpsCallable('solicitarReativacao').call({
      'commandId': cid,
      'equipeId': equipeId,
      if (participacaoId != null && participacaoId.trim().isNotEmpty)
        'participacaoId': participacaoId.trim(),
      if (justificativa != null && justificativa.trim().isNotEmpty)
        'justificativa': justificativa.trim(),
    });
    final dados = (resposta.data as Map).cast<String, dynamic>();
    return ParticipacaoModel(
      id: dados['participacaoId'] as String? ?? '',
      fichaId: '',
      equipeId: dados['equipeId'] as String? ?? equipeId,
      nomeEquipe: dados['nomeEquipe'] as String? ?? '',
      estado: dados['estado'] as String? ?? 'AGUARDANDO_PASTOR_LOCAL',
      ciclo: 'REATIVACAO',
      proximaAcao: dados['proximaAcao'] as String? ??
          'Aguardando avaliação do Pastor Local',
      cicloAtualId: dados['cicloId'] as String?,
      criadoEm: dados['criadoEm'] as String?,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> manifestarRenovacao({
    required List<ManifestacaoEquipeInput> manifestacoes,
    String? commandId,
  }) async {
    final cid = commandId ?? comandoOpaco();
    final resposta = await _functions.httpsCallable('manifestarRenovacao').call({
      'commandId': cid,
      'manifestacoes': manifestacoes.map((m) => m.toMap()).toList(),
    });
    final dados = (resposta.data as Map).cast<String, dynamic>();
    final itens = (dados['itens'] as List? ?? const [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList(growable: false);
    return itens;
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

  @override
  Future<ParticipacaoModel> solicitarEquipeAdicional(
    String equipeId, {
    String? commandId,
  }) async {
    final nova = ParticipacaoModel(
      id: 'mem-$equipeId-${_participacoes.length}',
      fichaId: 'mem-uid',
      equipeId: equipeId,
      nomeEquipe: nomesEquipes[equipeId] ?? equipeId,
      estado: 'AGUARDANDO_RESPONSAVEL_EQUIPE',
      ciclo: 'INICIAL',
      proximaAcao: 'Aguardando avaliação do Responsável de Equipe',
      cicloAtualId: 'ciclo-mem-$equipeId',
      criadoEm: DateTime.now().toIso8601String(),
    );
    _participacoes.add(nova);
    _participacoes.sort((a, b) => a.nomeEquipe.compareTo(b.nomeEquipe));
    return nova;
  }

  @override
  Future<void> cancelarParticipacao({
    required String participacaoId,
    String? motivo,
    int? expectedVersion,
    String? commandId,
  }) async {
    final index = _participacoes.indexWhere((p) => p.id == participacaoId);
    if (index != -1) {
      final p = _participacoes[index];
      _participacoes[index] = p.copyWith(
        estado: 'CANCELADA',
        proximaAcao: motivo != null && motivo.trim().isNotEmpty
            ? mensagemNeutraCanonica
            : 'Participação cancelada pelo voluntário',
      );
    }
  }

  @override
  Future<ParticipacaoModel> solicitarReativacao({
    required String equipeId,
    String? participacaoId,
    String? justificativa,
    String? commandId,
  }) async {
    final nova = ParticipacaoModel(
      id: 'mem-$equipeId-reativacao-${_participacoes.length}',
      fichaId: 'mem-uid',
      equipeId: equipeId,
      nomeEquipe: nomesEquipes[equipeId] ?? equipeId,
      estado: 'AGUARDANDO_PASTOR_LOCAL',
      ciclo: 'REATIVACAO',
      proximaAcao: 'Aguardando avaliação do Pastor Local',
      cicloAtualId: 'ciclo-mem-reativacao-$equipeId',
      criadoEm: DateTime.now().toIso8601String(),
    );
    _participacoes.add(nova);
    _participacoes.sort((a, b) => a.nomeEquipe.compareTo(b.nomeEquipe));
    return nova;
  }

  @override
  Future<List<Map<String, dynamic>>> manifestarRenovacao({
    required List<ManifestacaoEquipeInput> manifestacoes,
    String? commandId,
  }) async {
    final resultados = <Map<String, dynamic>>[];
    for (final m in manifestacoes) {
      final index = _participacoes.indexWhere((p) => p.id == m.participacaoId);
      if (index != -1) {
        final p = _participacoes[index];
        if (m.decisao == 'CONTINUAR') {
          _participacoes[index] = p.copyWith(
            intencaoRenovacao: 'CONTINUAR',
            cicloRenovacaoId: 'ciclo_${p.id}_2027',
            proximaAcao: 'Aguardando avaliação do Pastor Local (Ciclo Anual)',
          );
        } else {
          _participacoes[index] = p.copyWith(
            intencaoRenovacao: 'NAO_CONTINUAR',
            programadoEncerramentoEm: p.vigenciaFim,
            proximaAcao: 'Encerramento programado ao término da vigência',
          );
        }
        resultados.add({
          'participacaoId': m.participacaoId,
          'equipeId': p.equipeId,
          'nomeEquipe': p.nomeEquipe,
          'decisao': m.decisao,
        });
      }
    }
    return resultados;
  }
}

