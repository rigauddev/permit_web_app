import 'package:flutter/material.dart';

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
        final compactMenu = constraints.maxWidth < 900;
        final menu = CustomDrawer(
          userType: userType,
          userProfile: userProfile,
          asDrawer: false,
          compactMode: compactMenu,
        );

        return Scaffold(
          floatingActionButton: floatingActionButton,
          backgroundColor: backgroundColor,
          body: Row(
            children: [
              menu,
              Expanded(
                child: Scaffold(
                  appBar: appBar,
                  backgroundColor: backgroundColor,
                  body: body,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
