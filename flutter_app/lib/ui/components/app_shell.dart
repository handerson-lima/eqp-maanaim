import 'package:flutter/material.dart';

import '../tokens.dart';
import 'status_chips.dart';
import 'logo_maanaim.dart';

/// Item de navegação padronizado para a sidebar e gaveta (Drawer).
class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.badge,
    this.route,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final Widget? badge;
  final String? route;
  final bool enabled;
}

/// Sidebar institucional Maanaim (fundo navy-900, largura ~220px no desktop).
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.items,
    this.selectedIndex = 0,
    this.onDestinationSelected,
    this.onLogout,
    this.footer,
    this.isCompact = false,
  });

  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final VoidCallback? onLogout;
  final Widget? footer;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final width = isCompact ? 72.0 : AppGeometry.sidebarDesktopWidth;

    return Container(
      width: width,
      color: AppColors.navy900,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header com Logo institucional
            _SidebarHeader(isCompact: isCompact),
            const Divider(color: AppColors.navy800, height: 1),
            const SizedBox(height: AppSpacing.s12),

            // Itens de navegação
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? AppSpacing.s8 : AppSpacing.s12,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s4),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = index == selectedIndex;

                  return _SidebarItemTile(
                    item: item,
                    isSelected: isSelected,
                    isCompact: isCompact,
                    onTap: item.enabled
                        ? () => onDestinationSelected?.call(index)
                        : null,
                  );
                },
              ),
            ),

            // Footer / Botão de Sair
            if (footer != null) ...[
              const Divider(color: AppColors.navy800, height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s12),
                child: footer!,
              ),
            ],
            if (onLogout != null) ...[
              const Divider(color: AppColors.navy800, height: 1),
              Padding(
                padding: EdgeInsets.all(isCompact ? AppSpacing.s8 : AppSpacing.s12),
                child: _LogoutTile(
                  isCompact: isCompact,
                  onLogout: onLogout!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.isCompact});
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        constraints: const BoxConstraints(minHeight: AppGeometry.topBarHeight),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: LogoMaanaim.compacta(size: 38),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: AppGeometry.topBarHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          LogoMaanaim.sidebar(height: 38),
          const SizedBox(width: AppSpacing.s8),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Maanaim',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: AppTypography.fontFallbacks,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Gestão de Voluntários',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: AppTypography.fontFallbacks,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFD5E2EF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItemTile extends StatelessWidget {
  const _SidebarItemTile({
    required this.item,
    required this.isSelected,
    required this.isCompact,
    this.onTap,
  });

  final AppNavItem item;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconData = (isSelected && item.selectedIcon != null)
        ? item.selectedIcon!
        : item.icon;

    final tile = Material(
      color: isSelected ? AppColors.navy800 : Colors.transparent,
      borderRadius: AppGeometry.buttonBorderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppGeometry.buttonBorderRadius,
        hoverColor: isSelected ? AppColors.navy800 : const Color(0xFF0C3352),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppGeometry.minTouchTarget),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 0 : AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          alignment: isCompact ? Alignment.center : Alignment.centerLeft,
          child: isCompact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      iconData,
                      size: 20,
                      color: isSelected ? Colors.white : const Color(0xFFD5E2EF),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontFamilyFallback: AppTypography.fontFallbacks,
                        fontSize: 9,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : const Color(0xFFD5E2EF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      iconData,
                      size: 20,
                      color: isSelected ? Colors.white : const Color(0xFFD5E2EF),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontFamilyFallback: AppTypography.fontFallbacks,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? Colors.white : const Color(0xFFD5E2EF),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.badge != null) ...[
                      const SizedBox(width: AppSpacing.s8),
                      item.badge!,
                    ],
                  ],
                ),
        ),
      ),
    );

    if (isCompact) {
      return Tooltip(
        message: item.label,
        waitDuration: const Duration(milliseconds: 300),
        child: tile,
      );
    }

    return tile;
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({
    required this.isCompact,
    required this.onLogout,
  });

  final bool isCompact;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: Colors.transparent,
      borderRadius: AppGeometry.buttonBorderRadius,
      child: InkWell(
        onTap: onLogout,
        borderRadius: AppGeometry.buttonBorderRadius,
        hoverColor: const Color(0xFF0C3352),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppGeometry.minTouchTarget),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 0 : AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          alignment: isCompact ? Alignment.center : Alignment.centerLeft,
          child: isCompact
              ? const Icon(
                  Icons.logout,
                  size: 20,
                  color: Color(0xFFD5E2EF),
                )
              : const Row(
                  children: [
                    Icon(
                      Icons.logout,
                      size: 20,
                      color: Color(0xFFD5E2EF),
                    ),
                    SizedBox(width: AppSpacing.s12),
                    Text(
                      'Sair',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontFamilyFallback: AppTypography.fontFallbacks,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFD5E2EF),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    if (isCompact) {
      return Tooltip(
        message: 'Sair',
        child: tile,
      );
    }
    return tile;
  }
}

