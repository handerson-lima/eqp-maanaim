String? obrigatorio(String? valor, String rotulo) {
  if (valor == null || valor.trim().isEmpty) return '$rotulo é obrigatório.';
  return null;
}

String? emailValido(String? valor) {
  if (obrigatorio(valor, 'E-mail') != null) return 'E-mail é obrigatório.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(valor!.trim())) {
    return 'Informe um e-mail válido.';
  }
  return null;
}

String? senhaValida(String? valor) {
  if (obrigatorio(valor, 'Senha') != null) return 'Senha é obrigatória.';
  if (valor!.length < 8) return 'Use pelo menos 8 caracteres na senha.';
  return null;
}

String? cpfValido(String? valor) {
  final cpf = (valor ?? '').replaceAll(RegExp(r'\D'), '');
  if (cpf.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) {
    return 'Informe um CPF válido.';
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
  return (digito(cpf.substring(0, 9), 10) == int.parse(cpf[9]) &&
          digito(cpf.substring(0, 10), 11) == int.parse(cpf[10]))
      ? null
      : 'Informe um CPF válido.';
}
