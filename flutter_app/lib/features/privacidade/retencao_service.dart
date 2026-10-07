import 'package:cloud_functions/cloud_functions.dart';

/// Exceção lançada quando o ator não tem autorização para a rotina de retenção.
class RetencaoAcessoNegadoException implements Exception {
  const RetencaoAcessoNegadoException();
}

/// Exceção genérica de falha da rotina de retenção.
class RetencaoFalhaException implements Exception {
  const RetencaoFalhaException(this.mensagem);
  final String mensagem;
}

/// Indicadores agregados de conformidade de retenção (somente contagens).
class IndicadoresRetencao {
  const IndicadoresRetencao({
    required this.politicaId,
    required this.anosRetencao,
    required this.diasRascunho,
    required this.expurgoAutomaticoHabilitado,
    required this.totalFichas,
    required this.fichasAnonimizadas,
    required this.fichasAtivas,
    required this.fichasElegiveisAnonimizacao,
    required this.rascunhosElegiveisExpurgo,
    required this.porEstado,
    required this.geradoEm,
  });

  final String politicaId;
  final int anosRetencao;
  final int diasRascunho;
  final bool expurgoAutomaticoHabilitado;
  final int totalFichas;
  final int fichasAnonimizadas;
  final int fichasAtivas;
  final int fichasElegiveisAnonimizacao;
  final int rascunhosElegiveisExpurgo;
  final Map<String, int> porEstado;
  final String geradoEm;

  factory IndicadoresRetencao.fromJson(Map<String, dynamic> json) {
    final raw = json['porEstado'];
    final porEstado = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, v) => porEstado[k.toString()] = (v as num?)?.toInt() ?? 0);
    }
    return IndicadoresRetencao(
      politicaId: json['politicaId']?.toString() ?? 'AD-12_V1',
      anosRetencao: (json['anosRetencao'] as num?)?.toInt() ?? 5,
      diasRascunho: (json['diasRascunho'] as num?)?.toInt() ?? 180,
      expurgoAutomaticoHabilitado: json['expurgoAutomaticoHabilitado'] == true,
      totalFichas: (json['totalFichas'] as num?)?.toInt() ?? 0,
      fichasAnonimizadas: (json['fichasAnonimizadas'] as num?)?.toInt() ?? 0,
      fichasAtivas: (json['fichasAtivas'] as num?)?.toInt() ?? 0,
      fichasElegiveisAnonimizacao:
          (json['fichasElegiveisAnonimizacao'] as num?)?.toInt() ?? 0,
      rascunhosElegiveisExpurgo:
          (json['rascunhosElegiveisExpurgo'] as num?)?.toInt() ?? 0,
      porEstado: porEstado,
      geradoEm: json['geradoEm']?.toString() ?? '',
    );
  }
}

/// Item candidato/executado da rotina (IDs nunca são exibidos na UI de conformidade).
class ItemRetencao {
  const ItemRetencao({
    required this.fichaId,
    required this.estado,
    required this.acao,
    required this.motivo,
    this.retencaoAte,
  });

  final String fichaId;
  final String estado;
  final String acao;
  final String motivo;
  final String? retencaoAte;

  factory ItemRetencao.fromJson(Map<String, dynamic> json) {
    return ItemRetencao(
      fichaId: json['fichaId']?.toString() ?? '',
      estado: json['estado']?.toString() ?? '',
      acao: json['acao']?.toString() ?? '',
      motivo: json['motivo']?.toString() ?? '',
      retencaoAte: json['retencaoAte']?.toString(),
    );
  }
}

/// Resultado da rotina (simulação ou execução).
class ResultadoRotinaRetencao {
  const ResultadoRotinaRetencao({
    required this.sucesso,
    required this.repetido,
    required this.dryRun,
    required this.politicaId,
    required this.totalAnalisadas,
    required this.totalAnonimizadas,
    required this.totalExpurgadas,
    required this.ignoradas,
    required this.itens,
    required this.processadoEm,
  });

  final bool sucesso;
  final bool repetido;
  final bool dryRun;
  final String politicaId;
  final int totalAnalisadas;
  final int totalAnonimizadas;
  final int totalExpurgadas;
  final int ignoradas;
  final List<ItemRetencao> itens;
  final String processadoEm;

