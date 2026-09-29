import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'comando.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/validadores.dart';
import 'features/admin/catalogo_service.dart';
import 'features/admin/admin_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const resetUrl = String.fromEnvironment('PASSWORD_RESET_CONTINUE_URL');
  const messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  const appCheckSiteKey =
      String.fromEnvironment('FIREBASE_APP_CHECK_RECAPTCHA_SITE_KEY');
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
            authDomain: authDomain));
    await FirebaseAppCheck.instance
        .activate(webProvider: ReCaptchaV3Provider(appCheckSiteKey));
    const usarEmuladores = bool.fromEnvironment('FIREBASE_USE_EMULATORS');
    if (usarEmuladores) {
      const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST',
          defaultValue: '127.0.0.1');
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    }
  } catch (_) {
    runApp(const ConfiguracaoAusente());
    return;
  }
  final functions = FirebaseFunctions.instance;
  runApp(MaanaimApp(
      AuthService(FirebaseIdentidadeGateway(FirebaseAuth.instance),
          FirebaseRascunhoGateway(functions)),
      catalogo: FirebaseCatalogoGateway(functions),
      seed: FirebaseSeedGateway(functions)));
}

class ConfiguracaoAusente extends StatelessWidget {
  const ConfiguracaoAusente({super.key});
  @override
  Widget build(BuildContext c) => const MaterialApp(
      home: Scaffold(
          body: Center(child: Text('Configuração do ambiente indisponível.'))));
}

class MaanaimApp extends StatelessWidget {
  const MaanaimApp(this.auth, {super.key, this.catalogo, this.seed});
  final AuthService auth;
  final CatalogoGateway? catalogo;
  final SeedGateway? seed;
  @override
  Widget build(BuildContext c) => MaterialApp(
      title: 'Maanaim',
      theme: ThemeData(
          colorSchemeSeed: Colors.green,
          inputDecorationTheme:
              const InputDecorationTheme(border: OutlineInputBorder()),
          elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(minimumSize: const Size(44, 48))),
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(minimumSize: const Size(44, 48))),
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(minimumSize: const Size(44, 48)))),
      home: RaizSessao(auth, catalogo: catalogo, seed: seed));
}

/// Raiz da aplicação: ouve `authStateChanges` para restaurar sessão
/// ao recarregar e rotear automaticamente entre login, rascunho e admin.
class RaizSessao extends StatelessWidget {
  const RaizSessao(this.auth, {super.key, this.catalogo, this.seed});
  final AuthService auth;
  final CatalogoGateway? catalogo;
  final SeedGateway? seed;

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, estado) {
          if (estado.connectionState == ConnectionState.waiting) {
            return Scaffold(
                body: SafeArea(
                    child: Center(
                        child: Semantics(
                            label: 'Verificando sessão',
                            child: const CircularProgressIndicator()))));
          }
          final usuario = estado.data;
          if (usuario == null) {
            return Inicio(auth);
          }
          return AreaAutenticada(auth, catalogo: catalogo, seed: seed);
        },
      );
}

class AreaAutenticada extends StatefulWidget {
  const AreaAutenticada(this.auth, {super.key, this.catalogo, this.seed});
  final AuthService auth;
  final CatalogoGateway? catalogo;
  final SeedGateway? seed;
  @override
  State<AreaAutenticada> createState() => _AreaAutenticadaState();
}

class _AreaAutenticadaState extends State<AreaAutenticada> {
  late Future<bool> _autorizacao = widget.auth.possuiAdministracao();

  void _retentar() => setState(() {
        _autorizacao = widget.auth.possuiAdministracao();
      });

  Future<void> _sair() async {
    await widget.auth.sair();
    // O StreamBuilder em RaizSessao reagirá ao logout.
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
      future: _autorizacao,
      builder: (context, estado) {
        if (estado.hasError) {
          return Scaffold(
              body: SafeArea(
                  child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
            Semantics(
                liveRegion: true,
                child: const Text('Não foi possível confirmar sua autorização.')),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _retentar, child: const Text('Tentar novamente')),
          ]))));
        }
        if (!estado.hasData) {
          return Scaffold(
              body: SafeArea(
                  child: Center(
                      child: Semantics(
                          label: 'Carregando autorização',
                          child: const CircularProgressIndicator()))));
        }
        return estado.data!
            ? AdminShell(
                onSair: _sair,
                catalogo: widget.catalogo,
                seed: widget.seed,
              )
            : Scaffold(
                appBar: AppBar(
                  title: const Text('Maanaim'),
                  actions: [
                    IconButton(
                      onPressed: _sair,
                      icon: const Icon(Icons.logout),
                      tooltip: 'Sair',
                    ),
                  ],
                ),
                body: const SafeArea(
                    child: Center(
                        child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Acesso realizado. Sua ficha pode continuar em rascunho.')))));
      });
}

