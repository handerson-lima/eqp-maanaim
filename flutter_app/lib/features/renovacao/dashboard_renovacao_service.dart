import 'package:cloud_functions/cloud_functions.dart';

enum PapelDashboard {
  voluntario,
  pastorLocal,
  responsavelEquipe,
  coordenador,
  administrador;

  String get valorBackend {
    switch (this) {
      case PapelDashboard.voluntario:
        return 'VOLUNTARIO';
      case PapelDashboard.pastorLocal:
        return 'PASTOR_LOCAL';
      case PapelDashboard.responsavelEquipe:
        return 'RESPONSAVEL_EQUIPE';
      case PapelDashboard.coordenador:
        return 'COORDENADOR';
      case PapelDashboard.administrador:
        return 'ADMINISTRADOR';
    }
  }

  static PapelDashboard fromBackend(String? valor) {
    switch (valor?.toUpperCase()) {
      case 'PASTOR_LOCAL':
        return PapelDashboard.pastorLocal;
      case 'RESPONSAVEL_EQUIPE':
        return PapelDashboard.responsavelEquipe;
      case 'COORDENADOR':
        return PapelDashboard.coordenador;
      case 'ADMINISTRADOR':
        return PapelDashboard.administrador;
      default:
        return PapelDashboard.voluntario;
    }
  }
}

class MetricasRenovacaoVoluntarioModel {
  const MetricasRenovacaoVoluntarioModel({
    required this.totalParticipacoesAtivas,
    required this.emJanelaRenovacao,
    required this.pendentesManifestacao,
    required this.emTramitacao,
    required this.expiradas,
  });

  final int totalParticipacoesAtivas;
  final int emJanelaRenovacao;
  final int pendentesManifestacao;
  final int emTramitacao;
  final int expiradas;

  factory MetricasRenovacaoVoluntarioModel.fromMap(Map<String, dynamic> map) =>
      MetricasRenovacaoVoluntarioModel(
        totalParticipacoesAtivas: (map['totalParticipacoesAtivas'] as num?)?.toInt() ?? 0,
        emJanelaRenovacao: (map['emJanelaRenovacao'] as num?)?.toInt() ?? 0,
        pendentesManifestacao: (map['pendentesManifestacao'] as num?)?.toInt() ?? 0,
        emTramitacao: (map['emTramitacao'] as num?)?.toInt() ?? 0,
        expiradas: (map['expiradas'] as num?)?.toInt() ?? 0,
      );
}

class ItemRenovacaoVoluntarioModel {
  const ItemRenovacaoVoluntarioModel({
    required this.participacaoId,
    required this.equipeId,
    required this.equipeNome,
    required this.estadoParticipacao,
    this.vigenciaInicio,
    this.vigenciaFim,
    this.anoVigencia,
    required this.situacaoVigencia,
    this.diasRestantes,
    required this.emJanelaRenovacao,
    required this.podeManifestar,
    this.cicloId,
    this.anoCiclo,
    this.estadoCiclo,
  });

  final String participacaoId;
  final String equipeId;
  final String equipeNome;
  final String estadoParticipacao;
  final String? vigenciaInicio;
  final String? vigenciaFim;
  final int? anoVigencia;
  final String situacaoVigencia;
  final int? diasRestantes;
  final bool emJanelaRenovacao;
  final bool podeManifestar;
  final String? cicloId;
  final int? anoCiclo;
  final String? estadoCiclo;

  factory ItemRenovacaoVoluntarioModel.fromMap(Map<String, dynamic> map) =>
      ItemRenovacaoVoluntarioModel(
        participacaoId: map['participacaoId']?.toString() ?? '',
        equipeId: map['equipeId']?.toString() ?? '',
        equipeNome: map['equipeNome']?.toString() ?? 'Equipe',
        estadoParticipacao: map['estadoParticipacao']?.toString() ?? 'ATIVA',
        vigenciaInicio: map['vigenciaInicio']?.toString(),
        vigenciaFim: map['vigenciaFim']?.toString(),
        anoVigencia: (map['anoVigencia'] as num?)?.toInt(),
        situacaoVigencia: map['situacaoVigencia']?.toString() ?? 'VIGENTE',
        diasRestantes: (map['diasRestantes'] as num?)?.toInt(),
        emJanelaRenovacao: map['emJanelaRenovacao'] == true,
        podeManifestar: map['podeManifestar'] == true,
        cicloId: map['cicloId']?.toString(),
        anoCiclo: (map['anoCiclo'] as num?)?.toInt(),
        estadoCiclo: map['estadoCiclo']?.toString(),
      );
}

