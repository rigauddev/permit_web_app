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
      if (eventDate.isBefore(_addBusinessDays(currentDate, 15))) {
        return 'A solicitação precisa ser feita com pelo menos 15 dias úteis de antecedência.';
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
    }

    return null;
  }

  List<Map<String, String>> previewRequirements() {
    return PermitApiService.previewRequirements(state.answers, state.eventData);
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
}
