import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utilitário canônico de formatação, mascaramento, validação e acessibilidade
/// para Cadastro de Pessoas Físicas (CPF) no Design System do Maanaim.
///
/// Atende às diretrizes de conformidade com WCAG 2.2 AA (Critérios 1.3.1 e 4.1.2)
/// para que leitores de tela não soletrem pontuações sonoras ("ponto", "hífen")
/// nem leiam o CPF como um número ordinal/cardinal de 11 dígitos.
abstract final class CpfFormatter {
  /// Extrai exclusivamente os dígitos numéricos de uma string ou retorna vazio.
  static String apenasDigitos(String? valor) {
    if (valor == null || valor.isEmpty) return '';
    return valor.replaceAll(RegExp(r'\D'), '');
  }

  /// Aplica a máscara canônica visual `000.000.000-00` sobre dígitos brutos ou texto parcial.
  /// Se a string já estiver formatada ou contiver asteriscos de privacidade,
  /// preserva o formato de forma idempotente e segura.
  static String formatar(String? valor) {
    if (valor == null || valor.trim().isEmpty) return '';
    final texto = valor.trim();

    // Se já estiver com asteriscos de mascaramento (LGPD), preserva
    if (texto.contains('*')) {
      return texto;
    }

    final digitos = apenasDigitos(texto);
    if (digitos.isEmpty) return '';

    // Trunca em 11 dígitos caso exceda
    final truncado = digitos.length > 11 ? digitos.substring(0, 11) : digitos;
    final len = truncado.length;

    if (len <= 3) {
      return truncado;
    } else if (len <= 6) {
      return '${truncado.substring(0, 3)}.${truncado.substring(3)}';
    } else if (len <= 9) {
      return '${truncado.substring(0, 3)}.${truncado.substring(3, 6)}.${truncado.substring(6)}';
    } else {
      return '${truncado.substring(0, 3)}.${truncado.substring(3, 6)}.${truncado.substring(6, 9)}-${truncado.substring(9)}';
    }
  }

  /// Aplica máscara de privacidade sobre o CPF.
  ///
  /// - Por padrão (formato início/fim visíveis): `123.***.***-01`
  /// - Com `formatoCentral: true` (formato com dígitos centrais): `***.456.789-**`
  static String mascarar(String? valor, {bool formatoCentral = false}) {
    if (valor == null || valor.trim().isEmpty) return '***.***.***-**';
    final digitos = apenasDigitos(valor);
    if (digitos.length != 11) {
      // Se já contiver máscara ou for parcial, retorna com sanitização básica
      return valor.trim();
    }

    if (formatoCentral) {
      return '***.${digitos.substring(3, 6)}.${digitos.substring(6, 9)}-**';
    }
    return '${digitos.substring(0, 3)}.***.***-${digitos.substring(9, 11)}';
  }

  /// Valida o CPF conforme o algoritmo oficial dos dígitos verificadores (módulo 11).
  static bool validar(String? valor) {
    final cpf = apenasDigitos(valor);
    if (cpf.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) {
      return false;
    }

    int digito(String base, int peso) =>
        (base
                .split('')
                .asMap()
                .entries
                .fold<int>(0, (s, e) => s + int.parse(e.value) * (peso - e.key)) *
            10 %
            11) %
        10;

    return digito(cpf.substring(0, 9), 10) == int.parse(cpf[9]) &&
        digito(cpf.substring(0, 10), 11) == int.parse(cpf[10]);
  }

  /// Gera um rótulo semântico inteligível para sintetizadores de voz / leitores de tela
  /// (TalkBack / VoiceOver) em conformidade com WCAG 2.2 AA.
  ///
  /// Agrupa os dígitos com pausas naturais separadas por vírgula para evitar
  /// a leitura confusa de valores na casa dos bilhões ou a soletração sonora de pontuação.
  static String rotuloAcessivel(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'CPF não informado';
    }
    final texto = valor.trim();

    // Cenário 1: Totalmente mascarado
    if (texto == '***.***.***-**') {
      return 'CPF mascarado por privacidade';
    }