class MetricasRenovacaoPastorModel {
  const MetricasRenovacaoPastorModel({
    required this.pendentesParecer,
    required this.semManifestacao,
    required this.proximasVencimento,
    required this.expiradas,
    required this.totalSobEscopo,
  });

  final int pendentesParecer;
  final int semManifestacao;
  final int proximasVencimento;
  final int expiradas;
  final int totalSobEscopo;

  factory MetricasRenovacaoPastorModel.fromMap(Map<String, dynamic> map) =>
      MetricasRenovacaoPastorModel(
        pendentesParecer: (map['pendentesParecer'] as num?)?.toInt() ?? 0,
        semManifestacao: (map['semManifestacao'] as num?)?.toInt() ?? 0,
        proximasVencimento: (map['proximasVencimento'] as num?)?.toInt() ?? 0,
        expiradas: (map['expiradas'] as num?)?.toInt() ?? 0,
        totalSobEscopo: (map['totalSobEscopo'] as num?)?.toInt() ?? 0,
      );
}

class ItemRenovacaoPastorModel {
  const ItemRenovacaoPastorModel({
    required this.participacaoId,
    required this.fichaId,
    required this.voluntarioNome,
    required this.igrejaId,
    required this.igrejaNome,
    required this.equipeId,
    required this.equipeNome,
    this.vigenciaFim,
    this.diasRestantes,
    required this.situacaoVigencia,
    this.cicloId,
    this.estadoCiclo,
    required this.estadoRenovacao,
  });

  final String participacaoId;
  final String fichaId;
  final String voluntarioNome;
  final String igrejaId;
  final String igrejaNome;
  final String equipeId;
  final String equipeNome;
  final String? vigenciaFim;
  final int? diasRestantes;
  final String situacaoVigencia;
  final String? cicloId;
  final String? estadoCiclo;
  final String estadoRenovacao;

  factory ItemRenovacaoPastorModel.fromMap(Map<String, dynamic> map) =>
      ItemRenovacaoPastorModel(
        participacaoId: map['participacaoId']?.toString() ?? '',
        fichaId: map['fichaId']?.toString() ?? '',
        voluntarioNome: map['voluntarioNome']?.toString() ?? 'Voluntário',
        igrejaId: map['igrejaId']?.toString() ?? '',
        igrejaNome: map['igrejaNome']?.toString() ?? 'Igreja',
        equipeId: map['equipeId']?.toString() ?? '',
        equipeNome: map['equipeNome']?.toString() ?? 'Equipe',
        vigenciaFim: map['vigenciaFim']?.toString(),
        diasRestantes: (map['diasRestantes'] as num?)?.toInt(),
        situacaoVigencia: map['situacaoVigencia']?.toString() ?? 'VIGENTE',
        cicloId: map['cicloId']?.toString(),
        estadoCiclo: map['estadoCiclo']?.toString(),
        estadoRenovacao: map['estadoRenovacao']?.toString() ?? 'OUTRO',
      );
}

class MetricasRenovacaoResponsavelModel {
  const MetricasRenovacaoResponsavelModel({
    required this.pendentesEquipe,
    required this.emTramitacao,
    required this.semManifestacao,
    required this.expiradas,
    required this.totalEquipe,
  });

  final int pendentesEquipe;
  final int emTramitacao;
  final int semManifestacao;
  final int expiradas;
  final int totalEquipe;

  factory MetricasRenovacaoResponsavelModel.fromMap(Map<String, dynamic> map) =>
      MetricasRenovacaoResponsavelModel(
        pendentesEquipe: (map['pendentesEquipe'] as num?)?.toInt() ?? 0,
        emTramitacao: (map['emTramitacao'] as num?)?.toInt() ?? 0,
        semManifestacao: (map['semManifestacao'] as num?)?.toInt() ?? 0,
        expiradas: (map['expiradas'] as num?)?.toInt() ?? 0,
        totalEquipe: (map['totalEquipe'] as num?)?.toInt() ?? 0,
      );
}

class ItemRenovacaoResponsavelModel {
  const ItemRenovacaoResponsavelModel({
    required this.participacaoId,
    required this.fichaId,
    required this.voluntarioNome,
    required this.igrejaId,
    required this.igrejaNome,
    required this.equipeId,
    required this.equipeNome,
    this.vigenciaFim,
    this.diasRestantes,
    required this.situacaoVigencia,
    this.cicloId,
    this.estadoCiclo,
    required this.estadoRenovacao,
  });

