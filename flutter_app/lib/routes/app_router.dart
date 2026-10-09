import 'package:flutter/material.dart';
import '../features/auth/acesso_negado_screen.dart';
import '../features/auth/contexto_acesso_model.dart';

/// Rotas canônicas e declarativas do sistema Maanaim (Story 8.3).
abstract final class AppRotas {
  static const String raiz = '/';
  static const String inicio = '/inicio';
  static const String minhaFicha = '/minha-ficha';
  static const String pastor = '/pastor';
  static const String equipe = '/equipe';
  static const String coordenador = '/coordenador';
  static const String admin = '/admin';
  static const String renovacao = '/renovacao';
  static const String perfil = '/perfil';
  static const String destinos = '/destinos';
  static const String acessoNegado = '/acesso-negado';

  /// Sanitiza e valida rotas para garantir que nenhuma PII, CPF, token ou URL assinada
  /// trafegue na URL do navegador web (AD-12).
  static String sanitizarRota(String? caminhoCompleto) {
    if (caminhoCompleto == null || caminhoCompleto.isEmpty) return inicio;
    final uri = Uri.tryParse(caminhoCompleto);
    if (uri == null) return inicio;

    // Remove qualquer parâmetro que possa conter PII ou tokens
    final parametrosLimpos = Map<String, String>.from(uri.queryParameters);
    parametrosLimpos.removeWhere((chave, valor) {
      final k = chave.toLowerCase();
      return k.contains('token') ||
          k.contains('cpf') ||
          k.contains('email') ||
          k.contains('senha') ||
          k.contains('signature') ||
          valor.contains('token=') ||
          valor.length > 120;
    });

    final novoUri = uri.replace(queryParameters: parametrosLimpos.isEmpty ? null : parametrosLimpos);
    return novoUri.toString();
  }
}

/// Resultado da avaliação do guarda de rota por capacidades.
sealed class ResultadoGuardaRota {
  const ResultadoGuardaRota();
}

class RotaAutorizada extends ResultadoGuardaRota {
  const RotaAutorizada({required this.caminho, this.parametros = const {}});
  final String caminho;
  final Map<String, String> parametros;
}

class RotaNaoAutorizada extends ResultadoGuardaRota {
  const RotaNaoAutorizada({
    required this.caminho,
    required this.capacidadeFaltante,
  });
  final String caminho;
  final String capacidadeFaltante;
}

/// Guarda de rotas declarativas baseado em capacidades e autoridade do servidor.
class AppRouteGuard {
  const AppRouteGuard();

  ResultadoGuardaRota avaliar(String rotaSolicitada, ContextoAcesso contexto) {
    final uri = Uri.parse(AppRotas.sanitizarRota(rotaSolicitada));
    final caminho = uri.path.isEmpty ? AppRotas.raiz : uri.path;

    switch (caminho) {
      case AppRotas.raiz:
      case AppRotas.inicio:
      case AppRotas.minhaFicha:
      case AppRotas.perfil:
      case AppRotas.destinos:
        // Rotas acessíveis a qualquer usuário autenticado (voluntário)
        return RotaAutorizada(caminho: caminho, parametros: uri.queryParameters);

      case AppRotas.pastor:
        if (contexto.ehPastorLocal || contexto.ehAdministrador) {
          return RotaAutorizada(caminho: caminho, parametros: uri.queryParameters);
        }
        return const RotaNaoAutorizada(
          caminho: AppRotas.pastor,
          capacidadeFaltante: 'Pastor Local',
        );

      case AppRotas.equipe:
        if (contexto.ehResponsavelEquipe || contexto.ehAdministrador) {
          return RotaAutorizada(caminho: caminho, parametros: uri.queryParameters);
        }
        return const RotaNaoAutorizada(
          caminho: AppRotas.equipe,
          capacidadeFaltante: 'Responsável de Equipe',
        );

      case AppRotas.coordenador:
        if (contexto.ehCoordenador || contexto.ehAdministrador) {
          return RotaAutorizada(caminho: caminho, parametros: uri.queryParameters);
        }
        return const RotaNaoAutorizada(
          caminho: AppRotas.coordenador,
          capacidadeFaltante: 'Coordenador Geral',
        );

      case AppRotas.admin:
        if (contexto.ehAdministrador) {
          return RotaAutorizada(caminho: caminho, parametros: uri.queryParameters);
        }
        return const RotaNaoAutorizada(
          caminho: AppRotas.admin,
          capacidadeFaltante: 'Administrador',
        );

      case AppRotas.renovacao:
        if (contexto.ehPastorLocal ||
            contexto.ehResponsavelEquipe ||
            contexto.ehCoordenador ||
            contexto.ehAdministrador ||
            contexto.ehVoluntario) {
          return RotaAutorizada(caminho: caminho, parametros: uri.queryParameters);
        }
        return const RotaNaoAutorizada(
          caminho: AppRotas.renovacao,
          capacidadeFaltante: 'Vínculo com ciclo de renovação',
        );

      default:
        return RotaAutorizada(caminho: caminho, parametros: uri.queryParameters);
    }
  }

  /// Retorna a tela de erro 403 apropriada em caso de acesso negado.
  Widget construirTelaAcessoNegado({
    required String capacidadeFaltante,
    VoidCallback? onVoltar,
    VoidCallback? onSair,
  }) {
    return AcessoNegadoScreen(
      capacidadeNecessaria: capacidadeFaltante,
      onVoltar: onVoltar,
      onSair: onSair,
    );
  }
}