/// Barra superior institucional com fundo branco, borda fina e identidade do usuário.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title,
    this.userName,
    this.userRole,
    this.userChurch,
    this.userStatus,
    this.userAvatar,
    this.actions,
    this.leading,
    this.showMenuButton = false,
    this.onMenuPressed,
  });

  final Widget? title;
  final String? userName;
  final String? userRole;
  final String? userChurch;
  final String? userStatus;
  final Widget? userAvatar;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showMenuButton;
  final VoidCallback? onMenuPressed;

  @override
  Size get preferredSize => const Size.fromHeight(AppGeometry.topBarHeight);

  @override
  Widget build(BuildContext context) {
    final hasUserIdentity = userName != null;

    final userSubtitle = [
      if (userRole != null && userRole!.isNotEmpty) userRole!,
      if (userChurch != null && userChurch!.isNotEmpty) userChurch!,
    ].join(' • ');

    return Container(
      constraints: const BoxConstraints(minHeight: AppGeometry.topBarHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: AppGeometry.borderWidth,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s4,
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textPrimary),
              tooltip: 'Abrir menu de navegação',
              onPressed: onMenuPressed,
            ),
            const SizedBox(width: AppSpacing.s4),
          ] else if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.s4),
          ],

          if (title != null)
            Expanded(child: title!)
          else if (showMenuButton)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: LogoMaanaim.topBar(height: 28),
              ),
            )
          else
            const Spacer(),

          // Identidade do usuário
          if (hasUserIdentity) ...[
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  userAvatar ??
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.blue50,
                        child: Text(
                          userName!.isNotEmpty ? userName![0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blue600,
                          ),
                        ),
                      ),
                  const SizedBox(width: AppSpacing.s8),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName!,
                          style: AppTypography.label.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (userSubtitle.isNotEmpty)
                          Text(
                            userSubtitle,
                            style: AppTypography.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (userStatus != null &&
                      userStatus!.isNotEmpty &&
                      MediaQuery.of(context).size.width >= 600) ...[
                    const SizedBox(width: AppSpacing.s8),
                    StatusChip(status: userStatus!),
                  ],
                ],
              ),
            ),
          ],

          // Ações à direita
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.s8),
            ...actions!,
          ],
        ],
      ),
    );
  }
}

/// Orquestrador responsivo do layout institucional.
/// - Desktop (≥1024px): Sidebar fixa à esquerda (220px) -> TopBar -> Conteúdo fluido sobre fundo neutro.
/// - Tablet (600–1023px): Sidebar compacta recolhível com ícones e tooltips.
/// - Mobile (<600px): Sidebar vira Drawer acionado por menu hambúrguer na TopBar.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.body,
    required this.items,
    this.selectedIndex = 0,
    this.onDestinationSelected,
    this.title,
    this.userName,
    this.userRole,
    this.userChurch,
    this.userStatus,
    this.userAvatar,
    this.topBarActions,
    this.topBarLeading,
    this.onLogout,
    this.footer,
    this.floatingActionButton,
  });

  final Widget body;
  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final Widget? title;
  final String? userName;
  final String? userRole;
  final String? userChurch;
  final String? userStatus;
  final Widget? userAvatar;
  final List<Widget>? topBarActions;
  final Widget? topBarLeading;
  final VoidCallback? onLogout;
  final Widget? footer;
  final Widget? floatingActionButton;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
        final isMobile = constraints.maxWidth < 600;

        // TopBar institucional compartilhada
        final topBar = AppTopBar(
          title: widget.title,
          userName: widget.userName,
          userRole: widget.userRole,
          userChurch: widget.userChurch,
          userStatus: widget.userStatus,
          userAvatar: widget.userAvatar,
          actions: widget.topBarActions,
          leading: widget.topBarLeading,
          showMenuButton: isMobile,
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        );

        // Sidebar para Desktop e Tablet
        Widget? sidebarWidget;
        if (isDesktop) {
          sidebarWidget = AppSidebar(
            items: widget.items,
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onDestinationSelected,
            onLogout: widget.onLogout,
            footer: widget.footer,
            isCompact: false,
          );
        } else if (isTablet) {
          sidebarWidget = AppSidebar(
            items: widget.items,
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onDestinationSelected,
            onLogout: widget.onLogout,
            footer: widget.footer,
            isCompact: true,
          );
        }

        // Drawer para Mobile
        final drawer = isMobile
            ? Drawer(
                backgroundColor: AppColors.navy900,
                child: AppSidebar(
                  items: widget.items,
                  selectedIndex: widget.selectedIndex,
                  onDestinationSelected: (index) {
                    Navigator.of(context).maybePop();
                    widget.onDestinationSelected?.call(index);
                  },
                  onLogout: widget.onLogout != null
                      ? () {
                          Navigator.of(context).maybePop();
                          widget.onLogout!();
                        }
                      : null,
                  footer: widget.footer,
                  isCompact: false,
                ),
              )
            : null;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          drawer: drawer,
          floatingActionButton: widget.floatingActionButton,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sidebarWidget != null) sidebarWidget,
              Expanded(
                child: Column(
                  children: [
                    topBar,
                    Expanded(
                      child: Container(
                        color: AppColors.background,
                        child: widget.body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
