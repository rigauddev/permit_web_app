import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permit_web_app/core/routes/app_routes.dart';
import 'package:permit_web_app/core/themes/customer_theme.dart';
import 'package:permit_web_app/data/models/user_model.dart';
import 'package:permit_web_app/data/providers/user_provider.dart';

import 'features/services/receita_municipal/ui/receita_municipal_services_page.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/home_content_page.dart';
import 'presentation/pages/my_requests_page.dart';
import 'presentation/pages/permissions_page.dart';
import 'presentation/pages/inspection_schedule_page.dart';
import 'presentation/pages/recovery_password.dart';
import 'presentation/pages/secretaria_requests_page.dart';
import 'presentation/pages/user_profile.dart';
import 'presentation/pages/users_list.dart';
import 'presentation/pages/user_registration_page.dart';
import 'presentation/pages/user_create_page.dart';
import 'presentation/pages/question_page.dart';
import 'presentation/pages/secretarias_page.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    return _SessionBootstrap(user: user, child: _AppRouter(user: user));
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter({required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema de Serviços da Prefeitura',
      theme: customTheme,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.recoveryPassword: (context) => RecoveryPassword(),
        AppRoutes.home:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {
                'admin',
                'gestor_secretaria',
                'operador_secretaria',
                'cidadao',
              },
              child: UserHomePage(userType: user?.userType ?? ''),
            ),
        AppRoutes.profile:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {
                'admin',
                'gestor_secretaria',
                'operador_secretaria',
                'cidadao',
              },
              child: ProfilePage(userType: user?.userType ?? ''),
            ),
        AppRoutes.users:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {'admin', 'gestor_secretaria'},
              child: UsersListPage(userType: user?.userType ?? ''),
            ),
        AppRoutes.registerUser: (context) => const UserRegistrationPage(),
        AppRoutes.createUser:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {'admin', 'gestor_secretaria'},
              child: UserCreatePage(userType: user?.userType ?? ''),
            ),
        AppRoutes.userCreate:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {'admin', 'gestor_secretaria'},
              child: UserCreatePage(userType: user?.userType ?? ''),
            ),
        AppRoutes.homeContent:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {'admin', 'gestor_secretaria'},
              child: HomeContentPage(userType: user?.userType ?? ''),
            ),
        AppRoutes.secretarias:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {'admin', 'gestor_secretaria'},
              child: SecretariasPage(userType: user?.userType ?? ''),
            ),
        AppRoutes.permissions:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {'admin'},
              child: PermissionsPage(userType: user?.userType ?? ''),
            ),
        AppRoutes.services:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {'cidadao'},
              child: ReceitaMunicipalServicesPage(
                userType: user?.userType ?? '',
                userProfile: user?.profile ?? '',
              ),
            ),
        AppRoutes.favoriteServices:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {'cidadao'},
              child: FavoriteServicesPage(
                userType: user?.userType ?? '',
                userProfile: user?.profile ?? '',
              ),
            ),
        AppRoutes.myRequests:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {'cidadao'},
              child: MyRequestsPage(userType: user?.userType ?? ''),
            ),
        AppRoutes.secretariaRequests:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {
                'admin',
                'gestor_secretaria',
                'operador_secretaria',
              },
              child: SecretariaRequestsPage(userType: user?.userType ?? ''),
            ),
        AppRoutes.inspections:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {
                'admin',
                'gestor_secretaria',
                'operador_secretaria',
              },
              child: InspectionSchedulePage(userType: user?.userType ?? ''),
            ),
        AppRoutes.questions:
            (context) => _GuardedRoute(
              user: user,
              allowedRoles: const {'admin', 'gestor_secretaria'},
              child: PerguntasPage(userType: user?.userType ?? ''),
            ),
      },
      onGenerateRoute: (settings) => AppRoutes.generateRoute(settings, user),
    );
  }
}

class _SessionBootstrap extends ConsumerStatefulWidget {
  const _SessionBootstrap({required this.user, required this.child});

  final UserModel? user;
  final Widget child;

  @override
  ConsumerState<_SessionBootstrap> createState() => _SessionBootstrapState();
}

class _SessionBootstrapState extends ConsumerState<_SessionBootstrap> {
  static const _storage = FlutterSecureStorage();
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final expiresAtText = await _storage.read(key: 'session_expires_at');
    final token = await _storage.read(key: 'access_token');
    final userJson = await _storage.read(key: 'user');
    final expiresAt =
        expiresAtText == null ? null : DateTime.tryParse(expiresAtText);
    if (token == null ||
        userJson == null ||
        expiresAt == null ||
        expiresAt.toUtc().isBefore(DateTime.now().toUtc())) {
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'user');
      await _storage.delete(key: 'session_expires_at');
      if (mounted) setState(() => _checked = true);
      return;
    }
    if (widget.user == null) {
      ref
          .read(userProvider.notifier)
          .setUser(
            UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>),
          );
    }
    if (mounted) setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return widget.child;
  }
}

class _GuardedRoute extends StatelessWidget {
  const _GuardedRoute({
    required this.user,
    required this.allowedRoles,
    required this.child,
  });

  final UserModel? user;
  final Set<String> allowedRoles;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final role = user?.role ?? '';
    if (user == null) {
      return const _AccessBlockedPage(
        title: 'Sessão necessária',
        message: 'Faça login novamente para acessar esta área.',
        buttonLabel: 'Ir para login',
        route: AppRoutes.login,
      );
    }
    if (!allowedRoles.contains(role)) {
      return const _AccessBlockedPage(
        title: 'Acesso não permitido',
        message: 'Seu perfil não possui permissão para acessar esta página.',
        buttonLabel: 'Voltar para início',
        route: AppRoutes.home,
      );
    }
    return child;
  }
}

class _AccessBlockedPage extends StatelessWidget {
  const _AccessBlockedPage({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.route,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final String route;

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
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed:
                      () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        route,
                        (_) => false,
                      ),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