    // Cenário 2: Mascarado central (ex: ***.456.789-**)
    if (texto.startsWith('***.') && texto.endsWith('-**')) {
      final partes = texto.split('.');
      if (partes.length >= 3) {
        final bloco2 = partes[1].split('').join(' ');
        final bloco3 = partes[2].replaceAll('-**', '').split('').join(' ');
        return 'CPF mascarado: dígitos centrais $bloco2, $bloco3';
      }
      return 'CPF com início e final mascarados';
    }

    // Cenário 3: Mascarado nas pontas (ex: 111.***.***-22)
    if (texto.contains('.***.***-')) {
      final partes = texto.split('.***.***-');
      if (partes.length == 2) {
        final inicio = partes[0].split('').join(' ');
        final fim = partes[1].split('').join(' ');
        return 'CPF mascarado: $inicio, dígitos centrais ocultos, final $fim';
      }
    }

    // Cenário 4: CPF regular (completo ou dígitos)
    final digitos = apenasDigitos(texto);
    if (digitos.length == 11) {
      final b1 = digitos.substring(0, 3).split('').join(' ');
      final b2 = digitos.substring(3, 6).split('').join(' ');
      final b3 = digitos.substring(6, 9).split('').join(' ');
      final b4 = digitos.substring(9, 11).split('').join(' ');
      return 'CPF: $b1, $b2, $b3, $b4';
    }

    // Fallback amigável
    return 'CPF: ${digitos.split('').join(' ')}';
  }
}

/// [TextInputFormatter] que formata reativamente a digitação de CPF em tempo real,
/// limitando a 11 dígitos e aplicando a pontuação `000.000.000-00`.
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final novosDigitos = CpfFormatter.apenasDigitos(newValue.text);
    if (novosDigitos.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Trunca em 11 dígitos
    final digitos = novosDigitos.length > 11
        ? novosDigitos.substring(0, 11)
        : novosDigitos;

    final textoFormatado = CpfFormatter.formatar(digitos);

    // Ajusta a posição do cursor (selection offset)
    int cursorOffset = textoFormatado.length;

    // Se o usuário estiver editando no meio e a alteração foi de deleção
    if (newValue.text.length < oldValue.text.length) {
      // Ajuste de deleção
      cursorOffset = newValue.selection.end.clamp(0, textoFormatado.length);
    }

    return TextEditingValue(
      text: textoFormatado,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }
}

/// Widget acessível de exibição de CPF conforme o Design System do Maanaim e WCAG 2.2 AA.
///
/// Encapsula a apresentação visual padronizada (`000.000.000-00` ou formato de privacidade)
/// com anotação semântica [Semantics] dedicada para leitores de tela.
class CpfText extends StatelessWidget {
  const CpfText({
    super.key,
    required this.cpf,
    this.style,
    this.incluirRotuloVisual = false,
    this.destaqueMonospaced = false,
  });

  /// O valor bruto, formatado ou mascarado de CPF.
  final String? cpf;

  /// Estilo de tipografia customizado (opcional).
  final TextStyle? style;

  /// Se verdadeiro, prefixa visualmente o texto com 'CPF: '.
  final bool incluirRotuloVisual;

  /// Se verdadeiro, força a renderização em fonte monoespaçada para alinhamento em tabelas.
  final bool destaqueMonospaced;

  @override
  Widget build(BuildContext context) {
    final valorFormatado = CpfFormatter.formatar(cpf);
    final textoVisual = incluirRotuloVisual
        ? 'CPF: $valorFormatado'
        : valorFormatado;

    final rotuloSemantico = CpfFormatter.rotuloAcessivel(cpf);

    TextStyle estiloFinal = style ?? DefaultTextStyle.of(context).style;
    if (destaqueMonospaced) {
      estiloFinal = estiloFinal.copyWith(fontFamily: 'monospace');
    }

    return Semantics(
      label: rotuloSemantico,
      excludeSemantics: true,
      child: Text(
        textoVisual,
        style: estiloFinal,
      ),
    );
  }
}
