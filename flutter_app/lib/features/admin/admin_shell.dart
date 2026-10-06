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
    this.pastor,
  });

  final VoidCallback onSair;
  final CatalogoGateway? catalogo;
  final SeedGateway? seed;
  final PessoasGateway? pessoas;
  final VinculosGateway? vinculos;
  final TermosGateway? termos;
  final PastorLocalGateway? pastor;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _indice = 0;

  List<AppNavItem> get _itensNavegacao => [
    const AppNavItem(
      label: 'Catálogo',
      icon: Icons.list_alt_outlined,
      selectedIcon: Icons.list_alt,
    ),
    const AppNavItem(
      label: 'Seed',
      icon: Icons.cloud_upload_outlined,
      selectedIcon: Icons.cloud_upload,
    ),
    const AppNavItem(
      label: 'Pessoas e Papéis',
      icon: Icons.manage_accounts_outlined,
      selectedIcon: Icons.manage_accounts,
    ),
    const AppNavItem(
      label: 'Vínculos e Responsáveis',
      icon: Icons.handshake_outlined,
      selectedIcon: Icons.handshake,
    ),
    const AppNavItem(
      label: 'Termos',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
    ),
    if (widget.pastor != null)
      const AppNavItem(
        label: 'Fila do Pastor',
        icon: Icons.how_to_reg_outlined,
        selectedIcon: Icons.how_to_reg,
      ),
  ];

  Widget _corpo() {
    switch (_indice) {
      case 0:
        final catalogo = widget.catalogo;
        return catalogo != null
            ? ConsultaCatalogo(catalogo)
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.cardPadding),
                  child: Text('Serviço de catálogo indisponível.'),
                ),
              );
      case 1:
        final seed = widget.seed;
        return seed != null
            ? SeedCatalogo(seed)
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.cardPadding),
                  child: Text('Serviço de seed indisponível.'),
                ),
              );
      case 2:
        final pessoas = widget.pessoas;
        return pessoas != null
            ? PessoasPapeis(pessoas)
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.cardPadding),
                  child: Text('Serviço de pessoas e papéis indisponível.'),
                ),
              );
      case 3:
        final vinculos = widget.vinculos;
        return vinculos != null
            ? VinculosResponsaveis(vinculos)
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.cardPadding),
                  child: Text('Serviço de vínculos indisponível.'),
                ),
              );
      case 4:
        final termos = widget.termos;
        return termos != null
            ? TermosScreen(gateway: termos)
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.cardPadding),
                  child: Text('Serviço de termos indisponível.'),
                ),
              );
      case 5:
        final pastor = widget.pastor;
        return pastor != null
            ? FilaPastorScreen(gateway: pastor, onSair: widget.onSair)
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.cardPadding),
                  child: Text('Serviço pastoral indisponível.'),
                ),
              );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      items: _itensNavegacao,
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
