import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';

/// Exceção lançada quando a foto selecionada excede o limite permitido (2 MB).
class FotoMuitoGrandeException implements Exception {
  final int tamanhoBytes;
  const FotoMuitoGrandeException(this.tamanhoBytes);

  @override
  String toString() => 'A imagem excede o tamanho máximo de 2 MB.';
}

/// Utilitário canônico de máscara e formatação para telefone brasileiro.
abstract final class TelefoneFormatter {
  static String apenasDigitos(String? valor) {
    if (valor == null || valor.isEmpty) return '';
    return valor.replaceAll(RegExp(r'\D'), '');
  }

  static String formatar(String? valor) {
    if (valor == null || valor.trim().isEmpty) return '';
    final digitos = apenasDigitos(valor.trim());
    if (digitos.isEmpty) return '';

    final truncado = digitos.length > 11 ? digitos.substring(0, 11) : digitos;
    final len = truncado.length;

    if (len <= 2) {
      return '($truncado';
    } else if (len <= 6) {
      return '(${truncado.substring(0, 2)}) ${truncado.substring(2)}';
    } else if (len <= 10) {
      // Formato fixo: (XX) XXXX-XXXX
      return '(${truncado.substring(0, 2)}) ${truncado.substring(2, 6)}-${truncado.substring(6)}';
    } else {
      // Formato celular: (XX) XXXXX-XXXX
      return '(${truncado.substring(0, 2)}) ${truncado.substring(2, 7)}-${truncado.substring(7)}';
    }
  }
}

/// Formatter interativo de texto para campos de telefone.
class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = newValue.text;
    final formatado = TelefoneFormatter.formatar(texto);

    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }
}

/// Modelo de dados representativo do perfil do usuário.
class PerfilUsuario {
  const PerfilUsuario({
    required this.uid,
    required this.nome,
    required this.email,
    required this.telefone,
    this.fotoUrl,
  });

  final String uid;
  final String nome;
  final String email;
  final String telefone;
  final String? fotoUrl;

  PerfilUsuario copyWith({
    String? nome,
    String? email,
    String? telefone,
    String? fotoUrl,
  }) {
    return PerfilUsuario(
      uid: uid,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      telefone: telefone ?? this.telefone,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }
}

/// Interface do gateway para abstração de testes do serviço de perfil.
abstract interface class IPerfilService {
  Future<PerfilUsuario> obterPerfil();
  Future<String> atualizarFoto({
    required Uint8List bytes,
    required String extensao,
  });
  Future<void> atualizarTelefone(String telefone);
  Future<void> solicitarTrocaEmail(String novoEmail);
  Future<void> reautenticarEAtualizarEmail({
    required String senhaAtual,
    required String novoEmail,
  });
}

/// Implementação padrão integrada com Firebase Auth, Storage e Cloud Functions.
class PerfilService implements IPerfilService {
  PerfilService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? _obterStorageSeguro(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  static FirebaseStorage _obterStorageSeguro() {
    try {
      final app = Firebase.app();
      final bucket = app.options.storageBucket;
      if (bucket != null && bucket.isNotEmpty) {
        return FirebaseStorage.instanceFor(app: app, bucket: bucket);
      }
      return FirebaseStorage.instanceFor(bucket: 'eqp-maanaim.firebasestorage.app');
    } catch (_) {
      try {
        return FirebaseStorage.instanceFor(bucket: 'eqp-maanaim.firebasestorage.app');
      } catch (_) {
        return FirebaseStorage.instance;
      }
    }
  }

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  static const int limiteMaximoBytes = 2 * 1024 * 1024; // 2 MB

  User? get _currentUser => _auth.currentUser;

  @override
  Future<PerfilUsuario> obterPerfil() async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('Nenhum usuário autenticado.');
    }

    String nome = (user.displayName ?? '').trim();
    String telefone = '';
    String? fotoUrl = user.photoURL;

