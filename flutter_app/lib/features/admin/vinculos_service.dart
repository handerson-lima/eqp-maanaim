import 'package:cloud_functions/cloud_functions.dart';

import 'catalogo_service.dart' show normalizarBusca;
import 'pessoas_service.dart';

/// Rótulos de tipo de entidade, ação e papel de vínculo para exibição.
const Map<String, String> rotulosTipoEntidade = {
  'IGREJA': 'Igreja',
  'EQUIPE': 'Equipe',
};

const Map<String, String> rotulosAcaoVinculo = {
  'ATRIBUIR': 'Atribuição',
  'SUBSTITUIR': 'Substituição',
  'ENCERRAR': 'Encerramento',
};

String rotuloAcaoVinculo(String acao) => rotulosAcaoVinculo[acao] ?? acao;

String rotuloPapelVinculo(String papel) => papel == 'PASTOR_LOCAL'
    ? 'Pastor Local'
    : papel == 'PASTOR_EQUIPE'
    ? 'Responsável de Equipe'
    : papel;

/// Responsável canônico vigente de uma igreja ou equipe.
class ResponsavelVigente {
  const ResponsavelVigente({required this.pessoaId, required this.nome});

  final String pessoaId;
  final String nome;

  String get rotulo => nome.isNotEmpty ? nome : pessoaId;
}

/// Evento imutável da linha do tempo de um vínculo.
class EventoHistoricoVinculo {
  const EventoHistoricoVinculo({
    required this.acao,
    required this.papel,
    required this.estado,
    required this.atorUid,
    required this.atorNome,
    required this.inicioVigencia,
    this.fimVigencia,
    this.justificativa,
    this.encerradoPorUid,
  });

  final String acao;
  final String papel;
  final String estado;
  final String atorUid;
  final String atorNome;
  final DateTime? inicioVigencia;
  final DateTime? fimVigencia;
  final String? justificativa;
  final String? encerradoPorUid;

  bool get vigente => estado == 'VIGENTE';
  String get atorRotulo => atorNome.isNotEmpty ? atorNome : atorUid;
}

/// Igreja ou equipe com o responsável vigente e a linha do tempo read-only.
class ItemVinculo {
  const ItemVinculo({
    required this.id,
    required this.tipoEntidade,
    required this.rotulo,
    required this.ativo,
    required this.versaoVinculo,
    this.codigo,
    this.responsavel,
    this.historico = const [],
  });

  final String id;
  final String tipoEntidade;
  final String? codigo;
  final String rotulo;
  final bool ativo;
  final int versaoVinculo;
  final ResponsavelVigente? responsavel;
  final List<EventoHistoricoVinculo> historico;

  bool get temResponsavel => responsavel != null;
}

class VinculosResposta {
  const VinculosResposta({required this.igrejas, required this.equipes});

  final List<ItemVinculo> igrejas;
  final List<ItemVinculo> equipes;

  bool get vazio => igrejas.isEmpty && equipes.isEmpty;
}

class VinculoResultado {
  const VinculoResultado({
    required this.vinculoId,
    required this.pessoaId,
    required this.versaoVinculo,
    required this.repetido,
  });

  final String? vinculoId;
  final String? pessoaId;
  final int versaoVinculo;
  final bool repetido;
}

