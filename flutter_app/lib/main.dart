import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'comando.dart';
import 'ui/identidade.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/validadores.dart';
import 'features/admin/catalogo_service.dart';
import 'features/admin/pessoas_service.dart';
import 'features/admin/termos_service.dart';
import 'features/admin/vinculos_service.dart';
import 'features/admin/admin_shell.dart';
import 'features/voluntario/ficha_service.dart';
import 'features/voluntario/minha_ficha_screen.dart';
import 'features/voluntario/participacao_service.dart';
import 'features/termo/termo_service.dart';
import 'features/pastor/pastor_service.dart';
import 'features/responsavel_equipe/responsavel_equipe_service.dart';
import 'features/coordenador/coordenador_service.dart';
import 'features/coordenador/fila_coordenador_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const resetUrl = String.fromEnvironment('PASSWORD_RESET_CONTINUE_URL');
  const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  const appCheckSiteKey = String.fromEnvironment(
    'FIREBASE_APP_CHECK_RECAPTCHA_SITE_KEY',
  );
  if (apiKey.isEmpty ||
      appId.isEmpty ||
      projectId.isEmpty ||
      resetUrl.isEmpty ||
      messagingSenderId.isEmpty ||
      authDomain.isEmpty ||
      appCheckSiteKey.isEmpty) {
    runApp(const ConfiguracaoAusente());
    return;
  }
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
      ),
    );
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider(appCheckSiteKey),
    );
    const usarEmuladores = bool.fromEnvironment('FIREBASE_USE_EMULATORS');
    if (usarEmuladores) {
      const host = String.fromEnvironment(
        'FIREBASE_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      );
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    }
  } catch (_) {
    runApp(const ConfiguracaoAusente());
    return;
  }
  final functions = FirebaseFunctions.instance;
  runApp(
    MaanaimApp(
      AuthService(
        FirebaseIdentidadeGateway(FirebaseAuth.instance),
        FirebaseRascunhoGateway(functions),
      ),
      catalogo: FirebaseCatalogoGateway(functions),
      seed: FirebaseSeedGateway(functions),
      pessoas: FirebasePessoasGateway(functions),
      vinculos: FirebaseVinculosGateway(functions),
      termos: FirebaseTermosService(functions: functions),
      ficha: FirebaseFichaGateway(functions),
      pastor: FirebasePastorLocalGateway(functions),
      responsavelEquipe: FirebaseResponsavelEquipeGateway(functions),
      coordenador: FirebaseCoordenadorGateway(functions),
    ),
  );
}

class ConfiguracaoAusente extends StatelessWidget {
  const ConfiguracaoAusente({super.key});
  @override
  Widget build(BuildContext c) => const MaterialApp(
    home: Scaffold(
      body: Center(child: Text('Configuração do ambiente indisponível.')),
    ),
  );
}

class MaanaimApp extends StatelessWidget {
  const MaanaimApp(
    this.auth, {
    super.key,
    this.catalogo,
    this.seed,
    this.pessoas,
    this.vinculos,
    this.termos,
    this.ficha,
    this.participacao,
    this.termoVoluntario,
    this.pastor,
    this.responsavelEquipe,
    this.coordenador,
  });
  final AuthService auth;
  final CatalogoGateway? catalogo;
  final SeedGateway? seed;
  final PessoasGateway? pessoas;
  final VinculosGateway? vinculos;
  final TermosGateway? termos;
  final FichaGateway? ficha;
  final ParticipacaoGateway? participacao;
  final TermoGateway? termoVoluntario;
  final PastorLocalGateway? pastor;
  final ResponsavelEquipeGateway? responsavelEquipe;
  final CoordenadorGateway? coordenador;
  @override
  Widget build(BuildContext c) => MaterialApp(
    title: 'Maanaim',
    theme: temaMaanaim(),
    home: RaizSessao(
      auth,
      catalogo: catalogo,
      seed: seed,
      pessoas: pessoas,
      vinculos: vinculos,
      termos: termos,
      ficha: ficha,
      participacao: participacao,
      termoVoluntario: termoVoluntario,
      pastor: pastor,
      responsavelEquipe: responsavelEquipe,
      coordenador: coordenador,
    ),
  );
}

