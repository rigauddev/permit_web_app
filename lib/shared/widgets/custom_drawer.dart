import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permit_api_service.dart';
import '../../core/routes/app_routes.dart';
import '../../core/session_expiration.dart';
import '../../data/providers/user_provider.dart';

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
  bool get canManageSystem => isAdmin;
  bool get canManageServices => isAdmin || isManager;
  bool get canAccessServiceOperations => isAdmin || isManager || isOperator;

  Set<String> _activeServices = const {'alvara_evento', 'acesso_orla'};

  @override
  void initState() {
    super.initState();
    _loadActiveServices();
  }

  Future<void> _loadActiveServices() async {
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) return;
      final configs = await PermitApiService().listServiceConfigs(
        accessToken: token,
      );
      if (!mounted) return;
      setState(() {
        _activeServices =
            configs
                .where((item) => item['is_active'] == true)
                .map((item) => item['key'].toString())
                .toSet();
      });
    } catch (_) {
      // Mantém os serviços principais visíveis se a configuração não carregar.
    }
  }

  bool _serviceActive(String key) => _activeServices.contains(key);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';
    final collapsed = widget.compactMode || _collapsed;
    final isTourismBusiness =
        isUser &&
        const {
          'pousada_hotel',
          'restaurante',
          'quiosque',
        }.contains(user?.businessCategory);
    final canManageOrlaDashboard =
        isAdmin ||
        user?.secretaria == 'semop' ||
        user?.secretaria == 'dmtran' ||
        user?.secretaria == 'guarda_civil';
    final canManageOrlaInspection =
        isAdmin ||
        user?.secretaria == 'dmtran' ||
        user?.secretaria == 'guarda_civil';
    final canShowServiceManagement =
        canAccessServiceOperations &&
        (_serviceActive('alvara_evento') || canManageOrlaDashboard);
    const drawerBackground = Color(0xFFF8FBF7);
    final content = SafeArea(
      child: Column(
        children: [
          _DrawerHeader(
            collapsed: collapsed,
            primaryColor: colorScheme.primary,
            textColor: colorScheme.onSurface,
            userName: user?.name ?? '',
            userPhotoUrl: user?.photoUrl ?? '',
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
                  route: AppRoutes.home,
                  currentRoute: currentRoute,
                ),
                if (_serviceActive('acesso_orla') ||
                    _serviceActive('alvara_evento') ||
                    _serviceActive('alvara_funcionamento') ||
                    _serviceActive('iptu'))
                  _DrawerTile(
                    collapsed: collapsed,
                    icon: Icons.design_services_outlined,
                    title: 'Serviços',
                    route: AppRoutes.services,
                    currentRoute: currentRoute,
                  ),
                if (isUser)
                  _DrawerSection(
                    collapsed: collapsed,
                    icon: Icons.folder_special_outlined,
                    title: 'Meus serviços',
                    routes: [
                      AppRoutes.myRequests,
                      AppRoutes.orlaVehicles,
                      if (isTourismBusiness) AppRoutes.orlaGuests,
                      if (isTourismBusiness) AppRoutes.orlaBanners,
                      AppRoutes.favoriteServices,
                    ],
                    currentRoute: currentRoute,
                    children: [
                      const _DrawerSectionItem(
                        'Minhas solicitações',
                        AppRoutes.myRequests,
                      ),
                      if (_serviceActive('acesso_orla'))
                        const _DrawerSectionItem(
                          'Veículos',
                          AppRoutes.orlaVehicles,
                        ),
                      if (isTourismBusiness &&
                          user?.businessCategory == 'pousada_hotel')
                        const _DrawerSectionItem(
                          'Hóspedes',
                          AppRoutes.orlaGuests,
                        ),
                      if (isTourismBusiness)
                        const _DrawerSectionItem(
                          'Banners',
                          AppRoutes.orlaBanners,
                        ),
                      const _DrawerSectionItem(
                        'Favoritos',
                        AppRoutes.favoriteServices,
                      ),
                    ],
                  ),
                if (canShowServiceManagement)
                  _DrawerSection(
                    collapsed: collapsed,
                    icon: Icons.tune_outlined,
                    title: 'Gestão de Serviços',
                    routes: const [
                      AppRoutes.inspections,
                      AppRoutes.secretariaRequests,
                      AppRoutes.verifyEvent,
                      AppRoutes.reports,
                      AppRoutes.eventMap,
                      AppRoutes.contentManagement,
                      AppRoutes.orlaDashboard,
                      AppRoutes.orlaInspection,
                    ],
                    currentRoute: currentRoute,
                    children: [
                      if (_serviceActive('alvara_evento'))
                        const _DrawerSectionGroup(
                          title: 'Alvará',
                          children: [
                            _DrawerSectionGroup(
                              title: 'Alvará de Eventos',
                              children: [
                                _DrawerSectionGroup(
                                  title: 'Gestão do serviço',
                                  children: [
                                    _DrawerSectionItem(
                                      'Solicitações',
                                      AppRoutes.secretariaRequests,
                                    ),
                                    _DrawerSectionItem(
                                      'Vistorias',
                                      AppRoutes.inspections,
                                    ),
                                    _DrawerSectionItem(
                                      'Fiscalização',
                                      AppRoutes.verifyEvent,
                                    ),
                                    _DrawerSectionItem(
                                      'Relatórios',
                                      AppRoutes.reports,
                                    ),
                                    _DrawerSectionItem(
                                      'Mapa de eventos',
                                      AppRoutes.eventMap,
                                    ),
                                    _DrawerSectionItem(
                                      'Configurar mapa de eventos',
                                      AppRoutes.contentManagement,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      if (canManageOrlaDashboard)
                        _DrawerSectionGroup(
                          title: 'Acesso à Orla',
                          children: [
                            const _DrawerSectionItem(
                              'Dashboard',
                              AppRoutes.orlaDashboard,
                            ),
                            if (canManageOrlaInspection)
                              const _DrawerSectionItem(
                                'Fiscalização',
                                AppRoutes.orlaInspection,
                              ),
                          ],
                        ),
                    ],
                  ),
                if (canManageSystem)
                  _DrawerSection(
                    collapsed: collapsed,
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Gestão do Sistema',
                    routes: const [
                      AppRoutes.users,
                      AppRoutes.permissions,
                      AppRoutes.secretarias,
                      AppRoutes.homeContent,
                      AppRoutes.contentManagement,
                    ],
                    currentRoute: currentRoute,
                    children: [
                      const _DrawerSectionItem('Usuários', AppRoutes.users),
                      if (isAdmin)
                        const _DrawerSectionItem(
                          'Tipos de usuário e permissões',
                          AppRoutes.permissions,
                        ),
                      const _DrawerSectionItem(
                        'Secretarias',
                        AppRoutes.secretarias,
                      ),
                      const _DrawerSectionItem(
                        'Conteúdo da página inicial',
                        AppRoutes.homeContent,
                      ),
                      const _DrawerSectionItem(
                        'Mapas e conteúdo turístico',
                        AppRoutes.contentManagement,
                      ),
                    ],
                  ),
                _DrawerSection(
                  collapsed: collapsed,
                  icon: Icons.help_outline,
                  title: 'Ajuda',
                  routes: const [AppRoutes.help, AppRoutes.operatorHelp],
                  currentRoute: currentRoute,
                  children: [
                    const _DrawerSectionItem(
                      'Ajuda do usuário',
                      AppRoutes.help,
                    ),
                    if (!isUser)
                      const _DrawerSectionItem(
                        'Ajuda dos operadores',
                        AppRoutes.operatorHelp,
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
    required this.userPhotoUrl,
    required this.compactMode,
    required this.showToggle,
    required this.onToggle,
  });

  final bool collapsed;
  final Color primaryColor;
  final Color textColor;
  final String userName;
  final String userPhotoUrl;
  final bool compactMode;
  final bool showToggle;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FBF7),
        border: Border(bottom: BorderSide(color: Color(0xFFD8E0D8))),
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
                    color: primaryColor,
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
                backgroundColor: const Color(0xFFE5F4EA),
                backgroundImage:
                    _avatarImage(userPhotoUrl) == null
                        ? null
                        : NetworkImage(_avatarImage(userPhotoUrl)!),
                child:
                    _avatarImage(userPhotoUrl) == null
                        ? Text(
                          _initials(userName),
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                        : null,
              ),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(height: 10),
            Text(
              userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor.withValues(alpha: 0.35)),
              ),
              onPressed:
                  () => Navigator.pushReplacementNamed(context, '/profile'),
              child: const Text('Meu perfil'),
            ),
          ],
        ],
      ),
    );
  }
}

String? _avatarImage(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('/uploads/')) {
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: String.fromEnvironment(
        'API_URL',
        defaultValue: 'http://127.0.0.1:8000',
      ),
    );
    return '$baseUrl$value';
  }
  return null;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'U';
  final first = parts.first.characters.first;
  final second = parts.length > 1 ? parts.last.characters.first : '';
  return (first + second).toUpperCase();
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
        if (route == AppRoutes.home) {
          Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
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
  final List<_DrawerSectionEntry> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final selected = routes.contains(currentRoute);
    const selectedBackground = Color(0xFFE5F4EA);
    const selectedForeground = Color(0xFF0E5F2F);
    const defaultForeground = Color(0xFF26342A);
    if (collapsed) {
      final targetRoute = children.first.primaryRoute;
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
              .map((item) => item.build(context, currentRoute: currentRoute))
              .toList(),
    );
  }
}

