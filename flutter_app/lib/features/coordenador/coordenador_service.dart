import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

class ParticipacaoItemCoordenador {
  const ParticipacaoItemCoordenador({
    required this.participacaoId,
    required this.equipeId,
    required this.nomeEquipe,
    required this.estado,
    required this.proximaAcao,
    this.responsavelNome,
    this.responsavelDecididoEm,
    this.justificativaResponsavel,
    required this.elegivelAtivacao,
  });

  final String participacaoId;
  final String equipeId;
  final String nomeEquipe;
  final String estado;
  final String proximaAcao;
  final String? responsavelNome;
  final String? responsavelDecididoEm;
  final String? justificativaResponsavel;
  final bool elegivelAtivacao;

  factory ParticipacaoItemCoordenador.fromMap(Map<String, dynamic> map) {
    final estadoStr = (map['estado'] ?? '').toString();
    return ParticipacaoItemCoordenador(
      participacaoId: (map['participacaoId'] ?? map['id'] ?? '').toString(),
      equipeId: (map['equipeId'] ?? '').toString(),
      nomeEquipe: (map['nomeEquipe'] ?? 'Equipe').toString(),
      estado: estadoStr,
      proximaAcao: (map['proximaAcao'] ?? '').toString(),
      responsavelNome: map['responsavelNome']?.toString(),
      responsavelDecididoEm: map['responsavelDecididoEm']?.toString(),
      justificativaResponsavel: map['justificativaResponsavel']?.toString(),
      elegivelAtivacao: map['elegivelAtivacao'] == true,
    );
  }
}

class ItemFilaCoordenador {
  const ItemFilaCoordenador({
    required this.fichaId,
    required this.voluntarioUid,
    required this.voluntarioNome,
    required this.profissao,
    required this.cpfMascarado,
    required this.igrejaId,
    required this.nomeIgreja,
    required this.versaoFicha,
    required this.enviadoEm,
    this.pastorLocalNome,
    this.pastorLocalDecididoEm,
    required this.participacoes,
  });

  final String fichaId;
  final String voluntarioUid;
  final String voluntarioNome;
  final String profissao;
  final String cpfMascarado;
  final String igrejaId;
  final String nomeIgreja;
  final int versaoFicha;
  final String enviadoEm;
  final String? pastorLocalNome;
  final String? pastorLocalDecididoEm;
  final List<ParticipacaoItemCoordenador> participacoes;

  List<ParticipacaoItemCoordenador> get participacoesElegiveis =>
      participacoes.where((p) => p.elegivelAtivacao).toList();

  factory ItemFilaCoordenador.fromMap(Map<String, dynamic> map) {
    final rawParts = map['participacoes'] as List<dynamic>? ?? [];
    final participacoes = rawParts
        .map((p) => ParticipacaoItemCoordenador.fromMap(
            (p as Map).cast<String, dynamic>()))
        .toList();

    return ItemFilaCoordenador(
      fichaId: (map['fichaId'] ?? '').toString(),
      voluntarioUid: (map['voluntarioUid'] ?? '').toString(),
      voluntarioNome: (map['voluntarioNome'] ?? 'Voluntário').toString(),
      profissao: (map['profissao'] ?? '').toString(),
      cpfMascarado: (map['cpfMascarado'] ?? '***.***.***-**').toString(),
      igrejaId: (map['igrejaId'] ?? '').toString(),
      nomeIgreja: (map['nomeIgreja'] ?? 'Igreja').toString(),
      versaoFicha: map['versaoFicha'] is num
          ? (map['versaoFicha'] as num).toInt()
          : 1,
      enviadoEm: (map['enviadoEm'] ?? '').toString(),
      pastorLocalNome: map['pastorLocalNome']?.toString(),
      pastorLocalDecididoEm: map['pastorLocalDecididoEm']?.toString(),
      participacoes: participacoes,
    );
  }
}

class ResultadoDecisaoCoordenador {
  const ResultadoDecisaoCoordenador({
    required this.sucesso,
    required this.repetido,
    required this.fichaId,
    required this.decisao,
    required this.estadoFicha,
    required this.versaoFicha,
    required this.participacoesAtivadas,
    required this.participacoesRejeitadas,
    this.vigenciaInicio,
    this.vigenciaFim,
    required this.decididoEm,
  });

  final bool sucesso;
  final bool repetido;
  final String fichaId;
  final String decisao;
  final String estadoFicha;
  final int versaoFicha;
  final List<String> participacoesAtivadas;
  final List<String> participacoesRejeitadas;
  final String? vigenciaInicio;
  final String? vigenciaFim;
  final String decididoEm;

