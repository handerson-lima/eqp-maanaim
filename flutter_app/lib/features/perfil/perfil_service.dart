import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

/// Implementação padrão integrada com Firebase Auth, Storage e Firestore.
class PerfilService implements IPerfilService {
  PerfilService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;

  static const int limiteMaximoBytes = 2 * 1024 * 1024; // 2 MB

  User? get _currentUser => _auth.currentUser;

  @override
  Future<PerfilUsuario> obterPerfil() async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('Nenhum usuário autenticado.');
    }

    String telefone = '';
    String? fotoUrl = user.photoURL;

    try {
      // Busca informações complementares da ficha ou coleção de usuários
      final docFicha = await _firestore.collection('fichas').doc(user.uid).get();
      if (docFicha.exists) {
        final data = docFicha.data();
        if (data != null) {
          telefone = (data['telefone'] as String?) ?? '';
          fotoUrl = (data['fotoUrl'] as String?) ?? fotoUrl;
        }
      }
    } catch (_) {
      // Preserva os dados do Auth se o Firestore falhar ou estiver sem documento
    }

    return PerfilUsuario(
      uid: user.uid,
      nome: user.displayName ?? 'Voluntário',
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
            : 'image/jpeg';

    final nomeArquivo = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$extLimpa';
    final storageRef = _storage.ref('avatars/${user.uid}/$nomeArquivo');

    final metadata = SettableMetadata(
      contentType: mimeType,
      customMetadata: {'uid': user.uid},
    );

    final uploadTask = await storageRef.putData(bytes, metadata);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // Atualiza o perfil no Auth
    await user.updatePhotoURL(downloadUrl);

    // Sincroniza fotoUrl no Firestore
    try {
      await _firestore.collection('fichas').doc(user.uid).set(
        {
          'fotoUrl': downloadUrl,
          'atualizadoEm': DateTime.now().toUtc().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Ignora falha de sincronização se o documento ainda não existir
    }

    return downloadUrl;
  }

  @override
  Future<void> atualizarTelefone(String telefone) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('Nenhum usuário autenticado.');
    }

    final telefoneFormatado = TelefoneFormatter.formatar(telefone);

    await _firestore.collection('fichas').doc(user.uid).set(
      {
        'telefone': telefoneFormatado,
        'atualizadoEm': DateTime.now().toUtc().toIso8601String(),
      },
      SetOptions(merge: true),
    );
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
