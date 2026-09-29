import 'package:eqp_maanaim/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('comandoOpaco segue o contrato do commandId e não repete', () {
    final a = comandoOpaco();
    final b = comandoOpaco();
    final contrato = RegExp(r'^[A-Za-z0-9_-]{16,128}$');
    expect(a, matches(contrato));
    expect(b, matches(contrato));
    expect(a, isNot(b));
  });
}
