import 'package:cloud_functions/cloud_functions.dart';

class ItemAuditoria {
  const ItemAuditoria({
    required this.id,
    required this.commandId,
    required this.correlationId,
    required this.atorUid,
    required this.acao,
    required this.entidades,
    required this.timestamp,
    this.antes,
    this.depois,
    this.metadados,
    this.sanitizado = true,
  });

  final String id;
  final String commandId;
  final String correlationId;
  final String atorUid;
  final String acao;
  final List<Map<String, String>> entidades;
  final String timestamp;
  final Map<String, dynamic>? antes;
  final Map<String, dynamic>? depois;
  final Map<String, dynamic>? metadados;
  final bool sanitizado;

  factory ItemAuditoria.fromJson(Map<String, dynamic> json) {
    final rawEntidades = json['entidades'];
    final entidadesList = <Map<String, String>>[];
    if (rawEntidades is List) {
      for (final e in rawEntidades) {
        if (e is Map) {
          entidadesList.add({
            'tipo': e['tipo']?.toString() ?? '',
            'id': e['id']?.toString() ?? '',
          });
        }
      }
    }

    return ItemAuditoria(
      id: json['id']?.toString() ?? '',
      commandId: json['commandId']?.toString() ?? '',
      correlationId: json['correlationId']?.toString() ?? '',
      atorUid: json['atorUid']?.toString() ?? 'SISTEMA',
      acao: json['acao']?.toString() ?? '',
      entidades: entidadesList,
      timestamp: json['timestamp']?.toString() ?? '',
      antes: json['antes'] is Map ? Map<String, dynamic>.from(json['antes'] as Map) : null,
      depois: json['depois'] is Map ? Map<String, dynamic>.from(json['depois'] as Map) : null,
      metadados: json['metadados'] is Map ? Map<String, dynamic>.from(json['metadados'] as Map) : null,
      sanitizado: json['sanitizado'] == true,
    );
  }
}

class ResultadoConsultaAuditoria {
  const ResultadoConsultaAuditoria({
    required this.itens,
    this.proximoCursor,
    required this.temMais,
    required this.totalRetornado,
  });

  final List<ItemAuditoria> itens;
  final String? proximoCursor;
  final bool temMais;
  final int totalRetornado;

  factory ResultadoConsultaAuditoria.fromJson(Map<String, dynamic> json) {
    final rawItens = json['itens'];
    final itensList = <ItemAuditoria>[];
    if (rawItens is List) {
      for (final i in rawItens) {
        if (i is Map) {
          itensList.add(ItemAuditoria.fromJson(Map<String, dynamic>.from(i)));
        }
      }
    }

    return ResultadoConsultaAuditoria(
      itens: itensList,
      proximoCursor: json['proximoCursor']?.toString(),
      temMais: json['temMais'] == true,
      totalRetornado: (json['totalRetornado'] as num?)?.toInt() ?? itensList.length,
    );
  }
}

class FiltrosAuditoria {
  const FiltrosAuditoria({
    this.igrejaId,
    this.equipeId,
    this.acao,
    this.voluntarioId,
    this.periodoInicio,
    this.periodoFim,
    this.limite,
    this.cursor,
  });

  final String? igrejaId;
  final String? equipeId;
  final String? acao;
  final String? voluntarioId;
  final String? periodoInicio;
  final String? periodoFim;
  final int? limite;
  final String? cursor;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (igrejaId != null && igrejaId!.isNotEmpty) map['igrejaId'] = igrejaId;
    if (equipeId != null && equipeId!.isNotEmpty) map['equipeId'] = equipeId;
    if (acao != null && acao!.isNotEmpty) map['acao'] = acao;
    if (voluntarioId != null && voluntarioId!.isNotEmpty) map['voluntarioId'] = voluntarioId;
    if (periodoInicio != null && periodoInicio!.isNotEmpty) map['periodoInicio'] = periodoInicio;
    if (periodoFim != null && periodoFim!.isNotEmpty) map['periodoFim'] = periodoFim;
    if (limite != null) map['limite'] = limite;
    if (cursor != null && cursor!.isNotEmpty) map['cursor'] = cursor;
    return map;
  }
}

class MetricasRelatorio {
  const MetricasRelatorio({
    required this.totalVoluntarios,
    required this.totalFichasAtivas,
    required this.totalParticipacoesAtivas,
    required this.totalAguardandoAprovacao,
    required this.totalCanceladasOuInativas,
    required this.distribuicaoPorEquipe,
    required this.distribuicaoPorIgreja,
    required this.distribuicaoPorEstado,
  });

