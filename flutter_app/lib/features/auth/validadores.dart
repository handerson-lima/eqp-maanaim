import '../../ui/components/cpf_formatter.dart';

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
  return CpfFormatter.validar(valor) ? null : 'Informe um CPF válido.';
}

