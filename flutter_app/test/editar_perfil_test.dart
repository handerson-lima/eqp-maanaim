import 'dart:typed_data';
import 'package:eqp_maanaim/features/perfil/avatar_picker_widget.dart';
import 'package:eqp_maanaim/features/perfil/editar_perfil_screen.dart';
import 'package:eqp_maanaim/features/perfil/perfil_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Bytes de um PNG 1x1 válido para evitar erro de decodificação no test
final Uint8List png1x1Valido = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
]);

class PerfilServiceFake implements IPerfilService {
  PerfilServiceFake({
    this.perfilInicial = const PerfilUsuario(
      uid: 'user-123',
      nome: 'João da Silva',
      email: 'joao@example.com',
      telefone: '(11) 98765-4321',
      fotoUrl: null,
    ),
  });

  PerfilUsuario perfilInicial;
  String? ultimoTelefoneSalvo;
  String? ultimoEmailSolicitado;
  Uint8List? ultimosBytesFoto;
  bool deveLancarErroNoUpload = false;

  @override
  Future<PerfilUsuario> obterPerfil() async {
    return perfilInicial;
  }

  @override
  Future<String> atualizarFoto({
    required Uint8List bytes,
    required String extensao,
  }) async {
    if (deveLancarErroNoUpload) {
      throw const FotoMuitoGrandeException(3000000);
    }
    ultimosBytesFoto = bytes;
    perfilInicial = perfilInicial.copyWith(
      fotoUrl: 'https://storage.googleapis.com/test/avatar.jpg',
    );
    return perfilInicial.fotoUrl!;
  }

  @override
  Future<void> atualizarTelefone(String telefone) async {
    ultimoTelefoneSalvo = telefone;
    perfilInicial = perfilInicial.copyWith(telefone: telefone);
  }

  @override
  Future<void> solicitarTrocaEmail(String novoEmail) async {
    ultimoEmailSolicitado = novoEmail;
  }

  @override
  Future<void> reautenticarEAtualizarEmail({
    required String senhaAtual,
    required String novoEmail,
  }) async {
    ultimoEmailSolicitado = novoEmail;
  }
}

void main() {
  group('TelefoneFormatter', () {
    test('formata números parciais e completos com máscara brasileira', () {
      expect(TelefoneFormatter.formatar('11'), '(11');
      expect(TelefoneFormatter.formatar('119'), '(11) 9');
      expect(TelefoneFormatter.formatar('11987654321'), '(11) 98765-4321');
      expect(TelefoneFormatter.formatar('1133334444'), '(11) 3333-4444');
      expect(TelefoneFormatter.apenasDigitos('(11) 98765-4321'), '11987654321');
    });
  });

  group('AvatarPickerWidget', () {
    testWidgets('exibe iniciais do usuário quando não há fotoUrl', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvatarPickerWidget(
              nome: 'João Silva',
              fotoUrl: null,
              onImageSelected: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.text('JS'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('exibe preview quando previewBytes for fornecido', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvatarPickerWidget(
              nome: 'João Silva',
              previewBytes: png1x1Valido,
              onImageSelected: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('EditarPerfilScreen', () {
    testWidgets('carrega e exibe os dados do perfil com máscara de telefone', (tester) async {
      final service = PerfilServiceFake();

      await tester.pumpWidget(
        MaterialApp(
          home: EditarPerfilScreen(service: service),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Editar Perfil'), findsOneWidget);
      expect(find.text('João da Silva'), findsNWidgets(2)); // Avatar e título
      expect(find.text('joao@example.com'), findsOneWidget);
      expect(find.text('(11) 98765-4321'), findsOneWidget);
    });

    testWidgets('salva telefone alterado com sucesso', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = PerfilServiceFake();

      await tester.pumpWidget(
        MaterialApp(
          home: EditarPerfilScreen(service: service),
        ),
      );

      await tester.pump();
      await tester.pump();

      final campoTelefone = find.widgetWithText(TextFormField, '(11) 98765-4321');
      await tester.enterText(campoTelefone, '11999998888');
      await tester.pump();

      final botaoSalvar = find.text('Salvar Alterações');
      await tester.ensureVisible(botaoSalvar);
      await tester.pumpAndSettle();

      await tester.tap(botaoSalvar);
      await tester.pump();
      await tester.pump();

      expect(service.ultimoTelefoneSalvo, '(11) 99999-8888');
      expect(find.text('Perfil atualizado com sucesso!'), findsOneWidget);
    });

    testWidgets('solicita verificação ao alterar e-mail', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = PerfilServiceFake();

      await tester.pumpWidget(
        MaterialApp(
          home: EditarPerfilScreen(service: service),
        ),
      );

      await tester.pump();
      await tester.pump();

      final campoEmail = find.widgetWithText(TextFormField, 'joao@example.com');
      await tester.enterText(campoEmail, 'novo.email@example.com');
      await tester.pump();

      final botaoSalvar = find.text('Salvar Alterações');
      await tester.ensureVisible(botaoSalvar);
      await tester.pumpAndSettle();

      await tester.tap(botaoSalvar);
      await tester.pump();
      await tester.pump();

      expect(service.ultimoEmailSolicitado, 'novo.email@example.com');
      expect(find.textContaining('Enviamos um link de confirmação para novo.email@example.com'), findsOneWidget);
    });

    testWidgets('valida e recusa e-mail inválido', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = PerfilServiceFake();

      await tester.pumpWidget(
        MaterialApp(
          home: EditarPerfilScreen(service: service),
        ),
      );

      await tester.pump();
      await tester.pump();

      final campoEmail = find.widgetWithText(TextFormField, 'joao@example.com');
      await tester.enterText(campoEmail, 'email_invalido');
      await tester.pump();

      final botaoSalvar = find.text('Salvar Alterações');
      await tester.ensureVisible(botaoSalvar);
      await tester.pumpAndSettle();

      await tester.tap(botaoSalvar);
      await tester.pump();

      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
      expect(service.ultimoEmailSolicitado, isNull);
    });
  });
}