/// Raiz da aplicação: ouve `authStateChanges` para restaurar sessão
/// ao recarregar e rotear automaticamente entre login, rascunho e admin.
class RaizSessao extends StatefulWidget {
  const RaizSessao(
    this.auth, {
    super.key,
    this.catalogo,
    this.seed,
    this.pessoas,
    this.vinculos,
    this.termos,
    this.ficha,
    this.participacao,
    this.termoVoluntario,
    this.pastor,
    this.responsavelEquipe,
    this.coordenador,
  });
  final AuthService auth;
  final CatalogoGateway? catalogo;
  final SeedGateway? seed;
  final PessoasGateway? pessoas;
  final VinculosGateway? vinculos;
  final TermosGateway? termos;
  final FichaGateway? ficha;
  final ParticipacaoGateway? participacao;
  final TermoGateway? termoVoluntario;
  final PastorLocalGateway? pastor;
  final ResponsavelEquipeGateway? responsavelEquipe;
  final CoordenadorGateway? coordenador;

  @override
  State<RaizSessao> createState() => _RaizSessaoState();
}

class _RaizSessaoState extends State<RaizSessao> {
  /// Assinatura estável: criada uma vez, e recriada apenas numa retentativa,
  /// para não perder/reordenar eventos de login/logout a cada rebuild.
  late Stream<User?> _estadoSessao = widget.auth.authStateChanges();

  void _retentar() =>
      setState(() => _estadoSessao = widget.auth.authStateChanges());

  Future<void> _sair() async {
    try {
      await widget.auth.sair();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _estadoSessao,
    builder: (context, estado) {
      if (estado.hasError) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: const Text(
                      'Não foi possível verificar sua sessão.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _retentar,
                    child: const Text('Tentar novamente'),
                  ),
                  TextButton(onPressed: _sair, child: const Text('Sair')),
                ],
              ),
            ),
          ),
        );
      }
      if (estado.connectionState == ConnectionState.waiting) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Semantics(
                label: 'Verificando sessão',
                child: const CircularProgressIndicator(),
              ),
            ),
          ),
        );
      }
      final usuario = estado.data;
      if (usuario == null) {
        return Inicio(widget.auth);
      }
      return AreaAutenticada(
        widget.auth,
        catalogo: widget.catalogo,
        seed: widget.seed,
        pessoas: widget.pessoas,
        vinculos: widget.vinculos,
        termos: widget.termos,
        ficha: widget.ficha,
        participacao: widget.participacao,
        termoVoluntario: widget.termoVoluntario,
        pastor: widget.pastor,
        responsavelEquipe: widget.responsavelEquipe,
        coordenador: widget.coordenador,
      );
    },
  );
}

/// Perfil de acesso resolvido a partir das claims da sessão, preservando o
/// menor privilégio: administrador > coordenador > voluntário.
enum _PerfilAcesso { administrador, coordenador, voluntario }

class AreaAutenticada extends StatefulWidget {
  const AreaAutenticada(
    this.auth, {
    super.key,
    this.catalogo,
    this.seed,
    this.pessoas,
    this.vinculos,
    this.termos,
    this.ficha,
    this.participacao,
    this.termoVoluntario,
    this.pastor,
    this.responsavelEquipe,
    this.coordenador,
  });
  final AuthService auth;
  final CatalogoGateway? catalogo;
  final SeedGateway? seed;
  final PessoasGateway? pessoas;
  final VinculosGateway? vinculos;
  final TermosGateway? termos;
  final FichaGateway? ficha;
  final ParticipacaoGateway? participacao;
  final TermoGateway? termoVoluntario;
  final PastorLocalGateway? pastor;
  final ResponsavelEquipeGateway? responsavelEquipe;
  final CoordenadorGateway? coordenador;
  @override
  State<AreaAutenticada> createState() => _AreaAutenticadaState();
}

