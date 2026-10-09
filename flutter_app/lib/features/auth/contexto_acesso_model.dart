import 'package:flutter/foundation.dart';

/// Capacidades canônicas de acesso reconhecidas pela aplicação e autorizadas no backend.
enum CapacidadeAcesso {
  voluntario,
  pastorLocal,
  responsavelEquipe,
  coordenador,
  administrador;

  static CapacidadeAcesso? fromString(String valor) {
    switch (valor.trim().toLowerCase()) {
      case 'voluntario':
        return CapacidadeAcesso.voluntario;
      case 'pastor_local':
      case 'pastorlocal':
        return CapacidadeAcesso.pastorLocal;
      case 'responsavel_equipe':
      case 'responsavelequipe':
        return CapacidadeAcesso.responsavelEquipe;
      case 'coordenador':
        return CapacidadeAcesso.coordenador;
      case 'administrador':
      case 'admin':
        return CapacidadeAcesso.administrador;
      default:
        return null;
    }
  }

  String get chave {
    switch (this) {
      case CapacidadeAcesso.voluntario:
        return 'voluntario';
      case CapacidadeAcesso.pastorLocal:
        return 'pastor_local';
      case CapacidadeAcesso.responsavelEquipe:
        return 'responsavel_equipe';
      case CapacidadeAcesso.coordenador:
        return 'coordenador';
      case CapacidadeAcesso.administrador:
        return 'administrador';
    }
  }

  String get rotuloExibicao {
    switch (this) {
      case CapacidadeAcesso.voluntario:
        return 'Voluntário';
      case CapacidadeAcesso.pastorLocal:
        return 'Pastor Local';
      case CapacidadeAcesso.responsavelEquipe:
        return 'Responsável de Equipe';
      case CapacidadeAcesso.coordenador:
        return 'Coordenador Geral';
      case CapacidadeAcesso.administrador:
        return 'Administrador';
    }
  }
}

/// Escopo mínimo de igreja vinculada sob pastoreio.
@immutable
class EscopoIgreja {
  const EscopoIgreja({
    required this.id,
    required this.nome,
    this.codigo,
  });

  final String id;
  final String nome;
  final String? codigo;

