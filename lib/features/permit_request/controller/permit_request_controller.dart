import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permit_api_service.dart';
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
      totalSteps: 4 + newQuestions.length,
      currentStep: 0,
      submittedProtocol: null,
    );
  }

  Map<String, dynamic> toDraftJson() {
    return {
      'currentStep': state.currentStep,
      'responsibleData': state.responsibleData,
      'eventData': state.eventData,
      'answers': state.answers,
      'answerDetails': state.answerDetails,
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  void restoreDraft(Map<String, dynamic> draft) {
    final currentStep = draft['currentStep'];
    final maxStep = state.totalSteps > 0 ? state.totalSteps - 1 : 0;
    state = state.copyWith(
      currentStep:
          currentStep is int
              ? currentStep.clamp(0, maxStep)
              : int.tryParse(currentStep?.toString() ?? '')?.clamp(0, maxStep),
      responsibleData: _stringMap(draft['responsibleData']),
      eventData: _stringMap(draft['eventData']),
      answers: _boolMap(draft['answers']),
      answerDetails: _dynamicMap(draft['answerDetails']),
      attachments: const [],
      submittedProtocol: null,
    );
  }

  void updateAnswer(String questionKey, dynamic answer) {
    final response = answer is Map ? answer['resposta'] : answer;
    state = state.copyWith(
      answers: {...state.answers, questionKey: response == 'Sim'},
      answerDetails: {...state.answerDetails, questionKey: answer},
    );
  }

  void updateBasicInfo({
    String? name,
    String? cpfCnpj,
    String? address,
    String? phone,
    String? email,
  }) {
    final updated = Map<String, String>.from(state.responsibleData);
    if (name != null) updated['nome'] = name;
    if (cpfCnpj != null) updated['cpf_cnpj'] = cpfCnpj;
    if (address != null) updated['endereco'] = address;
    if (phone != null) updated['telefone'] = phone;
    if (email != null) updated['email'] = email;

    state = state.copyWith(responsibleData: updated);
  }

  void updateEventInfo({
    String? eventName,
    String? eventDate,
    String? eventAddress,
    String? expectedPublic,
    String? startTime,
    String? endTime,
    bool? isBeneficente,
    String? instituicaoBeneficiada,
    bool? termoAceite,
    String? publicRangeId,
    String? publicMin,
    String? publicMax,
    String? deadlineBusinessDays,
  }) {
    final updated = Map<String, String>.from(state.eventData);
    if (eventName != null) updated['nome_evento'] = eventName;
    if (eventDate != null) updated['data_evento'] = eventDate;
    if (eventAddress != null) updated['endereco_evento'] = eventAddress;
    if (expectedPublic != null) updated['publico_estimado'] = expectedPublic;
    if (startTime != null) updated['horario_inicio'] = startTime;
    if (endTime != null) updated['horario_termino'] = endTime;
    if (isBeneficente != null) {
      updated['is_beneficente'] = isBeneficente.toString();
    }
    if (instituicaoBeneficiada != null) {
      updated['instituicao_beneficiada'] = instituicaoBeneficiada;
    }
    if (publicRangeId != null) updated['publico_faixa_id'] = publicRangeId;
    if (publicMin != null) updated['publico_estimado_min'] = publicMin;
    if (publicMax != null) updated['publico_estimado_max'] = publicMax;
    if (deadlineBusinessDays != null) {
      updated['prazo_dias_uteis'] = deadlineBusinessDays;
    }
    if (termoAceite != null) {
      updated['termo_aceite'] = termoAceite.toString();
    }
    state = state.copyWith(eventData: updated);
  }

  void addAttachments(List<PlatformFile> newFiles) {
    state = state.copyWith(attachments: [...state.attachments, ...newFiles]);
  }

  void removeAttachment(PlatformFile file) {
    state = state.copyWith(
      attachments:
          state.attachments
              .where(
                (item) =>
                    item.name != file.name ||
                    item.size != file.size ||
                    item.path != file.path,
              )
              .toList(),
    );
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

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return {};
    return value.map(
      (key, entry) => MapEntry(key.toString(), entry.toString()),
    );
  }

  static Map<String, bool> _boolMap(Object? value) {
    if (value is! Map) return {};
    return value.map((key, entry) {
      final parsed = entry is bool ? entry : entry.toString() == 'true';
      return MapEntry(key.toString(), parsed);
    });
  }

  static Map<String, dynamic> _dynamicMap(Object? value) {
    if (value is! Map) return {};
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }

  bool canGoNext(BuildContext context) {
    final error = validateCurrentStep();
    if (error == null) return true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    return false;
  }

  String? validateCurrentStep() {
    if (state.currentStep == 0) {
      for (final field in [
        'nome',
        'cpf_cnpj',
        'telefone',
        'email',
        'endereco',
      ]) {
        if ((state.responsibleData[field] ?? '').trim().isEmpty) {
          return 'Preencha todos os dados do responsável.';
        }
      }
    }

    if (state.currentStep == 1 && state.attachments.length < 3) {
      return 'Anexe RG/CPF, comprovante de residência e alvará do local.';
    }

    if (state.currentStep == 2) {
      for (final field in [
        'nome_evento',
        'data_evento',
        'endereco_evento',
        'publico_estimado',
        'horario_inicio',
        'horario_termino',
      ]) {
        if ((state.eventData[field] ?? '').trim().isEmpty) {
          return 'Preencha todos os dados obrigatórios do evento.';
        }
      }
      final eventDate = DateTime.tryParse(state.eventData['data_evento'] ?? '');
      if (eventDate == null) {
        return 'Informe a data do evento no formato correto.';
      }
      final today = DateTime.now();
      final currentDate = DateTime(today.year, today.month, today.day);
      final deadlineDays =
          int.tryParse(state.eventData['prazo_dias_uteis'] ?? '') ?? 15;
      if (eventDate.isBefore(_addBusinessDays(currentDate, deadlineDays))) {
        return 'A solicitação precisa ser feita com pelo menos $deadlineDays dias úteis de antecedência.';
      }
      if (state.eventData['is_beneficente'] == 'true' &&
          (state.eventData['instituicao_beneficiada'] ?? '').trim().isEmpty) {
        return 'Informe a instituição beneficiada pelo evento.';
      }
    }

    if (state.currentStep >= 3 && state.currentStep < state.totalSteps - 1) {
      final question = state.questions[state.currentStep - 3];
      final key = question['key'] as String;
      if (!state.answers.containsKey(key)) {
        return 'Responda a pergunta antes de avançar.';
      }
      final requiredError = _validateRequiredQuestionFields(question, key);
      if (requiredError != null) {
        return requiredError;
      }
    }

    if (state.currentStep == state.totalSteps - 1 &&
        state.eventData['termo_aceite'] != 'true') {
      return 'Aceite o termo de responsabilidade para enviar a solicitação.';
    }

    return null;
  }

  List<Map<String, String>> previewRequirements() {
    return PermitApiService.previewRequirements(
      state.answers,
      state.eventData,
      state.questions,
    );
  }

  DateTime _addBusinessDays(DateTime startDate, int businessDays) {
    var currentDate = startDate;
    var addedDays = 0;
    while (addedDays < businessDays) {
      currentDate = currentDate.add(const Duration(days: 1));
      if (currentDate.weekday <= DateTime.friday) {
        addedDays += 1;
      }
    }
    return currentDate;
  }

  Future<String?> submitRequest(BuildContext context) async {
    if (state.isSubmitting) return null;
    state = state.copyWith(isSubmitting: true);
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        throw PermitApiException('Sessão expirada. Faça login novamente.');
      }
      final response = await PermitApiService().createRequest(
        accessToken: token,
        responsibleData: state.responsibleData,
        eventData: state.eventData,
        answers: state.answers,
        answerDetails: state.answerDetails,
        attachmentNames: state.attachments.map((file) => file.name).toList(),
      );
      final protocolo = response['protocolo'] as String? ?? '';
      state = state.copyWith(isSubmitting: false, submittedProtocol: protocolo);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Solicitação enviada. Protocolo: $protocolo')),
        );
      }
      return protocolo;
    } catch (error) {
      state = state.copyWith(isSubmitting: false);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return null;
    }
  }

  String? _validateRequiredQuestionFields(
    Map<String, dynamic> question,
    String questionKey,
  ) {
    if (state.answers[questionKey] != true) return null;
    final requiredFields =
        (question['campos_obrigatorios'] as Map<String, dynamic>?) ?? {};
    if (requiredFields.isEmpty) return null;
    final answer = state.answerDetails[questionKey];
    if (answer is! Map) {
      return 'Preencha os campos obrigatórios desta pergunta.';
    }
    for (final entry in requiredFields.entries) {
      if (entry.value != true) continue;
      final fieldValue = answer[_fieldKey(entry.key)];
      if (fieldValue == null || fieldValue.toString().trim().isEmpty) {
        return 'Preencha o campo obrigatório: ${entry.key}.';
      }
    }
    return null;
  }

  String _fieldKey(String label) {
    switch (label) {
      case 'Texto':
        return 'texto';
      case 'Calendário':
        return 'data';
      case 'Anexar Documento':
        return 'arquivo';
      case 'Assinatura impressa':
      case 'Assinatura gov.br':
        return 'assinatura';
      default:
        return label;
    }
  }
}
