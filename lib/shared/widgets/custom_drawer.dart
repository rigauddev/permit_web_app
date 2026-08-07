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
  bool get isOperatorOrManager =>
      widget.userType == 'operador' || widget.userType == 'gestor';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';
    final collapsed = widget.compactMode || _collapsed;
    final content = SafeArea(
      child: Column(
        children: [
          _DrawerHeader(
            collapsed: collapsed,
            primaryColor: primaryColor,
            userName: user?.name ?? '',
            compactMode: widget.compactMode,
            onToggle:
                () => setState(() {
                  _collapsed = !_collapsed;
                  _menuCollapsed = _collapsed;
                }),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
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
                      '/my-requests',
                      '/permit-dashboard',
                      '/event-permit',
                    ],
                    currentRoute: currentRoute,
                    children: const [
                      _DrawerSectionItem('Serviços', '/services'),
                      _DrawerSectionItem('Minhas solicitações', '/my-requests'),
                    ],
                  ),
                if (isOperatorOrManager || isAdmin)
                  _DrawerSection(
                    collapsed: collapsed,
                    icon: Icons.work,
                    title: 'Gestão',
                    routes: const [
                      '/secretaria-requests',
                      '/inspections',
                      '/permit-dashboard',
                      '/event-permit',
                      '/home-content',
                    ],
                    currentRoute: currentRoute,
                    children: [
                      const _DrawerSectionItem(
                        'Solicitações',
                        '/secretaria-requests',
                      ),
                      const _DrawerSectionItem('Vistorias', '/inspections'),
                      if (widget.userType == 'gestor' || isAdmin)
                        const _DrawerSectionItem(
                          'Conteúdo da página inicial',
                          '/home-content',
                        ),
                    ],
                  ),
                if (isAdmin || widget.userType == 'gestor')
                  _DrawerTile(
                    collapsed: collapsed,
                    icon: Icons.people,
                    title: 'Usuários',
                    route: '/users',
                    currentRoute: currentRoute,
                  ),
                if (isAdmin || widget.userType == 'gestor')
                  _DrawerSection(
                    collapsed: collapsed,
                    icon: Icons.groups,
                    title: 'Secretaria',
                    routes: const ['/users'],
                    currentRoute: currentRoute,
                    children: const [
                      _DrawerSectionItem('Gestão de operadores', '/users'),
                      _DrawerSectionItem('Gestão de gestores', '/users'),
                    ],
                  ),
                if (isAdmin)
                  _DrawerSection(
                    collapsed: collapsed,
                    icon: Icons.settings,
                    title: 'Configurações',
                    routes: const ['/users', '/questtions'],
                    currentRoute: currentRoute,
                    children: const [
                      _DrawerSectionItem('Permissões', '/users'),
                      _DrawerSectionItem('Tipo de usuários', '/users'),
                      _DrawerSectionItem('Criar perguntas', '/questtions'),
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
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: collapsed ? 88 : 304,
      decoration: BoxDecoration(
        color:
            Theme.of(context).drawerTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: content,
    );

    if (!widget.asDrawer) {
      return Material(elevation: 1, child: menu);
    }
    return Drawer(width: collapsed ? 88 : 304, child: content);
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.collapsed,
    required this.primaryColor,
    required this.userName,
    required this.compactMode,
    required this.onToggle,
  });

  final bool collapsed;
  final Color primaryColor;
  final String userName;
  final bool compactMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          if (!compactMode)
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
    final color =
        iconColor ??
        (selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).iconTheme.color);
    final tile = ListTile(
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      leading: Icon(icon, color: color),
      title: collapsed ? null : Text(title),
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
    if (collapsed) {
      final targetRoute = children.first.route;
      return Tooltip(
        message: title,
        child: ListTile(
          selected: selected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          leading: Icon(
            icon,
            color:
                selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).iconTheme.color,
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
        color:
            selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).iconTheme.color,
      ),
      title: Text(title),
      collapsedBackgroundColor:
          selected ? Theme.of(context).colorScheme.primaryContainer : null,
      backgroundColor:
          selected
              ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.45)
              : null,
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
    return ListTile(
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      title: Text(item.title),
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
