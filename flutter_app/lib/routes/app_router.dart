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

  /// Parâmetros de filtro permitidos em URL (allowlist). Qualquer outro é
  /// descartado para não trafegar PII, tokens ou dados sensíveis (AD-12).
  static const Set<String> parametrosSeguros = {'igrejaid', 'equipeid', 'ano'};

  /// Sanitiza e valida rotas para garantir que nenhuma PII, CPF, token ou URL assinada
  /// trafegue na URL do navegador web (AD-12).
  static String sanitizarRota(String? caminhoCompleto) {
    if (caminhoCompleto == null || caminhoCompleto.isEmpty) return inicio;
    final uri = Uri.tryParse(caminhoCompleto);
    if (uri == null) return inicio;

    var caminho = uri.path;
    var parametros = uri.queryParameters;

    // Flutter Web (hash strategy): rota e query vivem no fragmento (/#/rota?...).
    if ((caminho.isEmpty || caminho == '/') && uri.fragment.isNotEmpty) {
      final fragmento = Uri.tryParse(uri.fragment);
      if (fragmento != null) {
        if (fragmento.path.isNotEmpty) caminho = fragmento.path;
        if (fragmento.queryParameters.isNotEmpty) {
          parametros = fragmento.queryParameters;
        }
      }
    }

    if (caminho.isEmpty) caminho = raiz;

    // Allowlist: só parâmetros de filtro conhecidos sobrevivem.
    final seguros = <String, String>{
      for (final entrada in parametros.entries)
        if (parametrosSeguros.contains(entrada.key.toLowerCase()))
          entrada.key: entrada.value,
    };

    if (seguros.isEmpty) return caminho;
    return Uri(path: caminho, queryParameters: seguros).toString();
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
        // Renovação é jornada do voluntário: disponível a qualquer usuário
        // autenticado (decisão de revisão 2026-10-09).
        return RotaAutorizada(caminho: caminho, parametros: uri.queryParameters);

      default:
        return RotaNaoAutorizada(
          caminho: caminho,
          capacidadeFaltante: 'uma rota válida',
        );
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
