import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
import 'features/voluntario/inicio_voluntario_screen.dart';
import 'features/voluntario/minha_ficha_screen.dart';
import 'features/voluntario/solicitacao_equipe_screen.dart';
import 'features/voluntario/renovacao_screen.dart';
import 'features/voluntario/participacao_service.dart';
import 'features/termo/termo_service.dart';
import 'features/pastor/pastor_service.dart';
import 'features/responsavel_equipe/responsavel_equipe_service.dart';
import 'features/coordenador/coordenador_service.dart';
import 'features/coordenador/fila_coordenador_screen.dart';
import 'features/renovacao/dashboard_renovacao_service.dart';
import 'features/auditoria/auditoria_service.dart';
import 'features/privacidade/retencao_service.dart';
import 'features/admin/solicitacoes_pendentes_service.dart';
import 'features/auth/contexto_acesso_model.dart';
import 'features/auth/contexto_acesso_service.dart';
import 'features/auth/acesso_negado_screen.dart';
import 'features/auth/seletor_destino_capacidades.dart';
import 'routes/app_router.dart';
import 'routes/navegacao_url.dart';
import 'features/pastor/fila_pastor_screen.dart';
import 'features/responsavel_equipe/fila_responsavel_equipe_screen.dart';
import 'features/renovacao/dashboard_renovacao_screen.dart';
import 'features/perfil/editar_perfil_screen.dart';
import 'features/perfil/perfil_service.dart';

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
    final storageBucket = const String.fromEnvironment('FIREBASE_STORAGE_BUCKET').isNotEmpty
        ? const String.fromEnvironment('FIREBASE_STORAGE_BUCKET')
        : (projectId.isNotEmpty ? '$projectId.firebasestorage.app' : 'eqp-maanaim.firebasestorage.app');
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
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
      FirebaseStorage.instance.useStorageEmulator(host, 9199);
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
      dashboardRenovacao: FirebaseDashboardRenovacaoGateway(functions),
      auditoria: CloudFunctionsAuditoriaGateway(functions: functions),
      retencao: CloudFunctionsRetencaoGateway(functions: functions),
      solicitacoesPendentes:
          FirebaseSolicitacoesPendentesGateway(functions: functions),
      contextoAcesso: FirebaseContextoAcessoGateway(functions),
      rotaInicial: rotaInicialDoNavegador(),
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
    this.contextoAcesso,
    this.rotaInicial,
    this.catalogo,
    this.seed,
    this.pessoas,
    this.vinculos,
    this.termos,
    this.solicitacoesPendentes,
    this.ficha,
    this.participacao,
    this.termoVoluntario,
    this.pastor,
    this.responsavelEquipe,
    this.coordenador,
    this.dashboardRenovacao,
    this.auditoria,
    this.retencao,
  });
  final AuthService auth;
  final ContextoAcessoGateway? contextoAcesso;
  final String? rotaInicial;
  final CatalogoGateway? catalogo;
  final SeedGateway? seed;
  final PessoasGateway? pessoas;
  final VinculosGateway? vinculos;
  final TermosGateway? termos;
  final SolicitacoesPendentesGateway? solicitacoesPendentes;
  final FichaGateway? ficha;
  final ParticipacaoGateway? participacao;
  final TermoGateway? termoVoluntario;
  final PastorLocalGateway? pastor;
  final ResponsavelEquipeGateway? responsavelEquipe;
  final CoordenadorGateway? coordenador;
  final DashboardRenovacaoGateway? dashboardRenovacao;
  final AuditoriaRelatoriosGateway? auditoria;
  final RetencaoGateway? retencao;
  @override
  Widget build(BuildContext c) => MaterialApp(
    title: 'Maanaim',
    theme: temaMaanaim(),
    home: RaizSessao(
      auth,
      contextoAcesso: contextoAcesso,
      rotaInicial: rotaInicial,
      catalogo: catalogo,
      seed: seed,
      pessoas: pessoas,
      vinculos: vinculos,
      termos: termos,
      solicitacoesPendentes: solicitacoesPendentes,
      ficha: ficha,
      participacao: participacao,
      termoVoluntario: termoVoluntario,
      pastor: pastor,
      responsavelEquipe: responsavelEquipe,
      coordenador: coordenador,
      dashboardRenovacao: dashboardRenovacao,
      auditoria: auditoria,
      retencao: retencao,
    ),
  );
}