/// Formata uma data efetiva como `YYYY-MM-DD` usando o dia escolhido.
String formatarDataEfetiva(DateTime data) {
  final ano = data.year.toString().padLeft(4, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final dia = data.day.toString().padLeft(2, '0');
  return '$ano-$mes-$dia';
}

/// Contrato de leitura e mutação dos vínculos temporais, sempre via Cloud Function.
abstract interface class VinculosGateway {
  Future<VinculosResposta> consultar({String? termo});

  Future<List<PessoaAdministrativa>> buscarPessoas({String? termo});

  Future<VinculoResultado> gerenciar({
    required String commandId,
    required String tipoEntidade,
    required String entidadeId,
    required String acao,
    String? pessoaId,
    required DateTime dataEfetiva,
    required int versao,
    String? justificativa,
  });
}

bool _correspondeVinculo(ItemVinculo item, String termo) {
  final alvo = normalizarBusca(termo).trim();
  if (alvo.isEmpty) return true;
  if (normalizarBusca(item.rotulo).contains(alvo)) return true;
  return (item.codigo ?? '').contains(termo.trim());
}

List<ItemVinculo> filtrarVinculos(List<ItemVinculo> itens, String termo) =>
    itens
        .where((item) => _correspondeVinculo(item, termo))
        .toList(growable: false);

class FirebaseVinculosGateway implements VinculosGateway {
  FirebaseVinculosGateway(this._functions);

  final FirebaseFunctions _functions;
  late final FirebasePessoasGateway _pessoas = FirebasePessoasGateway(
    _functions,
  );

  @override
  Future<VinculosResposta> consultar({String? termo}) async {
    final payload = <String, dynamic>{};
    if (termo != null && termo.trim().isNotEmpty) {
      payload['termo'] = termo.trim();
    }
    final resposta = await _functions
        .httpsCallable('consultarVinculos')
        .call(payload);
    final dados = (resposta.data as Map).cast<String, dynamic>();
    return VinculosResposta(
      igrejas: mapearListaVinculos(dados['igrejas']),
      equipes: mapearListaVinculos(dados['equipes']),
    );
  }

  @override
  Future<List<PessoaAdministrativa>> buscarPessoas({String? termo}) async {
    final resposta = await _pessoas.consultar(termo: termo);
    return resposta.pessoas;
  }

  @override
  Future<VinculoResultado> gerenciar({
    required String commandId,
    required String tipoEntidade,
    required String entidadeId,
    required String acao,
    String? pessoaId,
    required DateTime dataEfetiva,
    required int versao,
    String? justificativa,
  }) async {
    final payload = montarPayloadVinculo(
      commandId: commandId,
      tipoEntidade: tipoEntidade,
      entidadeId: entidadeId,
      acao: acao,
      pessoaId: pessoaId,
      dataEfetiva: dataEfetiva,
      versao: versao,
      justificativa: justificativa,
    );
    final resposta = await _functions
        .httpsCallable('gerenciarVinculo')
        .call(payload);
    final dados = (resposta.data as Map).cast<String, dynamic>();
    return VinculoResultado(
      vinculoId: dados['vinculoId'] as String?,
      pessoaId: dados['pessoaId'] as String?,
      versaoVinculo: (dados['versaoVinculo'] as num?)?.toInt() ?? 0,
      repetido: dados['repetido'] as bool? ?? false,
    );
  }
}

/// Monta o payload canônico de `gerenciarVinculo`, em `YYYY-MM-DD` (UTC) e com
/// `expectedVersion` explícito; omite pessoas/justificativa vazias.
Map<String, dynamic> montarPayloadVinculo({
  required String commandId,
  required String tipoEntidade,
  required String entidadeId,
  required String acao,
  String? pessoaId,
  required DateTime dataEfetiva,
  required int versao,
  String? justificativa,
}) {
  final payload = <String, dynamic>{
    'commandId': commandId,
    'tipoEntidade': tipoEntidade,
    'entidadeId': entidadeId,
    'acao': acao,
    'dataEfetiva': formatarDataEfetiva(dataEfetiva),
    'expectedVersion': versao,
  };
  if (pessoaId != null && pessoaId.isNotEmpty) payload['pessoaId'] = pessoaId;
  if (justificativa != null && justificativa.trim().isNotEmpty) {
    payload['justificativa'] = justificativa.trim();
  }
  return payload;
}

/// Mapeia a lista de igrejas/equipes devolvida por `consultarVinculos`.
List<ItemVinculo> mapearListaVinculos(dynamic lista) =>
    (lista as List? ?? const [])
        .map((item) => mapearItemVinculo((item as Map).cast<String, dynamic>()))
        .toList(growable: false);

/// Mapeia uma igreja/equipe com responsável vigente e linha do tempo.
ItemVinculo mapearItemVinculo(Map<String, dynamic> dados) {
  final responsavel = (dados['responsavel'] as Map?)?.cast<String, dynamic>();
  return ItemVinculo(
    id: dados['id'] as String? ?? '',
    tipoEntidade: dados['tipoEntidade'] as String? ?? 'IGREJA',
    rotulo: dados['rotulo'] as String? ?? '',
    codigo: dados['codigo'] as String?,
    ativo: dados['ativo'] as bool? ?? false,
    versaoVinculo: (dados['versaoVinculo'] as num?)?.toInt() ?? 0,
    responsavel: responsavel == null
        ? null
        : ResponsavelVigente(
            pessoaId: responsavel['pessoaId'] as String? ?? '',
            nome: responsavel['nome'] as String? ?? '',
          ),
    historico: (dados['historico'] as List? ?? const [])
        .map((item) => mapearEventoVinculo((item as Map).cast<String, dynamic>()))
        .toList(growable: false),
  );
}

/// Mapeia um evento da linha do tempo, normalizando os timestamps em UTC.
EventoHistoricoVinculo mapearEventoVinculo(Map<String, dynamic> dados) =>
    EventoHistoricoVinculo(
      acao: dados['acao'] as String? ?? 'ATRIBUIR',
      papel: dados['papel'] as String? ?? '',
      estado: dados['estado'] as String? ?? 'VIGENTE',
      atorUid: dados['atorUid'] as String? ?? '',
      atorNome: dados['atorNome'] as String? ?? '',
      inicioVigencia: DateTime.tryParse(
        dados['inicioVigencia'] as String? ?? '',
      )?.toUtc(),
      fimVigencia: DateTime.tryParse(
        dados['fimVigencia'] as String? ?? '',
      )?.toUtc(),
      justificativa: dados['justificativa'] as String?,
      encerradoPorUid: dados['encerradoPorUid'] as String?,
    );
