
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
      '/home': (context) => UserHomePage(userType: user?.userType ?? ''),
      '/profile': (context) => ProfilePage(userType: user?.userType ?? ''),
      '/users': (context) => UsersListPage(userType: user?.userType ?? ''),
      '/registrar_usuario': (context) => UserRegistrationPage(),
      '/cadastro_usuario': (context) => UserCreatePage(userType: user?.userType ?? ''),
      '/services': (context) => ServicesPage(userType: user?.userType ?? '', userProfile: user?.profile ?? ''),
      '/user-create': (context) => UserCreatePage(userType: user?.userType ?? ''),
      // '/permit-dashboard': (context) => PermitDashboardPage(userType: user?.userType ?? '', userProfile: user?.profile ?? '', permitType: '', questions: [], forms: []),
      '/questtions': (context) => PerguntasPage(userType: user?.userType ?? ''),
      '/event-permit': (context) => PermitRequestPage(userType: user?.userType ?? '', userProfile: user?.profile ?? '', permitType: '', questions: []),
    },
    onGenerateRoute: (settings) {
        if (settings.name == '/permit-dashboard') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (ctx) => PermitDashboardPage(
              userType: args['userType'],
              userProfile: args['userProfile'],
              permitType: args['permitType'],
              questions: args['questions'],
              forms: args['forms'],
            ),
          );
        }
        return null;
      },
  );
  }
}
