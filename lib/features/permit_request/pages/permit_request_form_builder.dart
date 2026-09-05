import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/permit_api_service.dart';
import '../../../core/session_expiration.dart';
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
  late final TextEditingController applicantNotesController;
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
    applicantNotesController = TextEditingController(
      text: state.eventData['observacoes_solicitante'] ?? '',
    );
  }

  Future<List<Map<String, dynamic>>> _loadPublicRanges() async {
    final token = await SessionExpiration.readAccessToken();
    if (token == null || token.isEmpty) return const [];
    try {
      return await PermitApiService().listPublicRanges(accessToken: token);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _searchEventAddress() async {
    final initialQuery = eventAddressController.text.trim();
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddressSearchDialog(initialQuery: initialQuery),
    );
    if (selected == null) return;
    final address =
        selected['display_name']?.toString() ?? eventAddressController.text;
    final latitude = double.tryParse(selected['lat']?.toString() ?? '');
    final longitude = double.tryParse(selected['lon']?.toString() ?? '');
    eventAddressController.text = address;
    ref
        .read(permitRequestControllerProvider.notifier)
        .updateEventInfo(
          eventAddress: address,
          eventLatitude: latitude?.toStringAsFixed(6),
          eventLongitude: longitude?.toStringAsFixed(6),
        );
  }

  Future<PlatformFile?> _pickSingleDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single;
  }

  Future<PlatformFile?> _takeDocumentPhoto(String fileName) async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (photo == null) return null;
    final bytes = await photo.readAsBytes();
    return PlatformFile(name: fileName, size: bytes.length, bytes: bytes);
  }

  Future<void> _chooseIdentificationDocument() async {
    final controller = ref.read(permitRequestControllerProvider.notifier);
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'RG/CNH',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.upload_file_outlined),
                    title: const Text('Anexar arquivo único'),
                    subtitle: const Text('PDF ou imagem com frente e verso.'),
                    onTap: () => Navigator.pop(context, 'file'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Tirar foto da frente e do verso'),
                    onTap: () => Navigator.pop(context, 'camera'),
                  ),
                ],
              ),
            ),
          ),
    );
    if (mode == 'file') {
      final file = await _pickSingleDocument();
      if (file == null) return;
      controller
        ..removeDocumentAttachment('documento_identificacao_frente')
        ..removeDocumentAttachment('documento_identificacao_verso')
        ..setDocumentAttachment('documento_identificacao', file);
    } else if (mode == 'camera') {
      final front = await _takeDocumentPhoto('documento_frente.jpg');
      if (front == null) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agora tire a foto do verso.')),
      );
      final back = await _takeDocumentPhoto('documento_verso.jpg');
      if (back == null) return;
      controller
        ..removeDocumentAttachment('documento_identificacao')
        ..setDocumentAttachment('documento_identificacao_frente', front)
        ..setDocumentAttachment('documento_identificacao_verso', back);
    }
  }

  Future<void> _chooseResidenceProof() async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.upload_file_outlined),
                    title: const Text('Anexar arquivo'),
                    onTap: () => Navigator.pop(context, 'file'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Tirar foto'),
                    onTap: () => Navigator.pop(context, 'camera'),
                  ),
                ],
              ),
            ),
          ),
    );
    final file =
        mode == 'camera'
            ? await _takeDocumentPhoto('comprovante_residencia.jpg')
            : mode == 'file'
            ? await _pickSingleDocument()
            : null;
    if (file == null) return;
    ref
        .read(permitRequestControllerProvider.notifier)
        .setDocumentAttachment('comprovante_residencia', file);
  }

  Future<void> _chooseDocumentAttachment(String key) async {
    final file = await _pickSingleDocument();
    if (file == null) return;
    ref
        .read(permitRequestControllerProvider.notifier)
        .setDocumentAttachment(key, file);
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
    applicantNotesController.dispose();
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
              labelText: 'E-mail (opcional)',
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
      final docs = state.documentAttachments;
      return ListView(
        children: [
          const _StepTitle('Documentos obrigatórios'),
          const Text(
            'Separe os documentos principais antes de informar os dados do evento.',
          ),
          const SizedBox(height: 12),
          _DocumentRequirementCard(
            title: 'RG ou CNH',
            description:
                'Anexe um arquivo único com frente e verso ou tire duas fotos separadas.',
            icon: Icons.badge_outlined,
            files:
                [
                  docs['documento_identificacao'],
                  docs['documento_identificacao_frente'],
                  docs['documento_identificacao_verso'],
                ].whereType<PlatformFile>().toList(),
            onPressed: _chooseIdentificationDocument,
            onRemove: () {
              controller
                ..removeDocumentAttachment('documento_identificacao')
                ..removeDocumentAttachment('documento_identificacao_frente')
                ..removeDocumentAttachment('documento_identificacao_verso');
            },
          ),
          const SizedBox(height: 10),
          _DocumentRequirementCard(
            title: 'Comprovante de residência',
            description: 'Conta de água ou luz em nome do usuário, pai ou mãe.',
            icon: Icons.home_work_outlined,
            files:
                [
                  docs['comprovante_residencia'],
                ].whereType<PlatformFile>().toList(),
            onPressed: _chooseResidenceProof,
            onRemove:
                () => controller.removeDocumentAttachment(
                  'comprovante_residencia',
                ),
          ),
        ],
      );
    }

    if (state.currentStep == 2) {
      final isBeneficente = state.eventData['is_beneficente'] == 'true';
      final eventTypes = state.eventTypes;
      final selectedEventType = _selectedEventType(state);
      return ListView(
        children: [
          const _StepTitle('Dados do evento'),
          _EventTypeSelectorButton(
            eventTypes: eventTypes,
            selectedEventType: selectedEventType,
            onSelected: controller.selectEventType,
          ),
          if (selectedEventType != null) ...[
            const SizedBox(height: 12),
            _EventTypeRequirementsCard(eventType: selectedEventType),
            const SizedBox(height: 12),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8D9A8)),
              ),
              child: const Text(
                'Selecione o tipo de evento para carregar a lista de documentos e as perguntas pertinentes.',
              ),
            ),
            const SizedBox(height: 12),
          ],
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
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'publico',
                icon: Icon(Icons.account_balance_outlined),
                label: Text('Espaço público'),
              ),
              ButtonSegment(
                value: 'privado',
                icon: Icon(Icons.storefront_outlined),
                label: Text('Espaço privado'),
              ),
            ],
            selected:
                (state.eventData['tipo_espaco_evento'] ?? '').isEmpty
                    ? const <String>{}
                    : {state.eventData['tipo_espaco_evento']!},
            emptySelectionAllowed: true,
            onSelectionChanged: (value) {
              if (value.isEmpty) return;
              controller.updateEventInfo(eventSpaceType: value.first);
            },
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
                  onPressed: _searchEventAddress,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar endereço'),
                ),
              ],
            ),
          ),
          _LocationStatusCard(
            latitude: state.eventData['latitude_evento'],
            longitude: state.eventData['longitude_evento'],
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: state.eventData['local_sem_alvara'] == 'true',
            onChanged:
                (value) => controller.updateEventInfo(
                  localWithoutPermit: value ?? false,
                ),
            title: const Text('O local não possui alvará de funcionamento'),
            subtitle: const Text(
              'Nesse caso, anexe uma conta de água ou luz do endereço do local.',
            ),
          ),
          _DocumentRequirementCard(
            title:
                state.eventData['local_sem_alvara'] == 'true'
                    ? 'Comprovante de endereço do local'
                    : 'Alvará de funcionamento do local',
            description:
                state.eventData['local_sem_alvara'] == 'true'
                    ? 'Use conta de água ou luz do local do evento.'
                    : 'Se o local não tiver alvará, marque a opção acima e envie comprovante do endereço.',
            icon:
                state.eventData['local_sem_alvara'] == 'true'
                    ? Icons.home_work_outlined
                    : Icons.verified_outlined,
            tooltip:
                'Se o local não estiver regularizado com alvará, inclua documento que comprove o endereço do local, como conta de água ou luz.',
            files:
                [
                  state.eventData['local_sem_alvara'] == 'true'
                      ? state.documentAttachments['comprovante_endereco_local']
                      : state.documentAttachments['alvara_funcionamento_local'],
                ].whereType<PlatformFile>().toList(),
            onPressed:
                () => _chooseDocumentAttachment(
                  state.eventData['local_sem_alvara'] == 'true'
                      ? 'comprovante_endereco_local'
                      : 'alvara_funcionamento_local',
                ),
            onRemove:
                () => controller.removeDocumentAttachment(
                  state.eventData['local_sem_alvara'] == 'true'
                      ? 'comprovante_endereco_local'
                      : 'alvara_funcionamento_local',
                ),
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
            const SizedBox(height: 12),
            _DocumentRequirementCard(
              title: 'Documento da entidade beneficiada',
              description:
                  'Opcional nesta etapa. A prefeitura poderá solicitar validação durante a análise.',
              icon: Icons.volunteer_activism_outlined,
              files:
                  [
                    state.documentAttachments['documento_entidade_beneficente'],
                  ].whereType<PlatformFile>().toList(),
              onPressed:
                  () => _chooseDocumentAttachment(
                    'documento_entidade_beneficente',
                  ),
              onRemove:
                  () => controller.removeDocumentAttachment(
                    'documento_entidade_beneficente',
                  ),
            ),
          ],
        ],
      );
    }

    final observationsStep = state.totalSteps - 2;

    if (state.currentStep >= 3 && state.currentStep < observationsStep) {
      final questionIndex = state.currentStep - 3;
      final question = state.questions[questionIndex];
      final questionKey = question['key'] as String;

      return QuestionFieldWidget(
        key: ValueKey(questionKey),
        questionId: question['id'] as int,
        questionKey: questionKey,
        questionText: question['pergunta'] as String,
        descricao: question['descricao'] as String?,
        tiposResposta: List<String>.from(question['tipos_resposta'] ?? []),
        opcoesResposta: List<String>.from(question['opcoes_resposta'] ?? []),
        camposObrigatorios:
            (question['campos_obrigatorios'] as Map<String, dynamic>?) ??
            const {},
        modeloDocumentoNome: question['modelo_documento_nome'] as String?,
        modeloDocumentoUrl: question['modelo_documento_url'] as String?,
        onChanged: (value) => controller.updateAnswer(questionKey, value),
        currentValue: state.answerDetails[questionKey],
      );
    }

    if (state.currentStep == observationsStep) {
      return ListView(
        children: [
          const _StepTitle('Observações finais'),
          const Text(
            'Inclua alguma informação complementar sobre o evento, se necessário.',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: applicantNotesController,
            minLines: 4,
            maxLines: 7,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Observação opcional',
              alignLabelWithHint: true,
            ),
            onChanged:
                (value) => controller.updateEventInfo(applicantNotes: value),
          ),
          const SizedBox(height: 8),
          _DocumentRequirementCard(
            title: 'Anexo complementar',
            description:
                'Opcional. Use para enviar um arquivo que ajude a análise do pedido.',
            icon: Icons.attach_file_outlined,
            files:
                [
                  state.documentAttachments['observacao_anexo'],
                ].whereType<PlatformFile>().toList(),
            onPressed: () => _chooseDocumentAttachment('observacao_anexo'),
            onRemove:
                () => controller.removeDocumentAttachment('observacao_anexo'),
          ),
        ],
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
              for (final entry in state.documentAttachments.entries)
                _documentLabel(entry.key): entry.value.name,
              if (state.attachments.isNotEmpty)
                'Outros anexos': state.attachments
                    .map((file) => file.name)
                    .join(', '),
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

  Map<String, dynamic>? _selectedEventType(PermitRequestState state) {
    final selectedKey = state.eventData['tipo_evento'];
    if (selectedKey == null || selectedKey.isEmpty) return null;
    for (final eventType in state.eventTypes) {
      if (eventType['key']?.toString() == selectedKey) {
        return eventType;
      }
    }
    return {
      'key': selectedKey,
      'name': state.eventData['tipo_evento_nome'] ?? selectedKey,
      'required_documents': const [],
    };
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
      firstDate: firstValidDate,
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Selecione a data do evento',
      selectableDayPredicate:
          (date) =>
              !DateTime(
                date.year,
                date.month,
                date.day,
              ).isBefore(firstValidDate),
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

class _EventTypeSelectorButton extends StatelessWidget {
  const _EventTypeSelectorButton({
    required this.eventTypes,
    required this.selectedEventType,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> eventTypes;
  final Map<String, dynamic>? selectedEventType;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedName = selectedEventType?['name']?.toString();
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: eventTypes.isEmpty ? null : () => _openSelector(context),
          icon: const Icon(Icons.category_outlined),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              selectedName == null || selectedName.isEmpty
                  ? 'Selecionar tipo de evento'
                  : selectedName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            foregroundColor: colorScheme.primary,
            side: BorderSide(
              color:
                  selectedEventType == null
                      ? colorScheme.outline
                      : colorScheme.primary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A seleção define quais perguntas e documentos serão exibidos.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _openSelector(BuildContext context) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.72,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: eventTypes.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Tipo de evento',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    );
                  }
                  final eventType = eventTypes[index - 1];
                  final key = eventType['key']?.toString() ?? '';
                  final isSelected =
                      key == selectedEventType?['key']?.toString();
                  final description =
                      (eventType['description'] ?? eventType['descricao'])
                          ?.toString()
                          .trim();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(eventType['name']?.toString() ?? key),
                    subtitle: Text(
                      description != null && description.isNotEmpty
                          ? description
                          : eventType['examples']?.toString() ??
                              'Sem descrição cadastrada.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(context, eventType),
                  );
                },
              ),
            ),
          ),
    );
    if (selected != null) onSelected(selected);
  }
}

