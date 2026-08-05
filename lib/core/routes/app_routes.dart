import 'package:flutter/material.dart';
// import 'package:permit_web_app/presentation/pages/login_page.dart';
// import 'package:permit_web_app/presentation/pages/recovery_password.dart';
// import 'package:permit_web_app/presentation/pages/home_page.dart';
// import 'package:permit_web_app/presentation/pages/user_profile.dart';
// import 'package:permit_web_app/presentation/pages/users_list.dart';
// import 'package:permit_web_app/presentation/pages/user_registration_page.dart';
// import 'package:permit_web_app/presentation/pages/user_create_page.dart';
// import 'package:permit_web_app/presentation/pages/services.dart';
// import 'package:permit_web_app/presentation/pages/question_page.dart';
// import 'package:permit_web_app/presentation/pages/permit_request_page.dart';
import 'package:permit_web_app/presentation/pages/user_alvara_dashboard.dart';

import '../../features/permit_request/pages/permit_request_page.dart';

class AppRoutes {
  static const String login = '/';
  static const String recoveryPassword = '/recovery-password';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String users = '/users';
  static const String registerUser = '/registrar_usuario';
  static const String createUser = '/cadastro_usuario';
  static const String services = '/services';
  static const String questions = '/questtions';
  static const String userCreate = '/user-create';

  static const String permitDashboard = '/permit-dashboard';
  static const String eventPermit = '/event-permit';

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case permitDashboard:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder:
              (_) => PermitDashboardPage(
                userType: args['userType'],
                userProfile: args['userProfile'],
                permitType: args['permitType'],
                questions: args['questions'],
                forms: args['forms'],
              ),
        );
      case eventPermit:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder:
              (_) => PermitRequestPage(
                userType: args['userType'],
                userProfile: args['userProfile'],
                permitType: args['permitType'],
                questions: args['questions'],
              ),
        );

      default:
        return null;
    }
  }
}