  final String participacaoId;
  final String fichaId;
  final String voluntarioNome;
  final String igrejaId;
  final String igrejaNome;
  final String equipeId;
  final String equipeNome;
  final String? vigenciaFim;
  final int? diasRestantes;
  final String situacaoVigencia;
  final String? cicloId;
  final String? estadoCiclo;
  final String estadoRenovacao;

  factory ItemRenovacaoResponsavelModel.fromMap(Map<String, dynamic> map) =>
      ItemRenovacaoResponsavelModel(
        participacaoId: map['participacaoId']?.toString() ?? '',
        fichaId: map['fichaId']?.toString() ?? '',
        voluntarioNome: map['voluntarioNome']?.toString() ?? 'Voluntário',
        igrejaId: map['igrejaId']?.toString() ?? '',
        igrejaNome: map['igrejaNome']?.toString() ?? 'Igreja',
        equipeId: map['equipeId']?.toString() ?? '',
        equipeNome: map['equipeNome']?.toString() ?? 'Equipe',
        vigenciaFim: map['vigenciaFim']?.toString(),
        diasRestantes: (map['diasRestantes'] as num?)?.toInt(),
        situacaoVigencia: map['situacaoVigencia']?.toString() ?? 'VIGENTE',
        cicloId: map['cicloId']?.toString(),
        estadoCiclo: map['estadoCiclo']?.toString(),
        estadoRenovacao: map['estadoRenovacao']?.toString() ?? 'OUTRO',
      );
}

class MetricasRenovacaoCoordenadorModel {
  const MetricasRenovacaoCoordenadorModel({
    required this.totalAtivos,
    required this.emJanelaRenovacao,
    required this.pendentesPastorLocal,
    required this.pendentesResponsaveis,
    required this.aguardandoCoordenador,
    required this.renovadosConcluidos,
    required this.expirados,
  });

  final int totalAtivos;
  final int emJanelaRenovacao;
  final int pendentesPastorLocal;
  final int pendentesResponsaveis;
  final int aguardandoCoordenador;
  final int renovadosConcluidos;
  final int expirados;

  factory MetricasRenovacaoCoordenadorModel.fromMap(Map<String, dynamic> map) =>
      MetricasRenovacaoCoordenadorModel(
        totalAtivos: (map['totalAtivos'] as num?)?.toInt() ?? 0,
        emJanelaRenovacao: (map['emJanelaRenovacao'] as num?)?.toInt() ?? 0,
        pendentesPastorLocal: (map['pendentesPastorLocal'] as num?)?.toInt() ?? 0,
        pendentesResponsaveis: (map['pendentesResponsaveis'] as num?)?.toInt() ?? 0,
        aguardandoCoordenador: (map['aguardandoCoordenador'] as num?)?.toInt() ?? 0,
        renovadosConcluidos: (map['renovadosConcluidos'] as num?)?.toInt() ?? 0,
        expirados: (map['expirados'] as num?)?.toInt() ?? 0,
      );
}

class ItemRenovacaoCoordenadorModel {
  const ItemRenovacaoCoordenadorModel({
    required this.participacaoId,
    required this.fichaId,
    required this.voluntarioNome,
    required this.igrejaId,
    required this.igrejaNome,
    required this.equipeId,
    required this.equipeNome,
    this.vigenciaFim,
    this.diasRestantes,
    required this.situacaoVigencia,
    this.cicloId,
    this.estadoCiclo,
    this.anoVigencia,
    required this.estadoRenovacao,
  });

  final String participacaoId;
  final String fichaId;
  final String voluntarioNome;
  final String igrejaId;
  final String igrejaNome;
  final String equipeId;
  final String equipeNome;
  final String? vigenciaFim;
  final int? diasRestantes;
  final String situacaoVigencia;
  final String? cicloId;
  final String? estadoCiclo;
  final int? anoVigencia;
  final String estadoRenovacao;