class _AreaAutenticadaState extends State<AreaAutenticada> {
  late Future<_PerfilAcesso> _autorizacao = _resolverPerfil();

  Future<_PerfilAcesso> _resolverPerfil() async {
    if (await widget.auth.possuiAdministracao()) {
      return _PerfilAcesso.administrador;
    }
    if (await widget.auth.possuiCoordenacao()) {
      return _PerfilAcesso.coordenador;
    }
    return _PerfilAcesso.voluntario;
  }

  void _retentar() => setState(() {
    _autorizacao = _resolverPerfil();
  });

  Future<void> _sair() async {
    try {
      await widget.auth.sair();
      // O StreamBuilder em RaizSessao reagirá ao logout.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Não foi possível sair. Tente novamente.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_PerfilAcesso>(
    future: _autorizacao,
    builder: (context, estado) {
      if (estado.hasError) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: const Text(
                      'Não foi possível confirmar sua autorização.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _retentar,
                    child: const Text('Tentar novamente'),
                  ),
                  TextButton(onPressed: _sair, child: const Text('Sair')),
                ],
              ),
            ),
          ),
        );
      }
      if (!estado.hasData) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Semantics(
                label: 'Carregando autorização',
                child: const CircularProgressIndicator(),
              ),
            ),
          ),
        );
      }
      final perfil = estado.data!;
      if (perfil == _PerfilAcesso.administrador) {
        return AdminShell(
          onSair: _sair,
          catalogo: widget.catalogo,
          seed: widget.seed,
          pessoas: widget.pessoas,
          vinculos: widget.vinculos,
          termos: widget.termos,
          pastor: widget.pastor,
          responsavelEquipe: widget.responsavelEquipe,
          coordenador: widget.coordenador,
        );
      }
      if (perfil == _PerfilAcesso.coordenador && widget.coordenador != null) {
        return FilaCoordenadorScreen(
          gateway: widget.coordenador!,
          onSair: _sair,
        );
      }
      return MinhaFichaScreen(
        fichaGateway: _obterFichaGateway(),
        catalogoGateway: _obterCatalogoGateway(),
        participacaoGateway: _obterParticipacaoGateway(),
        termoGateway: _obterTermoGateway(),
        onSair: _sair,
        userName: widget.auth.emailAtual,
      );
    },
  );

  FichaGateway _obterFichaGateway() {
    if (widget.ficha != null) return widget.ficha!;
    try {
      return FirebaseFichaGateway(FirebaseFunctions.instance);
    } catch (_) {
      return const _FichaMemoriaFallback();
    }
  }

  CatalogoGateway _obterCatalogoGateway() {
    if (widget.catalogo != null) return widget.catalogo!;
    try {
      return FirebaseCatalogoGateway(FirebaseFunctions.instance);
    } catch (_) {
      return const _CatalogoMemoriaFallback();
    }
  }

  ParticipacaoGateway _obterParticipacaoGateway() {
    if (widget.participacao != null) return widget.participacao!;
    try {
      return FirebaseParticipacaoGateway(FirebaseFunctions.instance);
    } catch (_) {
      return MemoriaParticipacaoGateway();
    }
  }

  TermoGateway _obterTermoGateway() {
    if (widget.termoVoluntario != null) return widget.termoVoluntario!;
    try {
      return FirebaseTermoGateway(functions: FirebaseFunctions.instance);
    } catch (_) {
      return MemoriaTermoGateway();
    }
  }
}

class _FichaMemoriaFallback implements FichaGateway {
  const _FichaMemoriaFallback();

  @override
  Future<ObterFichaResposta> obterMinhaFicha() async =>
      const ObterFichaResposta(existe: false);

  @override
  Future<SalvarFichaResposta> salvarMinhaFicha(SalvarFichaEntrada entrada) async =>
      SalvarFichaResposta(
        sucesso: true,
        repetido: false,
        ficha: FichaModel(
          id: 'temp',
          nomeCompleto: entrada.nomeCompleto,
          profissao: entrada.profissao,
          cpf: entrada.cpf,
          igrejaId: entrada.igrejaId,
          estado: 'RASCUNHO',
          versao: 1,
        ),
      );