class Inicio extends StatelessWidget {
  const Inicio(this.auth, {super.key});
  final AuthService auth;
  @override
  Widget build(BuildContext c) => Scaffold(
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Maanaim',
                                style: TextStyle(
                                    fontSize: 32, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            const Text(
                                'Inicie sua ficha de voluntariado com segurança.'),
                            const SizedBox(height: 28),
                            ElevatedButton(
                                onPressed: () => Navigator.push(
                                    c,
                                    MaterialPageRoute(
                                        builder: (_) => Cadastro(auth))),
                                child: const Text('Cadastre-se')),
                            const SizedBox(height: 12),
                            OutlinedButton(
                                onPressed: () => Navigator.push(
                                    c,
                                    MaterialPageRoute(
                                        builder: (_) => Login(auth))),
                                child: const Text('Entrar'))
                          ]))))));
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
      final resultado =
          await widget.auth.cadastrar(email: email.text, senha: senha.text, dados: {
        'commandId': commandId,
        'nomeCompleto': nome.text,
        'profissao': profissao.text,
        'cpf': cpf.text,
        'igrejaId': igreja!
      });
      if (mounted) {
        setState(() => aviso = resultado.retomado
            ? 'Sua ficha já estava em rascunho e foi retomada; isto não concede aprovação ou função.'
            : 'Cadastro iniciado. Sua ficha está em rascunho; isto não concede aprovação ou função.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => aviso =
            'Não foi possível concluir agora. Revise os campos e tente novamente.');
      }
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Cadastre-se')),
      body: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Form(
                          key: f,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Crie seu acesso',
                                    style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                _campo(nome, 'Nome completo',
                                    (v) => obrigatorio(v, 'Nome completo')),
                                _campo(profissao, 'Profissão',
                                    (v) => obrigatorio(v, 'Profissão')),
                                _campo(cpf, 'CPF', cpfValido,
                                    tipo: TextInputType.number,
                                    formatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ]),
                                StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>>(
                                    stream: FirebaseFirestore.instance
                                        .collection('igrejas')
                                        .where('ativo', isEqualTo: true)
                                        .snapshots(),
                                    builder: (_, s) {
                                      if (s.hasError) {
                                        return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 14),
                                            child: Semantics(
                                                liveRegion: true,
                                                child: const Text(
                                                    'Não foi possível carregar as igrejas.')));
                                      }
                                      if (!s.hasData) {
                                        return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 14),
                                            child: Semantics(
                                                liveRegion: true,
                                                label: 'Carregando igrejas',
                                                child: const Center(
                                                    child:
                                                        CircularProgressIndicator())));
                                      }
                                      final itens = s.data!.docs;
                                      if (itens.isEmpty) {
                                        return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 14),
                                            child: Semantics(
                                                liveRegion: true,
                                                child: const Text(
                                                    'Nenhuma igreja disponível no momento.')));
                                      }
                                      // Reconcilia a seleção: um valor que
                                      // deixou de existir não quebra o
                                      // dropdown.
                                      final selecionada = itens
                                              .any((d) => d.id == igreja)
                                          ? igreja
                                          : null;
                                      return DropdownButtonFormField<String>(
                                          key: ValueKey(
                                              itens.map((d) => d.id).join('|')),
                                          initialValue: selecionada,
                                          decoration: const InputDecoration(
                                              labelText: 'Igreja'),
                                          items: itens
                                              .map((d) => DropdownMenuItem(
                                                  value: d.id,
                                                  child: Text(d.data()['nome']
                                                          as String? ??
                                                      'Igreja')))
                                              .toList(),
                                          onChanged: (v) =>
                                              setState(() => igreja = v),
                                          validator: (v) => v == null
                                              ? 'Selecione sua igreja.'
                                              : null);
                                    }),
                                const SizedBox(height: 14),
                                _campo(email, 'E-mail', emailValido,
                                    tipo: TextInputType.emailAddress),
                                _campo(senha, 'Senha', senhaValida,
                                    segredo: true),
                                if (aviso != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Semantics(
                                          liveRegion: true,
                                          child: Text(aviso!))),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                    onPressed: enviando ? null : enviar,
                                    child: Text(enviando
                                        ? 'Enviando…'
                                        : 'Criar cadastro'))
                              ])))))));
  Widget _campo(TextEditingController controller, String label,
          String? Function(String?) valida,
          {TextInputType? tipo,
          bool segredo = false,
          List<TextInputFormatter>? formatters}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
              controller: controller,
              decoration: InputDecoration(labelText: label),
              validator: valida,
              keyboardType: tipo,
              inputFormatters: formatters,
              obscureText: segredo,
              autocorrect: !segredo,
              enableSuggestions: !segredo));
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
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Form(
                          key: f,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _campo(email, 'E-mail', emailValido),
                                _campo(senha, 'Senha', senhaValida,
                                    segredo: true),
                                if (aviso != null)
                                  Semantics(
                                      liveRegion: true,
                                      child: Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: Text(aviso!))),
                                ElevatedButton(
                                    onPressed: carregando
                                        ? null
                                        : () async {
                                            if (!f.currentState!.validate()) {
                                              return;
                                            }
                                            setState(() => carregando = true);
                                            try {
                                              await widget.auth.entrar(
                                                  email.text, senha.text);
                                              // O StreamBuilder em RaizSessao
                                              // reagirá ao login; basta voltar.
                                              if (mounted) {
                                                Navigator.of(context)
                                                    .popUntil(
                                                        (route) => route.isFirst);
                                              }
                                            } catch (_) {
                                              if (mounted) {
                                                setState(() => aviso =
                                                    'Não foi possível entrar. Verifique seus dados e tente novamente.');
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(
                                                    () => carregando = false);
                                              }
                                            }
                                          },
                                    child: const Text('Entrar')),
                                TextButton(
                                    onPressed: carregando ? null : recuperar,
                                    child: const Text('Esqueci minha senha'))
                              ])))))));
  Widget _campo(TextEditingController controller, String label,
          String? Function(String?) valida, {bool segredo = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
              controller: controller,
              decoration: InputDecoration(labelText: label),
              validator: valida,
              keyboardType: segredo ? null : TextInputType.emailAddress,
              obscureText: segredo));
}
