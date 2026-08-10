import 'package:flutter/material.dart';
import 'package:permit_web_app/core/routes/app_routes.dart';

import 'custom_appbar.dart';
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

        if (isMobile) {
          return Scaffold(
            appBar: _buildMobileAppBar(context, appBar, currentRoute),
            drawer: CustomDrawer(
              userType: userType,
              userProfile: userProfile,
              asDrawer: true,
              compactMode: false,
            ),
            drawerEnableOpenDragGesture: true,
            backgroundColor: backgroundColor,
            body: body,
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
                    if (appBar != null) appBar!,
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget? _buildMobileAppBar(
    BuildContext context,
    PreferredSizeWidget? appBar,
    String currentRoute,
  ) {
    if (appBar == null) return null;

    if (appBar is AppBar) {
      final canNavigateBack =
          currentRoute != AppRoutes.home && Navigator.canPop(context);
      return AppBar(
        title: appBar.title,
        leading:
            appBar.leading ?? (canNavigateBack ? const BackButton() : null),
        actions: appBar.actions,
        centerTitle: appBar.centerTitle,
        elevation: appBar.elevation,
        backgroundColor: appBar.backgroundColor,
        foregroundColor: appBar.foregroundColor,
        iconTheme: appBar.iconTheme,
        titleTextStyle: appBar.titleTextStyle,
        toolbarHeight: appBar.toolbarHeight,
        bottom: appBar.bottom,
        automaticallyImplyLeading: false,
      );
    }

    if (appBar is CustomAppBar) {
      final canNavigateBack =
          currentRoute != AppRoutes.home && Navigator.canPop(context);
      return CustomAppBar(
        title: appBar.title,
        actions: appBar.actions,
        hideDrawerButton: !canNavigateBack,
      );
    }

    return appBar;
  }
}

class _MobileBottomNavigationBar extends StatelessWidget {
  const _MobileBottomNavigationBar({
    required this.userType,
    required this.currentRoute,
  });

  final String userType;
  final String currentRoute;

  static const _homeRoute = AppRoutes.home;

  String get _favoritesRoute {
    if (userType == 'cidadao' || userType == 'user') {
      return AppRoutes.favoriteServices;
    }
    return AppRoutes.secretariaRequests;
  }

  int get _selectedIndex {
    if (currentRoute == _homeRoute) return 0;
    if (currentRoute == _favoritesRoute) return 1;
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
          1 => _favoritesRoute,
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
          icon: Icon(Icons.favorite_border),
          selectedIcon: Icon(Icons.favorite),
          label: 'Favoritos',
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