  @override
  Future<EnviarFichaResposta> enviarFichaAprovacao({
    required String commandId,
    int? expectedVersion,
  }) async =>
      const EnviarFichaResposta(
        sucesso: true,
        repetido: false,
        estado: 'AGUARDANDO_PASTOR_LOCAL',
        versao: 2,
        proximaAcao: 'Aguardando avaliação do Pastor Local',
        igrejaId: 'temp',
        enviadoEm: '2026-10-06T12:00:00Z',
      );

  @override
  Future<void> cancelarVoluntariado({
    required String fichaId,
    String? motivo,
    String? commandId,
  }) async {}
}

class _CatalogoMemoriaFallback implements CatalogoGateway {
  const _CatalogoMemoriaFallback();

  @override
  Future<CatalogoResposta> consultar({String? termo}) async =>
      const CatalogoResposta(igrejas: [], equipes: []);
}

class Inicio extends StatelessWidget {
  const Inicio(this.auth, {super.key});
  final AuthService auth;
  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: PainelAcesso(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Bem-vindo',
                style: AppTypography.h2,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Acesse sua conta para continuar.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            PrimaryButton(
              label: 'Entrar',
              isFullWidth: true,
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => Login(auth)),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            SecondaryButton(
              label: 'Cadastre-se',
              isFullWidth: true,
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => Cadastro(auth)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class Cadastro extends StatefulWidget {
  const Cadastro(this.auth, {super.key});
  final AuthService auth;
  @override
  State<Cadastro> createState() => _CadastroState();
}

class _CadastroState extends State<Cadastro> {
  final f = GlobalKey<FormState>();
  final nome = TextEditingController(),
      profissao = TextEditingController(),
      cpf = TextEditingController(),
      email = TextEditingController(),
      senha = TextEditingController();
  String? igreja;
  late final String commandId;
  bool enviando = false;
  String? aviso;
  @override
  void initState() {
    super.initState();
    // O mesmo identificador opaco é usado se a resposta da callable se perder.
    commandId = comandoOpaco();
  }

  @override
  void dispose() {
    for (final c in [nome, profissao, cpf, email, senha]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> enviar() async {
    if (!(f.currentState?.validate() ?? false)) return;
    setState(() {
      enviando = true;
      aviso = null;
    });
    try {
      final resultado = await widget.auth.cadastrar(
        email: email.text,
        senha: senha.text,
        dados: {
          'commandId': commandId,
          'nomeCompleto': nome.text,
          'profissao': profissao.text,
          'cpf': cpf.text,
          'igrejaId': igreja!,
        },
      );
      if (mounted) {
        setState(
          () => aviso = resultado.retomado
              ? 'Sua ficha já estava em rascunho e foi retomada; isto não concede aprovação ou função.'
              : 'Cadastro iniciado. Sua ficha está em rascunho; isto não concede aprovação ou função.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => aviso =
              'Não foi possível concluir agora. Revise os campos e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Cadastre-se')),
    body: SafeArea(
      child: PainelAcesso(
        child: Form(
          key: f,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Crie seu acesso',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _campo(
                nome,
                'Nome completo',
                (v) => obrigatorio(v, 'Nome completo'),
              ),
              _campo(
                profissao,
                'Profissão',
                (v) => obrigatorio(v, 'Profissão'),
              ),
              _campo(
                cpf,
                'CPF',
                cpfValido,
                tipo: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('igrejas')
                    .where('ativo', isEqualTo: true)
                    .snapshots(),
                builder: (_, s) {
                  if (s.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Semantics(
                        liveRegion: true,
                        child: const Text(
                          'Não foi possível carregar as igrejas.',
                        ),
                      ),
                    );
                  }
                  if (!s.hasData) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Semantics(
                        liveRegion: true,
                        label: 'Carregando igrejas',
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  final itens = s.data!.docs;
                  if (itens.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Semantics(
                        liveRegion: true,
                        child: const Text(
                          'Nenhuma igreja disponível no momento.',
                        ),
                      ),
                    );
                  }
                  // Reconcilia a seleção: um valor que
                  // deixou de existir não quebra o
                  // dropdown.
                  final selecionada = itens.any((d) => d.id == igreja)
                      ? igreja
                      : null;
                  return DropdownButtonFormField<String>(
                    key: ValueKey(itens.map((d) => d.id).join('|')),
                    initialValue: selecionada,
                    decoration: const InputDecoration(labelText: 'Igreja'),
                    items: itens
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(
                              d.data()['nome'] as String? ?? 'Igreja',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => igreja = v),
                    validator: (v) =>
                        v == null ? 'Selecione sua igreja.' : null,
                  );
                },
              ),
              const SizedBox(height: 14),
              _campo(
                email,
                'E-mail',
                emailValido,
                tipo: TextInputType.emailAddress,
              ),
              _campo(senha, 'Senha', senhaValida, segredo: true),
              if (aviso != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(liveRegion: true, child: Text(aviso!)),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: enviando ? null : enviar,
                child: Text(enviando ? 'Enviando…' : 'Criar cadastro'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _campo(
    TextEditingController controller,
    String label,
    String? Function(String?) valida, {
    TextInputType? tipo,
    bool segredo = false,
    List<TextInputFormatter>? formatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: valida,
      keyboardType: tipo,
      inputFormatters: formatters,
      obscureText: segredo,
      autocorrect: !segredo,
      enableSuggestions: !segredo,
    ),
  );
}

class Login extends StatefulWidget {
  const Login(this.auth, {super.key});
  final AuthService auth;
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final f = GlobalKey<FormState>();
  final email = TextEditingController(), senha = TextEditingController();
  bool carregando = false;
  String? aviso;
  @override
  void dispose() {
    email.dispose();
    senha.dispose();
    super.dispose();
  }

  Future<void> recuperar() async {
    if (emailValido(email.text) != null) {
      setState(() => aviso = 'Informe um e-mail válido para continuar.');
      return;
    }
    setState(() => carregando = true);
    try {
      await widget.auth.recuperar(email.text);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
          aviso = AuthService.mensagemRecuperacaoNeutra;
        });
      }
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Entrar')),
    body: SafeArea(
      child: PainelAcesso(
        child: Form(
          key: f,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Bem-vindo',
                  style: AppTypography.h2,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Acesse sua conta para continuar',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              _campo(
                email,
                'E-mail',
                emailValido,
                tipo: TextInputType.emailAddress,
              ),
              _campo(
                senha,
                'Senha',
                senhaValida,
                segredo: true,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: carregando ? null : recuperar,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.blue600,
                    minimumSize: const Size(44, 36),
                  ),
                  child: const Text('Esqueci minha senha'),
                ),
              ),
              if (aviso != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                    child: Text(
                      aviso!,
                      style: AppTypography.body.copyWith(color: AppColors.danger),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.s8),
              PrimaryButton(
                label: 'Entrar',
                isFullWidth: true,
                onPressed: carregando
                    ? null
                    : () async {
                  if (!f.currentState!.validate()) {
                    return;
                  }
                  setState(() => carregando = true);
                  try {
                    await widget.auth.entrar(email.text, senha.text);
                    if (mounted) {
                      Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst);
                    }
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => aviso =
                            'Não foi possível entrar. Verifique seus dados e tente novamente.',
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => carregando = false);
                    }
                  }
                },
              ),
              const SizedBox(height: AppSpacing.s16),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.border, height: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                    child: Text(
                      'ou',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.border, height: 1)),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              SecondaryButton(
                label: 'Entrar com Google',
                icon: Icons.login,
                isFullWidth: true,
                onPressed: carregando
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Login com Google não configurado no momento.',
                            ),
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _campo(
    TextEditingController controller,
    String label,
    String? Function(String?) valida, {
    bool segredo = false,
    TextInputType? tipo,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Informe seu ${label.toLowerCase()}',
          ),
          validator: valida,
          keyboardType: segredo ? null : tipo,
          obscureText: segredo,
        ),
      ],
    ),
  );
}
