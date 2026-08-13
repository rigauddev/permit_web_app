import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/permit_api_service.dart';
import '../../../data/providers/user_provider.dart';
import '../controller/permit_request_controller.dart';
import '../models/permit_request_state.dart';
import '../widgets/question_field_widget.dart';

class PermitRequestFormBuilder extends ConsumerStatefulWidget {
  const PermitRequestFormBuilder({super.key});

  @override
  ConsumerState<PermitRequestFormBuilder> createState() =>
      _PermitRequestFormBuilderState();
}

class _PermitRequestFormBuilderState
    extends ConsumerState<PermitRequestFormBuilder> {
  static const _responsibilityTerm = '''
Declaro, sob minha responsabilidade, que as informações prestadas e os documentos anexados nesta solicitação são verdadeiros, completos e correspondem ao evento informado.

Declaro estar ciente de que a autorização municipal depende da análise das secretarias competentes, da regularidade dos documentos apresentados, do atendimento às exigências técnicas aplicáveis e, quando não houver isenção, da emissão e comprovação de pagamento do DAM.

Comprometo-me a cumprir as normas municipais, ambientais, sanitárias, de trânsito, segurança e ordem pública relacionadas à realização do evento, assumindo responsabilidade por informações incorretas, omissões ou alterações não comunicadas ao Município.
''';

  late final TextEditingController nomeController;
  late final TextEditingController cpfCnpjController;
  late final TextEditingController addressController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController eventDateController;
  late final TextEditingController eventNameController;
  late final TextEditingController eventAddressController;
  late final TextEditingController expectedPublicController;
  late final TextEditingController startTimeController;
  late final TextEditingController endTimeController;
  late final TextEditingController beneficiaryController;
  late Future<List<Map<String, dynamic>>> _publicRangesFuture;

  @override
  void initState() {
    super.initState();
    final state = ref.read(permitRequestControllerProvider);
    final user = ref.read(userProvider);
    _publicRangesFuture = _loadPublicRanges();

    nomeController = TextEditingController(
      text: user?.name ?? state.responsibleData['nome'] ?? '',
    );
    cpfCnpjController = TextEditingController(
      text: user?.cpfCnpj ?? state.responsibleData['cpf_cnpj'] ?? '',
    );
    addressController = TextEditingController(
      text: user?.address ?? state.responsibleData['endereco'] ?? '',
    );
    phoneController = TextEditingController(
      text: user?.phone ?? state.responsibleData['telefone'] ?? '',
    );
    emailController = TextEditingController(
      text: user?.email ?? state.responsibleData['email'] ?? '',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(permitRequestControllerProvider.notifier)
          .updateBasicInfo(
            name: nomeController.text,
            cpfCnpj: cpfCnpjController.text,
            address: addressController.text,
            phone: phoneController.text,
            email: emailController.text,
          );
    });

    eventNameController = TextEditingController(
      text: state.eventData['nome_evento'] ?? '',
    );
    eventDateController = TextEditingController(
      text: state.eventData['data_evento'] ?? '',
    );
    eventAddressController = TextEditingController(
      text: state.eventData['endereco_evento'] ?? '',
    );
    expectedPublicController = TextEditingController(
      text: state.eventData['publico_estimado'] ?? '',
    );
    startTimeController = TextEditingController(
      text: state.eventData['horario_inicio'] ?? '',
    );
    endTimeController = TextEditingController(
      text: state.eventData['horario_termino'] ?? '',
    );
    beneficiaryController = TextEditingController(
      text: state.eventData['instituicao_beneficiada'] ?? '',
    );
  }

  Future<List<Map<String, dynamic>>> _loadPublicRanges() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == null || token.isEmpty) return const [];
    try {
      return await PermitApiService().listPublicRanges(accessToken: token);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _openEventAddressMap() async {
    final address = eventAddressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o endereço do evento antes de abrir o mapa.'),
        ),
      );
      return;
    }
    final query = Uri.encodeComponent('$address, Valença, BA');
    final uri = Uri.parse('https://www.openstreetmap.org/search?query=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pickEventLocation() async {
    final state = ref.read(permitRequestControllerProvider);
    final initialLat = double.tryParse(
      state.eventData['latitude_evento'] ?? '',
    );
    final initialLng = double.tryParse(
      state.eventData['longitude_evento'] ?? '',
    );
    final result = await showDialog<({double latitude, double longitude})>(
      context: context,
      builder:
          (context) => _AddressMapPickerDialog(
            initialLatitude: initialLat,
            initialLongitude: initialLng,
          ),
    );
    if (result == null) return;
    ref
        .read(permitRequestControllerProvider.notifier)
        .updateEventInfo(
          eventLatitude: result.latitude.toStringAsFixed(6),
          eventLongitude: result.longitude.toStringAsFixed(6),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local do evento marcado no mapa.')),
    );
  }

  @override
  void dispose() {
    nomeController.dispose();
    cpfCnpjController.dispose();
    addressController.dispose();
    phoneController.dispose();
    emailController.dispose();
    eventNameController.dispose();
    eventDateController.dispose();
    eventAddressController.dispose();
    expectedPublicController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    beneficiaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(permitRequestControllerProvider);
    final controller = ref.read(permitRequestControllerProvider.notifier);

    if (state.currentStep == 0) {
      return ListView(
        children: [
          const _StepTitle('Responsável pelo evento'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD8E0D8)),
            ),
            child: const Text(
              'Os dados do responsável vêm da conta logada. Apenas o titular da conta pode solicitar o alvará de evento.',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: nomeController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Nome completo',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: cpfCnpjController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'CPF/CNPJ',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneController,
            readOnly: true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefone',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            readOnly: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: addressController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Endereço residencial',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
        ],
      );
    }

    if (state.currentStep == 1) {
      return ListView(
        children: [
          const _StepTitle('Documentos obrigatórios'),
          const Text(
            'Anexe RG/CPF, comprovante de residência e alvará do local.',
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: true,
                type: FileType.custom,
                allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
              );
              if (result != null) {
                controller.addAttachments(result.files);
              }
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Selecionar arquivos'),
          ),
          const SizedBox(height: 10),
          ...state.attachments.map(
            (file) => ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: Text(file.name),
              trailing: IconButton(
                tooltip: 'Remover anexo',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => controller.removeAttachment(file),
              ),
            ),
          ),
        ],
      );
    }

    if (state.currentStep == 2) {
      final isBeneficente = state.eventData['is_beneficente'] == 'true';
      return ListView(
        children: [
          const _StepTitle('Dados do evento'),
          TextFormField(
            controller: eventNameController,
            decoration: const InputDecoration(labelText: 'Nome do evento'),
            onChanged: (value) => controller.updateEventInfo(eventName: value),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _publicRangesFuture,
            builder: (context, snapshot) {
              final ranges = snapshot.data ?? const <Map<String, dynamic>>[];
              if (ranges.isEmpty) {
                return TextFormField(
                  controller: expectedPublicController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Expectativa de público',
                  ),
                  onChanged:
                      (value) =>
                          controller.updateEventInfo(expectedPublic: value),
                );
              }
              final currentId = state.eventData['publico_faixa_id'];
              return DropdownButtonFormField<String>(
                initialValue:
                    ranges.any((range) => range['id'].toString() == currentId)
                        ? currentId
                        : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Expectativa de público',
                ),
                items:
                    ranges
                        .map(
                          (range) => DropdownMenuItem<String>(
                            value: range['id'].toString(),
                            child: Text(
                              '${range['label']} - prazo mínimo ${range['prazo_dias_uteis']} dias úteis',
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  final selected = ranges.firstWhere(
                    (range) => range['id'].toString() == value,
                  );
                  expectedPublicController.text =
                      selected['label']?.toString() ?? '';
                  eventDateController.clear();
                  controller.updateEventInfo(
                    expectedPublic: selected['label']?.toString() ?? '',
                    publicRangeId: selected['id']?.toString(),
                    publicMin: selected['min_publico']?.toString(),
                    publicMax: selected['max_publico']?.toString(),
                    deadlineBusinessDays:
                        selected['prazo_dias_uteis']?.toString(),
                    eventDate: '',
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: eventDateController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Data do evento',
              suffixIcon: Icon(Icons.calendar_today),
            ),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: eventAddressController,
            minLines: 1,
            maxLines: 2,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Local/endereço do evento',
              hintText: 'Rua/Avenida, número, bairro, Valença - BA',
              helperText:
                  'Informe um endereço completo para localização no mapa de eventos.',
              suffixIcon: Icon(Icons.place_outlined),
            ),
            onChanged:
                (value) => controller.updateEventInfo(eventAddress: value),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _pickEventLocation,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Marcar no mapa gratuito'),
                ),
                TextButton.icon(
                  onPressed: _openEventAddressMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Conferir endereço'),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: startTimeController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Início',
                    suffixIcon: Icon(Icons.schedule),
                  ),
                  onTap:
                      () => _pickTime(startTimeController, (value) {
                        controller.updateEventInfo(startTime: value);
                      }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: endTimeController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Término',
                    suffixIcon: Icon(Icons.schedule),
                  ),
                  onTap:
                      () => _pickTime(endTimeController, (value) {
                        controller.updateEventInfo(endTime: value);
                      }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Evento beneficente'),
            value: isBeneficente,
            onChanged:
                (value) => controller.updateEventInfo(isBeneficente: value),
          ),
          if (isBeneficente) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: beneficiaryController,
              decoration: const InputDecoration(
                labelText: 'Instituição beneficiada',
              ),
              onChanged:
                  (value) =>
                      controller.updateEventInfo(instituicaoBeneficiada: value),
            ),
          ],
        ],
      );
    }

    if (state.currentStep >= 3 && state.currentStep < state.totalSteps - 1) {
      final questionIndex = state.currentStep - 3;
      final question = state.questions[questionIndex];
      final questionKey = question['key'] as String;

      return QuestionFieldWidget(
        key: ValueKey(questionKey),
        questionId: question['id'] as int,
        questionText: question['pergunta'] as String,
        descricao: question['descricao'] as String?,
        tiposResposta: List<String>.from(question['tipos_resposta'] ?? []),
        camposObrigatorios:
            (question['campos_obrigatorios'] as Map<String, dynamic>?) ??
            const {},
        modeloDocumentoNome: question['modelo_documento_nome'] as String?,
        modeloDocumentoUrl: question['modelo_documento_url'] as String?,
        onChanged: (value) => controller.updateAnswer(questionKey, value),
        currentValue: state.answerDetails[questionKey],
      );
    }

    if (state.currentStep == state.totalSteps - 1) {
      final requirements = controller.previewRequirements();
      final pendingFiles = _pendingQuestionFiles(state);
      return ListView(
        children: [
          const _StepTitle('Revise antes de enviar'),
          _ReviewSection(title: 'Responsável', values: state.responsibleData),
          _ReviewSection(title: 'Evento', values: state.eventData),
          _ReviewSection(
            title: 'Documentos',
            values: {
              'anexos': state.attachments.map((file) => file.name).join(', '),
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Exigências geradas',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (requirements.isEmpty)
            const Text('Nenhuma exigência condicional foi marcada.')
          else
            ...requirements.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.task_alt),
                title: Text(item['exigencia'] ?? ''),
                subtitle: Text(item['secretaria'] ?? ''),
              ),
            ),
          const SizedBox(height: 8),
          if (pendingFiles.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8D9A8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Arquivos pendentes por pergunta',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Estas respostas possuem modelo ou anexo previsto e ainda não receberam arquivo. Você poderá anexar na solicitação após a criação, quando aplicável.',
                  ),
                  const SizedBox(height: 8),
                  ...pendingFiles.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.attach_file),
                      title: Text(item['pergunta'] ?? ''),
                      subtitle: Text(
                        [
                          if ((item['secretaria'] ?? '').isNotEmpty)
                            item['secretaria'],
                          if ((item['modelo'] ?? '').isNotEmpty)
                            'Modelo: ${item['modelo']}',
                        ].whereType<String>().join(' | '),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            state.eventData['is_beneficente'] == 'true'
                ? 'DAM: isento mediante conferência da declaração beneficente.'
                : 'DAM: pendente de emissão/pagamento na Receita Municipal.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD8E0D8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TermStatus(
                  accepted: state.eventData['termo_aceite'] == 'true',
                  refused: state.eventData['termo_aceite'] == 'false',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Termo de responsabilidade',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Para concluir, abra o termo, leia até o final e escolha aceitar ou recusar.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      () => _openResponsibilityTerm(
                        onAccepted:
                            () => controller.updateEventInfo(termoAceite: true),
                        onRefused:
                            () =>
                                controller.updateEventInfo(termoAceite: false),
                      ),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Ler termo de responsabilidade'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox();
  }

  Future<void> _openResponsibilityTerm({
    required VoidCallback onAccepted,
    required VoidCallback onRefused,
  }) async {
    var reachedEnd = false;
    final scrollController = ScrollController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              void markReachedEnd() {
                if (reachedEnd) return;
                setDialogState(() => reachedEnd = true);
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!scrollController.hasClients) return;
                if (scrollController.position.maxScrollExtent <= 0) {
                  markReachedEnd();
                }
              });

              return AlertDialog(
                title: const Text('Termo de responsabilidade'),
                content: SizedBox(
                  width: 620,
                  height: MediaQuery.of(context).size.height * 0.56,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      final metrics = notification.metrics;
                      if (metrics.maxScrollExtent <= 0 ||
                          metrics.pixels >= metrics.maxScrollExtent - 16) {
                        markReachedEnd();
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(_responsibilityTerm),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F8F5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFD8E0D8),
                              ),
                            ),
                            child: const Text(
                              'Ao aceitar, você confirma que leu o termo e assume responsabilidade pelas informações prestadas na solicitação.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton.icon(
                    onPressed:
                        reachedEnd ? () => Navigator.pop(context, false) : null,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Recusar'),
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        reachedEnd ? () => Navigator.pop(context, true) : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Aceitar'),
                  ),
                ],
              );
            },
          ),
    );

    if (result == true) {
      onAccepted();
    } else if (result == false) {
      onRefused();
    }
    scrollController.dispose();
  }

  List<Map<String, String>> _pendingQuestionFiles(PermitRequestState state) {
    final pending = <Map<String, String>>[];
    for (final question in state.questions) {
      final key = question['key'] as String?;
      if (key == null || state.answers[key] != true) continue;

      final tiposResposta = List<String>.from(
        question['tipos_resposta'] ?? const [],
      );
      final hasDocumentFlow =
          tiposResposta.contains('Anexar Documento') ||
          (question['modelo_documento_url'] as String?)?.trim().isNotEmpty ==
              true;
      if (!hasDocumentFlow) continue;

      final answer = state.answerDetails[key];
      final arquivo =
          answer is Map ? (answer['arquivo']?.toString().trim() ?? '') : '';
      if (arquivo.isNotEmpty) continue;

      pending.add({
        'pergunta': question['pergunta']?.toString() ?? key,
        'secretaria': question['secretaria']?.toString() ?? '',
        'modelo': question['modelo_documento_nome']?.toString() ?? '',
      });
    }
    return pending;
  }

  Future<void> _pickDate() async {
    final state = ref.read(permitRequestControllerProvider);
    final deadlineDays =
        int.tryParse(state.eventData['prazo_dias_uteis'] ?? '') ?? 15;
    final firstValidDate = _addBusinessDays(DateTime.now(), deadlineDays);
    final selected = await showDatePicker(
      context: context,
      initialDate: firstValidDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected == null || !mounted) return;
    final value =
        '${selected.year.toString().padLeft(4, '0')}-'
        '${selected.month.toString().padLeft(2, '0')}-'
        '${selected.day.toString().padLeft(2, '0')}';
    eventDateController.text = value;
    ref
        .read(permitRequestControllerProvider.notifier)
        .updateEventInfo(eventDate: value);
  }

  DateTime _addBusinessDays(DateTime startDate, int businessDays) {
    var currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    var addedDays = 0;
    while (addedDays < businessDays) {
      currentDate = currentDate.add(const Duration(days: 1));
      if (currentDate.weekday <= DateTime.friday) {
        addedDays += 1;
      }
    }
    return currentDate;
  }

  Future<void> _pickTime(
    TextEditingController controller,
    ValueChanged<String> onSelected,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    final value =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    controller.text = value;
    onSelected(value);
  }
}