  final int totalVoluntarios;
  final int totalFichasAtivas;
  final int totalParticipacoesAtivas;
  final int totalAguardandoAprovacao;
  final int totalCanceladasOuInativas;
  final Map<String, int> distribuicaoPorEquipe;
  final Map<String, int> distribuicaoPorIgreja;
  final Map<String, int> distribuicaoPorEstado;

  factory MetricasRelatorio.fromJson(Map<String, dynamic> json) {
    Map<String, int> parseDist(dynamic raw) {
      if (raw is! Map) return {};
      return raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    }

    return MetricasRelatorio(
      totalVoluntarios: (json['totalVoluntarios'] as num?)?.toInt() ?? 0,
      totalFichasAtivas: (json['totalFichasAtivas'] as num?)?.toInt() ?? 0,
      totalParticipacoesAtivas: (json['totalParticipacoesAtivas'] as num?)?.toInt() ?? 0,
      totalAguardandoAprovacao: (json['totalAguardandoAprovacao'] as num?)?.toInt() ?? 0,
      totalCanceladasOuInativas: (json['totalCanceladasOuInativas'] as num?)?.toInt() ?? 0,
      distribuicaoPorEquipe: parseDist(json['distribuicaoPorEquipe']),
      distribuicaoPorIgreja: parseDist(json['distribuicaoPorIgreja']),
      distribuicaoPorEstado: parseDist(json['distribuicaoPorEstado']),
    );
  }
}

class VoluntarioRelatorioItem {
  const VoluntarioRelatorioItem({
    required this.fichaId,
    required this.nomeCompleto,
    required this.cpfMascarado,
    required this.igrejaId,
    this.igrejaNome,
    required this.estadoFicha,
    required this.equipes,
  });

  final String fichaId;
  final String nomeCompleto;
  final String cpfMascarado;
  final String igrejaId;
  final String? igrejaNome;
  final String estadoFicha;
  final List<Map<String, dynamic>> equipes;

  factory VoluntarioRelatorioItem.fromJson(Map<String, dynamic> json) {
    final rawEq = json['equipes'];
    final eqList = <Map<String, dynamic>>[];
    if (rawEq is List) {
      for (final item in rawEq) {
        if (item is Map) eqList.add(Map<String, dynamic>.from(item));
      }
    }

    return VoluntarioRelatorioItem(
      fichaId: json['fichaId']?.toString() ?? '',
      nomeCompleto: json['nomeCompleto']?.toString() ?? '',
      cpfMascarado: json['cpfMascarado']?.toString() ?? '***.***.***-**',
      igrejaId: json['igrejaId']?.toString() ?? '',
      igrejaNome: json['igrejaNome']?.toString(),
      estadoFicha: json['estadoFicha']?.toString() ?? '',
      equipes: eqList,
    );
  }
}

class ResultadoRelatorioOperacional {
  const ResultadoRelatorioOperacional({
    required this.metricas,
    required this.voluntarios,
    required this.geradoEm,
    required this.escopoAtor,
  });

  final MetricasRelatorio metricas;
  final List<VoluntarioRelatorioItem> voluntarios;
  final String geradoEm;
  final String escopoAtor;

  factory ResultadoRelatorioOperacional.fromJson(Map<String, dynamic> json) {
    final rawVol = json['voluntarios'];
    final volList = <VoluntarioRelatorioItem>[];
    if (rawVol is List) {
      for (final v in rawVol) {
        if (v is Map) {
          volList.add(VoluntarioRelatorioItem.fromJson(Map<String, dynamic>.from(v)));
        }
      }
    }

    return ResultadoRelatorioOperacional(
      metricas: MetricasRelatorio.fromJson(
        json['metricas'] is Map ? Map<String, dynamic>.from(json['metricas'] as Map) : {},
      ),
      voluntarios: volList,
      geradoEm: json['geradoEm']?.toString() ?? '',
      escopoAtor: json['escopoAtor']?.toString() ?? 'GLOBAL',
    );
  }
}

class FiltrosRelatorio {
  const FiltrosRelatorio({
    this.igrejaId,
    this.equipeId,
    this.estado,
    this.ano,
  });

  final String? igrejaId;
  final String? equipeId;
  final String? estado;
  final int? ano;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (igrejaId != null && igrejaId!.isNotEmpty) map['igrejaId'] = igrejaId;
    if (equipeId != null && equipeId!.isNotEmpty) map['equipeId'] = equipeId;
    if (estado != null && estado!.isNotEmpty) map['estado'] = estado;
    if (ano != null) map['ano'] = ano;
    return map;
  }
}

