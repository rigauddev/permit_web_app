import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/auth_service.dart';
import '../../../core/session_expiration.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/user_provider.dart';
import '../../../presentation/pages/user_alvara_dashboard.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../controller/permit_request_controller.dart';
import 'permit_request_form_builder.dart';

class PermitRequestPage extends ConsumerStatefulWidget {
  final String userType;
  final String userProfile;
  final String permitType;
  final List<Map<String, dynamic>> questions;

  const PermitRequestPage({
    super.key,
    required this.userType,
    required this.userProfile,
    required this.permitType,
    required this.questions,
  });

  @override
  ConsumerState<PermitRequestPage> createState() => _PermitRequestPageState();
}

class _PermitRequestPageState extends ConsumerState<PermitRequestPage> {
  final _storage = const FlutterSecureStorage();
  final _authService = AuthService();
  late Future<UserModel?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadCurrentUser();
    Future.microtask(() {
      ref
          .read(permitRequestControllerProvider.notifier)
          .initializeQuestions(widget.questions);
    });
  }

  Future<UserModel?> _loadCurrentUser() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      if (mounted) await SessionExpiration.logout(context);
      return null;
    }
    try {
      final user = await _authService.currentUser(accessToken: token);
      if (mounted) {
        ref.read(userProvider.notifier).setUser(user);
      }
      return user;
    } on AuthException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return null;
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(permitRequestControllerProvider.notifier);
    final state = ref.watch(permitRequestControllerProvider);

    return AppScaffold(
      userType: widget.userType,
      userProfile: widget.userProfile,
      appBar: AppBar(title: Text('Solicitação de ${widget.permitType}')),
      body: SafeArea(
        child: FutureBuilder<UserModel?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Não foi possível carregar seus dados cadastrais.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed:
                            () => setState(() {
                              _profileFuture = _loadCurrentUser();
                            }),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Passo ${state.currentStep + 1} de ${state.totalSteps}',
                      ),
                      const SizedBox(height: 20),
                      Expanded(child: PermitRequestFormBuilder()),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width:
                                MediaQuery.of(context).size.width < 420
                                    ? 140
                                    : null,
                            child: OutlinedButton(
                              onPressed: () {
                                if (state.currentStep == 0) {
                                  controller.resetForm();
                                  Navigator.of(context).pop();
                                } else {
                                  controller.previousStep();
                                }
                              },
                              child: const Text('Voltar'),
                            ),
                          ),
                          SizedBox(
                            width:
                                MediaQuery.of(context).size.width < 420
                                    ? 140
                                    : null,
                            child: ElevatedButton(
                              onPressed:
                                  state.isSubmitting
                                      ? null
                                      : () async {
                                        if (!controller.canGoNext(context)) {
                                          return;
                                        }
                                        if (state.currentStep ==
                                            state.totalSteps - 1) {
                                          final protocolo = await controller
                                              .submitRequest(context);
                                          if (protocolo == null ||
                                              !context.mounted) {
                                            return;
                                          }
                                          controller.resetForm();
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => PermitDashboardPage(
                                                    userType: widget.userType,
                                                    userProfile:
                                                        widget.userProfile,
                                                    permitType:
                                                        widget.permitType,
                                                    questions: widget.questions,
                                                    forms: const [],
                                                  ),
                                            ),
                                          );
                                        } else {
                                          controller.nextStep();
                                        }
                                      },
                              child: Text(
                                state.isSubmitting
                                    ? 'Enviando...'
                                    : state.currentStep == state.totalSteps - 1
                                    ? 'Enviar'
                                    : 'Avançar',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
