import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/user_provider.dart';
import '../controller/permit_request_controller.dart';
import '../widgets/question_field_widget.dart';

class PermitRequestFormBuilder extends ConsumerStatefulWidget {
  const PermitRequestFormBuilder({super.key});

  @override
  ConsumerState<PermitRequestFormBuilder> createState() =>
      _PermitRequestFormBuilderState();
}

class _PermitRequestFormBuilderState
    extends ConsumerState<PermitRequestFormBuilder> {
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

  @override
  void initState() {
    super.initState();
    final state = ref.read(permitRequestControllerProvider);
    final user = ref.read(userProvider);

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

    ref
        .read(permitRequestControllerProvider.notifier)
        .updateBasicInfo(
          name: nomeController.text,
          cpfCnpj: cpfCnpjController.text,
          address: addressController.text,
          phone: phoneController.text,
          email: emailController.text,
        );

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
          TextFormField(
            controller: nomeController,
            decoration: const InputDecoration(labelText: 'Nome completo'),
            onChanged: (value) => controller.updateBasicInfo(name: value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: cpfCnpjController,
            decoration: const InputDecoration(labelText: 'CPF/CNPJ'),
            onChanged: (value) => controller.updateBasicInfo(cpfCnpj: value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefone'),
            onChanged: (value) => controller.updateBasicInfo(phone: value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
            onChanged: (value) => controller.updateBasicInfo(email: value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: addressController,
            decoration: const InputDecoration(
              labelText: 'Endereço residencial',
            ),
            onChanged: (value) => controller.updateBasicInfo(address: value),
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
            decoration: const InputDecoration(labelText: 'Local/endereço'),
            onChanged:
                (value) => controller.updateEventInfo(eventAddress: value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: expectedPublicController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Expectativa de público',
            ),
            onChanged:
                (value) => controller.updateEventInfo(expectedPublic: value),
          ),
          const SizedBox(height: 12),
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
        questionId: question['id'] as int,
        questionText: question['pergunta'] as String,
        tiposResposta: List<String>.from(question['tipos_resposta'] ?? []),
        onChanged: (value) => controller.updateAnswer(questionKey, value),
        currentValue: state.answerDetails[questionKey],
      );
    }

    if (state.currentStep == state.totalSteps - 1) {
      final requirements = controller.previewRequirements();
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
          Text(
            state.eventData['is_beneficente'] == 'true'
                ? 'DAM: isento mediante conferência da declaração beneficente.'
                : 'DAM: pendente de emissão/pagamento na Receita Municipal.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return const SizedBox();
  }

  Future<void> _pickDate() async {
    final firstValidDate = _addBusinessDays(DateTime.now(), 15);
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
