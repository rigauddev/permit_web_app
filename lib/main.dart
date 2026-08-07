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
import 'presentation/pages/inspection_schedule_page.dart';
import 'presentation/pages/recovery_password.dart';
import 'presentation/pages/secretaria_requests_page.dart';
import 'presentation/pages/user_profile.dart';
import 'presentation/pages/users_list.dart';
import 'presentation/pages/user_registration_page.dart';
import 'presentation/pages/user_create_page.dart';
import 'presentation/pages/question_page.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final _storage = const FlutterSecureStorage();
  bool _restoringSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSessionUser();
  }

  Future<void> _restoreSessionUser() async {
    final rawUser = await _storage.read(key: 'user');
    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        final json = jsonDecode(rawUser) as Map<String, dynamic>;
        ref.read(userProvider.notifier).setUser(UserModel.fromJson(json));
      } catch (_) {
        await _storage.delete(key: 'user');
        await _storage.delete(key: 'access_token');
      }
    }
    if (mounted) {
      setState(() => _restoringSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final userType = user?.userType ?? '';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema de Serviços da Prefeitura',
      theme: customTheme,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.recoveryPassword: (context) => RecoveryPassword(),
        AppRoutes.home:
            (context) => _protectedPage(
              user,
              UserHomePage(userType: userType, userProfile: user?.profile),
            ),
        AppRoutes.profile:
            (context) => _protectedPage(user, ProfilePage(userType: userType)),
        AppRoutes.users:
            (context) => _internalPage(user, UsersListPage(userType: userType)),
        AppRoutes.registerUser: (context) => const UserRegistrationPage(),
        AppRoutes.createUser:
            (context) =>
                _internalPage(user, UserCreatePage(userType: userType)),
        AppRoutes.userCreate:
            (context) =>
                _internalPage(user, UserCreatePage(userType: userType)),
        AppRoutes.homeContent:
            (context) =>
                _internalPage(user, HomeContentPage(userType: userType)),
        AppRoutes.services:
            (context) => _protectedPage(
              user,
              ReceitaMunicipalServicesPage(
                userType: userType,
                userProfile: user?.profile ?? '',
              ),
            ),
        AppRoutes.myRequests:
            (context) => _citizenPage(user, MyRequestsPage(userType: userType)),
        AppRoutes.secretariaRequests:
            (context) =>
                _internalPage(user, SecretariaRequestsPage(userType: userType)),
        AppRoutes.inspections:
            (context) =>
                _internalPage(user, InspectionSchedulePage(userType: userType)),
        AppRoutes.questions:
            (context) => _internalPage(
              user,
              PerguntasPage(
                userType: userType,
                userProfile: user?.profile ?? '',
              ),
            ),
      },
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }

  Widget _protectedPage(UserModel? user, Widget page) {
    if (_restoringSession) return const _SessionLoadingPage();
    if (user == null) return const LoginPage();
    return page;
  }

  Widget _internalPage(UserModel? user, Widget page) {
    if (_restoringSession) return const _SessionLoadingPage();
    if (user == null) return const LoginPage();
    if (user.userType == 'user' || user.role == 'cidadao') {
      return UserHomePage(userType: user.userType, userProfile: user.profile);
    }
    return page;
  }

  Widget _citizenPage(UserModel? user, Widget page) {
    if (_restoringSession) return const _SessionLoadingPage();
    if (user == null) return const LoginPage();
    if (user.userType != 'user' && user.role != 'cidadao') {
      return UserHomePage(userType: user.userType, userProfile: user.profile);
    }
    return page;
  }
}

class _SessionLoadingPage extends StatelessWidget {
  const _SessionLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
