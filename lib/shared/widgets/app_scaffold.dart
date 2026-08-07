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
        final useFixedMenu = constraints.maxWidth >= 900;
        final menu = CustomDrawer(
          userType: userType,
          userProfile: userProfile,
          asDrawer: false,
        );

        if (useFixedMenu) {
          return Scaffold(
            backgroundColor: backgroundColor,
            body: Row(
              children: [
                menu,
                Expanded(
                  child: Scaffold(
                    appBar: appBar,
                    floatingActionButton: floatingActionButton,
                    backgroundColor: backgroundColor,
                    body: body,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          drawer: CustomDrawer(userType: userType, userProfile: userProfile),
          floatingActionButton: floatingActionButton,
          backgroundColor: backgroundColor,
          body: body,
        );
      },
    );
  }
}
