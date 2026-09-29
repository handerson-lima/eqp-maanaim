import 'package:eqp_maanaim/features/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  final dados = {'commandId': 'a' * 32, 'igrejaId': 'igreja-abc'};

  test('sem sessão cria a identidade e chama a callable uma vez', () async {
    final identidade = IdentidadeFake();
    final rascunho = RascunhoFake();
    await AuthService(identidade, rascunho)
        .cadastrar(email: 'novo@x.com', senha: 'segredo123', dados: dados);
    expect(identidade.criadas, 1);
    expect(rascunho.chamadas, 1);
    expect(rascunho.ultimo, dados);
  });

  test('retentativa após falha mantém a identidade e repete só a callable',
      () async {
    final identidade = IdentidadeFake();
    final rascunho = RascunhoFake()..falhar = true;
    final service = AuthService(identidade, rascunho);
    await expectLater(
        service.cadastrar(email: 'novo@x.com', senha: 'segredo123', dados: dados),
        throwsException);
    rascunho.falhar = false;
    await service.cadastrar(email: 'novo@x.com', senha: 'segredo123', dados: dados);
    expect(identidade.criadas, 1);
    expect(rascunho.chamadas, 2);
  });

  test('sessão de outra conta não recebe os dados desta inscrição', () async {
    final identidade = IdentidadeFake(email: 'outro@x.com');
    final rascunho = RascunhoFake();
    await AuthService(identidade, rascunho)
        .cadastrar(email: 'novo@x.com', senha: 'segredo123', dados: dados);
    expect(identidade.criadas, 1);
    expect(identidade.emailAtual, 'novo@x.com');
    expect(rascunho.chamadas, 1);
  });

  test('recuperação dispara a redefinição sem revelar existência', () async {
    final identidade = IdentidadeFake();
    await AuthService(identidade, RascunhoFake()).recuperar('talvez@x.com');
    expect(identidade.redefinicoes, 1);
  });
}
