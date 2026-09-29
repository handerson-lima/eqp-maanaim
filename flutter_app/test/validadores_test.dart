import 'package:eqp_maanaim/features/auth/validadores.dart';
import 'package:eqp_maanaim/features/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valida campos obrigatórios sem expor valores', () {
    expect(emailValido('invalido'), isNotNull);
    expect(senhaValida('123'), isNotNull);
    expect(cpfValido('529.982.247-25'), isNull);
  });
  test('a recuperação sempre usa resposta neutra', () {
    expect(AuthService.mensagemRecuperacaoNeutra, contains('Se houver'));
    expect(AuthService.mensagemRecuperacaoNeutra.toLowerCase(),
        isNot(contains('não existe')));
  });
  test('uma sessão de outro e-mail não recebe os dados desta inscrição', () {
    expect(AuthService.precisaCriarIdentidade(null, 'a@b.com'), isTrue);
    expect(AuthService.precisaCriarIdentidade('a@b.com', 'a@b.com'), isFalse);
    expect(AuthService.precisaCriarIdentidade('outro@x.com', 'a@b.com'), isTrue);
  });
}
