import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui/components/buttons.dart';
import '../../ui/tokens.dart';
import 'avatar_picker_widget.dart';
import 'perfil_service.dart';

/// Tela mobile-first para edição das informações de perfil do usuário.
///
/// Permite:
/// - Atualização de foto de perfil com preview e upload para Firebase Storage.
/// - Atualização de número de telefone (WhatsApp) com máscara brasileira.
/// - Solicitação de troca de e-mail com confirmação por link de verificação.
/// - Reautenticação segura se a sessão do Firebase Auth exigir login recente.
class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({
    super.key,
    this.service,
    this.nomeInicial,
    this.telefoneInicial,
    this.fotoUrlInicial,
    this.onVoltar,
  });

  final IPerfilService? service;
  final String? nomeInicial;
  final String? telefoneInicial;
  final String? fotoUrlInicial;
  final VoidCallback? onVoltar;

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  late final IPerfilService _service;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();

  PerfilUsuario? _perfil;
  bool _carregando = true;
  bool _salvando = false;
  String? _mensagemErro;
  String? _avisoEmailPendente;

  Uint8List? _previewBytes;
  String? _extensaoSelecionada;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PerfilService();

    final nomeIn = widget.nomeInicial?.trim();
    final nomeValido = (nomeIn != null &&
            nomeIn.isNotEmpty &&
            !nomeIn.contains('@') &&
            nomeIn.toLowerCase() != 'voluntário')
        ? nomeIn
        : null;

    if (nomeValido != null) {
      _perfil = PerfilUsuario(
        uid: FirebaseAuth.instance.currentUser?.uid ?? '',
        nome: nomeValido,
        email: FirebaseAuth.instance.currentUser?.email ?? '',
        telefone: TelefoneFormatter.formatar(widget.telefoneInicial ?? ''),
        fotoUrl: widget.fotoUrlInicial ?? FirebaseAuth.instance.currentUser?.photoURL,
      );
      _emailController.text = _perfil!.email;
      _telefoneController.text = _perfil!.telefone;
      _carregando = false;
    }

    _carregarPerfil();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  Future<void> _carregarPerfil() async {
    if (_perfil == null) {
      setState(() {
        _carregando = true;
        _mensagemErro = null;
      });
    }

    try {
      final perfil = await _service.obterPerfil();
      if (!mounted) return;

      setState(() {
        String nomeFinal = perfil.nome;
        if (nomeFinal.contains('@') || nomeFinal.isEmpty) {
          nomeFinal = 'Voluntário';
        }
        if (nomeFinal == 'Voluntário' &&
            _perfil != null &&
            !_perfil!.nome.contains('@') &&
            _perfil!.nome != 'Voluntário') {
          nomeFinal = _perfil!.nome;
        }

        _perfil = perfil.copyWith(nome: nomeFinal);
        if (_emailController.text.isEmpty) {
          _emailController.text = perfil.email;
        }
        if (_telefoneController.text.isEmpty && perfil.telefone.isNotEmpty) {
          _telefoneController.text = perfil.telefone;
        }
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_perfil == null) {
        setState(() {
          _mensagemErro = 'Não foi possível carregar o perfil: $e';
          _carregando = false;
        });
      }
    }
  }

  void _onImageSelected(Uint8List bytes, String extensao) {
    setState(() {
      _previewBytes = bytes;
      _extensaoSelecionada = extensao;
    });
  }

  Future<void> _salvar() async {
    if (_perfil == null || _salvando) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _salvando = true;
      _mensagemErro = null;
    });

    try {
      String? novaFotoUrl;
      final emailAlterado = _emailController.text.trim().toLowerCase() !=
          _perfil!.email.trim().toLowerCase();
      final telefoneAlterado = _telefoneController.text.trim() !=
          _perfil!.telefone.trim();

      // 1. Upload de foto se houver nova imagem selecionada
      if (_previewBytes != null) {
        novaFotoUrl = await _service.atualizarFoto(
          bytes: _previewBytes!,
          extensao: _extensaoSelecionada ?? 'jpg',
        );
      }

      // 2. Atualização de telefone
      if (telefoneAlterado) {
        await _service.atualizarTelefone(_telefoneController.text.trim());
      }

      // 3. Atualização de e-mail (com verificação por link)
      if (emailAlterado) {
        await _processarTrocaEmail(_emailController.text.trim());
      }

      if (!mounted) return;

      setState(() {
        _perfil = _perfil!.copyWith(
          telefone: _telefoneController.text.trim(),
          fotoUrl: novaFotoUrl ?? _perfil!.fotoUrl,
        );
        _previewBytes = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emailAlterado
                ? 'Perfil atualizado! Enviamos um link de confirmação para ${_emailController.text.trim()}.'
                : 'Perfil atualizado com sucesso!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final erroTexto = e.toString();
      final String mensagemAmigavel;
      if (erroTexto.contains('quota-exceeded')) {
        mensagemAmigavel =
            'O serviço de armazenamento está temporariamente indisponível (limite de cota atingido). Tente novamente mais tarde.';
      } else if (erroTexto.contains('unauthorized') ||
          erroTexto.contains('permission-denied') ||
          erroTexto.contains('unauthenticated')) {
        mensagemAmigavel =
            'Permissão negada para atualizar as informações do perfil.';
      } else if (e is FotoMuitoGrandeException) {
        mensagemAmigavel = e.toString();
      } else if (erroTexto.contains('network') ||
          erroTexto.contains('timeout') ||
          erroTexto.contains('Tempo limite')) {
        mensagemAmigavel =
            'Tempo limite esgotado. Verifique sua conexão e tente novamente.';
      } else {
        mensagemAmigavel =
            'Não foi possível salvar as alterações no momento. Tente novamente.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagemAmigavel),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  Future<void> _processarTrocaEmail(String novoEmail) async {
    try {
      await _service.solicitarTrocaEmail(novoEmail);
      if (mounted) {
        setState(() {
          _avisoEmailPendente = novoEmail;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Solicita senha para reautenticação
        final reautenticado = await _exibirDialogoReautenticacao(novoEmail);
        if (!reautenticado) {
          throw Exception(
              'A troca de e-mail requer confirmação de senha recente.');
        }
      } else {
        rethrow;
      }
    }
  }

  Future<bool> _exibirDialogoReautenticacao(String novoEmail) async {
    final senhaController = TextEditingController();
    bool confirmou = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmação de Segurança'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Por segurança, digite sua senha atual para autorizar a alteração do e-mail de acesso:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.s16),
              TextField(
                controller: senhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha atual',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final senha = senhaController.text;
                if (senha.isEmpty) return;

                try {
                  await _service.reautenticarEAtualizarEmail(
                    senhaAtual: senha,
                    novoEmail: novoEmail,
                  );
                  confirmou = true;
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (err) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Senha incorreta: $err'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmar e Enviar'),
            ),
          ],
        );
      },
    );

    return confirmou;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Editar Perfil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.navy900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Voltar',
          onPressed: widget.onVoltar ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: _buildConteudo(),
    );
  }

  Widget _buildConteudo() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.blue600,
        ),
      );
    }

    if (_mensagemErro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: AppSpacing.s16),
              Text(
                _mensagemErro!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.s16),
              PrimaryButton(
                label: 'Tentar novamente',
                onPressed: _carregarPerfil,
              ),
            ],
          ),
        ),
      );
    }

    final perfil = _perfil!;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s24,
            ),
            children: [
              // Avatar interativo
              AvatarPickerWidget(
                nome: perfil.nome,
                fotoUrl: perfil.fotoUrl,
                previewBytes: _previewBytes,
                carregando: _salvando,
                onImageSelected: _onImageSelected,
              ),
              const SizedBox(height: AppSpacing.s8),
              Center(
                child: Text(
                  perfil.nome,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'Toque na foto ou na câmera para alterar (máx. 2 MB)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s24),

              // Banner de e-mail pendente caso haja alteração recente
              if (_avisoEmailPendente != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    border: Border.all(color: AppColors.warning),
                    borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.mail_outline, color: AppColors.warning),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          'Confirmação pendente: um link foi enviado para $_avisoEmailPendente. Seu login continuará sendo ${perfil.email} até a validação.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
              ],

              // Card do Formulário
              Card(
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppGeometry.radiusCard),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome (Leitura apenas)
                      TextFormField(
                        key: ValueKey(perfil.nome),
                        initialValue: perfil.nome,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Nome Completo',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                          helperText: 'Alterações de nome devem ser solicitadas à administração.',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s20),

                      // E-mail
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-mail de Acesso',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                          helperText: 'Enviaremos um link de confirmação para o novo e-mail.',
                        ),
                        validator: (valor) {
                          if (valor == null || valor.trim().isEmpty) {
                            return 'Informe o e-mail.';
                          }
                          final emailRegExp = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                          if (!emailRegExp.hasMatch(valor.trim())) {
                            return 'Informe um e-mail válido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s20),

                      // Telefone
                      TextFormField(
                        controller: _telefoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          TelefoneInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Telefone (WhatsApp)',
                          hintText: '(00) 00000-0000',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_outlined),
                          helperText: 'Número para contato nas escalas e triagens do Maanaim.',
                        ),
                        validator: (valor) {
                          if (valor == null || valor.trim().isEmpty) {
                            return 'Informe o telefone.';
                          }
                          final digitos = TelefoneFormatter.apenasDigitos(valor);
                          if (digitos.length < 10 || digitos.length > 11) {
                            return 'Informe um telefone válido com DDD (10 ou 11 dígitos).';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s24),

              // Botões de Ação
              PrimaryButton(
                label: 'Salvar Alterações',
                icon: Icons.save_outlined,
                isLoading: _salvando,
                isFullWidth: true,
                onPressed: _salvando ? null : _salvar,
              ),
              const SizedBox(height: AppSpacing.s12),
              SecondaryButton(
                label: 'Cancelar',
                isFullWidth: true,
                onPressed: _salvando
                    ? null
                    : (widget.onVoltar ?? () => Navigator.of(context).maybePop()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