  factory ResultadoDecisaoCoordenador.fromMap(Map<String, dynamic> map) {
    final ativadas = (map['participacoesAtivadas'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final rejeitadas = (map['participacoesRejeitadas'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return ResultadoDecisaoCoordenador(
      sucesso: map['sucesso'] == true,
      repetido: map['repetido'] == true,
      fichaId: (map['fichaId'] ?? '').toString(),
      decisao: (map['decisao'] ?? '').toString(),
      estadoFicha: (map['estadoFicha'] ?? '').toString(),
      versaoFicha: map['versaoFicha'] is num
          ? (map['versaoFicha'] as num).toInt()
          : 1,
      participacoesAtivadas: ativadas,
      participacoesRejeitadas: rejeitadas,
      vigenciaInicio: map['vigenciaInicio']?.toString(),
      vigenciaFim: map['vigenciaFim']?.toString(),
      decididoEm: (map['decididoEm'] ?? '').toString(),
    );
  }
}

abstract interface class CoordenadorGateway {
  Future<List<ItemFilaCoordenador>> obterFila();

  Future<ResultadoDecisaoCoordenador> decidir({
    required String commandId,
    String? correlationId,
    required String fichaId,
    required String decisao,
    required bool confirmouReuniaoPastores,
    String? observacao,
    required int expectedVersion,
  });
}

class FirebaseCoordenadorGateway implements CoordenadorGateway {
  const FirebaseCoordenadorGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<List<ItemFilaCoordenador>> obterFila() async {
    final callable = _functions.httpsCallable('obterFilaCoordenador');
    final resp = await callable.call<Map<dynamic, dynamic>>();
    final dados = resp.data.cast<String, dynamic>();
    final lista = (dados['pendencias'] as List<dynamic>? ?? [])
        .map((item) => ItemFilaCoordenador.fromMap(
            (item as Map).cast<String, dynamic>()))
        .toList();
    return lista;
  }

  @override
  Future<ResultadoDecisaoCoordenador> decidir({
    required String commandId,
    String? correlationId,
    required String fichaId,
    required String decisao,
    required bool confirmouReuniaoPastores,
    String? observacao,
    required int expectedVersion,
  }) async {
    final callable = _functions.httpsCallable('decidirAtivacaoCoordenador');
    final resp = await callable.call<Map<dynamic, dynamic>>({
      'commandId': commandId,
      if (correlationId != null) 'correlationId': correlationId,
      'fichaId': fichaId,
      'decisao': decisao,
      'confirmouReuniaoPastores': confirmouReuniaoPastores,
      if (observacao != null) 'observacao': observacao,
      'expectedVersion': expectedVersion,
    });
    final dados = resp.data.cast<String, dynamic>();
    return ResultadoDecisaoCoordenador.fromMap(dados);
  }
}

class MemoriaCoordenadorGateway implements CoordenadorGateway {
  MemoriaCoordenadorGateway({
    List<ItemFilaCoordenador>? pendenciasIniciais,
    this.erroAoObterFila,
    this.erroAoDecidir,
  }) : _pendencias = List.of(pendenciasIniciais ?? []);

  final List<ItemFilaCoordenador> _pendencias;
  final Exception? erroAoObterFila;
  final Exception? erroAoDecidir;
  final List<Map<String, dynamic>> historicoDecisoes = [];

  @override
  Future<List<ItemFilaCoordenador>> obterFila() async {
    if (erroAoObterFila != null) throw erroAoObterFila!;
    return List.unmodifiable(_pendencias);
  }

  @override
  Future<ResultadoDecisaoCoordenador> decidir({
    required String commandId,
    String? correlationId,
    required String fichaId,
    required String decisao,
    required bool confirmouReuniaoPastores,
    String? observacao,
    required int expectedVersion,
  }) async {
    if (erroAoDecidir != null) throw erroAoDecidir!;

    final index = _pendencias.indexWhere((p) => p.fichaId == fichaId);
    if (index == -1) {
      throw Exception('Ficha não encontrada na fila do coordenador.');
    }

    final item = _pendencias[index];
    if (item.versaoFicha != expectedVersion) {
      throw Exception('Conflito de versão ao decidir ativação.');
    }

    if (decisao == 'APROVADO' && !confirmouReuniaoPastores) {
      throw Exception(
          'É obrigatório confirmar a verificação na Reunião de Pastores.');
    }

    historicoDecisoes.add({
      'commandId': commandId,
      'fichaId': fichaId,
      'decisao': decisao,
      'confirmouReuniaoPastores': confirmouReuniaoPastores,
      'observacao': observacao,
      'expectedVersion': expectedVersion,
    });

    _pendencias.removeAt(index);

    final ativadas = decisao == 'APROVADO'
        ? item.participacoesElegiveis.map((p) => p.participacaoId).toList()
        : <String>[];
    final rejeitadas = decisao == 'DESFAVORAVEL'
        ? item.participacoesElegiveis.map((p) => p.participacaoId).toList()
        : <String>[];

    final agora = DateTime.now().toUtc();
    final inicioIso = agora.toIso8601String();
    final fimIso = DateTime.utc(
      agora.year + 1,
      agora.month,
      agora.day,
      agora.hour,
      agora.minute,
      agora.second,
    ).toIso8601String();

    return ResultadoDecisaoCoordenador(
      sucesso: true,
      repetido: false,
      fichaId: fichaId,
      decisao: decisao,
      estadoFicha: decisao == 'APROVADO' ? 'ATIVA' : 'REJEITADA',
      versaoFicha: item.versaoFicha + 1,
      participacoesAtivadas: ativadas,
      participacoesRejeitadas: rejeitadas,
      vigenciaInicio: decisao == 'APROVADO' ? inicioIso : null,
      vigenciaFim: decisao == 'APROVADO' ? fimIso : null,
      decididoEm: inicioIso,
    );
  }
}
