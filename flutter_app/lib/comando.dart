import 'dart:math';

/// Identificador opaco usado como `commandId` idempotente.
String comandoOpaco() {
  final r = Random.secure();
  return List<int>.generate(16, (_) => r.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}
