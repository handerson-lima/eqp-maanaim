import 'package:flutter/material.dart';
import '../../ui/identidade.dart';

import '../auth/auth_service.dart';
import 'consulta_catalogo.dart';
import 'catalogo_service.dart';
import 'seed_catalogo.dart';

/// Shell administrativo responsivo: `NavigationRail` no desktop (≥600px)
/// e `Drawer` no mobile, com papel ativo visível e sign-out.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.onSair, this.catalogo, this.seed});

  final VoidCallback onSair;
  final CatalogoGateway? catalogo;
  final SeedGateway? seed;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _indice = 0;

  static const _destinos = <_Destino>[
    _Destino(
      icone: Icons.list_alt_outlined,
      iconeAtivo: Icons.list_alt,
      rotulo: 'Catálogo',
    ),
    _Destino(
      icone: Icons.cloud_upload_outlined,
      iconeAtivo: Icons.cloud_upload,
      rotulo: 'Seed',
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
                  padding: EdgeInsets.all(24),
                  child: Text('Serviço de catálogo indisponível.'),
                ),
              );
      case 1:
        final seed = widget.seed;
        return seed != null
            ? SeedCatalogo(seed)
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Serviço de seed indisponível.'),
                ),
              );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _chipPapel() => Semantics(
    label: 'Papel ativo: Administrador',
    child: Chip(
      avatar: const Icon(Icons.admin_panel_settings, size: 18),
      label: const Text('Administrador'),
      visualDensity: VisualDensity.compact,
    ),
  );

  Widget _botaoSair({bool expandido = false}) => expandido
      ? SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onSair,
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        )
      : IconButton(
          onPressed: widget.onSair,
          icon: const Icon(Icons.logout),
          tooltip: 'Sair',
        );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktopLayout = constraints.maxWidth >= 600;

      if (desktopLayout) {
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  backgroundColor: marinhoMaanaim,
                  extended: constraints.maxWidth >= 1000,
                  minWidth: 180,
                  selectedIconTheme: const IconThemeData(color: Colors.white),
                  unselectedIconTheme: const IconThemeData(
                    color: Color(0xFFD5E2EF),
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: Color(0xFFD5E2EF),
                  ),
                  indicatorColor: const Color(0xFF285477),
                  selectedIndex: _indice,
                  onDestinationSelected: (i) => setState(() => _indice = i),
                  labelType: constraints.maxWidth >= 1000
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Maanaim',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        IconTheme(
                          data: const IconThemeData(color: Colors.white),
                          child: _botaoSair(),
                        ),
                      ],
                    ),
                  ),
                  destinations: [
                    for (final d in _destinos)
                      NavigationRailDestination(
                        icon: Icon(d.icone),
                        selectedIcon: Icon(d.iconeAtivo),
                        label: Text(d.rotulo),
                      ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        color: Colors.white,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Administração',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            _chipPapel(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Card(margin: EdgeInsets.zero, child: _corpo()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Mobile: AppBar + Drawer
      return Scaffold(
        appBar: AppBar(
          title: const Text('Administração'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chipPapel(),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: marinhoMaanaim,
          child: Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
              listTileTheme: const ListTileThemeData(
                textColor: Colors.white,
                iconColor: Colors.white,
                selectedColor: Colors.white,
                selectedTileColor: Color(0xFF285477),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 48),
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Maanaim',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _chipPapel(),
                      ],
                    ),
                  ),
                  const Divider(),
                  for (var i = 0; i < _destinos.length; i++)
                    ListTile(
                      leading: Icon(
                        _indice == i
                            ? _destinos[i].iconeAtivo
                            : _destinos[i].icone,
                      ),
                      title: Text(_destinos[i].rotulo),
                      selected: _indice == i,
                      onTap: () {
                        setState(() => _indice = i);
                        Navigator.pop(context);
                      },
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _botaoSair(expandido: true),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _corpo(),
      );
    },
  );
}

class _Destino {
  const _Destino({
    required this.icone,
    required this.iconeAtivo,
    required this.rotulo,
  });

  final IconData icone;
  final IconData iconeAtivo;
  final String rotulo;
}