/// Raiz da aplicação: ouve `authStateChanges` para restaurar sessão
/// ao recarregar e rotear automaticamente por capacidades.
class RaizSessao extends StatefulWidget {
  const RaizSessao(
    this.auth, {
    super.key,
    this.contextoAcesso,
    this.rotaInicial,
    this.catalogo,
    this.seed,
    this.pessoas,
    this.vinculos,
    this.termos,
    this.solicitacoesPendentes,
    this.ficha,
    this.participacao,
    this.termoVoluntario,
    this.pastor,
    this.responsavelEquipe,
    this.coordenador,
    this.dashboardRenovacao,
    this.auditoria,
    this.retencao,
  });
  final AuthService auth;
  final ContextoAcessoGateway? contextoAcesso;
  final String? rotaInicial;
  final CatalogoGateway? catalogo;
  final SeedGateway? seed;
  final PessoasGateway? pessoas;
  final VinculosGateway? vinculos;
  final TermosGateway? termos;
  final SolicitacoesPendentesGateway? solicitacoesPendentes;
  final FichaGateway? ficha;
  final ParticipacaoGateway? participacao;
  final TermoGateway? termoVoluntario;
  final PastorLocalGateway? pastor;
  final ResponsavelEquipeGateway? responsavelEquipe;
  final CoordenadorGateway? coordenador;
  final DashboardRenovacaoGateway? dashboardRenovacao;
  final AuditoriaRelatoriosGateway? auditoria;
  final RetencaoGateway? retencao;

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
        contextoAcesso: widget.contextoAcesso,
        rotaInicial: widget.rotaInicial,
        catalogo: widget.catalogo,
        seed: widget.seed,
        pessoas: widget.pessoas,
        vinculos: widget.vinculos,
        termos: widget.termos,
        solicitacoesPendentes: widget.solicitacoesPendentes,
        ficha: widget.ficha,
        participacao: widget.participacao,
        termoVoluntario: widget.termoVoluntario,
        pastor: widget.pastor,
        responsavelEquipe: widget.responsavelEquipe,
        coordenador: widget.coordenador,
        dashboardRenovacao: widget.dashboardRenovacao,
        auditoria: widget.auditoria,
        retencao: widget.retencao,
      );
    },
  );
}

class AreaAutenticada extends StatefulWidget {
  const AreaAutenticada(
    this.auth, {
    super.key,
    this.contextoAcesso,
    this.rotaInicial,
    this.catalogo,
    this.seed,
    this.pessoas,
    this.vinculos,
    this.termos,
    this.solicitacoesPendentes,
    this.ficha,
    this.participacao,
    this.termoVoluntario,
    this.pastor,
    this.responsavelEquipe,
    this.coordenador,
    this.dashboardRenovacao,
    this.auditoria,
    this.retencao,
    this.perfilService,
  });
  final AuthService auth;
  final ContextoAcessoGateway? contextoAcesso;
  final String? rotaInicial;
  final CatalogoGateway? catalogo;
  final SeedGateway? seed;
  final PessoasGateway? pessoas;
  final VinculosGateway? vinculos;
  final TermosGateway? termos;
  final SolicitacoesPendentesGateway? solicitacoesPendentes;
  final FichaGateway? ficha;
  final ParticipacaoGateway? participacao;
  final TermoGateway? termoVoluntario;
  final PastorLocalGateway? pastor;
  final ResponsavelEquipeGateway? responsavelEquipe;
  final CoordenadorGateway? coordenador;
  final DashboardRenovacaoGateway? dashboardRenovacao;
  final AuditoriaRelatoriosGateway? auditoria;
  final RetencaoGateway? retencao;
  final IPerfilService? perfilService;
  @override
  State<AreaAutenticada> createState() => _AreaAutenticadaState();
}

class _AreaAutenticadaState extends State<AreaAutenticada> {
  late Future<ContextoAcesso> _autorizacao = _resolverContexto();
  late String _destinoAtual =
      AppRotas.sanitizarRota(widget.rotaInicial ?? AppRotas.raiz);
  ContextoAcessoService? _contextoService;
  bool _exibirRenovacaoVoluntario = false;

  @override
  void initState() {
    super.initState();
    registrarMudancaDeRotaNoNavegador(_aoMudarRotaNoNavegador);
  }

