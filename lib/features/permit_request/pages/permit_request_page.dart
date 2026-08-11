import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const _draftKey = 'event_permit_request_draft_v1';

  final _storage = const FlutterSecureStorage();
  final _authService = AuthService();
  late Future<UserModel?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadCurrentUser();
    Future.microtask(() async {
      final controller = ref.read(permitRequestControllerProvider.notifier);
      controller.initializeQuestions(widget.questions);
      await _offerDraftRestore();
    });
  }

  Future<void> _offerDraftRestore() async {
    final preferences = await SharedPreferences.getInstance();
    final rawDraft = preferences.getString(_draftKey);
    if (rawDraft == null || rawDraft.isEmpty || !mounted) return;
    try {
      final decoded = jsonDecode(rawDraft);
      if (decoded is Map<String, dynamic>) {
        ref
            .read(permitRequestControllerProvider.notifier)
            .restoreDraft(decoded);
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Rascunho restaurado. Se havia anexos, selecione os arquivos novamente.',
              ),
            ),
          );
        });
      }
    } catch (_) {
      await preferences.remove(_draftKey);
    }
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

  Future<void> _saveDraft() async {
    final controller = ref.read(permitRequestControllerProvider.notifier);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _draftKey,
      jsonEncode(controller.toDraftJson()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rascunho salvo para continuar depois.')),
    );
  }

  Future<void> _clearDraft() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_draftKey);
  }

  Future<void> _cancelDraft() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancelar solicitação'),
            content: const Text(
              'A solicitação em preenchimento será descartada neste dispositivo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Voltar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Cancelar solicitação'),
              ),
            ],
          ),
    );
    if (confirm != true || !mounted) return;
    await _clearDraft();
    final controller = ref.read(permitRequestControllerProvider.notifier);
    controller.resetForm();
    controller.initializeQuestions(widget.questions);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(permitRequestControllerProvider.notifier);
    final state = ref.watch(permitRequestControllerProvider);
    final isReviewStep = state.currentStep == state.totalSteps - 1;
    final termAccepted = state.eventData['termo_aceite'] == 'true';
    final submitBlockedByTerm = isReviewStep && !termAccepted;

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
                      if (submitBlockedByTerm) ...[
                        const Text(
                          'Leia e aceite o termo de responsabilidade para liberar o envio.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                      ],
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
                            child: TextButton.icon(
                              onPressed: state.isSubmitting ? null : _saveDraft,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Salvar'),
                            ),
                          ),
                          SizedBox(
                            width:
                                MediaQuery.of(context).size.width < 420
                                    ? 140
                                    : null,
                            child: TextButton.icon(
                              onPressed:
                                  state.isSubmitting ? null : _cancelDraft,
                              icon: const Icon(Icons.close),
                              label: const Text('Cancelar'),
                            ),
                          ),
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
                                  state.isSubmitting || submitBlockedByTerm
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
                                          await _clearDraft();
                                          if (!context.mounted) return;
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
