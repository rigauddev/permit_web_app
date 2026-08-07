import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permit_web_app/core/routes/app_routes.dart';
import 'package:permit_web_app/core/themes/customer_theme.dart';
import 'package:permit_web_app/data/providers/user_provider.dart';

import 'features/services/receita_municipal/ui/receita_municipal_services_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/home_content_page.dart';
import 'presentation/pages/my_requests_page.dart';
import 'presentation/pages/recovery_password.dart';
import 'presentation/pages/user_profile.dart';
import 'presentation/pages/users_list.dart';
import 'presentation/pages/user_registration_page.dart';
import 'presentation/pages/user_create_page.dart';
import 'presentation/pages/question_page.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema de Serviços da Prefeitura',
      theme: customTheme,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.recoveryPassword: (context) => RecoveryPassword(),
        AppRoutes.home:
            (context) => UserHomePage(userType: user?.userType ?? ''),
        AppRoutes.profile:
            (context) => ProfilePage(userType: user?.userType ?? ''),
        AppRoutes.users:
            (context) => UsersListPage(userType: user?.userType ?? ''),
        AppRoutes.registerUser: (context) => const UserRegistrationPage(),
        AppRoutes.createUser:
            (context) => UserCreatePage(userType: user?.userType ?? ''),
        AppRoutes.userCreate:
            (context) => UserCreatePage(userType: user?.userType ?? ''),
        AppRoutes.homeContent:
            (context) => HomeContentPage(userType: user?.userType ?? ''),
        AppRoutes.services:
            (context) => ReceitaMunicipalServicesPage(
              userType: user?.userType ?? '',
              userProfile: user?.profile ?? '',
            ),
        AppRoutes.myRequests:
            (context) => MyRequestsPage(userType: user?.userType ?? ''),
        AppRoutes.questions:
            (context) => PerguntasPage(userType: user?.userType ?? ''),
      },
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
