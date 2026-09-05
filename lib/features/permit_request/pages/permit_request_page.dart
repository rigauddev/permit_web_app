import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final Map<String, dynamic>? eventType;
  final List<Map<String, dynamic>> eventTypes;

  const PermitRequestPage({
    super.key,
    required this.userType,
    required this.userProfile,
    required this.permitType,
    required this.questions,
    this.eventType,
    this.eventTypes = const [],
  });

  @override
  ConsumerState<PermitRequestPage> createState() => _PermitRequestPageState();
}

class _PermitRequestPageState extends ConsumerState<PermitRequestPage> {
  static const _draftKey = 'event_permit_request_draft_v1';

  final _authService = AuthService();
  late Future<UserModel?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadCurrentUser();
    Future.microtask(() async {
      final controller = ref.read(permitRequestControllerProvider.notifier);
      controller.initializeQuestions(
        widget.questions,
        eventTypes: widget.eventTypes,
      );
      final eventType = widget.eventType;
      if (eventType != null) {
        controller.selectEventType(eventType);
      }
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
    final token = await SessionExpiration.readAccessToken();
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

  Future<void> _clearDraft() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_draftKey);
  }

  Future<void> _exitFlow() async {
    final action = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sair da solicitação'),
            content: const Text(
              'Você pode salvar o preenchimento neste dispositivo para continuar depois.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'stay'),
                child: const Text('Continuar aqui'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'leave'),
                child: const Text('Sair sem salvar'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'save'),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar e sair'),
              ),
            ],
          ),
    );
    if (action == null || action == 'stay' || !mounted) return;
    if (action == 'save') {
      await _saveDraft(showMessage: false);
    } else {
      await _clearDraft();
    }
    final controller = ref.read(permitRequestControllerProvider.notifier);
    controller.resetForm();
    controller.initializeQuestions(
      widget.questions,
      eventTypes: widget.eventTypes,
    );
    if (widget.eventType != null) {
      controller.selectEventType(widget.eventType!);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _saveDraft({bool showMessage = true}) async {
    final controller = ref.read(permitRequestControllerProvider.notifier);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _draftKey,
      jsonEncode(controller.toDraftJson()),
    );
    if (!mounted || !showMessage) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rascunho salvo para continuar depois.')),
    );
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
                      _RequestNavigationBar(
                        currentStep: state.currentStep,
                        isLastStep: state.currentStep == state.totalSteps - 1,
                        isSubmitting: state.isSubmitting,
                        submitBlockedByTerm: submitBlockedByTerm,
                        onBack: controller.previousStep,
                        onExit: _exitFlow,
                        onNext: () async {
                          if (!controller.canGoNext(context)) return;
                          if (state.currentStep == state.totalSteps - 1) {
                            final protocolo = await controller.submitRequest(
                              context,
                            );
                            if (protocolo == null || !context.mounted) return;
                            await _clearDraft();
                            if (!context.mounted) return;
                            controller.resetForm();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => PermitDashboardPage(
                                      userType: widget.userType,
                                      userProfile: widget.userProfile,
                                      permitType: widget.permitType,
                                      questions: widget.questions,
                                      forms: const [],
                                      eventTypes: widget.eventTypes,
                                    ),
                              ),
                            );
                          } else {
                            controller.nextStep();
                          }
                        },
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

class _RequestNavigationBar extends StatelessWidget {
  const _RequestNavigationBar({
    required this.currentStep,
    required this.isLastStep,
    required this.isSubmitting,
    required this.submitBlockedByTerm,
    required this.onBack,
    required this.onExit,
    required this.onNext,
  });

  final int currentStep;
  final bool isLastStep;
  final bool isSubmitting;
  final bool submitBlockedByTerm;
  final VoidCallback onBack;
  final VoidCallback onExit;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    final buttons = <Widget>[
      if (currentStep > 0)
        OutlinedButton.icon(
          onPressed: isSubmitting ? null : onBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Voltar'),
        ),
      TextButton.icon(
        onPressed: isSubmitting ? null : onExit,
        icon: const Icon(Icons.exit_to_app),
        label: const Text('Sair'),
      ),
      ElevatedButton.icon(
        onPressed: isSubmitting || submitBlockedByTerm ? null : onNext,
        icon: Icon(isLastStep ? Icons.send_outlined : Icons.arrow_forward),
        label: Text(
          isSubmitting
              ? 'Enviando...'
              : isLastStep
              ? 'Enviar'
              : 'Avançar',
        ),
      ),
    ];

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:
            buttons
                .map(
                  (button) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: button,
                  ),
                )
                .toList(),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (currentStep > 0) buttons.first,
          const Spacer(),
          if (currentStep > 0) const SizedBox(width: 8),
          buttons[currentStep > 0 ? 1 : 0],
          const SizedBox(width: 8),
          buttons.last,
        ],
      ),
    );
  }
}
