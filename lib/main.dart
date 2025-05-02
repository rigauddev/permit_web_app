import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permit_web_app/core/themes/customer_theme.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/permit_request_page.dart';
import 'presentation/pages/question_page.dart';
import 'presentation/pages/services.dart';
import 'presentation/pages/user_alvara_dashboard.dart';
import 'presentation/pages/user_profile.dart';
import 'presentation/pages/user_registration_page.dart';
import 'data/providers/user_provider.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/users_list.dart';
import 'presentation/pages/user_create_page.dart';

void main() {
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema de Alvarás',
      theme: customTheme,
      initialRoute: '/',
      routes: {
      '/': (context) => LoginPage(),
      '/home': (context) => UserHomePage(userType: user?.tipoUsuario ?? ''),
      '/profile': (context) => ProfilePage(userType: user?.tipoUsuario ?? ''),
      '/users': (context) => UsersListPage(userType: user?.tipoUsuario ?? ''),
      '/registrar_usuario': (context) => UserRegistrationPage(),
      '/cadastro_usuario': (context) => UserCreatePage(userType: user?.tipoUsuario ?? ''),
      '/services': (context) => ServicesPage(userType: user?.tipoUsuario ?? '', userProfile: user?.profile ?? ''),
      '/user-create': (context) => UserCreatePage(userType: user?.tipoUsuario ?? ''),
      '/permit-dashboard': (context) => PermitDashboardPage(userType: user?.tipoUsuario ?? '', userProfile: user?.profile ?? '', permitType: '', questions: []),
      '/questtions': (context) => PerguntasPage(userType: user?.tipoUsuario ?? ''),
      '/event-permit': (context) => PermitRequestPage(userType: user?.tipoUsuario ?? '', userProfile: user?.profile ?? '', permitType: '', questions: []),
    },
  );
  }
}
