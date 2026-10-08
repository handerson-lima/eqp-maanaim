import 'package:flutter/material.dart';

import '../tokens.dart';

/// Componente canônico para exibição da Logo Oficial do Maanaim (Natal - RN).
class LogoMaanaim extends StatelessWidget {
  const LogoMaanaim({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.comFundoBranco = false,
    this.transparente = true,
  });

  /// Variante para o Painel Institucional de Login (área escura navy-900).
  /// Exibe a logo com fundo branco arredondado e sombra suave para máximo destaque.
  factory LogoMaanaim.painel({Key? key, double width = 220}) {
    return LogoMaanaim(
      key: key,
      width: width,
      comFundoBranco: true,
      transparente: false,
    );
  }

  /// Variante para o cabeçalho da Sidebar Institucional Desktop e Drawer.
  factory LogoMaanaim.sidebar({Key? key, double height = 36}) {
    return LogoMaanaim(
      key: key,
      height: height,
      comFundoBranco: true,
      transparente: false,
    );
  }

  /// Variante para o cabeçalho compactado de tablet (ícone quadrado com logo).
  factory LogoMaanaim.compacta({Key? key, double size = 36}) {
    return LogoMaanaim(
      key: key,
      width: size,
      height: size,
      comFundoBranco: true,
      transparente: false,
    );
  }

  /// Variante direta com fundo transparente para superfícies claras (como TopBar).
  factory LogoMaanaim.topBar({Key? key, double height = 32}) {
    return LogoMaanaim(
      key: key,
      height: height,
      comFundoBranco: false,
      transparente: true,
    );
  }

  final double? width;
  final double? height;
  final BoxFit fit;
  final bool comFundoBranco;
  final bool transparente;

  @override
  Widget build(BuildContext context) {
    final assetPath = transparente
        ? 'assets/images/logo_maanaim_transparente.png'
        : 'assets/images/logo_maanaim.png';

    final imagem = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Fallback resiliente para testes ou indisponibilidade de assets
        return Icon(
          Icons.church_outlined,
          color: comFundoBranco ? AppColors.blue600 : Colors.white,
          size: height ?? width ?? 32,
        );
      },
    );

    if (comFundoBranco) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: imagem,
      );
    }

    return imagem;
  }
}
