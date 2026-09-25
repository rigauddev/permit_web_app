import 'package:flutter/material.dart';
import 'package:permit_web_app/core/routes/app_routes.dart';

import 'custom_drawer.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.userType,
    required this.body,
    this.userProfile,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor,
  });

  final String userType;
  final String? userProfile;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final currentRoute = ModalRoute.of(context)?.settings.name ?? '';
        final contextualAppBar = _contextualAppBar(context, currentRoute);

        if (isMobile) {
          return Scaffold(
            appBar: const _MobileSafeTopBoundary(),
            drawer: CustomDrawer(
              userType: userType,
              userProfile: userProfile,
              asDrawer: true,
              compactMode: false,
            ),
            drawerEnableOpenDragGesture: true,
            backgroundColor: backgroundColor,
            body: Column(
              children: [
                if (contextualAppBar != null) contextualAppBar,
                Expanded(child: body),
                const _SystemFooter(),
              ],
            ),
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: _MobileBottomNavigationBar(
              userType: userType,
              currentRoute: currentRoute,
            ),
          );
        }

        final menu = CustomDrawer(
          userType: userType,
          userProfile: userProfile,
          asDrawer: false,
          compactMode: false,
        );

        return Scaffold(
          floatingActionButton: floatingActionButton,
          backgroundColor: backgroundColor,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              menu,
              Expanded(
                child: Column(
                  children: [
                    if (contextualAppBar != null) contextualAppBar,
                    Expanded(child: body),
                    const _SystemFooter(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget? _contextualAppBar(BuildContext context, String currentRoute) {
    if (appBar == null || _mainRoutes.contains(currentRoute)) return null;
    if (appBar is! AppBar) {
      return SizedBox(height: appBar!.preferredSize.height, child: appBar);
    }

    final source = appBar! as AppBar;
    return AppBar(
      automaticallyImplyLeading: false,
      leading:
          source.leading ??
          BackButton(onPressed: () => _goBack(context, currentRoute)),
      title: source.title,
      actions: source.actions,
      bottom: source.bottom,
      toolbarHeight: source.toolbarHeight,
      centerTitle: source.centerTitle,
      elevation: source.elevation,
      scrolledUnderElevation: source.scrolledUnderElevation,
      backgroundColor: source.backgroundColor,
      foregroundColor: source.foregroundColor,
      surfaceTintColor: source.surfaceTintColor,
    );
  }

  static const _mainRoutes = {
    AppRoutes.home,
    AppRoutes.services,
    AppRoutes.help,
    AppRoutes.operatorHelp,
  };

  void _goBack(BuildContext context, String currentRoute) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    final parent =
        currentRoute.startsWith('${AppRoutes.orla}/')
            ? AppRoutes.orla
            : currentRoute == AppRoutes.orla
            ? AppRoutes.services
            : AppRoutes.home;
    Navigator.pushReplacementNamed(context, parent);
  }
}

class _MobileSafeTopBoundary extends StatelessWidget
    implements PreferredSizeWidget {
  const _MobileSafeTopBoundary();

  @override
  Size get preferredSize => const Size.fromHeight(1);

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF8FBF7),
    child: SafeArea(
      bottom: false,
      child: Container(
        height: 1,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFD8E0D8))),
        ),
      ),
    ),
  );
}

class _MobileBottomNavigationBar extends StatelessWidget {
  const _MobileBottomNavigationBar({
    required this.userType,
    required this.currentRoute,
  });

  final String userType;
  final String currentRoute;

  static const _homeRoute = AppRoutes.home;

  String get _servicesRoute => AppRoutes.services;

  int get _selectedIndex {
    if (currentRoute == _homeRoute) return 0;
    if (currentRoute == _servicesRoute) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        if (index == 2) {
          Scaffold.of(context).openDrawer();
          return;
        }

        final targetRoute = switch (index) {
          0 => _homeRoute,
          1 => _servicesRoute,
          _ => _homeRoute,
        };
        if (currentRoute == targetRoute) return;
        if (targetRoute == _homeRoute) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            targetRoute,
            (route) => false,
          );
          return;
        }
        Navigator.pushReplacementNamed(context, targetRoute);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Início',
        ),
        NavigationDestination(
          icon: Icon(Icons.design_services_outlined),
          selectedIcon: Icon(Icons.design_services),
          label: 'Serviços',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu),
          selectedIcon: Icon(Icons.menu),
          label: 'Menu',
        ),
      ],
    );
  }
}

class _SystemFooter extends StatelessWidget {
  const _SystemFooter();

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: const Color(0xFF526257),
      fontWeight: FontWeight.w600,
    );
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FBF7),
        border: Border(top: BorderSide(color: Color(0xFFD8E0D8))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 4,
        children: [
          Text(
            'Secretaria de Mobilidade Pública - SEMOP',
            style: textStyle,
            textAlign: TextAlign.center,
          ),
          Text(
            'Desenvolvido por: Matheus Rigaud',
            style: textStyle,
            textAlign: TextAlign.center,
          ),
          Text(
            'Diretor: Rael Costa',
            style: textStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
