import 'package:flutter/material.dart';
import '../../ui/identidade.dart';

import '../auth/auth_service.dart';
import 'consulta_catalogo.dart';
import 'catalogo_service.dart';
import 'pessoas_papeis.dart';
import 'pessoas_service.dart';
import 'seed_catalogo.dart';
import 'termos_screen.dart';
import 'termos_service.dart';
import 'vinculos_responsaveis.dart';
import 'vinculos_service.dart';
import '../pastor/fila_pastor_screen.dart';
import '../pastor/pastor_service.dart';
import '../responsavel_equipe/fila_responsavel_equipe_screen.dart';
import '../responsavel_equipe/responsavel_equipe_service.dart';
import '../coordenador/fila_coordenador_screen.dart';
import '../coordenador/coordenador_service.dart';
import '../renovacao/dashboard_renovacao_service.dart';
import '../renovacao/dashboard_renovacao_screen.dart';
import '../auditoria/auditoria_service.dart';
import '../auditoria/auditoria_relatorios_screen.dart';
import '../privacidade/retencao_service.dart';
import '../privacidade/conformidade_retencao_screen.dart';
import 'painel_solicitacoes_pendentes_screen.dart';
import 'solicitacoes_pendentes_service.dart';

class _AbaAdmin {
  const _AbaAdmin({required this.item, required this.builder});
  final AppNavItem item;
  final Widget Function() builder;
}