abstract class AuditoriaRelatoriosGateway {
  Future<ResultadoConsultaAuditoria> consultarAuditoria(FiltrosAuditoria filtros);
  Future<ResultadoRelatorioOperacional> consultarRelatorio(FiltrosRelatorio filtros);
}

class CloudFunctionsAuditoriaGateway implements AuditoriaRelatoriosGateway {
  CloudFunctionsAuditoriaGateway({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<ResultadoConsultaAuditoria> consultarAuditoria(FiltrosAuditoria filtros) async {
    final callable = _functions.httpsCallable('consultarAuditoriaAutorizada');
    final response = await callable.call<Map<dynamic, dynamic>>(filtros.toJson());
    final data = Map<String, dynamic>.from(response.data);
    return ResultadoConsultaAuditoria.fromJson(data);
  }

  @override
  Future<ResultadoRelatorioOperacional> consultarRelatorio(FiltrosRelatorio filtros) async {
    final callable = _functions.httpsCallable('consultarRelatorioOperacional');
    final response = await callable.call<Map<dynamic, dynamic>>(filtros.toJson());
    final data = Map<String, dynamic>.from(response.data);
    return ResultadoRelatorioOperacional.fromJson(data);
  }
}

class MemoriaAuditoriaGateway implements AuditoriaRelatoriosGateway {
  MemoriaAuditoriaGateway({
    List<ItemAuditoria>? eventosIniciais,
    ResultadoRelatorioOperacional? relatorioInicial,
  })  : _eventos = eventosIniciais ?? [],
        _relatorio = relatorioInicial ??
            const ResultadoRelatorioOperacional(
              metricas: MetricasRelatorio(
                totalVoluntarios: 12,
                totalFichasAtivas: 10,
                totalParticipacoesAtivas: 14,
                totalAguardandoAprovacao: 2,
                totalCanceladasOuInativas: 0,
                distribuicaoPorEquipe: {'Louvor': 6, 'Recepção': 8},
                distribuicaoPorIgreja: {'Igreja Central': 12},
                distribuicaoPorEstado: {'ATIVA': 10, 'AGUARDANDO_COORDENADOR': 2},
              ),
              voluntarios: [
                VoluntarioRelatorioItem(
                  fichaId: 'ficha_exemplo_1',
                  nomeCompleto: 'Carlos Eduardo Santos',
                  cpfMascarado: '123.***.***-00',
                  igrejaId: 'ig_central',
                  igrejaNome: 'Igreja Central',
                  estadoFicha: 'ATIVA',
                  equipes: [
                    {'equipeNome': 'Louvor', 'estado': 'ATIVA', 'anoVigencia': 2026},
                  ],
                ),
                VoluntarioRelatorioItem(
                  fichaId: 'ficha_exemplo_2',
                  nomeCompleto: 'Ana Beatriz Ferreira',
                  cpfMascarado: '987.***.***-11',
                  igrejaId: 'ig_central',
                  igrejaNome: 'Igreja Central',
                  estadoFicha: 'ATIVA',
                  equipes: [
                    {'equipeNome': 'Recepção', 'estado': 'ATIVA', 'anoVigencia': 2026},
                  ],
                ),
              ],
              geradoEm: '2026-10-07T12:00:00.000Z',
              escopoAtor: 'GLOBAL',
            );

  final List<ItemAuditoria> _eventos;
  final ResultadoRelatorioOperacional _relatorio;

  @override
  Future<ResultadoConsultaAuditoria> consultarAuditoria(FiltrosAuditoria filtros) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    var itens = List<ItemAuditoria>.from(_eventos);

    if (filtros.acao != null && filtros.acao!.isNotEmpty) {
      itens = itens.where((e) => e.acao.toUpperCase() == filtros.acao!.toUpperCase()).toList();
    }
    if (filtros.igrejaId != null && filtros.igrejaId!.isNotEmpty) {
      itens = itens.where((e) => e.entidades.any((ent) => ent['id'] == filtros.igrejaId)).toList();
    }
    if (filtros.equipeId != null && filtros.equipeId!.isNotEmpty) {
      itens = itens.where((e) => e.entidades.any((ent) => ent['id'] == filtros.equipeId)).toList();
    }

    final limite = filtros.limite ?? 20;
    final slice = itens.take(limite).toList();
    final temMais = itens.length > limite;

    return ResultadoConsultaAuditoria(
      itens: slice,
      proximoCursor: temMais ? 'cursor_simulado' : null,
      temMais: temMais,
      totalRetornado: slice.length,
    );
  }

  @override
  Future<ResultadoRelatorioOperacional> consultarRelatorio(FiltrosRelatorio filtros) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return _relatorio;
  }
}
