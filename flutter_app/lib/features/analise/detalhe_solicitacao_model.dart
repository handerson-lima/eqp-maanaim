import '../voluntario/historico_service.dart';

/// Papel do usuário no momento da análise contextual.
enum PapelContextualAnalise {
  pastorLocal,
  responsavelEquipe,
  coordenadorGeral,
}

/// Item de participação projetado no detalhe da solicitação (S05).
class ItemParticipacaoDetalhe {
  const ItemParticipacaoDetalhe({
    required this.id,
    required this.equipeId,
    required this.nomeEquipe,
    required this.estado,
    required this.ciclo,
    this.proximaAcao,
    this.decisao,
    this.vigenciaInicio,
    this.vigenciaFim,
  });

  final String id;
  final String equipeId;
  final String nomeEquipe;
  final String estado;
  final String ciclo;
  final String? proximaAcao;
  final String? decisao;
  final String? vigenciaInicio;
  final String? vigenciaFim;

  /// Participação elegível para PDF de aprovação da ficha (APROVADA ou ATIVA).
  bool get isElegivelPdf => estado == 'APROVADA' || estado == 'ATIVA';
  bool get isAtiva => estado == 'ATIVA';
  bool get isAprovada => estado == 'APROVADA';
  bool get isPendenteResponsavel => estado == 'AGUARDANDO_RESPONSAVEL_EQUIPE';
  bool get isPendentePastor => estado == 'AGUARDANDO_PASTOR_LOCAL';
  bool get isPendenteCoordenador => estado == 'AGUARDANDO_COORDENADOR';

  factory ItemParticipacaoDetalhe.fromMap(Map<String, dynamic> map) {
    return ItemParticipacaoDetalhe(
      id: map['id'] as String? ?? '',
      equipeId: map['equipeId'] as String? ?? '',
      nomeEquipe: map['nomeEquipe'] as String? ?? '',
      estado: map['estado'] as String? ?? 'RASCUNHO',
      ciclo: map['ciclo'] as String? ?? 'INICIAL',
      proximaAcao: map['proximaAcao'] as String?,
      decisao: map['decisao'] as String?,
      vigenciaInicio: map['vigenciaInicio'] as String?,
      vigenciaFim: map['vigenciaFim'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipeId': equipeId,
      'nomeEquipe': nomeEquipe,
      'estado': estado,
      'ciclo': ciclo,
      'proximaAcao': proximaAcao,
      'decisao': decisao,
      'vigenciaInicio': vigenciaInicio,
      'vigenciaFim': vigenciaFim,
    };
  }
}

/// Evidência ou documento associado à solicitação.
class DocumentoEvidenciaModel {
  const DocumentoEvidenciaModel({
    required this.tipo,
    required this.titulo,
    required this.descricao,
    required this.disponivel,
    this.url,
    this.geradoEm,
  });

  final String tipo; // 'TERMO_ADESAO', 'COMPROVANTE', 'PDF_APROVACAO'
  final String titulo;
  final String descricao;
  final bool disponivel;
  final String? url;
  final String? geradoEm;

  factory DocumentoEvidenciaModel.fromMap(Map<String, dynamic> map) {
    return DocumentoEvidenciaModel(
      tipo: map['tipo'] as String? ?? 'OUTRO',
      titulo: map['titulo'] as String? ?? 'Documento',
      descricao: map['descricao'] as String? ?? '',
      disponivel: map['disponivel'] as bool? ?? false,
      url: map['url'] as String?,
      geradoEm: map['geradoEm'] as String?,
    );
  }
}

/// Projeção unificada de dados para a Tela S05 (Detalhe da Solicitação e Análise).
class DetalheSolicitacaoDados {
  const DetalheSolicitacaoDados({
    required this.fichaId,
    required this.voluntarioUid,
    required this.voluntarioNome,
    this.cpfMascarado,
    this.profissao,
    required this.igrejaId,
    this.nomeIgreja,
    required this.estadoFicha,
    required this.versao,
    this.vinculoId,
    this.enviadoEm,
    this.atualizadoEm,
    this.isRenovacaoAnual = false,
    this.anoCiclo,
    this.cicloId,
    this.participacoes = const [],
    this.documentos = const [],
    this.linhaDoTempo = const [],
  });

