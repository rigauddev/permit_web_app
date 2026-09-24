import 'package:flutter/material.dart';
import '../../presentation/pages/orla_page.dart';
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
import 'package:permit_web_app/presentation/pages/event_qr_scanner_page.dart';

import '../../features/permit_request/pages/permit_request_page.dart';

class AppRoutes {
  static const String orla = '/orla';
  static const String orlaVehicles = '/orla/veiculos';
  static const String orlaDashboard = '/orla/dashboard';
  static const String orlaInspection = '/orla/fiscalizacao';
  static const String orlaEstablishments = '/orla/estabelecimentos';
  static const String orlaGuests = '/orla/hospedes';
  static const String orlaBanners = '/orla/banners';
  static const String login = '/';
  static const String serverLogin = '/servidor';
  static const String adminLogin = '/administrativo';
  static const String recoveryPassword = '/recovery-password';
  static const String changePassword = '/change-password';
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
  static const String eventMap = '/event-map';
  static const String reports = '/reports';
  static const String questions = '/questions';
  static const String userCreate = '/user-create';
  static const String homeContent = '/home-content';
  static const String contentManagement = '/content-management';
  static const String emailTemplates = '/email-templates';
  static const String secretarias = '/secretarias';
  static const String permissions = '/permissions';
  static const String help = '/help';
  static const String operatorHelp = '/help/operadores';

  static const String permitDashboard = '/permit-dashboard';
  static const String eventPermit = '/event-permit';
  static const String validateEvent = '/validar-evento';
  static const String verifyEvent = '/verificar-evento';

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
              userType: user?.userType ?? '',
              userProfile: user?.profile ?? '',
            ),
      );
    }

    switch (settings.name) {
      case orla:
        if (!_canAccessOrla(user)) return _blockedRoute(user);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const OrlaPage(),
        );
      case orlaVehicles:
        if (!_canAccess(user, const {'cidadao'})) return _blockedRoute(user);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const OrlaPage(section: OrlaSection.vehicles),
        );
      case orlaDashboard:
        if (!_canAccessOrlaStaff(user)) return _blockedRoute(user);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const OrlaPage(section: OrlaSection.dashboard),
        );
      case orlaInspection:
        if (!_canAccessOrlaInspection(user)) return _blockedRoute(user);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const OrlaPage(section: OrlaSection.inspection),
        );
      case orlaEstablishments:
      case orlaGuests:
        if (user == null) return _blockedRoute(user);
        return MaterialPageRoute(
          settings: settings,
          builder:
              (_) => const OrlaPage(
                establishmentsOnly: true,
                section: OrlaSection.guests,
              ),
        );
      case orlaBanners:
        if (user == null) return _blockedRoute(user);
        return MaterialPageRoute(
          settings: settings,
          builder:
              (_) => const OrlaPage(
                establishmentsOnly: true,
                section: OrlaSection.banners,
              ),
        );
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
                eventType: args['eventType'] as Map<String, dynamic>?,
                eventTypes:
                    (args['eventTypes'] as List<dynamic>?)
                        ?.cast<Map<String, dynamic>>() ??
                    const [],
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
                eventType: args['eventType'] as Map<String, dynamic>?,
                eventTypes:
                    (args['eventTypes'] as List<dynamic>?)
                        ?.cast<Map<String, dynamic>>() ??
                    const [],
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
          builder:
              (_) => EventCredentialPage(
                userType: user?.userType ?? '',
                userProfile: user?.profile ?? '',
              ),
        );
      case verifyEvent:
        if (user == null || user.role == 'cidadao') {
          return _blockedRoute(user);
        }
        return MaterialPageRoute(
          settings: settings,
          builder:
              (_) => EventQrScannerPage(
                userType: user.userType,
                userProfile: user.profile,
              ),
        );

      default:
        return null;
    }
  }

  static bool _canAccess(UserModel? user, Set<String> allowedRoles) {
    return user != null && allowedRoles.contains(user.role);
  }

  static bool _canAccessOrla(UserModel? user) {
    if (user == null) return false;
    if (user.role == 'cidadao') return true;
    return _canAccessOrlaStaff(user);
  }

  static bool _canAccessOrlaStaff(UserModel? user) {
    if (user == null) return false;
    if (user.role == 'admin') return true;
    if (user.role == 'gestor_secretaria' ||
        user.role == 'operador_secretaria') {
      return const {
        'semop',
        'dmtran',
        'guarda_civil',
      }.contains(user.secretaria);
    }
    return false;
  }

  static bool _canAccessOrlaInspection(UserModel? user) {
    if (user == null) return false;
    if (user.role == 'admin') return true;
    if (user.role == 'gestor_secretaria' ||
        user.role == 'operador_secretaria') {
      return const {'dmtran', 'guarda_civil'}.contains(user.secretaria);
    }
    return false;
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