/// Shell administrativo responsivo construído sobre o [AppShell] institucional:
/// Sidebar no desktop (≥1024px), sidebar compacta no tablet (600–1023px) e
/// Drawer responsivo no mobile (<600px), com identidade do usuário e ações na TopBar.
class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.onSair,
    this.catalogo,
    this.seed,
    this.pessoas,
    this.vinculos,
    this.termos,
    this.solicitacoesPendentes,
    this.pastor,
    this.responsavelEquipe,
    this.coordenador,
    this.dashboardRenovacao,
    this.auditoria,
    this.retencao,
  });

  final VoidCallback onSair;
  final CatalogoGateway? catalogo;
  final SeedGateway? seed;
  final PessoasGateway? pessoas;
  final VinculosGateway? vinculos;
  final TermosGateway? termos;
  final SolicitacoesPendentesGateway? solicitacoesPendentes;
  final PastorLocalGateway? pastor;
  final ResponsavelEquipeGateway? responsavelEquipe;
  final CoordenadorGateway? coordenador;
  final DashboardRenovacaoGateway? dashboardRenovacao;
  final AuditoriaRelatoriosGateway? auditoria;
  final RetencaoGateway? retencao;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _indice = 0;

  List<_AbaAdmin> get _abas => [
    _AbaAdmin(
      item: const AppNavItem(
        label: 'Catálogo',
        icon: Icons.list_alt_outlined,
        selectedIcon: Icons.list_alt,
      ),
      builder: () => widget.catalogo != null
          ? ConsultaCatalogo(widget.catalogo!)
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.cardPadding),
                child: Text('Serviço de catálogo indisponível.'),
              ),
            ),
    ),
    _AbaAdmin(
      item: const AppNavItem(
        label: 'Seed',
        icon: Icons.cloud_upload_outlined,
        selectedIcon: Icons.cloud_upload,
      ),
      builder: () => widget.seed != null
          ? SeedCatalogo(widget.seed!)
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.cardPadding),
                child: Text('Serviço de seed indisponível.'),
              ),
            ),
    ),
    _AbaAdmin(
      item: const AppNavItem(
        label: 'Pessoas e Papéis',
        icon: Icons.manage_accounts_outlined,
        selectedIcon: Icons.manage_accounts,
      ),
      builder: () => widget.pessoas != null
          ? PessoasPapeis(widget.pessoas!)
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.cardPadding),
                child: Text('Serviço de pessoas e papéis indisponível.'),
              ),
            ),
    ),
    _AbaAdmin(
      item: const AppNavItem(
        label: 'Vínculos e Responsáveis',
        icon: Icons.handshake_outlined,
        selectedIcon: Icons.handshake,
      ),
      builder: () => widget.vinculos != null
          ? VinculosResponsaveis(widget.vinculos!)
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.cardPadding),
                child: Text('Serviço de vínculos indisponível.'),
              ),
            ),
    ),
    _AbaAdmin(
      item: const AppNavItem(
        label: 'Termos',
        icon: Icons.description_outlined,
        selectedIcon: Icons.description,
      ),
      builder: () => widget.termos != null
          ? TermosScreen(gateway: widget.termos!)
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.cardPadding),
                child: Text('Serviço de termos indisponível.'),
              ),
            ),
    ),
    _AbaAdmin(
      item: const AppNavItem(
        label: 'Solicitações por Equipe',
        icon: Icons.pending_actions_outlined,
        selectedIcon: Icons.pending_actions,
      ),
      builder: () => widget.solicitacoesPendentes != null
          ? PainelSolicitacoesPendentesScreen(gateway: widget.solicitacoesPendentes!)
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.cardPadding),
                child: Text('Serviço de solicitações indisponível.'),
              ),
            ),
    ),
    if (widget.pastor != null)
      _AbaAdmin(
        item: const AppNavItem(
          label: 'Fila do Pastor',
          icon: Icons.how_to_reg_outlined,
          selectedIcon: Icons.how_to_reg,
        ),
        builder: () => FilaPastorScreen(
          gateway: widget.pastor!,
          onSair: widget.onSair,
          dentroDeShell: true,
        ),
      ),
    if (widget.responsavelEquipe != null)
      _AbaAdmin(
        item: const AppNavItem(
          label: 'Fila da Equipe',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups,
        ),
        builder: () => FilaResponsavelEquipeScreen(
          gateway: widget.responsavelEquipe!,
          onSair: widget.onSair,
          dentroDeShell: true,
        ),
      ),
    if (widget.coordenador != null)
      _AbaAdmin(
        item: const AppNavItem(
          label: 'Fila do Coordenador',
          icon: Icons.verified_outlined,
          selectedIcon: Icons.verified,
        ),
        builder: () => FilaCoordenadorScreen(
          gateway: widget.coordenador!,
          dashboardRenovacaoGateway: widget.dashboardRenovacao,
          onSair: widget.onSair,
          dentroDeShell: true,
        ),
      ),
    _AbaAdmin(
      item: const AppNavItem(
        label: 'Renovações',
        icon: Icons.autorenew_outlined,
        selectedIcon: Icons.autorenew,
      ),
      builder: () => DashboardRenovacaoScreen(
        gateway: widget.dashboardRenovacao ?? MemoriaDashboardRenovacaoGateway(),
        papelInicial: widget.coordenador != null
            ? PapelDashboard.coordenador
            : (widget.pastor != null
                ? PapelDashboard.pastorLocal
                : (widget.responsavelEquipe != null
                    ? PapelDashboard.responsavelEquipe
                    : PapelDashboard.voluntario)),
        onSair: widget.onSair,
      ),
    ),
    _AbaAdmin(
      item: const AppNavItem(
        label: 'Auditoria & Relatórios',
        icon: Icons.history_edu_outlined,
        selectedIcon: Icons.history_edu,
      ),
      builder: () => AuditoriaRelatoriosScreen(
        gateway: widget.auditoria ?? MemoriaAuditoriaGateway(),
        onSair: widget.onSair,
      ),
    ),
    _AbaAdmin(
      item: const AppNavItem(
        label: 'Retenção e Privacidade',
        icon: Icons.privacy_tip_outlined,
        selectedIcon: Icons.privacy_tip,
      ),
      builder: () => ConformidadeRetencaoScreen(
        gateway: widget.retencao ?? MemoriaRetencaoGateway(),
        onSair: widget.onSair,
      ),
    ),
  ];

  Widget _corpo() {
    final abas = _abas;
    if (_indice >= abas.length) {
      return const SizedBox.shrink();
    }
    return abas[_indice].builder();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      items: _abas.map((a) => a.item).toList(),
      selectedIndex: _indice,
      onDestinationSelected: (i) => setState(() => _indice = i),
      userName: 'Administração',
      userRole: 'Administrador',
      userStatus: 'ATIVA',
      onLogout: widget.onSair,
      topBarActions: [
        IconButton(
          onPressed: widget.onSair,
          icon: const Icon(Icons.logout, color: AppColors.textSecondary),
          tooltip: 'Sair',
        ),
      ],
      body: _corpo(),
    );
  }
}