  final String fichaId;
  final String voluntarioUid;
  final String voluntarioNome;
  final String? cpfMascarado;
  final String? profissao;
  final String igrejaId;
  final String? nomeIgreja;
  final String estadoFicha;
  final int versao;
  final String? vinculoId;
  final String? enviadoEm;
  final String? atualizadoEm;
  final bool isRenovacaoAnual;
  final int? anoCiclo;
  final String? cicloId;
  final List<ItemParticipacaoDetalhe> participacoes;
  final List<DocumentoEvidenciaModel> documentos;
  final List<EventoLinhaDoTempoModel> linhaDoTempo;

  /// Retorna se há pelo menos uma participação elegível para o PDF de aprovação (APROVADA ou ATIVA).
  bool get temParticipacaoElegivelPdf =>
      participacoes.any((p) => p.isElegivelPdf);

  factory DetalheSolicitacaoDados.fromMap(Map<String, dynamic> map) {
    final participacoesRaw = (map['participacoes'] as List<dynamic>?) ?? [];
    final docsRaw = (map['documentos'] as List<dynamic>?) ?? [];
    final linhaRaw = (map['linhaDoTempo'] as List<dynamic>?) ?? [];

    return DetalheSolicitacaoDados(
      fichaId: map['fichaId'] as String? ?? '',
      voluntarioUid: map['voluntarioUid'] as String? ?? '',
      voluntarioNome: map['voluntarioNome'] as String? ?? '',
      cpfMascarado: map['cpfMascarado'] as String?,
      profissao: map['profissao'] as String?,
      igrejaId: map['igrejaId'] as String? ?? '',
      nomeIgreja: map['nomeIgreja'] as String?,
      estadoFicha: map['estadoFicha'] as String? ?? 'RASCUNHO',
      versao: (map['versao'] as num?)?.toInt() ?? 1,
      vinculoId: map['vinculoId'] as String?,
      enviadoEm: map['enviadoEm'] as String?,
      atualizadoEm: map['atualizadoEm'] as String?,
      isRenovacaoAnual: map['isRenovacaoAnual'] as bool? ?? false,
      anoCiclo: (map['anoCiclo'] as num?)?.toInt(),
      cicloId: map['cicloId'] as String?,
      participacoes: participacoesRaw
          .map((p) => ItemParticipacaoDetalhe.fromMap(
                Map<String, dynamic>.from(p as Map),
              ))
          .toList(),
      documentos: docsRaw
          .map((d) => DocumentoEvidenciaModel.fromMap(
                Map<String, dynamic>.from(d as Map),
              ))
          .toList(),
      linhaDoTempo: linhaRaw
          .map((e) => EventoLinhaDoTempoModel.fromMap(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }
}

/// Resultado de uma ação tomada no painel de decisão contextual.
class ResultadoDecisaoContextual {
  const ResultadoDecisaoContextual({
    required this.fichaId,
    this.equipeId,
    required this.decisao,
    required this.sucesso,
    this.mensagem,
  });

  final String fichaId;
  final String? equipeId;
  final String decisao; // 'APROVADO', 'DESFAVORAVEL', 'HOMOLOGADO'
  final bool sucesso;
  final String? mensagem;
}

/// Parâmetros de entrada para deliberação do Coordenador Geral na análise contextual.
class EntradaDecisaoCoordenadorContextual {
  const EntradaDecisaoCoordenadorContextual({
    required this.commandId,
    required this.fichaId,
    this.cicloId,
    required this.decisao,
    required this.confirmacaoReuniaoPastores,
    this.justificativa,
    this.observacao,
    required this.expectedVersion,
  });

  final String commandId;
  final String fichaId;
  final String? cicloId;
  final String decisao; // 'APROVADO' ou 'DESFAVORAVEL'
  final bool confirmacaoReuniaoPastores;
  final String? justificativa;
  final String? observacao;
  final int expectedVersion;
}