class _TermStatus extends StatelessWidget {
  const _TermStatus({required this.accepted, required this.refused});

  final bool accepted;
  final bool refused;

  @override
  Widget build(BuildContext context) {
    final color =
        accepted
            ? const Color(0xFF0E5F2F)
            : refused
            ? Theme.of(context).colorScheme.error
            : const Color(0xFF6F5A00);
    final background =
        accepted
            ? const Color(0xFFE5F4EA)
            : refused
            ? const Color(0xFFFFECEC)
            : const Color(0xFFFFF7D6);
    final icon =
        accepted
            ? Icons.check_circle_outline
            : refused
            ? Icons.cancel_outlined
            : Icons.info_outline;
    final text =
        accepted
            ? 'Termo aceito'
            : refused
            ? 'Termo recusado. O envio ficará bloqueado.'
            : 'Termo pendente de leitura e aceite.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.values});

  final String title;
  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...values.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${_label(entry.key)}: ${entry.value}'),
            ),
          ),
        ],
      ),
    );
  }

  String _label(String key) {
    return key
        .replaceAll('_', ' ')
        .replaceFirstMapped(
          RegExp(r'^[a-z]'),
          (match) => match[0]!.toUpperCase(),
        );
  }
}

class _AddressMapPickerDialog extends StatefulWidget {
  const _AddressMapPickerDialog({
    required this.initialLatitude,
    required this.initialLongitude,
  });

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<_AddressMapPickerDialog> createState() =>
      _AddressMapPickerDialogState();
}

