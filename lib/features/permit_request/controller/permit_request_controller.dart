import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../permit_request/models/permit_request_state.dart';

final permitRequestControllerProvider =
    StateNotifierProvider<PermitRequestController, PermitRequestState>(
      (ref) => PermitRequestController(),
    );

class PermitRequestController extends StateNotifier<PermitRequestState> {
  PermitRequestController() : super(PermitRequestState.initial());

  void initializeQuestions(List<Map<String, dynamic>> newQuestions) {
    state = state.copyWith(
      questions: newQuestions,
      totalSteps: state.totalSteps + newQuestions.length,
    );
  }

  void updateAnswer(int questionId, dynamic answer) {
    state = state.copyWith(answers: {...state.answers, questionId: answer});
  }

  void updateBasicInfo({
    String? name,
    String? cpfCnpj,
    String? address,
    String? phone,
    String? email,
  }) {
    final updatedAnswers = Map<int, dynamic>.from(state.answers);
    if (name != null) updatedAnswers[-1] = name;
    if (cpfCnpj != null) updatedAnswers[-2] = cpfCnpj;
    if (address != null) updatedAnswers[-3] = address;
    if (phone != null) updatedAnswers[-4] = phone;
    if (email != null) updatedAnswers[-5] = email;

    state = state.copyWith(answers: updatedAnswers);
  }

  void updateEventInfo({
    String? eventName,
    String? eventDate,
    String? eventAddress,
  }) {
    final updatedAnswers = Map<int, dynamic>.from(state.answers);
    if (eventName != null) updatedAnswers[-3] = eventName;
    if (eventDate != null) updatedAnswers[-4] = eventDate;
    if (eventAddress != null) updatedAnswers[-5] = eventAddress;
    state = state.copyWith(answers: updatedAnswers);
  }

  void addAttachments(List<PlatformFile> newFiles) {
    state = state.copyWith(attachments: [...state.attachments, ...newFiles]);
  }

  void nextStep() {
    if (state.currentStep < state.totalSteps - 1) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void resetForm() {
    state = PermitRequestState.initial();
  }

  void submitRequest(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitação enviada com sucesso!')),
    );
  }
}
