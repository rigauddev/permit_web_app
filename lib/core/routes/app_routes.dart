import 'package:flutter/material.dart';
import 'package:permit_web_app/data/models/user_model.dart';
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
import 'package:permit_web_app/presentation/pages/question_page.dart';
import 'package:permit_web_app/presentation/pages/user_alvara_dashboard.dart';
import 'package:permit_web_app/presentation/pages/event_credential_page.dart';

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
  static const String favoriteServices = '/favorite-services';
  static const String myRequests = '/my-requests';
  static const String secretariaRequests = '/secretaria-requests';
  static const String inspections = '/inspections';
  static const String questions = '/questions';
  static const String userCreate = '/user-create';
  static const String homeContent = '/home-content';
  static const String secretarias = '/secretarias';

  static const String permitDashboard = '/permit-dashboard';
  static const String eventPermit = '/event-permit';
  static const String validateEvent = '/validar-evento';

  static Route<dynamic>? generateRoute(
    RouteSettings settings,
    UserModel? user,
  ) {
    final routeName = settings.name ?? '';
    if (routeName.startsWith('$validateEvent/')) {
      final uri = Uri.parse(routeName);
      return MaterialPageRoute(
        settings: settings,
        builder:
            (_) => EventCredentialPage(
              publicCode:
                  uri.pathSegments.length > 1 ? uri.pathSegments[1] : '',
              token: uri.queryParameters['t'],
            ),
      );
    }

    switch (settings.name) {
      case permitDashboard:
        if (!_canAccess(user, const {'cidadao'})) {
          return _blockedRoute(user);
        }
        if (settings.arguments is! Map<String, dynamic>) {
          return _blockedRoute(user);
        }
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          settings: settings,
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
        if (!_canAccess(user, const {'cidadao'})) {
          return _blockedRoute(user);
        }
        if (settings.arguments is! Map<String, dynamic>) {
          return _blockedRoute(user);
        }
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          settings: settings,
          builder:
              (_) => PermitRequestPage(
                userType: args['userType'],
                userProfile: args['userProfile'],
                permitType: args['permitType'],
                questions: args['questions'],
              ),
        );
      case questions:
        if (!_canAccess(user, const {'admin', 'gestor_secretaria'})) {
          return _blockedRoute(user);
        }
        return MaterialPageRoute(
          settings: settings,
          builder:
              (_) => PerguntasPage(
                userType: user?.userType ?? 'admin',
                userProfile: user?.profile ?? 'admin',
              ),
        );
      case validateEvent:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const EventCredentialPage(),
        );

      default:
        return null;
    }
  }

  static bool _canAccess(UserModel? user, Set<String> allowedRoles) {
    return user != null && allowedRoles.contains(user.role);
  }

  static Route<dynamic> _blockedRoute(UserModel? user) {
    return MaterialPageRoute(
      builder: (_) => _RouteAccessBlockedPage(loggedIn: user != null),
    );
  }
}

class _RouteAccessBlockedPage extends StatelessWidget {
  const _RouteAccessBlockedPage({required this.loggedIn});

  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  loggedIn ? 'Acesso não permitido' : 'Sessão necessária',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  loggedIn
                      ? 'Seu perfil não possui permissão para acessar esta página.'
                      : 'Faça login novamente para acessar esta área.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed:
                      () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        loggedIn ? AppRoutes.home : AppRoutes.login,
                        (_) => false,
                      ),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    loggedIn ? 'Voltar para início' : 'Ir para login',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