  void _aoMudarRotaNoNavegador() {
    if (!mounted) return;
    final rota = AppRotas.sanitizarRota(rotaInicialDoNavegador());
    if (rota == _destinoAtual) return;
    setState(() => _destinoAtual = rota);
  }

  Future<ContextoAcesso> _resolverContexto() async {
    try {
      final gateway = widget.contextoAcesso ??
          FirebaseContextoAcessoGateway(FirebaseFunctions.instance);
      final service = ContextoAcessoService(gateway);
      _contextoService = service;
      return await service.carregarContexto();
    } catch (_) {
      // Fallback resiliente com base nas claims autenticadas ou testes unitários
      final ehAdmin = await widget.auth.possuiAdministracao();
      final ehCoord = await widget.auth.possuiCoordenacao();
      return ContextoAcesso(
        uid: widget.auth.emailAtual ?? 'usuario',
        email: widget.auth.emailAtual,
        capacidades: {
          CapacidadeAcesso.voluntario,
          if (ehAdmin) CapacidadeAcesso.administrador,
          if (ehCoord) CapacidadeAcesso.coordenador,
          if (widget.pastor != null && !ehAdmin && !ehCoord) CapacidadeAcesso.pastorLocal,
          if (widget.responsavelEquipe != null && !ehAdmin && !ehCoord) CapacidadeAcesso.responsavelEquipe,
        },
        ehAdministrador: ehAdmin,
        ehCoordenador: ehCoord,
        ehPastorLocal: widget.pastor != null && !ehAdmin && !ehCoord,
        ehResponsavelEquipe: widget.responsavelEquipe != null && !ehAdmin && !ehCoord,
        ehVoluntario: true,
        igrejas: const [],
        equipes: const [],
      );
    }
  }

  void _retentar() => setState(() {
    _autorizacao = _contextoService?.carregarContexto(forcar: true) ??
        _resolverContexto();
  });

  void _navegarPara(String destino) {
    final rota = AppRotas.sanitizarRota(destino);
    atualizarRotaNoNavegador(rota);
    setState(() {
      _destinoAtual = rota;
      if (rota != AppRotas.renovacao) {
        _exibirRenovacaoVoluntario = false;
      }
    });
  }

  void _navegarParaRenovacaoVoluntario() {
    atualizarRotaNoNavegador(AppRotas.renovacao);
    setState(() {
      _destinoAtual = AppRotas.renovacao;
      _exibirRenovacaoVoluntario = true;
    });
  }