  factory ItemRenovacaoCoordenadorModel.fromMap(Map<String, dynamic> map) =>
      ItemRenovacaoCoordenadorModel(
        participacaoId: map['participacaoId']?.toString() ?? '',
        fichaId: map['fichaId']?.toString() ?? '',
        voluntarioNome: map['voluntarioNome']?.toString() ?? 'Voluntário',
        igrejaId: map['igrejaId']?.toString() ?? '',
        igrejaNome: map['igrejaNome']?.toString() ?? 'Igreja',
        equipeId: map['equipeId']?.toString() ?? '',
        equipeNome: map['equipeNome']?.toString() ?? 'Equipe',
        vigenciaFim: map['vigenciaFim']?.toString(),
        diasRestantes: (map['diasRestantes'] as num?)?.toInt(),
        situacaoVigencia: map['situacaoVigencia']?.toString() ?? 'VIGENTE',
        cicloId: map['cicloId']?.toString(),
        estadoCiclo: map['estadoCiclo']?.toString(),
        anoVigencia: (map['anoVigencia'] as num?)?.toInt(),
        estadoRenovacao: map['estadoRenovacao']?.toString() ?? 'EM_DIA',
      );
}

class EscopoOpcaoFiltroModel {
  const EscopoOpcaoFiltroModel({
    required this.id,
    required this.nome,
    this.codigo,
  });

  final String id;
  final String nome;
  final String? codigo;

  factory EscopoOpcaoFiltroModel.fromMap(Map<String, dynamic> map) =>
      EscopoOpcaoFiltroModel(
        id: map['id']?.toString() ?? '',
        nome: map['nome']?.toString() ?? '',
        codigo: map['codigo']?.toString(),
      );
}

class ResultadoDashboardRenovacaoModel {
  const ResultadoDashboardRenovacaoModel({
    required this.papelResolvido,
    this.metricasVoluntario,
    this.metricasPastor,
    this.metricasResponsavel,
    this.metricasCoordenador,
    this.itensVoluntario = const [],
    this.itensPastor = const [],
    this.itensResponsavel = const [],
    this.itensCoordenador = const [],
    required this.totalItens,
    required this.pagina,
    required this.totalPaginas,
    this.igrejasEscopo = const [],
    this.equipesEscopo = const [],
  });

  final PapelDashboard papelResolvido;
  final MetricasRenovacaoVoluntarioModel? metricasVoluntario;
  final MetricasRenovacaoPastorModel? metricasPastor;
  final MetricasRenovacaoResponsavelModel? metricasResponsavel;
  final MetricasRenovacaoCoordenadorModel? metricasCoordenador;

  final List<ItemRenovacaoVoluntarioModel> itensVoluntario;
  final List<ItemRenovacaoPastorModel> itensPastor;
  final List<ItemRenovacaoResponsavelModel> itensResponsavel;
  final List<ItemRenovacaoCoordenadorModel> itensCoordenador;

  final int totalItens;
  final int pagina;
  final int totalPaginas;

  final List<EscopoOpcaoFiltroModel> igrejasEscopo;
  final List<EscopoOpcaoFiltroModel> equipesEscopo;

