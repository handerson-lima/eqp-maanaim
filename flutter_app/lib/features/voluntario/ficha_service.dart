import 'package:cloud_functions/cloud_functions.dart';
import '../auth/validadores.dart';

/// Modelo representativo do aceite eletrônico registrado para a ficha.
class TermoAceitoModel {
  const TermoAceitoModel({
    required this.termoId,
    required this.versaoId,
    required this.numeroVersao,
    required this.hashSha256,
    this.titulo,
    required this.aceitoEm,
    required this.commandId,
  });

  final String termoId;
  final String versaoId;
  final int numeroVersao;
  final String hashSha256;
  final String? titulo;
  final String aceitoEm;
  final String commandId;

  factory TermoAceitoModel.fromMap(Map<String, dynamic> map) {
    return TermoAceitoModel(
      termoId: map['termoId'] as String? ?? '',
      versaoId: map['versaoId'] as String? ?? '',
      numeroVersao: (map['numeroVersao'] as num?)?.toInt() ?? 1,
      hashSha256: map['hashSha256'] as String? ?? '',
      titulo: map['titulo'] as String?,
      aceitoEm: map['aceitoEm'] as String? ?? '',
      commandId: map['commandId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'termoId': termoId,
        'versaoId': versaoId,
        'numeroVersao': numeroVersao,
        'hashSha256': hashSha256,
        if (titulo != null) 'titulo': titulo,
        'aceitoEm': aceitoEm,
        'commandId': commandId,
      };
}

/// Modelo de dados da ficha permanente do voluntário.
class FichaModel {
  const FichaModel({
    required this.id,
    required this.nomeCompleto,
    required this.profissao,
    required this.cpf,
    required this.igrejaId,
    required this.estado,
    required this.versao,
    this.termoAceito,
    this.atualizadoEm,
  });

  final String id;
  final String nomeCompleto;
  final String profissao;
  final String cpf;
  final String igrejaId;
  final String estado;
  final int versao;
  final TermoAceitoModel? termoAceito;
  final String? atualizadoEm;

  bool get isRascunho => estado == 'RASCUNHO';

  factory FichaModel.fromMap(Map<String, dynamic> map) {
    final termoAceitoRaw = map['termoAceito'];
    final termoAceito = termoAceitoRaw is Map
        ? TermoAceitoModel.fromMap(Map<String, dynamic>.from(termoAceitoRaw))
        : null;

    return FichaModel(
      id: map['id'] as String? ?? '',
      nomeCompleto: map['nomeCompleto'] as String? ?? '',
      profissao: map['profissao'] as String? ?? '',
      cpf: map['cpf'] as String? ?? '',
      igrejaId: map['igrejaId'] as String? ?? '',
      estado: map['estado'] as String? ?? 'RASCUNHO',
      versao: (map['versao'] as num?)?.toInt() ?? 1,
      termoAceito: termoAceito,
      atualizadoEm: map['atualizadoEm'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nomeCompleto': nomeCompleto,
        'profissao': profissao,
        'cpf': cpf,
        'igrejaId': igrejaId,
        'estado': estado,
        'versao': versao,
        if (termoAceito != null) 'termoAceito': termoAceito!.toMap(),
        if (atualizadoEm != null) 'atualizadoEm': atualizadoEm,
      };

  FichaModel copyWith({
    String? id,
    String? nomeCompleto,
    String? profissao,
    String? cpf,
    String? igrejaId,
    String? estado,
    int? versao,
    TermoAceitoModel? termoAceito,
    String? atualizadoEm,
  }) {
    return FichaModel(
      id: id ?? this.id,
      nomeCompleto: nomeCompleto ?? this.nomeCompleto,
      profissao: profissao ?? this.profissao,
      cpf: cpf ?? this.cpf,
      igrejaId: igrejaId ?? this.igrejaId,
      estado: estado ?? this.estado,
      versao: versao ?? this.versao,
      termoAceito: termoAceito ?? this.termoAceito,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }
}

class ObterFichaResposta {
  const ObterFichaResposta({required this.existe, this.ficha});

  final bool existe;
  final FichaModel? ficha;
}

class SalvarFichaEntrada {
  const SalvarFichaEntrada({
    required this.commandId,
    required this.nomeCompleto,
    required this.profissao,
    required this.cpf,
    required this.igrejaId,
    this.expectedVersion,
  });

  final String commandId;
  final String nomeCompleto;
  final String profissao;
  final String cpf;
  final String igrejaId;
  final int? expectedVersion;

  Map<String, dynamic> toMap() => {
        'commandId': commandId,
        'nomeCompleto': nomeCompleto.trim(),
        'profissao': profissao.trim(),
        'cpf': cpf.trim(),
        'igrejaId': igrejaId.trim(),
        if (expectedVersion != null) 'expectedVersion': expectedVersion,
      };
}

class SalvarFichaResposta {
  const SalvarFichaResposta({
    required this.sucesso,
    required this.repetido,
    required this.ficha,
  });

  final bool sucesso;
  final bool repetido;
  final FichaModel ficha;
}

class EnviarFichaResposta {
  const EnviarFichaResposta({
    required this.sucesso,
    required this.repetido,
    required this.estado,
    required this.versao,
    required this.proximaAcao,
    required this.igrejaId,
    required this.enviadoEm,
  });

  final bool sucesso;
  final bool repetido;
  final String estado;
  final int versao;
  final String proximaAcao;
  final String igrejaId;
  final String enviadoEm;
}

/// Contrato para comunicação com o backend de ficha permanente.
abstract interface class FichaGateway {
  Future<ObterFichaResposta> obterMinhaFicha();
  Future<SalvarFichaResposta> salvarMinhaFicha(SalvarFichaEntrada entrada);
  Future<EnviarFichaResposta> enviarFichaAprovacao({
    required String commandId,
    int? expectedVersion,
  });
}

/// Implementação Firebase Cloud Functions do gateway da ficha.
class FirebaseFichaGateway implements FichaGateway {
  FirebaseFichaGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<ObterFichaResposta> obterMinhaFicha() async {
    final resposta = await _functions.httpsCallable('obterMinhaFicha').call();
    final dados = (resposta.data as Map).cast<String, dynamic>();
    final existe = dados['existe'] as bool? ?? false;
    if (!existe || dados['ficha'] == null) {
      return const ObterFichaResposta(existe: false);
    }
    return ObterFichaResposta(
      existe: true,
      ficha: FichaModel.fromMap((dados['ficha'] as Map).cast<String, dynamic>()),
    );
  }

  @override
  Future<SalvarFichaResposta> salvarMinhaFicha(SalvarFichaEntrada entrada) async {
    final resposta = await _functions
        .httpsCallable('salvarMinhaFicha')
        .call(entrada.toMap());
    final dados = (resposta.data as Map).cast<String, dynamic>();
    return SalvarFichaResposta(
      sucesso: dados['sucesso'] as bool? ?? true,
      repetido: dados['repetido'] as bool? ?? false,
      ficha: FichaModel.fromMap((dados['ficha'] as Map).cast<String, dynamic>()),
    );
  }

  @override
  Future<EnviarFichaResposta> enviarFichaAprovacao({
    required String commandId,
    int? expectedVersion,
  }) async {
    final resposta = await _functions.httpsCallable('enviarFichaAprovacao').call({
      'commandId': commandId,
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
    });
    final dados = (resposta.data as Map).cast<String, dynamic>();
    return EnviarFichaResposta(
      sucesso: dados['sucesso'] as bool? ?? true,
      repetido: dados['repetido'] as bool? ?? false,
      estado: dados['estado'] as String? ?? 'AGUARDANDO_PASTOR_LOCAL',
      versao: (dados['versao'] as num?)?.toInt() ?? 1,
      proximaAcao: dados['proximaAcao'] as String? ?? 'Aguardando avaliação do Pastor Local',
      igrejaId: dados['igrejaId'] as String? ?? '',
      enviadoEm: dados['enviadoEm'] as String? ?? '',
    );
  }
}

/// Calcula campos obrigatórios pendentes para preenchimento da ficha permanente.
List<String> calcularPendenciasFicha({
  required String nomeCompleto,
  required String profissao,
  required String cpf,
  required String igrejaId,
}) {
  final pendencias = <String>[];

  if (nomeCompleto.trim().length < 3) {
    pendencias.add('Nome Completo (mínimo 3 caracteres)');
  }
  if (profissao.trim().length < 2) {
    pendencias.add('Profissão (mínimo 2 caracteres)');
  }
  if (cpfValido(cpf) != null) {
    pendencias.add('CPF válido');
  }
  if (igrejaId.trim().isEmpty) {
    pendencias.add('Igreja Local');
  }

  return pendencias;
}
