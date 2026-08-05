import 'package:file_picker/file_picker.dart';

class PermitRequestState {
  final int currentStep;
  final int totalSteps;
  final Map<int, dynamic> answers;
  final List<Map<String, dynamic>> questions;
  final List<PlatformFile> attachments;

  PermitRequestState({
    required this.currentStep,
    required this.totalSteps,
    required this.answers,
    required this.questions,
    this.attachments = const [],
  });

  factory PermitRequestState.initial() => PermitRequestState(
    currentStep: 0,
    totalSteps: 3,
    answers: {},
    questions: [],
    attachments: [],
  );

  PermitRequestState copyWith({
    int? currentStep,
    int? totalSteps,
    Map<int, dynamic>? answers,
    List<Map<String, dynamic>>? questions,
    List<PlatformFile>? attachments,
  }) {
    return PermitRequestState(
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      answers: answers ?? this.answers,
      questions: questions ?? this.questions,
      attachments: attachments ?? this.attachments,
    );
  }
}