  factory ResultadoDashboardRenovacaoModel.fromMap(Map<String, dynamic> map) {
    final papel = PapelDashboard.fromBackend(map['papelResolvido']?.toString());
    final rawMetricas = (map['metricas'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawItens = (map['itens'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final igrejas = ((map['igrejasEscopo'] as List?) ?? [])
        .map((i) => EscopoOpcaoFiltroModel.fromMap((i as Map).cast<String, dynamic>()))
        .toList();

    final equipes = ((map['equipesEscopo'] as List?) ?? [])
        .map((e) => EscopoOpcaoFiltroModel.fromMap((e as Map).cast<String, dynamic>()))
        .toList();

    final total = (map['totalItens'] as num?)?.toInt() ?? rawItens.length;
    final pag = (map['pagina'] as num?)?.toInt() ?? 1;
    final totalPags = (map['totalPaginas'] as num?)?.toInt() ?? 1;

    switch (papel) {
      case PapelDashboard.voluntario:
        return ResultadoDashboardRenovacaoModel(
          papelResolvido: papel,
          metricasVoluntario: MetricasRenovacaoVoluntarioModel.fromMap(rawMetricas),
          itensVoluntario: rawItens.map(ItemRenovacaoVoluntarioModel.fromMap).toList(),
          totalItens: total,
          pagina: pag,
          totalPaginas: totalPags,
          igrejasEscopo: igrejas,
          equipesEscopo: equipes,
        );
      case PapelDashboard.pastorLocal:
        return ResultadoDashboardRenovacaoModel(
          papelResolvido: papel,
          metricasPastor: MetricasRenovacaoPastorModel.fromMap(rawMetricas),
          itensPastor: rawItens.map(ItemRenovacaoPastorModel.fromMap).toList(),
          totalItens: total,
          pagina: pag,
          totalPaginas: totalPags,
          igrejasEscopo: igrejas,
          equipesEscopo: equipes,
        );
      case PapelDashboard.responsavelEquipe:
        return ResultadoDashboardRenovacaoModel(
          papelResolvido: papel,
          metricasResponsavel: MetricasRenovacaoResponsavelModel.fromMap(rawMetricas),
          itensResponsavel: rawItens.map(ItemRenovacaoResponsavelModel.fromMap).toList(),
          totalItens: total,
          pagina: pag,
          totalPaginas: totalPags,
          igrejasEscopo: igrejas,
          equipesEscopo: equipes,
        );
      case PapelDashboard.coordenador:
      case PapelDashboard.administrador:
        return ResultadoDashboardRenovacaoModel(
          papelResolvido: papel,
          metricasCoordenador: MetricasRenovacaoCoordenadorModel.fromMap(rawMetricas),
          itensCoordenador: rawItens.map(ItemRenovacaoCoordenadorModel.fromMap).toList(),
          totalItens: total,
          pagina: pag,
          totalPaginas: totalPags,
          igrejasEscopo: igrejas,
          equipesEscopo: equipes,
        );
    }
  }
}

abstract class DashboardRenovacaoGateway {
  Future<ResultadoDashboardRenovacaoModel> obterDashboardRenovacao({
    PapelDashboard? papelDesejado,
    String? igrejaId,
    String? equipeId,
    String? estadoRenovacao,
    int? anoVigencia,
    int? limite,
    int? pagina,
  });
}

class FirebaseDashboardRenovacaoGateway implements DashboardRenovacaoGateway {
  FirebaseDashboardRenovacaoGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<ResultadoDashboardRenovacaoModel> obterDashboardRenovacao({
    PapelDashboard? papelDesejado,
    String? igrejaId,
    String? equipeId,
    String? estadoRenovacao,
    int? anoVigencia,
    int? limite,
    int? pagina,
  }) async {
    final callable = _functions.httpsCallable('obterDashboardRenovacao');
    final payload = <String, dynamic>{
      if (papelDesejado != null) 'papelDesejado': papelDesejado.valorBackend,
      if (igrejaId != null && igrejaId.isNotEmpty) 'igrejaId': igrejaId,
      if (equipeId != null && equipeId.isNotEmpty) 'equipeId': equipeId,
      if (estadoRenovacao != null && estadoRenovacao.isNotEmpty)
        'estadoRenovacao': estadoRenovacao,
      if (anoVigencia != null) 'anoVigencia': anoVigencia,
      if (limite != null) 'limite': limite,
      if (pagina != null) 'pagina': pagina,
    };

    final response = await callable.call(payload);
    final data = (response.data as Map).cast<String, dynamic>();
    return ResultadoDashboardRenovacaoModel.fromMap(data);
  }
}

class MemoriaDashboardRenovacaoGateway implements DashboardRenovacaoGateway {
  MemoriaDashboardRenovacaoGateway({
    ResultadoDashboardRenovacaoModel? respostaPadrao,
  }) : _respostaPadrao = respostaPadrao;

  ResultadoDashboardRenovacaoModel? _respostaPadrao;

  void definirResposta(ResultadoDashboardRenovacaoModel resposta) {
    _respostaPadrao = resposta;
  }

  @override
  Future<ResultadoDashboardRenovacaoModel> obterDashboardRenovacao({
    PapelDashboard? papelDesejado,
    String? igrejaId,
    String? equipeId,
    String? estadoRenovacao,
    int? anoVigencia,
    int? limite,
    int? pagina,
  }) async {
    if (_respostaPadrao != null) return _respostaPadrao!;

    // Fallback básico para voluntário
    return const ResultadoDashboardRenovacaoModel(
      papelResolvido: PapelDashboard.voluntario,
      metricasVoluntario: MetricasRenovacaoVoluntarioModel(
        totalParticipacoesAtivas: 0,
        emJanelaRenovacao: 0,
        pendentesManifestacao: 0,
        emTramitacao: 0,
        expiradas: 0,
      ),
      totalItens: 0,
      pagina: 1,
      totalPaginas: 1,
    );
  }
}