abstract class _DrawerSectionEntry {
  const _DrawerSectionEntry();

  List<String> get routes;
  String get primaryRoute;

  Widget build(
    BuildContext context, {
    required String currentRoute,
    int level = 0,
  });
}

class _DrawerSubTile extends StatelessWidget {
  const _DrawerSubTile({
    required this.item,
    required this.currentRoute,
    required this.level,
  });

  final _DrawerSectionItem item;
  final String currentRoute;
  final int level;

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
      contentPadding: EdgeInsets.only(left: 72 + (level * 18), right: 16),
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

class _DrawerSectionItem extends _DrawerSectionEntry {
  const _DrawerSectionItem(this.title, this.route);

  final String title;
  final String route;

  @override
  List<String> get routes => [route];

  @override
  String get primaryRoute => route;

  @override
  Widget build(
    BuildContext context, {
    required String currentRoute,
    int level = 0,
  }) {
    return _DrawerSubTile(item: this, currentRoute: currentRoute, level: level);
  }
}

class _DrawerSectionGroup extends _DrawerSectionEntry {
  const _DrawerSectionGroup({required this.title, required this.children});

  final String title;
  final List<_DrawerSectionEntry> children;

  @override
  List<String> get routes => children.expand((child) => child.routes).toList();

  @override
  String get primaryRoute => children.first.primaryRoute;

  @override
  Widget build(
    BuildContext context, {
    required String currentRoute,
    int level = 0,
  }) {
    final selected = routes.contains(currentRoute);
    const selectedForeground = Color(0xFF0E5F2F);
    const defaultForeground = Color(0xFF26342A);
    return ExpansionTile(
      key: PageStorageKey('$title-$level'),
      initiallyExpanded: selected,
      tilePadding: EdgeInsets.only(left: 56 + (level * 18), right: 16),
      childrenPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        title,
        style: TextStyle(
          color: selected ? selectedForeground : defaultForeground,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      iconColor: selected ? selectedForeground : defaultForeground,
      collapsedIconColor: selected ? selectedForeground : defaultForeground,
      textColor: selectedForeground,
      collapsedTextColor: selected ? selectedForeground : defaultForeground,
      children:
          children
              .map(
                (entry) => entry.build(
                  context,
                  currentRoute: currentRoute,
                  level: level + 1,
                ),
              )
              .toList(),
    );
  }
}
