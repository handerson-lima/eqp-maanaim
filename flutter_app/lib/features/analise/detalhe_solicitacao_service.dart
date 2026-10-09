import 'package:cloud_functions/cloud_functions.dart';
import '../coordenador/coordenador_service.dart';
import '../pastor/pastor_service.dart';
import '../responsavel_equipe/responsavel_equipe_service.dart';
import '../voluntario/historico_service.dart';
import 'detalhe_solicitacao_model.dart';

/// Exceção disparada quando ocorre conflito de concorrência / versão desatualizada (ABORTED).
class ConflitoConcorrenciaException implements Exception {
  const ConflitoConcorrenciaException([
    this.message = 'A solicitação foi modificada por outro processo. Recarregue os dados antes de decidir.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Contrato canônico de Gateway para a Tela S05 (Detalhe da Solicitação e Análise).
abstract class DetalheSolicitacaoGateway {
  /// Obtém a projeção autorizada dos dados da solicitação, voluntário, participações e documentos.
  Future<DetalheSolicitacaoDados> obterDetalhe({
    required String fichaId,
    String? cicloId,
  });

  /// Executa decisão no âmbito pastoral (Pastor Local).
  Future<void> decidirPastor(
    EntradaDecisaoPastor entrada, {
    bool isRenovacao = false,
  });

  /// Executa decisão no âmbito da equipe (Responsável de Equipe).
  Future<void> decidirResponsavel(
    EntradaDecidirParticipacaoResponsavel entrada, {
    bool isRenovacao = false,
  });

  /// Executa deliberação e homologação final (Coordenador Geral).
  Future<void> decidirCoordenador({
    required EntradaDecisaoCoordenadorContextual entrada,
    bool isRenovacao = false,
  });
}

/// Implementação padrão que orquestra as Cloud Functions autorizadas e gateways de domínio.
class CompostoDetalheSolicitacaoGateway implements DetalheSolicitacaoGateway {
  CompostoDetalheSolicitacaoGateway({
    FirebaseFunctions? functions,
    PastorLocalGateway? pastorGateway,
    ResponsavelEquipeGateway? responsavelGateway,
    CoordenadorGateway? coordenadorGateway,
    HistoricoService? historicoService,
  })  : _functions = functions,
        _pastorGateway = pastorGateway,
        _responsavelGateway = responsavelGateway,
        _coordenadorGateway = coordenadorGateway,
        _historicoService = historicoService ?? HistoricoService(functions: functions);

  final FirebaseFunctions? _functions;
  final PastorLocalGateway? _pastorGateway;
  final ResponsavelEquipeGateway? _responsavelGateway;
  final CoordenadorGateway? _coordenadorGateway;
  final HistoricoService _historicoService;

  FirebaseFunctions get _resolvedFunctions =>
      _functions ?? FirebaseFunctions.instance;

  @override
  Future<DetalheSolicitacaoDados> obterDetalhe({
    required String fichaId,
    String? cicloId,
  }) async {
    Map<String, dynamic>? detalheRaw;
    try {
      final callable = _resolvedFunctions.httpsCallable('obterDetalheSolicitacao');
      final res = await callable.call<Map<String, dynamic>>({'fichaId': fichaId});
      detalheRaw = Map<String, dynamic>.from(res.data);
    } catch (_) {
      // Se obterDetalheSolicitacao falhar ou não estiver disponível em mocks,
      // fallback gracioso compondo via consultarFichaAutorizada
    }

    FichaConsultaModel? fichaConsulta;
    List<ParticipacaoConsultaModel> participacoesConsulta = [];
    List<EventoLinhaDoTempoModel> linhaDoTempo = [];

    try {
      final resFicha = await _historicoService.consultarFichaAutorizada(fichaId: fichaId);
      fichaConsulta = resFicha.ficha;
      participacoesConsulta = resFicha.participacoes;
    } catch (_) {
      // Continua com os dados disponíveis
    }

    try {
      linhaDoTempo = await _historicoService.consultarLinhaDoTempoAutorizada(fichaId: fichaId);
    } catch (_) {
      // Linha do tempo vazia em fallback
    }

    // Mesclar projeção autorizada
    final voluntarioUid = detalheRaw?['voluntarioUid'] as String? ??
        fichaConsulta?.ownerUid ??
        fichaId;
    final voluntarioNome = detalheRaw?['voluntarioNome'] as String? ??
        fichaConsulta?.nomeCompleto ??
        'Voluntário';
    final igrejaId = detalheRaw?['igrejaId'] as String? ??
        fichaConsulta?.igrejaId ??
        '';
    final nomeIgreja = fichaConsulta?.nomeIgreja;
    final estadoFicha = detalheRaw?['estadoFicha'] as String? ??
        fichaConsulta?.estado ??
        'AGUARDANDO_PASTOR_LOCAL';
    final versao = (detalheRaw?['versao'] as num?)?.toInt() ??
        fichaConsulta?.versao ??
        1;
    final vinculoId = detalheRaw?['vinculoId'] as String?;
    final enviadoEm = fichaConsulta?.atualizadoEm ?? fichaConsulta?.criadoEm;

    // Participações mapeadas
    final List<ItemParticipacaoDetalhe> listaParticipacoes = [];

    if (detalheRaw != null && detalheRaw['participacoes'] is List) {
      for (final p in (detalheRaw['participacoes'] as List)) {
        if (p is Map) {
          listaParticipacoes.add(ItemParticipacaoDetalhe.fromMap(
            Map<String, dynamic>.from(p),
          ));
        }
      }
    } else if (participacoesConsulta.isNotEmpty) {
      for (final p in participacoesConsulta) {
        listaParticipacoes.add(ItemParticipacaoDetalhe(
          id: p.id,
          equipeId: p.equipeId,
          nomeEquipe: p.nomeEquipe,
          estado: p.estado,
          ciclo: p.ciclo,
          proximaAcao: p.proximaAcao,
          vigenciaInicio: p.vigenciaInicio,
          vigenciaFim: p.vigenciaFim,
        ));
      }
    }

    final temElegivelPdf = listaParticipacoes.any((p) => p.isElegivelPdf);

    // Documentos e evidências autorizadas
    final documentos = <DocumentoEvidenciaModel>[
      const DocumentoEvidenciaModel(
        tipo: 'TERMO_ADESAO',
        titulo: 'Termo de Adesão ao Voluntariado',
        descricao: 'Aceite registrado eletronicamente com carimbo de tempo',
        disponivel: true,
      ),
      DocumentoEvidenciaModel(
        tipo: 'PDF_APROVACAO',
        titulo: 'Ficha de Aprovação Homologada (PDF Privado)',
        descricao: temElegivelPdf
            ? 'Documento assinado digitalmente com registros de aprovação'
            : 'Disponível exclusivamente após homologação e aprovação de equipe',
        disponivel: temElegivelPdf,
      ),
    ];

    return DetalheSolicitacaoDados(
      fichaId: fichaId,
      voluntarioUid: voluntarioUid,
      voluntarioNome: voluntarioNome,
      cpfMascarado: fichaConsulta?.cpfMascarado,
      profissao: fichaConsulta?.profissao,
      igrejaId: igrejaId,
      nomeIgreja: nomeIgreja,
      estadoFicha: estadoFicha,
      versao: versao,
      vinculoId: vinculoId,
      enviadoEm: enviadoEm,
      atualizadoEm: fichaConsulta?.atualizadoEm,
      isRenovacaoAnual: cicloId != null && cicloId.isNotEmpty,
      cicloId: cicloId,
      participacoes: listaParticipacoes,
      documentos: documentos,
      linhaDoTempo: linhaDoTempo,
    );
  }

  void _verificarErroConcorrencia(Object error) {
    if (error is FirebaseFunctionsException &&
        (error.code == 'aborted' ||
            error.message?.toLowerCase().contains('versao') == true ||
            error.message?.toLowerCase().contains('conflito') == true ||
            error.message?.toLowerCase().contains('concorrente') == true)) {
      throw ConflitoConcorrenciaException(
        error.message ?? 'Conflito de concorrência detectado. Recarregue os dados.',
      );
    }
  }

  @override
  Future<void> decidirPastor(
    EntradaDecisaoPastor entrada, {
    bool isRenovacao = false,
  }) async {
    if (_pastorGateway == null) {
      throw StateError('PastorGateway não configurado no DetalheSolicitacaoGateway.');
    }
    try {
      if (isRenovacao) {
        await _pastorGateway.decidirCicloAnual(entrada);
      } else {
        await _pastorGateway.decidirFicha(entrada);
      }
    } catch (e) {
      _verificarErroConcorrencia(e);
      rethrow;
    }
  }

  @override
  Future<void> decidirResponsavel(
    EntradaDecidirParticipacaoResponsavel entrada, {
    bool isRenovacao = false,
  }) async {
    if (_responsavelGateway == null) {
      throw StateError('ResponsavelEquipeGateway não configurado no DetalheSolicitacaoGateway.');
    }
    try {
      if (isRenovacao) {
        await _responsavelGateway.decidirCicloAnual(entrada);
      } else {
        await _responsavelGateway.decidirParticipacao(entrada);
      }
    } catch (e) {
      _verificarErroConcorrencia(e);
      rethrow;
    }
  }

  @override
  Future<void> decidirCoordenador({
    required EntradaDecisaoCoordenadorContextual entrada,
    bool isRenovacao = false,
  }) async {
    if (_coordenadorGateway == null) {
      throw StateError('CoordenadorGateway não configurado no DetalheSolicitacaoGateway.');
    }
    try {
      if (isRenovacao && entrada.cicloId != null) {
        await _coordenadorGateway.concluirCicloAnual(
          commandId: entrada.commandId,
          cicloId: entrada.cicloId!,
          decisao: entrada.decisao,
          confirmouReuniaoPastores: entrada.confirmacaoReuniaoPastores,
          justificativa: entrada.justificativa,
          observacao: entrada.observacao,
          expectedVersion: entrada.expectedVersion,
        );
      } else {
        await _coordenadorGateway.decidir(
          commandId: entrada.commandId,
          fichaId: entrada.fichaId,
          decisao: entrada.decisao,
          confirmouReuniaoPastores: entrada.confirmacaoReuniaoPastores,
          observacao: entrada.observacao ?? entrada.justificativa,
          expectedVersion: entrada.expectedVersion,
        );
      }
    } catch (e) {
      _verificarErroConcorrencia(e);
      rethrow;
    }
  }
}