  Future<void> _sair() async {
    _contextoService?.invalidar();
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
  Widget build(BuildContext context) => FutureBuilder<ContextoAcesso>(
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
                label: 'Carregando contexto de acesso',
                child: const CircularProgressIndicator(),
              ),
            ),
          ),
        );
      }
      final contexto = estado.data!;
      final avaliacao = const AppRouteGuard().avaliar(_destinoAtual, contexto);

      if (avaliacao is RotaNaoAutorizada) {
        return AcessoNegadoScreen(
          capacidadeNecessaria: avaliacao.capacidadeFaltante,
          onVoltar: () => _navegarPara(
            contexto.temMultiplosDestinos ? AppRotas.destinos : AppRotas.raiz,
          ),
          onSair: _sair,
        );
      }

      // Despacha pelo caminho sanitizado/autorizado pelo guard, não pela string
      // bruta (que poderia conter query/filtro). (review 8.3)
      final destino =
          avaliacao is RotaAutorizada ? avaliacao.caminho : _destinoAtual;

      // Se usuário tem múltiplos papéis e está na raiz ou pediu o seletor de destinos:
      if (destino == AppRotas.destinos ||
          (destino == AppRotas.raiz && contexto.temMultiplosDestinos)) {
        return SeletorDestinoCapacidades(
          contexto: contexto,
          onNavegarPastor: () => _navegarPara(AppRotas.pastor),
          onNavegarEquipe: () => _navegarPara(AppRotas.equipe),
          onNavegarCoordenador: () => _navegarPara(AppRotas.coordenador),
          onNavegarAdmin: () => _navegarPara(AppRotas.admin),
          onNavegarVoluntario: () => _navegarPara(AppRotas.inicio),
          onNavegarRenovacao: () => _navegarPara(AppRotas.renovacao),
          onSair: _sair,
        );
      }

      // Administrador Geral
      if (destino == AppRotas.admin ||
          (destino == AppRotas.raiz &&
              contexto.ehAdministrador &&
              !contexto.temMultiplosDestinos)) {
        return AdminShell(
          onSair: _sair,
          catalogo: widget.catalogo,
          seed: widget.seed,
          pessoas: widget.pessoas,
          vinculos: widget.vinculos,
          termos: widget.termos,
          solicitacoesPendentes: widget.solicitacoesPendentes,
          pastor: widget.pastor,
          responsavelEquipe: widget.responsavelEquipe,
          coordenador: widget.coordenador,
          dashboardRenovacao: widget.dashboardRenovacao,
          auditoria: widget.auditoria,
          retencao: widget.retencao,
        );
      }

      String? nomeAuth;
      try {
        nomeAuth = FirebaseAuth.instance.currentUser?.displayName?.trim();
      } catch (_) {}
      final nomeValido = (nomeAuth != null &&
              nomeAuth.isNotEmpty &&
              !nomeAuth.contains('@') &&
              nomeAuth.toLowerCase() != 'voluntário')
          ? nomeAuth
          : null;

      // Destino do corpo no shell único
      Widget corpo;
      if (destino == AppRotas.perfil) {
        corpo = EditarPerfilScreen(
          service: widget.perfilService,
          dentroDeShell: true,
          onVoltar: () => _navegarPara(
            contexto.ehPastorLocal
                ? AppRotas.pastor
                : (contexto.ehResponsavelEquipe
                    ? AppRotas.equipe
                    : (contexto.ehCoordenador
                        ? AppRotas.coordenador
                        : AppRotas.minhaFicha)),
          ),
        );
      } else if ((destino == AppRotas.pastor ||
              (destino == AppRotas.raiz &&
                  contexto.ehPastorLocal &&
                  !contexto.ehAdministrador &&
                  !contexto.ehCoordenador)) &&
          widget.pastor != null) {
        corpo = FilaPastorScreen(
          gateway: widget.pastor!,
          dashboardRenovacaoGateway: widget.dashboardRenovacao,
          onSair: _sair,
          dentroDeShell: true,
        );
      } else if ((destino == AppRotas.equipe ||
              (destino == AppRotas.raiz &&
                  contexto.ehResponsavelEquipe &&
                  !contexto.ehAdministrador &&
                  !contexto.ehCoordenador)) &&
          widget.responsavelEquipe != null) {
        corpo = FilaResponsavelEquipeScreen(
          gateway: widget.responsavelEquipe!,
          dashboardRenovacaoGateway: widget.dashboardRenovacao,
          onSair: _sair,
          dentroDeShell: true,
        );
      } else if ((destino == AppRotas.coordenador ||
              (destino == AppRotas.raiz &&
                  contexto.ehCoordenador &&
                  !contexto.ehAdministrador)) &&
          widget.coordenador != null) {
        corpo = FilaCoordenadorScreen(
          gateway: widget.coordenador!,
          dashboardRenovacaoGateway: widget.dashboardRenovacao,
          onSair: _sair,
          dentroDeShell: true,
        );
      } else if (destino == AppRotas.renovacao) {
        final apenasVoluntario = !contexto.ehPastorLocal &&
            !contexto.ehResponsavelEquipe &&
            !contexto.ehCoordenador &&
            !contexto.ehAdministrador;

        if (apenasVoluntario ||
            _exibirRenovacaoVoluntario ||
            widget.dashboardRenovacao == null) {
          corpo = RenovacaoScreen(
            participacaoGateway: _obterParticipacaoGateway(),
            onVoltar: () => _navegarPara(AppRotas.inicio),
            onIrParaInicio: () => _navegarPara(AppRotas.inicio),
            onIrParaMinhaFicha: () => _navegarPara(AppRotas.minhaFicha),
            dentroDeShell: true,
          );
        } else {
          corpo = DashboardRenovacaoScreen(
            gateway: widget.dashboardRenovacao!,
            papelInicial: contexto.ehCoordenador
                ? PapelDashboard.coordenador
                : (contexto.ehPastorLocal
                    ? PapelDashboard.pastorLocal
                    : (contexto.ehResponsavelEquipe
                        ? PapelDashboard.responsavelEquipe
                        : PapelDashboard.voluntario)),
            onManifestarVoluntario: (_) => _navegarParaRenovacaoVoluntario(),
            onSair: _sair,
          );
        }
      } else if (destino == AppRotas.solicitarEquipe) {
        // Voluntário (Solicitação de Equipe - S03 em Etapas)
        corpo = SolicitacaoEquipeScreen(
          fichaGateway: _obterFichaGateway(),
          catalogoGateway: _obterCatalogoGateway(),
          participacaoGateway: _obterParticipacaoGateway(),
          termoGateway: _obterTermoGateway(),
          onConcluido: () => _navegarPara(AppRotas.inicio),
        );
      } else if (destino == AppRotas.minhaFicha) {
        // Voluntário (Minha Ficha - S03/S09)
        corpo = MinhaFichaScreen(
          fichaGateway: _obterFichaGateway(),
          catalogoGateway: _obterCatalogoGateway(),
          participacaoGateway: _obterParticipacaoGateway(),
          termoGateway: _obterTermoGateway(),
          onSair: _sair,
          userName: nomeValido,
          dentroDeShell: true,
        );
      } else {
        // Voluntário (Início - S02 Dashboard)
        corpo = InicioVoluntarioScreen(
          fichaGateway: _obterFichaGateway(),
          participacaoGateway: _obterParticipacaoGateway(),
          catalogoGateway: _obterCatalogoGateway(),
          termoGateway: _obterTermoGateway(),
          onNavegarMinhaFicha: () => _navegarPara(AppRotas.minhaFicha),
          onNavegarRenovacao: _navegarParaRenovacaoVoluntario,
          onNavegarSolicitarEquipe: () => _navegarPara(AppRotas.solicitarEquipe),
          userName: nomeValido,
          dentroDeShell: true,
        );
      }

      final menuItens = _construirItensMenu(contexto);
      int indiceSelecionado =
          menuItens.indexWhere((it) => it.route == destino);
      if (indiceSelecionado < 0) {
        if (destino == AppRotas.raiz) {
          final rotaPadrao = contexto.ehPastorLocal
              ? AppRotas.pastor
              : (contexto.ehResponsavelEquipe
                  ? AppRotas.equipe
                  : (contexto.ehCoordenador
                      ? AppRotas.coordenador
                      : (contexto.ehAdministrador
                          ? AppRotas.admin
                          : AppRotas.inicio)));
          indiceSelecionado = menuItens.indexWhere((it) => it.route == rotaPadrao);
        }
        if (indiceSelecionado < 0) {
          indiceSelecionado = 0;
        }
      }

      return AppShell(
        items: menuItens,
        selectedIndex: indiceSelecionado,
        onDestinationSelected: (idx) {
          final rota = menuItens[idx].route;
          if (rota != null) {
            _navegarPara(rota);
          }
        },
        userName: nomeValido ?? 'Voluntário',
        userRole: _obterPapelExibicao(contexto),
        userStatus: 'ATIVA',
        onLogout: _sair,
        topBarActions: [
          IconButton(
            tooltip: 'Editar Perfil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => _navegarPara(AppRotas.perfil),
          ),
        ],
        body: corpo,
      );
    },
  );

  List<AppNavItem> _construirItensMenu(ContextoAcesso contexto) {
    final itens = <AppNavItem>[];
    final rotasAdicionadas = <String>{};

    void adicionar(AppNavItem item) {
      if (item.route != null && rotasAdicionadas.contains(item.route)) return;
      if (item.route != null) rotasAdicionadas.add(item.route!);
      itens.add(item);
    }

    if (contexto.ehVoluntario) {
      adicionar(
        const AppNavItem(
          label: 'Início',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          route: AppRotas.inicio,
        ),
      );
      adicionar(
        const AppNavItem(
          label: 'Minha Ficha',
          icon: Icons.badge_outlined,
          selectedIcon: Icons.badge,
          route: AppRotas.minhaFicha,
        ),
      );
    }

    if (contexto.ehPastorLocal) {
      adicionar(
        const AppNavItem(
          label: 'Fila do Pastor',
          icon: Icons.how_to_reg_outlined,
          selectedIcon: Icons.how_to_reg,
          route: AppRotas.pastor,
        ),
      );
    }

    if (contexto.ehResponsavelEquipe) {
      adicionar(
        const AppNavItem(
          label: 'Fila da Equipe',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups,
          route: AppRotas.equipe,
        ),
      );
    }

    if (contexto.ehCoordenador) {
      adicionar(
        const AppNavItem(
          label: 'Fila do Coordenador',
          icon: Icons.verified_outlined,
          selectedIcon: Icons.verified,
          route: AppRotas.coordenador,
        ),
      );
    }

    if (contexto.ehPastorLocal ||
        contexto.ehResponsavelEquipe ||
        contexto.ehCoordenador ||
        contexto.ehAdministrador) {
      adicionar(
        const AppNavItem(
          label: 'Renovações',
          icon: Icons.autorenew_outlined,
          selectedIcon: Icons.autorenew,
          route: AppRotas.renovacao,
        ),
      );
    }

    if (contexto.ehAdministrador) {
      adicionar(
        const AppNavItem(
          label: 'Administração',
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          route: AppRotas.admin,
        ),
      );
    }

    if (contexto.temMultiplosDestinos) {
      adicionar(
        const AppNavItem(
          label: 'Alternar Área',
          icon: Icons.swap_horiz,
          selectedIcon: Icons.swap_horiz,
          route: AppRotas.destinos,
        ),
      );
    }

    adicionar(
      const AppNavItem(
        label: 'Meu Perfil',
        icon: Icons.account_circle_outlined,
        selectedIcon: Icons.account_circle,
        route: AppRotas.perfil,
      ),
    );

    return itens;
  }

  String _obterPapelExibicao(ContextoAcesso contexto) {
    if (contexto.ehAdministrador) return 'Administrador';
    if (contexto.ehCoordenador) return 'Coordenador Geral';
    if (contexto.ehPastorLocal && contexto.ehResponsavelEquipe) {
      return 'Pastor Local / Resp. Equipe';
    }
    if (contexto.ehPastorLocal) return 'Pastor Local';
    if (contexto.ehResponsavelEquipe) return 'Responsável de Equipe';
    return 'Voluntário';
  }


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
    int? expectedVersion,
    String? commandId,
  }) async {}
}

