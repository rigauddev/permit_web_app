import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permit_api_service.dart';
import '../../../core/session_store.dart';
import '../../permit_request/models/permit_request_state.dart';

final permitRequestControllerProvider =
    StateNotifierProvider<PermitRequestController, PermitRequestState>(
      (ref) => PermitRequestController(),
    );

class PermitRequestController extends StateNotifier<PermitRequestState> {
  PermitRequestController() : super(PermitRequestState.initial());

  void initializeQuestions(
    List<Map<String, dynamic>> newQuestions, {
    List<Map<String, dynamic>> eventTypes = const [],
  }) {
    state = state.copyWith(
      allQuestions: newQuestions,
      questions: newQuestions,
      eventTypes: eventTypes,
      totalSteps: 5 + newQuestions.length,
      currentStep: 0,
      submittedProtocol: null,
    );
  }

  void selectEventType(Map<String, dynamic> eventType) {
    final key = eventType['key']?.toString() ?? '';
    final name = eventType['name']?.toString() ?? '';
    final filteredQuestions = _questionsForEventType(key);
    final allowedKeys =
        filteredQuestions
            .map((question) => question['key']?.toString() ?? '')
            .where((questionKey) => questionKey.isNotEmpty)
            .toSet();
    final updatedEventData =
        Map<String, String>.from(state.eventData)
          ..['tipo_evento'] = key
          ..['tipo_evento_nome'] = name;
    state = state.copyWith(
      eventData: updatedEventData,
      questions: filteredQuestions,
      answers: {
        for (final entry in state.answers.entries)
          if (allowedKeys.contains(entry.key)) entry.key: entry.value,
      },
      answerDetails: {
        for (final entry in state.answerDetails.entries)
          if (allowedKeys.contains(entry.key)) entry.key: entry.value,
      },
      totalSteps: 5 + filteredQuestions.length,
      currentStep:
          state.currentStep > 2
              ? 2
              : state.currentStep.clamp(0, 4 + filteredQuestions.length),
    );
  }

