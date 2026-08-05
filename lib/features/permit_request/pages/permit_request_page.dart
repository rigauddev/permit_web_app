import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../presentation/pages/user_alvara_dashboard.dart';
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
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(permitRequestControllerProvider.notifier)
          .initializeQuestions(widget.questions);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(permitRequestControllerProvider.notifier);
    final state = ref.watch(permitRequestControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Solicitação de ${widget.permitType}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Passo ${state.currentStep + 1} de ${state.totalSteps}'),
            const SizedBox(height: 20),
            Expanded(child: PermitRequestFormBuilder()),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
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
                ElevatedButton(
                  onPressed:
                      state.isSubmitting
                          ? null
                          : () async {
                            if (!controller.canGoNext(context)) return;
                            if (state.currentStep == state.totalSteps - 1) {
                              final protocolo = await controller.submitRequest(
                                context,
                              );
                              if (protocolo == null || !context.mounted) return;
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