class _CatalogoMemoriaFallback implements CatalogoGateway {
  const _CatalogoMemoriaFallback();

  @override
  Future<CatalogoResposta> consultar({String? termo}) async =>
      const CatalogoResposta(igrejas: [], equipes: []);

  @override
  Future<void> alternarStatusIgreja({
    required String commandId,
    required String igrejaId,
    required bool ativo,
    String? correlationId,
  }) async {}

  @override
  Future<void> alternarStatusEquipe({
    required String commandId,
    required String equipeId,
    required bool ativo,
    String? correlationId,
  }) async {}

  @override
  Future<void> salvarIgreja({
    required String commandId,
    required String nome,
    required String codigo,
    required int expectedVersion,
    String? igrejaId,
    String? correlationId,
  }) async {}

  @override
  Future<void> salvarEquipe({
    required String commandId,
    required String nome,
    required int expectedVersion,
    String? equipeId,
    String? correlationId,
  }) async {}
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
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          if (e.code == 'email-already-in-use') {
            aviso =
                'Este e-mail já possui cadastro. Volte e clique em "Entrar" para acessar sua conta.';
          } else if (e.code == 'weak-password') {
            aviso =
                'A senha escolhida é fraca. Utilize pelo menos 6 caracteres.';
          } else {
            aviso =
                'Não foi possível concluir o cadastro (${e.message ?? e.code}).';
          }
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          aviso = e.message ??
              'Não foi possível concluir agora. Revise os campos e tente novamente.';
        });
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

  Stream<QuerySnapshot<Map<String, dynamic>>>? _obterStreamIgrejas() {
    try {
      return FirebaseFirestore.instance
          .collection('igrejas')
          .where('ativo', isEqualTo: true)
          .snapshots();
    } catch (_) {
      return null;
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
                formatters: [CpfInputFormatter()],
              ),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _obterStreamIgrejas(),
                builder: (_, s) {
                  if (s.connectionState == ConnectionState.none) {
                    return const SizedBox.shrink();
                  }
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
              const SizedBox(height: AppSpacing.s12),
              SecondaryButton(
                label: 'Cadastre-se',
                isFullWidth: true,
                onPressed: carregando
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Cadastro(widget.auth),
                          ),
                        ),
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