class _AddressMapPickerDialogState extends State<_AddressMapPickerDialog> {
  static const _zoom = 14;
  static const _centerLat = -13.3704;
  static const _centerLng = -39.0733;

  late double _latitude = widget.initialLatitude ?? _centerLat;
  late double _longitude = widget.initialLongitude ?? _centerLng;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marcar endereço do evento'),
          actions: [
            TextButton(
              onPressed:
                  () => Navigator.pop(context, (
                    latitude: _latitude,
                    longitude: _longitude,
                  )),
              child: const Text('Salvar'),
            ),
            IconButton(
              tooltip: 'Fechar',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Toque no mapa para marcar o local do evento. Use o endereço digitado como referência.',
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final center = _project(_centerLat, _centerLng, _zoom);
                  final selected = _project(_latitude, _longitude, _zoom);
                  final markerLeft = selected.dx - center.dx + size.width / 2;
                  final markerTop = selected.dy - center.dy + size.height / 2;
                  return GestureDetector(
                    onTapUp: (details) {
                      final point = Offset(
                        center.dx - size.width / 2 + details.localPosition.dx,
                        center.dy - size.height / 2 + details.localPosition.dy,
                      );
                      final coordinates = _unproject(point, _zoom);
                      setState(() {
                        _latitude = coordinates.$1;
                        _longitude = coordinates.$2;
                      });
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ..._tiles(size, center),
                        Positioned(
                          left:
                              markerLeft.clamp(16, size.width - 48).toDouble(),
                          top: markerTop.clamp(16, size.height - 56).toDouble(),
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF0E7C3A),
                            size: 42,
                          ),
                        ),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'Lat ${_latitude.toStringAsFixed(6)} | Lng ${_longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _tiles(Size size, Offset center) {
    final topLeft = Offset(
      center.dx - size.width / 2,
      center.dy - size.height / 2,
    );
    final bottomRight = Offset(
      center.dx + size.width / 2,
      center.dy + size.height / 2,
    );
    final minX = (topLeft.dx / 256).floor() - 1;
    final maxX = (bottomRight.dx / 256).ceil() + 1;
    final minY = (topLeft.dy / 256).floor() - 1;
    final maxY = (bottomRight.dy / 256).ceil() + 1;
    final widgets = <Widget>[];
    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        widgets.add(
          Positioned(
            left: x * 256 - topLeft.dx,
            top: y * 256 - topLeft.dy,
            width: 256,
            height: 256,
            child: Image.network(
              'https://tile.openstreetmap.org/$_zoom/$x/$y.png',
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => Container(color: const Color(0xFFE8F2EC)),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  static Offset _project(double lat, double lng, int zoom) {
    final scale = 256 * math.pow(2, zoom).toDouble();
    final x = (lng + 180) / 360 * scale;
    final sinLat = math.sin(lat * math.pi / 180);
    final y =
        (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale;
    return Offset(x, y);
  }

  static (double, double) _unproject(Offset point, int zoom) {
    final scale = 256 * math.pow(2, zoom).toDouble();
    final lng = point.dx / scale * 360 - 180;
    final n = math.pi - 2 * math.pi * point.dy / scale;
    final sinh = (math.exp(n) - math.exp(-n)) / 2;
    final lat = 180 / math.pi * math.atan(sinh);
    return (lat, lng);
  }
}