    // Se o nome não estiver no Auth ou for "Voluntário", busca a Ficha oficial
    if (nome.isEmpty || nome.toLowerCase() == 'voluntário') {
      try {
        final callable = _functions.httpsCallable('obterMinhaFicha');
        final res = await callable.call().timeout(const Duration(seconds: 8));
        final dados = (res.data as Map?)?.cast<String, dynamic>();
        if (dados != null && dados['existe'] == true && dados['ficha'] != null) {
          final fichaMap = (dados['ficha'] as Map).cast<String, dynamic>();
          final nomeFicha = fichaMap['nomeCompleto'] as String?;
          if (nomeFicha != null && nomeFicha.trim().isNotEmpty) {
            nome = nomeFicha.trim();
            user.updateDisplayName(nome).catchError((_) {});
          }
          final telFicha = fichaMap['telefone'] as String?;
          if (telFicha != null && telFicha.trim().isNotEmpty) {
            telefone = telFicha.trim();
          }
          final fotoFicha = fichaMap['fotoUrl'] as String?;
          if (fotoFicha != null && fotoFicha.trim().isNotEmpty) {
            fotoUrl = fotoFicha.trim();
          }
        }
      } catch (_) {
        // Fallback silencioso se a function falhar
      }
    }

    if (nome.isEmpty) {
      nome = 'Voluntário';
    }

    return PerfilUsuario(
      uid: user.uid,
      nome: nome,
      email: user.email ?? '',
      telefone: TelefoneFormatter.formatar(telefone),
      fotoUrl: fotoUrl,
    );
  }

  @override
  Future<String> atualizarFoto({
    required Uint8List bytes,
    required String extensao,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('Nenhum usuário autenticado.');
    }

    if (bytes.lengthInBytes > limiteMaximoBytes) {
      throw FotoMuitoGrandeException(bytes.lengthInBytes);
    }

    final extLimpa = extensao.replaceAll('.', '').toLowerCase();
    final mimeType = extLimpa == 'png'
        ? 'image/png'
        : extLimpa == 'webp'
            ? 'image/webp'
            : (extLimpa == 'heic' || extLimpa == 'heif')
                ? 'image/heic'
                : 'image/jpeg';

    final nomeArquivo = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$extLimpa';
    final storageRef = _storage.ref('avatars/${user.uid}/$nomeArquivo');

    final metadata = SettableMetadata(
      contentType: mimeType,
      customMetadata: {'uid': user.uid},
    );

    final uploadTask = storageRef.putData(bytes, metadata);
    final snapshot = await uploadTask.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        uploadTask.cancel();
        throw TimeoutException('Tempo limite excedido no upload da foto.');
      },
    );
    final downloadUrl = await snapshot.ref.getDownloadURL().timeout(
      const Duration(seconds: 15),
    );

    // Atualiza o perfil no Auth
    await user.updatePhotoURL(downloadUrl);

    return downloadUrl;
  }

  @override
  Future<void> atualizarTelefone(String telefone) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('Nenhum usuário autenticado.');
    }

    final telefoneFormatado = TelefoneFormatter.formatar(telefone);

    try {
      await _firestore.collection('fichas').doc(user.uid).set(
        {
          'telefone': telefoneFormatado,
          'atualizadoEm': DateTime.now().toUtc().toIso8601String(),
        },
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Ignora erro de escrita direta para não bloquear a conclusão
    }
  }

  @override
  Future<void> solicitarTrocaEmail(String novoEmail) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('Nenhum usuário autenticado.');
    }

    final emailTrim = novoEmail.trim();
    if (emailTrim == user.email) {
      return;
    }

    await user.verifyBeforeUpdateEmail(emailTrim);
  }

  @override
  Future<void> reautenticarEAtualizarEmail({
    required String senhaAtual,
    required String novoEmail,
  }) async {
    final user = _currentUser;
    if (user == null || user.email == null) {
      throw StateError('Nenhum usuário autenticado.');
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: senhaAtual,
    );

    await user.reauthenticateWithCredential(credential);
    await user.verifyBeforeUpdateEmail(novoEmail.trim());
  }
}