  factory ResultadoRotinaRetencao.fromJson(Map<String, dynamic> json) {
    final rawItens = json['itens'];
    final itens = <ItemRetencao>[];
    if (rawItens is List) {
      for (final item in rawItens) {
        if (item is Map) {
          itens.add(ItemRetencao.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return ResultadoRotinaRetencao(
      sucesso: json['sucesso'] == true,
      repetido: json['repetido'] == true,
      dryRun: json['dryRun'] == true,
      politicaId: json['politicaId']?.toString() ?? 'AD-12_V1',
      totalAnalisadas: (json['totalAnalisadas'] as num?)?.toInt() ?? 0,
      totalAnonimizadas: (json['totalAnonimizadas'] as num?)?.toInt() ?? 0,
      totalExpurgadas: (json['totalExpurgadas'] as num?)?.toInt() ?? 0,
      ignoradas: (json['ignoradas'] as num?)?.toInt() ?? 0,
      itens: itens,
      processadoEm: json['processadoEm']?.toString() ?? '',
    );
  }
}

abstract class RetencaoGateway {
  Future<IndicadoresRetencao> consultarConformidade();

  Future<ResultadoRotinaRetencao> executarRotina({
    required String commandId,
    required bool dryRun,
    String motivo = 'EXECUCAO_MANUAL',
    int limite = 100,
  });
}

class CloudFunctionsRetencaoGateway implements RetencaoGateway {
  CloudFunctionsRetencaoGateway({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<IndicadoresRetencao> consultarConformidade() async {
    try {
      final callable = _functions.httpsCallable('consultarConformidadeRetencao');
      final response = await callable.call<Map<dynamic, dynamic>>(<String, dynamic>{});
      return IndicadoresRetencao.fromJson(Map<String, dynamic>.from(response.data));
    } on FirebaseFunctionsException catch (err) {
      if (err.code == 'permission-denied' || err.code == 'unauthenticated') {
        throw const RetencaoAcessoNegadoException();
      }
      throw RetencaoFalhaException(
        err.message ?? 'Não foi possível consultar os indicadores de retenção.',
      );
    }
  }

  @override
  Future<ResultadoRotinaRetencao> executarRotina({
    required String commandId,
    required bool dryRun,
    String motivo = 'EXECUCAO_MANUAL',
    int limite = 100,
  }) async {
    try {
      final callable = _functions.httpsCallable('executarRotinaRetencao');
      final response = await callable.call<Map<dynamic, dynamic>>(<String, dynamic>{
        'commandId': commandId,
        'dryRun': dryRun,
        'motivo': motivo,
        'limite': limite,
      });
      return ResultadoRotinaRetencao.fromJson(Map<String, dynamic>.from(response.data));
    } on FirebaseFunctionsException catch (err) {
      if (err.code == 'permission-denied' || err.code == 'unauthenticated') {
        throw const RetencaoAcessoNegadoException();
      }
      throw RetencaoFalhaException(
        err.message ?? 'Não foi possível executar a rotina de retenção.',
      );
    }
  }
}

/// Gateway em memória para testes e demonstração (nunca persistente).
class MemoriaRetencaoGateway implements RetencaoGateway {
  MemoriaRetencaoGateway({
    IndicadoresRetencao? indicadores,
    this.negarAcesso = false,
    this.falhar = false,
  }) : _indicadores = indicadores ??
            const IndicadoresRetencao(
              politicaId: 'AD-12_V1',
              anosRetencao: 5,
              diasRascunho: 180,
              expurgoAutomaticoHabilitado: false,
              totalFichas: 42,
              fichasAnonimizadas: 3,
              fichasAtivas: 30,
              fichasElegiveisAnonimizacao: 2,
              rascunhosElegiveisExpurgo: 4,
              porEstado: {
                'ATIVA': 30,
                'RASCUNHO': 6,
                'EXPIRADA': 4,
                'REJEITADA': 2,
              },
              geradoEm: '2026-10-07T12:00:00.000Z',
            );

  final IndicadoresRetencao _indicadores;
  final bool negarAcesso;
  final bool falhar;

  @override
  Future<IndicadoresRetencao> consultarConformidade() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (negarAcesso) throw const RetencaoAcessoNegadoException();
    if (falhar) throw const RetencaoFalhaException('Falha simulada.');
    return _indicadores;
  }

  @override
  Future<ResultadoRotinaRetencao> executarRotina({
    required String commandId,
    required bool dryRun,
    String motivo = 'EXECUCAO_MANUAL',
    int limite = 100,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (negarAcesso) throw const RetencaoAcessoNegadoException();
    if (falhar) throw const RetencaoFalhaException('Falha simulada.');
    return ResultadoRotinaRetencao(
      sucesso: true,
      repetido: false,
      dryRun: dryRun,
      politicaId: 'AD-12_V1',
      totalAnalisadas: _indicadores.totalFichas,
      totalAnonimizadas: dryRun ? _indicadores.fichasElegiveisAnonimizacao : 0,
      totalExpurgadas: dryRun ? _indicadores.rascunhosElegiveisExpurgo : 0,
      ignoradas: _indicadores.totalFichas -
          _indicadores.fichasElegiveisAnonimizacao -
          _indicadores.rascunhosElegiveisExpurgo,
      itens: const [],
      processadoEm: '2026-10-07T12:00:00.000Z',
    );
  }
}
