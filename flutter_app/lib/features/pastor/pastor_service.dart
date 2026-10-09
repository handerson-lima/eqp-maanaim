import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

class EquipeFilaPastor {
  const EquipeFilaPastor({
    required this.equipeId,
    required this.nomeEquipe,
  });

  final String equipeId;
  final String nomeEquipe;

  factory EquipeFilaPastor.fromMap(Map<String, dynamic> map) => EquipeFilaPastor(
        equipeId: (map['equipeId'] ?? '').toString(),
        nomeEquipe: (map['nomeEquipe'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() => {
        'equipeId': equipeId,
        'nomeEquipe': nomeEquipe,
      };
}

class ItemFilaPastor {
  const ItemFilaPastor({
    required this.id,
    required this.fichaId,
    required this.voluntarioUid,
    required this.voluntarioNome,
    required this.igrejaId,
    this.nomeIgreja,
    required this.estado,
    required this.proximaAcao,
    required this.ano,
    required this.equipes,
    required this.enviadoEm,
    this.versao = 1,
    this.isRenovacaoAnual = false,
    this.cicloId,
  });

  final String id;
  final String fichaId;
  final String voluntarioUid;
  final String voluntarioNome;
  final String igrejaId;
  final String? nomeIgreja;
  final String estado;
  final String proximaAcao;
  final int ano;
  final List<EquipeFilaPastor> equipes;
  final String enviadoEm;
  final int versao;
  final bool isRenovacaoAnual;
  final String? cicloId;

  factory ItemFilaPastor.fromMap(Map<String, dynamic> map) {
    final equipesRaw = map['equipes'] ?? map['equipesRenovacao'];
    final List<EquipeFilaPastor> equipes = [];
    if (equipesRaw is List) {
      for (final eq in equipesRaw) {
        if (eq is Map) {
          equipes.add(EquipeFilaPastor.fromMap(eq.cast<String, dynamic>()));
        }
      }
    }

    final isRenovacao = map['isRenovacaoAnual'] == true ||
        (map['tipo'] ?? '').toString() == 'RENOVACAO_ANUAL' ||
        (map['proximaAcao'] ?? '').toString().contains('Ciclo Anual') ||
        (map['equipesRenovacao'] is List && (map['equipesRenovacao'] as List).isNotEmpty);

    return ItemFilaPastor(
      id: (map['id'] ?? '').toString(),
      fichaId: (map['fichaId'] ?? map['id'] ?? '').toString(),
      voluntarioUid: (map['voluntarioUid'] ?? '').toString(),
      voluntarioNome: (map['voluntarioNome'] ?? 'Voluntário').toString(),
      igrejaId: (map['igrejaId'] ?? '').toString(),
      nomeIgreja: map['nomeIgreja']?.toString(),
      estado: (map['estado'] ?? 'AGUARDANDO_PASTOR_LOCAL').toString(),
      proximaAcao: (map['proximaAcao'] ?? 'Aguardando avaliação do Pastor Local').toString(),
      ano: map['ano'] is num ? (map['ano'] as num).toInt() : 2026,
      equipes: equipes,
      enviadoEm: (map['enviadoEm'] ?? '').toString(),
      versao: map['versao'] is num ? (map['versao'] as num).toInt() : 1,
      isRenovacaoAnual: isRenovacao,
      cicloId: map['cicloId']?.toString(),
    );
  }
}

class IgrejaEscopoPastor {
  const IgrejaEscopoPastor({
    required this.id,
    required this.nome,
    this.codigo,
  });

  final String id;
  final String nome;
  final String? codigo;

  factory IgrejaEscopoPastor.fromMap(Map<String, dynamic> map) => IgrejaEscopoPastor(
        id: (map['id'] ?? '').toString(),
        nome: (map['nome'] ?? '').toString(),
        codigo: map['codigo']?.toString(),
      );
}

class ResultadoFilaPastor {
  const ResultadoFilaPastor({
    required this.pendencias,
    required this.igrejas,
  });

  final List<ItemFilaPastor> pendencias;
  final List<IgrejaEscopoPastor> igrejas;
}

class EntradaDecisaoPastor {
  const EntradaDecisaoPastor({
    required this.commandId,
    this.correlationId,
    required this.fichaId,
    required this.decisao,
    this.justificativa,
    required this.expectedVersion,
    this.cicloId,
  });

  final String commandId;
  final String? correlationId;
  final String fichaId;
  final String decisao; // 'APROVADO' ou 'DESFAVORAVEL'
  final String? justificativa;
  final int expectedVersion;
  final String? cicloId;

  Map<String, dynamic> toMap() => {
        'commandId': commandId,
        if (correlationId != null) 'correlationId': correlationId,
        'fichaId': fichaId,
        if (cicloId != null) 'cicloId': cicloId,
        'decisao': decisao,
        if (justificativa != null) 'justificativa': justificativa,
        'expectedVersion': expectedVersion,
      };
}

class ResultadoDecisaoPastor {
  const ResultadoDecisaoPastor({
    required this.sucesso,
    required this.repetido,
    required this.decisao,
    required this.estado,
    required this.versao,
    required this.proximaAcao,
    required this.decididoEm,
  });

  final bool sucesso;
  final bool repetido;
  final String decisao;
  final String estado;
  final int versao;
  final String proximaAcao;
  final String decididoEm;

  factory ResultadoDecisaoPastor.fromMap(Map<String, dynamic> map) =>
      ResultadoDecisaoPastor(
        sucesso: map['sucesso'] == true,
        repetido: map['repetido'] == true,
        decisao: (map['decisao'] ?? '').toString(),
        estado: (map['estado'] ?? '').toString(),
        versao: map['versao'] is num ? (map['versao'] as num).toInt() : 1,
        proximaAcao: (map['proximaAcao'] ?? '').toString(),
        decididoEm: (map['decididoEm'] ?? '').toString(),
      );
}

abstract interface class PastorLocalGateway {
  Future<ResultadoFilaPastor> obterFila();
  Future<ResultadoDecisaoPastor> decidirFicha(EntradaDecisaoPastor entrada);
  Future<ResultadoDecisaoPastor> decidirCicloAnual(EntradaDecisaoPastor entrada);
}

class FirebasePastorLocalGateway implements PastorLocalGateway {
  FirebasePastorLocalGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<ResultadoFilaPastor> obterFila() async {
    final callable = _functions.httpsCallable('obterFilaPastorLocal');
    final resposta = await callable.call();
    final dados = (resposta.data as Map).cast<String, dynamic>();

    final pendenciasRaw = dados['pendencias'] as List? ?? [];
    final igrejasRaw = dados['igrejas'] as List? ?? [];

    final pendencias = pendenciasRaw
        .map((p) => ItemFilaPastor.fromMap((p as Map).cast<String, dynamic>()))
        .toList();

    final igrejas = igrejasRaw
        .map((i) => IgrejaEscopoPastor.fromMap((i as Map).cast<String, dynamic>()))
        .toList();

    return ResultadoFilaPastor(
      pendencias: pendencias,
      igrejas: igrejas,
    );
  }

  @override
  Future<ResultadoDecisaoPastor> decidirFicha(EntradaDecisaoPastor entrada) async {
    final callable = _functions.httpsCallable('decidirFichaPastorLocal');
    final resposta = await callable.call(entrada.toMap());
    final dados = (resposta.data as Map).cast<String, dynamic>();
    return ResultadoDecisaoPastor.fromMap(dados);
  }

  @override
  Future<ResultadoDecisaoPastor> decidirCicloAnual(EntradaDecisaoPastor entrada) async {
    final callable = _functions.httpsCallable('decidirCicloAnualPastor');
    final resposta = await callable.call(entrada.toMap());
    final dados = (resposta.data as Map).cast<String, dynamic>();
    return ResultadoDecisaoPastor.fromMap(dados);
  }
}

class MemoriaPastorLocalGateway implements PastorLocalGateway {
  MemoriaPastorLocalGateway({
    List<ItemFilaPastor>? pendenciasIniciais,
    List<IgrejaEscopoPastor>? igrejasIniciais,
    this.erroAoObterFila,
  })  : _pendencias = List.of(pendenciasIniciais ?? []),
        _igrejas = List.of(igrejasIniciais ?? []);

  final List<ItemFilaPastor> _pendencias;
  final List<IgrejaEscopoPastor> _igrejas;
  final Exception? erroAoObterFila;
  final Map<String, ResultadoDecisaoPastor> _recibos = {};

  @override
  Future<ResultadoFilaPastor> obterFila() async {
    if (erroAoObterFila != null) throw erroAoObterFila!;
    return ResultadoFilaPastor(
      pendencias: List.unmodifiable(_pendencias),
      igrejas: List.unmodifiable(_igrejas),
    );
  }

  @override
  Future<ResultadoDecisaoPastor> decidirFicha(EntradaDecisaoPastor entrada) async {
    if (_recibos.containsKey(entrada.commandId)) {
      final anterior = _recibos[entrada.commandId]!;
      return ResultadoDecisaoPastor(
        sucesso: anterior.sucesso,
        repetido: true,
        decisao: anterior.decisao,
        estado: anterior.estado,
        versao: anterior.versao,
        proximaAcao: anterior.proximaAcao,
        decididoEm: anterior.decididoEm,
      );
    }

    final index = _pendencias.indexWhere((p) => p.fichaId == entrada.fichaId);
    if (index == -1) {
      throw Exception('Ficha não encontrada na fila pastoral.');
    }

    final item = _pendencias[index];
    if (entrada.expectedVersion != item.versao) {
      throw Exception('Conflito de versão ao processar decisão pastoral.');
    }

    final bool aprovado = entrada.decisao.toUpperCase() == 'APROVADO';
    final novoEstado = aprovado ? 'AGUARDANDO_RESPONSAVEL_EQUIPE' : 'REJEITADA';
    final proximaAcao = aprovado
        ? 'Aguardando avaliação dos Responsáveis de Equipe'
        : 'Procure o Pastor da igreja local para mais informações';

    _pendencias.removeAt(index);

    final resultado = ResultadoDecisaoPastor(
      sucesso: true,
      repetido: false,
      decisao: aprovado ? 'APROVADO' : 'DESFAVORAVEL',
      estado: novoEstado,
      versao: item.versao + 1,
      proximaAcao: proximaAcao,
      decididoEm: DateTime.now().toUtc().toIso8601String(),
    );

    _recibos[entrada.commandId] = resultado;
    return resultado;
  }

  @override
  Future<ResultadoDecisaoPastor> decidirCicloAnual(EntradaDecisaoPastor entrada) async {
    return decidirFicha(entrada);
  }
}