  List<Map<String, dynamic>> _questionsForEventType(String eventTypeKey) {
    if (eventTypeKey.isEmpty) return state.allQuestions;
    return state.allQuestions.where((question) {
      final keys = List<String>.from(question['event_type_keys'] ?? const []);
      return keys.isEmpty || keys.contains(eventTypeKey);
    }).toList();
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
      documentAttachments: const {},
      submittedProtocol: null,
    );
    final eventTypeKey = state.eventData['tipo_evento'];
    if (eventTypeKey != null && eventTypeKey.isNotEmpty) {
      final eventType = state.eventTypes.firstWhere(
        (item) => item['key']?.toString() == eventTypeKey,
        orElse:
            () => {
              'key': eventTypeKey,
              'name': state.eventData['tipo_evento_nome'] ?? eventTypeKey,
            },
      );
      selectEventType(eventType);
    }
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
    String? eventLatitude,
    String? eventLongitude,
    String? eventTypeKey,
    String? eventTypeName,
    String? eventSpaceType,
    bool? localWithoutPermit,
    String? applicantNotes,
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
    if (eventLatitude != null) updated['latitude_evento'] = eventLatitude;
    if (eventLongitude != null) updated['longitude_evento'] = eventLongitude;
    if (eventTypeKey != null) updated['tipo_evento'] = eventTypeKey;
    if (eventTypeName != null) updated['tipo_evento_nome'] = eventTypeName;
    if (eventSpaceType != null) updated['tipo_espaco_evento'] = eventSpaceType;
    if (localWithoutPermit != null) {
      updated['local_sem_alvara'] = localWithoutPermit.toString();
    }
    if (applicantNotes != null) {
      updated['observacoes_solicitante'] = applicantNotes;
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

  void setDocumentAttachment(String key, PlatformFile file) {
    state = state.copyWith(
      documentAttachments: {...state.documentAttachments, key: file},
    );
  }

  void removeDocumentAttachment(String key) {
    final updated = Map<String, PlatformFile>.from(state.documentAttachments)
      ..remove(key);
    state = state.copyWith(documentAttachments: updated);
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
      for (final field in ['nome', 'cpf_cnpj', 'telefone', 'endereco']) {
        if ((state.responsibleData[field] ?? '').trim().isEmpty) {
          return 'Preencha todos os dados do responsável.';
        }
      }
    }

    if (state.currentStep == 1) {
      final docs = state.documentAttachments;
      final hasSingleId = docs.containsKey('documento_identificacao');
      final hasPhotoId =
          docs.containsKey('documento_identificacao_frente') &&
          docs.containsKey('documento_identificacao_verso');
      if (!hasSingleId && !hasPhotoId) {
        return 'Anexe RG/CNH em arquivo único ou tire foto da frente e do verso.';
      }
      if (!docs.containsKey('comprovante_residencia')) {
        return 'Anexe ou tire foto do comprovante de residência.';
      }
    }

    if (state.currentStep == 2) {
      if ((state.eventData['tipo_evento'] ?? '').trim().isEmpty) {
        return 'Selecione o tipo de evento.';
      }
      for (final field in [
        'nome_evento',
        'data_evento',
        'endereco_evento',
        'publico_estimado',
        'horario_inicio',
        'horario_termino',
        'tipo_espaco_evento',
        'latitude_evento',
        'longitude_evento',
      ]) {
        if ((state.eventData[field] ?? '').trim().isEmpty) {
          return 'Preencha todos os dados obrigatórios do evento.';
        }
      }
      if (double.tryParse(state.eventData['latitude_evento'] ?? '') == null ||
          double.tryParse(state.eventData['longitude_evento'] ?? '') == null) {
        return 'Busque e selecione o endereço do evento para salvar latitude e longitude.';
      }
      final docs = state.documentAttachments;
      final usesAddressProof = state.eventData['local_sem_alvara'] == 'true';
      if (usesAddressProof) {
        if (!docs.containsKey('comprovante_endereco_local')) {
          return 'Anexe o comprovante de endereço do local do evento.';
        }
      } else if (!docs.containsKey('alvara_funcionamento_local')) {
        return 'Anexe o alvará de funcionamento do local ou marque que usará comprovante de endereço.';
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

    final observationsStep = state.totalSteps - 2;
    if (state.currentStep >= 3 && state.currentStep < observationsStep) {
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
      final token = await const SessionStore().read().then(
        (s) => s?.accessToken,
      );
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
        documentAttachments: await _uploadInitialDocuments(token),
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

  Future<List<Map<String, dynamic>>> _uploadInitialDocuments(
    String token,
  ) async {
    final api = PermitApiService();
    final uploads = <Map<String, dynamic>>[];
    for (final entry in state.documentAttachments.entries) {
      final upload = await api.uploadFile(
        accessToken: token,
        kind: 'solicitacoes/documentos',
        file: entry.value,
      );
      uploads.add({
        'tipo_documento': entry.key,
        'nome_arquivo': upload['file_name']?.toString() ?? entry.value.name,
        'arquivo_url': upload['file_url']?.toString() ?? '',
        'mime_type': upload['mime_type']?.toString(),
        'tamanho_bytes': upload['size_bytes'],
      });
    }
    return uploads;
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
      if (_isEmptyRequiredValue(fieldValue)) {
        return 'Preencha o campo obrigatório: ${entry.key}.';
      }
    }
    return null;
  }

  bool _isEmptyRequiredValue(Object? value) {
    if (value == null) return true;
    if (value is Iterable) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return value.toString().trim().isEmpty;
  }

  String _fieldKey(String label) {
    switch (label) {
      case 'Texto':
        return 'texto';
      case 'Calendário':
        return 'data';
      case 'Anexar Documento':
        return 'arquivo';
      case 'Rota do Evento':
        return 'percurso_ruas';
      case 'Opções selecionáveis':
        return 'opcoes_selecionadas';
      case 'Assinatura impressa':
      case 'Assinatura gov.br':
        return 'assinatura';
      default:
        return label;
    }
  }
}