class _EventTypeRequirementsCard extends StatelessWidget {
  const _EventTypeRequirementsCard({required this.eventType});

  final Map<String, dynamic> eventType;

  @override
  Widget build(BuildContext context) {
    final documents = List<Map<String, dynamic>>.from(
      eventType['required_documents'] ?? const [],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E0D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eventType['name']?.toString() ?? 'Tipo de evento',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F6B43),
            ),
          ),
          if ((eventType['examples']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(eventType['examples'].toString()),
          ],
          const SizedBox(height: 8),
          const Text(
            'Documentos e informações necessárias',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (documents.isEmpty)
            const Text('Documentos gerais do alvará de evento.')
          else
            ...documents.map((document) {
              final url = document['url']?.toString() ?? '';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(document['label']?.toString() ?? ''),
                trailing:
                    url.trim().isEmpty
                        ? null
                        : IconButton(
                          tooltip: 'Baixar modelo',
                          icon: const Icon(Icons.download_outlined),
                          onPressed: () => _openDocument(url),
                        ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _openDocument(String rawReference) async {
    final parsed = Uri.tryParse(rawReference);
    final uri =
        parsed != null && parsed.hasScheme
            ? parsed
            : Uri.base.resolve(rawReference);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({required this.latitude, required this.longitude});

  final String? latitude;
  final String? longitude;

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        double.tryParse(latitude ?? '') != null &&
        double.tryParse(longitude ?? '') != null;
    final color =
        hasLocation ? const Color(0xFF0E7C3A) : const Color(0xFFB7791F);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasLocation ? Icons.check_circle_outline : Icons.location_searching,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasLocation
                  ? 'Local marcado: latitude $latitude e longitude $longitude.'
                  : 'Busque e selecione o endereço para registrar latitude e longitude do evento.',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRequirementCard extends StatelessWidget {
  const _DocumentRequirementCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.files,
    required this.onPressed,
    required this.onRemove,
    this.tooltip,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<PlatformFile> files;
  final VoidCallback onPressed;
  final VoidCallback onRemove;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final hasFiles = files.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            hasFiles
                ? const Color(0xFFF3FAF6)
                : Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasFiles ? const Color(0xFFB7DEC8) : const Color(0xFFE0E7E2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (tooltip != null)
                          Tooltip(
                            message: tooltip!,
                            child: const Icon(Icons.info_outline, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(description),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (files.isNotEmpty)
            ...files.map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(file.name, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(hasFiles ? Icons.edit_outlined : Icons.upload_file),
                label: Text(hasFiles ? 'Trocar documento' : 'Anexar documento'),
              ),
              if (hasFiles)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remover'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _documentLabel(String key) {
  switch (key) {
    case 'documento_identificacao':
      return 'RG/CNH';
    case 'documento_identificacao_frente':
      return 'RG/CNH - frente';
    case 'documento_identificacao_verso':
      return 'RG/CNH - verso';
    case 'comprovante_residencia':
      return 'Comprovante de residência';
    case 'alvara_funcionamento_local':
      return 'Alvará de funcionamento do local';
    case 'comprovante_endereco_local':
      return 'Comprovante de endereço do local';
    case 'documento_entidade_beneficente':
      return 'Documento da entidade beneficente';
    case 'observacao_anexo':
      return 'Anexo das observações finais';
    default:
      return key.replaceAll('_', ' ');
  }
}

class _AddressSearchDialog extends StatefulWidget {
  const _AddressSearchDialog({required this.initialQuery});

  final String initialQuery;

  @override
  State<_AddressSearchDialog> createState() => _AddressSearchDialogState();
}

class _AddressSearchDialogState extends State<_AddressSearchDialog> {
  late final TextEditingController _controller;
  List<Map<String, dynamic>> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().length >= 3) {
      Future.microtask(_search);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.length < 3) {
      setState(() => _error = 'Digite pelo menos 3 caracteres.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await PermitApiService().searchEventAddresses(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível buscar o endereço.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar endereço'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Rua, bairro ou local',
                suffixIcon:
                    _loading
                        ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                        : IconButton(
                          tooltip: 'Buscar',
                          onPressed: _search,
                          icon: const Icon(Icons.search),
                        ),
              ),
              onSubmitted: (_) => _search(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child:
                  _results.isEmpty
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Busque e selecione uma opção.'),
                        ),
                      )
                      : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(
                              item['display_name']?.toString() ?? '',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
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