  factory EscopoIgreja.fromJson(Map<String, dynamic> json) {
    return EscopoIgreja(
      id: (json['id'] ?? '').toString(),
      nome: (json['nome'] ?? json['id'] ?? '').toString(),
      codigo: json['codigo']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    if (codigo != null) 'codigo': codigo,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EscopoIgreja && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Escopo mínimo de equipe vinculada sob responsabilidade.
@immutable
class EscopoEquipe {
  const EscopoEquipe({
    required this.id,
    required this.nome,
  });

  final String id;
  final String nome;

  factory EscopoEquipe.fromJson(Map<String, dynamic> json) {
    return EscopoEquipe(
      id: (json['id'] ?? '').toString(),
      nome: (json['nome'] ?? json['id'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EscopoEquipe && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Contexto de acesso imutável e seguro derivado exclusivamente pelo backend (Story 8.3).
@immutable
class ContextoAcesso {
  const ContextoAcesso({
    required this.uid,
    this.email,
    required this.capacidades,
    required this.ehAdministrador,
    required this.ehCoordenador,
    required this.ehPastorLocal,
    required this.ehResponsavelEquipe,
    required this.ehVoluntario,
    required this.igrejas,
    required this.equipes,
    this.estadoFicha,
  });

  final String uid;
  final String? email;
  final Set<CapacidadeAcesso> capacidades;
  final bool ehAdministrador;
  final bool ehCoordenador;
  final bool ehPastorLocal;
  final bool ehResponsavelEquipe;
  final bool ehVoluntario;
  final List<EscopoIgreja> igrejas;
  final List<EscopoEquipe> equipes;
  final String? estadoFicha;

  /// Cria um contexto vazio/anônimo padrão para estados sem autenticação.
  factory ContextoAcesso.vazio() => const ContextoAcesso(
    uid: '',
    capacidades: {},
    ehAdministrador: false,
    ehCoordenador: false,
    ehPastorLocal: false,
    ehResponsavelEquipe: false,
    ehVoluntario: false,
    igrejas: [],
    equipes: [],
  );

  /// Desserializa o payload retornado da callable `obterContextoAcesso`.
  factory ContextoAcesso.fromJson(Map<String, dynamic> json) {
    final rawCaps = json['capacidades'];
    final caps = <CapacidadeAcesso>{};

    if (rawCaps is List) {
      for (final item in rawCaps) {
        if (item is String) {
          final parsed = CapacidadeAcesso.fromString(item);
          if (parsed != null) caps.add(parsed);
        }
      }
    }

    final rawIgrejas = json['igrejas'];
    final listaIgrejas = <EscopoIgreja>[];
    if (rawIgrejas is List) {
      for (final item in rawIgrejas) {
        if (item is Map) {
          listaIgrejas.add(EscopoIgreja.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    final rawEquipes = json['equipes'];
    final listaEquipes = <EscopoEquipe>[];
    if (rawEquipes is List) {
      for (final item in rawEquipes) {
        if (item is Map) {
          listaEquipes.add(EscopoEquipe.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    final admin = json['ehAdministrador'] == true || caps.contains(CapacidadeAcesso.administrador);
    final coord = json['ehCoordenador'] == true || caps.contains(CapacidadeAcesso.coordenador);
    final pastor = json['ehPastorLocal'] == true ||
        caps.contains(CapacidadeAcesso.pastorLocal) ||
        listaIgrejas.isNotEmpty;
    final responsavel = json['ehResponsavelEquipe'] == true ||
        caps.contains(CapacidadeAcesso.responsavelEquipe) ||
        listaEquipes.isNotEmpty;
    final voluntario = json['ehVoluntario'] == true ||
        caps.contains(CapacidadeAcesso.voluntario) ||
        (!admin && !coord && !pastor && !responsavel);

    return ContextoAcesso(
      uid: (json['uid'] ?? '').toString(),
      email: json['email']?.toString(),
      capacidades: {
        if (voluntario) CapacidadeAcesso.voluntario,
        if (pastor) CapacidadeAcesso.pastorLocal,
        if (responsavel) CapacidadeAcesso.responsavelEquipe,
        if (coord) CapacidadeAcesso.coordenador,
        if (admin) CapacidadeAcesso.administrador,
      },
      ehAdministrador: admin,
      ehCoordenador: coord,
      ehPastorLocal: pastor,
      ehResponsavelEquipe: responsavel,
      ehVoluntario: voluntario,
      igrejas: List.unmodifiable(listaIgrejas),
      equipes: List.unmodifiable(listaEquipes),
      estadoFicha: json['estadoFicha']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    if (email != null) 'email': email,
    'capacidades': capacidades.map((c) => c.chave).toList(),
    'ehAdministrador': ehAdministrador,
    'ehCoordenador': ehCoordenador,
    'ehPastorLocal': ehPastorLocal,
    'ehResponsavelEquipe': ehResponsavelEquipe,
    'ehVoluntario': ehVoluntario,
    'igrejas': igrejas.map((i) => i.toJson()).toList(),
    'equipes': equipes.map((e) => e.toJson()).toList(),
    if (estadoFicha != null) 'estadoFicha': estadoFicha,
  };

  /// Verifica se o usuário possui a capacidade informada.
  bool temCapacidade(CapacidadeAcesso capacidade) => capacidades.contains(capacidade);

  /// Verifica se o usuário tem múltiplos papéis ativos (ex.: pastor + responsável).
  bool get temMultiplosDestinos {
    int count = 0;
    if (ehPastorLocal) count++;
    if (ehResponsavelEquipe) count++;
    if (ehCoordenador) count++;
    if (ehAdministrador) count++;
    return count > 1;
  }

  /// Retorna as capacidades de liderança/serviço além de voluntário simples.
  List<CapacidadeAcesso> get capacidadesAtivas {
    return capacidades.toList();
  }
}
