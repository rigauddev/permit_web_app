import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/user_provider.dart';

class CustomDrawer extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const CustomDrawer({
    super.key,
    required this.userType,
    this.userProfile,
    this.asDrawer = true,
    this.compactMode = false,
  });

  final String userType;
  final String? userProfile;
  final bool asDrawer;
  final bool compactMode;

  @override
  ConsumerState<CustomDrawer> createState() => _CustomDrawerState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CustomDrawerState extends ConsumerState<CustomDrawer> {
  static bool _menuCollapsed = false;
  late bool _collapsed = _menuCollapsed;

  bool get isAdmin => widget.userType == 'admin';
  bool get isUser => widget.userType == 'user';
  bool get isManager => widget.userType == 'gestor';
  bool get isOperator => widget.userType == 'operador';
  bool get isOperatorOrManager => isOperator || isManager;
  bool get canManageSystem => isAdmin || isManager;
  bool get canManageServices => isAdmin || isManager;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';
    final collapsed = widget.compactMode || _collapsed;
    const drawerBackground = Color(0xFFF8FBF7);
    final content = SafeArea(
      child: Column(
        children: [
          _DrawerHeader(
            collapsed: collapsed,
            primaryColor: colorScheme.primary,
            textColor: colorScheme.onPrimary,
            userName: user?.name ?? '',
            compactMode: widget.compactMode,
            showToggle:
                !widget.asDrawer &&
                !Theme.of(context).platform.toString().contains('iOS'),
            onToggle:
                () => setState(() {
                  _collapsed = !_collapsed;
                  _menuCollapsed = _collapsed;
                }),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerTile(
                  collapsed: collapsed,
                  icon: Icons.home,
                  title: 'Início',
                  route: '/home',
                  currentRoute: currentRoute,
                ),
                if (isUser)
                  _DrawerSection(
                    collapsed: collapsed,
                    icon: Icons.event,
                    title: 'Serviços',
                    routes: const [
                      '/services',
                      '/favorite-services',
                      '/my-requests',
                    ],
                    currentRoute: currentRoute,
                    children: const [
                      _DrawerSectionItem('Serviços', '/services'),
                      _DrawerSectionItem('Favoritos', '/favorite-services'),
                      _DrawerSectionItem('Minhas solicitações', '/my-requests'),
                    ],
                  ),
                if (isOperatorOrManager || isAdmin)
                  _DrawerSection(
                    collapsed: collapsed,
                    icon: Icons.assignment_outlined,
                    title: 'Atendimento',
                    routes: const ['/secretaria-requests', '/inspections'],
                    currentRoute: currentRoute,
                    children: const [
                      _DrawerSectionItem(
                        'Central de solicitações',
                        '/secretaria-requests',
                      ),
                      _DrawerSectionItem('Vistorias', '/inspections'),
                    ],
                  ),
                if (canManageServices)
                  _DrawerSection(
                    collapsed: collapsed,
                    icon: Icons.design_services_outlined,
                    title: 'Gestão de Serviços',
                    routes: const ['/questions'],
                    currentRoute: currentRoute,
                    children: const [
                      _DrawerSectionItem('Perguntas e regras', '/questions'),
                    ],
                  ),
                if (canManageSystem)
                  _DrawerSection(
                    collapsed: collapsed,
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Gestão do Sistema',
                    routes: const [
                      '/users',
                      '/permissions',
                      '/secretarias',
                      '/home-content',
                    ],
                    currentRoute: currentRoute,
                    children: [
                      const _DrawerSectionItem('Usuários', '/users'),
                      if (isAdmin)
                        const _DrawerSectionItem(
                          'Tipos de usuário e permissões',
                          '/permissions',
                        ),
                      const _DrawerSectionItem('Secretarias', '/secretarias'),
                      const _DrawerSectionItem(
                        'Conteúdo da página inicial',
                        '/home-content',
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          _DrawerTile(
            collapsed: collapsed,
            icon: Icons.logout,
            iconColor: Colors.red,
            title: 'Sair',
            route: '/',
            currentRoute: currentRoute,
            replaceAll: true,
          ),
        ],
      ),
    );

    final menu = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      width: collapsed ? 84 : 280,
      decoration: BoxDecoration(
        color: drawerBackground,
        border: Border(right: BorderSide(color: const Color(0xFFD8E0D8))),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(color: drawerBackground, child: content),
    );

    if (widget.asDrawer) {
      return Drawer(child: menu);
    }

    return menu;
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.collapsed,
    required this.primaryColor,
    required this.textColor,
    required this.userName,
    required this.compactMode,
    required this.showToggle,
    required this.onToggle,
  });

  final bool collapsed;
  final Color primaryColor;
  final Color textColor;
  final String userName;
  final bool compactMode;
  final bool showToggle;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withValues(alpha: 0.92), primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          if (showToggle)
            Row(
              mainAxisAlignment:
                  collapsed ? MainAxisAlignment.center : MainAxisAlignment.end,
              children: [
                Tooltip(
                  message: collapsed ? 'Expandir menu' : 'Ocultar menu',
                  child: IconButton(
                    color: Colors.white,
                    icon: Icon(
                      collapsed
                          ? Icons.keyboard_double_arrow_right
                          : Icons.keyboard_double_arrow_left,
                    ),
                    onPressed: onToggle,
                  ),
                ),
              ],
            ),
          Tooltip(
            message: 'Meu perfil',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.pushReplacementNamed(context, '/profile'),
              child: CircleAvatar(
                radius: collapsed ? 22 : 42,
                backgroundImage: const AssetImage('assets/images/avatar.jpg'),
              ),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(height: 10),
            Text(
              userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
              onPressed:
                  () => Navigator.pushReplacementNamed(context, '/profile'),
              icon: const Icon(Icons.person_outline, size: 18),
              label: const Text('Meu perfil'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.collapsed,
    required this.icon,
    required this.title,
    required this.route,
    required this.currentRoute,
    this.iconColor,
    this.replaceAll = false,
  });

  final bool collapsed;
  final IconData icon;
  final String title;
  final String route;
  final String currentRoute;
  final Color? iconColor;
  final bool replaceAll;

  @override
  Widget build(BuildContext context) {
    final selected = currentRoute == route;
    const selectedBackground = Color(0xFFE5F4EA);
    const selectedForeground = Color(0xFF0E5F2F);
    const defaultForeground = Color(0xFF26342A);
    final color =
        iconColor ?? (selected ? selectedForeground : defaultForeground);
    final tile = ListTile(
      selected: selected,
      selectedColor: selectedForeground,
      textColor: defaultForeground,
      iconColor: defaultForeground,
      selectedTileColor: selectedBackground,
      leading: Icon(icon, color: color),
      title:
          collapsed
              ? null
              : Text(
                title,
                style: TextStyle(
                  color: selected ? selectedForeground : defaultForeground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
      horizontalTitleGap: collapsed ? 0 : 16,
      minLeadingWidth: collapsed ? 0 : null,
      contentPadding:
          collapsed
              ? const EdgeInsets.symmetric(horizontal: 28)
              : const EdgeInsets.symmetric(horizontal: 16),
      onTap: () {
        if (replaceAll) {
          Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
          return;
        }
        if (currentRoute == route) {
          if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
            Navigator.pop(context);
          }
          return;
        }
        Navigator.pushReplacementNamed(context, route);
      },
    );

    if (!collapsed) return tile;
    return Tooltip(message: title, child: tile);
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection({
    required this.collapsed,
    required this.icon,
    required this.title,
    required this.routes,
    required this.currentRoute,
    required this.children,
  });

  final bool collapsed;
  final IconData icon;
  final String title;
  final List<String> routes;
  final String currentRoute;
  final List<_DrawerSectionItem> children;

  @override
  Widget build(BuildContext context) {
    final selected = routes.contains(currentRoute);
    const selectedBackground = Color(0xFFE5F4EA);
    const selectedForeground = Color(0xFF0E5F2F);
    const defaultForeground = Color(0xFF26342A);
    if (collapsed) {
      final targetRoute = children.first.route;
      return Tooltip(
        message: title,
        child: ListTile(
          selected: selected,
          selectedColor: selectedForeground,
          iconColor: defaultForeground,
          selectedTileColor: selectedBackground,
          leading: Icon(
            icon,
            color: selected ? selectedForeground : defaultForeground,
          ),
          horizontalTitleGap: 0,
          minLeadingWidth: 0,
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          onTap: () {
            if (currentRoute == targetRoute) {
              if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                Navigator.pop(context);
              }
              return;
            }
            Navigator.pushReplacementNamed(context, targetRoute);
          },
        ),
      );
    }

    return ExpansionTile(
      initiallyExpanded: selected,
      leading: Icon(
        icon,
        color: selected ? selectedForeground : defaultForeground,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? selectedForeground : defaultForeground,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      iconColor: selected ? selectedForeground : defaultForeground,
      collapsedIconColor: selected ? selectedForeground : defaultForeground,
      textColor: selectedForeground,
      collapsedTextColor: selected ? selectedForeground : defaultForeground,
      collapsedBackgroundColor: selected ? selectedBackground : null,
      backgroundColor: selected ? selectedBackground : null,
      children:
          children
              .map(
                (item) =>
                    _DrawerSubTile(item: item, currentRoute: currentRoute),
              )
              .toList(),
    );
  }
}

class _DrawerSubTile extends StatelessWidget {
  const _DrawerSubTile({required this.item, required this.currentRoute});

  final _DrawerSectionItem item;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final selected = currentRoute == item.route;
    const selectedBackground = Color(0xFFE5F4EA);
    const selectedForeground = Color(0xFF0E5F2F);
    const defaultForeground = Color(0xFF26342A);
    return ListTile(
      selected: selected,
      selectedColor: selectedForeground,
      textColor: defaultForeground,
      selectedTileColor: selectedBackground,
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      title: Text(
        item.title,
        style: TextStyle(
          color: selected ? selectedForeground : defaultForeground,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: () {
        if (currentRoute == item.route) {
          if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
            Navigator.pop(context);
          }
          return;
        }
        Navigator.pushReplacementNamed(context, item.route);
      },
    );
  }
}

class _DrawerSectionItem {
  const _DrawerSectionItem(this.title, this.route);

  final String title;
  final String route;
}
