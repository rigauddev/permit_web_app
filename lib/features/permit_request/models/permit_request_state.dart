import 'package:file_picker/file_picker.dart';

class PermitRequestState {
  final int currentStep;
  final int totalSteps;
  final Map<String, String> responsibleData;
  final Map<String, String> eventData;
  final Map<String, bool> answers;
  final Map<String, dynamic> answerDetails;
  final List<Map<String, dynamic>> allQuestions;
  final List<Map<String, dynamic>> questions;
  final List<Map<String, dynamic>> eventTypes;
  final List<PlatformFile> attachments;
  final bool isSubmitting;
  final String? submittedProtocol;

  PermitRequestState({
    required this.currentStep,
    required this.totalSteps,
    required this.responsibleData,
    required this.eventData,
    required this.answers,
    required this.answerDetails,
    required this.allQuestions,
    required this.questions,
    required this.eventTypes,
    this.attachments = const [],
    this.isSubmitting = false,
    this.submittedProtocol,
  });

  factory PermitRequestState.initial() => PermitRequestState(
    currentStep: 0,
    totalSteps: 4,
    responsibleData: {},
    eventData: {},
    answers: {},
    answerDetails: {},
    allQuestions: [],
    questions: [],
    eventTypes: [],
    attachments: [],
  );

  PermitRequestState copyWith({
    int? currentStep,
    int? totalSteps,
    Map<String, String>? responsibleData,
    Map<String, String>? eventData,
    Map<String, bool>? answers,
    Map<String, dynamic>? answerDetails,
    List<Map<String, dynamic>>? allQuestions,
    List<Map<String, dynamic>>? questions,
    List<Map<String, dynamic>>? eventTypes,
    List<PlatformFile>? attachments,
    bool? isSubmitting,
    String? submittedProtocol,
  }) {
    return PermitRequestState(
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      responsibleData: responsibleData ?? this.responsibleData,
      eventData: eventData ?? this.eventData,
      answers: answers ?? this.answers,
      answerDetails: answerDetails ?? this.answerDetails,
      allQuestions: allQuestions ?? this.allQuestions,
      questions: questions ?? this.questions,
      eventTypes: eventTypes ?? this.eventTypes,
      attachments: attachments ?? this.attachments,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submittedProtocol: submittedProtocol ?? this.submittedProtocol,
    );
  }
}
