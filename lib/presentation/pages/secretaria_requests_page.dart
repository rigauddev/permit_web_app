import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/permit_api_service.dart';
import '../../core/routes/app_routes.dart';
import '../../core/session_expiration.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/user_provider.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'event_credential_page.dart';

class SecretariaRequestsPage extends ConsumerStatefulWidget {
  const SecretariaRequestsPage({super.key, required this.userType});

  final String userType;

  @override
  ConsumerState<SecretariaRequestsPage> createState() =>
      _SecretariaRequestsPageState();
}

class _SecretariaRequestsPageState
    extends ConsumerState<SecretariaRequestsPage> {
  final _api = PermitApiService();

  bool _loading = true;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _eventTypes = [];
  String? _error;
  late Set<String> _statusFilter;
  DateTimeRange? _dateFilter;
  int _currentPage = 0;
  int _rowsPerPage = 10;

  static const _openStatuses = {
    'enviada',
    'em_analise',
    'pendente_correcao',
    'aguardando_geracao_dam',
    'aguardando_pagamento_dam',
    'aguardando_geracao_alvara',
    'isenta_dam',
  };

  @override
  void initState() {
    super.initState();
    _statusFilter = _initialStatusFilter();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      final results = await Future.wait([
        _api.listRequests(token),
        _api.listEventTypes(accessToken: token),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0];
        _eventTypes = results[1];
      });
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar as solicitações.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateRequirement({
    required int requirementId,
    required String status,
    required String title,
  }) async {
    final observation = await _askObservation(title);
    if (observation == null) return;
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      await _api.updateRequirementStatus(
        accessToken: token,
        requirementId: requirementId,
        status: status,
        observacoes: observation.trim().isEmpty ? null : observation.trim(),
      );
      await _loadRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solicitação atualizada.')));
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _scheduleRequirementInspection(int requirementId) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selectedDate == null || !mounted) return;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (selectedTime == null) return;
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      await _api.scheduleInspection(
        accessToken: token,
        requirementId: requirementId,
        scheduledFor: _dateToIso(selectedDate),
        scheduledTime: _timeToText(selectedTime),
      );
      await _loadRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vistoria agendada.')));
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _confirmRequirementInspection(int requirementId) async {
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      await _api.confirmInspection(
        accessToken: token,
        requirementId: requirementId,
      );
      await _loadRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vistoria confirmada.')));
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _createAdditionalRequirement(
    Map<String, dynamic> request,
  ) async {
    if ((request['status']?.toString() ?? '') != 'autorizada') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Só é possível incluir perguntas em solicitações autorizadas.',
          ),
        ),
      );
      return;
    }
    final input = await _askAdditionalRequirement();
    if (input == null) return;
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      final requestId = request['formId'] as int? ?? request['id'] as int?;
      if (requestId == null) return;
      await _api.createAdditionalRequirement(
        accessToken: token,
        requestId: requestId,
        pergunta: input.pergunta,
        observacoes: input.observacoes,
        requiresInspection: input.requiresInspection,
        checklistVistoria: input.checklistVistoria,
        inspectionRequiresPhoto: input.inspectionRequiresPhoto,
        prazoRespostaDiasUteis: input.prazoRespostaDiasUteis,
      );
      await _loadRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pergunta adicionada à solicitação.')),
      );
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _reclassifyRequest(Map<String, dynamic> request) async {
    final requestId = request['formId'] as int? ?? request['id'] as int?;
    if (requestId == null) return;
    if (_eventTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma categoria de evento carregada.')),
      );
      return;
    }
    final selected = await _askEventType(request);
    if (selected == null) return;
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      await _api.reclassifyRequestEventType(
        accessToken: token,
        requestId: requestId,
        eventTypeKey: selected.key,
        eventTypeName: selected.name,
      );
      await _loadRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tipo de evento reclassificado.')),
      );
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<_EventTypeChoice?> _askEventType(Map<String, dynamic> request) {
    final currentKey = _requestEventTypeKey(request);
    var selectedKey =
        _eventTypes.any((item) => item['key']?.toString() == currentKey)
            ? currentKey
            : _eventTypes.first['key']?.toString();
    return showDialog<_EventTypeChoice>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Reclassificar tipo de evento'),
                  content: SizedBox(
                    width: 460,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedKey,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de evento',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          _eventTypes
                              .map(
                                (eventType) => DropdownMenuItem(
                                  value: eventType['key']?.toString() ?? '',
                                  child: Text(
                                    eventType['name']?.toString() ??
                                        eventType['key']?.toString() ??
                                        '',
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) => setDialogState(() => selectedKey = value),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed:
                          selectedKey == null
                              ? null
                              : () {
                                final eventType = _eventTypes.firstWhere(
                                  (item) =>
                                      item['key']?.toString() == selectedKey,
                                );
                                Navigator.pop(
                                  context,
                                  _EventTypeChoice(
                                    key: eventType['key']?.toString() ?? '',
                                    name:
                                        eventType['name']?.toString() ??
                                        eventType['key']?.toString() ??
                                        '',
                                  ),
                                );
                              },
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<_AdditionalRequirementInput?> _askAdditionalRequirement() async {
    final perguntaController = TextEditingController();
    final observacoesController = TextEditingController();
    final prazoController = TextEditingController(text: '2');
    final checklistController = TextEditingController();
    var requiresInspection = false;
    var inspectionRequiresPhoto = false;
    final checklist = <String>[];
    return showDialog<_AdditionalRequirementInput>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Incluir pergunta na solicitação'),
                  content: SizedBox(
                    width: 520,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: perguntaController,
                            decoration: const InputDecoration(
                              labelText: 'Pergunta ou exigência',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: observacoesController,
                            decoration: const InputDecoration(
                              labelText: 'Orientação ao cidadão',
                              border: OutlineInputBorder(),
                            ),
                            minLines: 2,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: prazoController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Prazo em dias úteis',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Exige vistoria?'),
                            value: requiresInspection,
                            onChanged:
                                (value) => setDialogState(() {
                                  requiresInspection = value ?? false;
                                  if (!requiresInspection) {
                                    inspectionRequiresPhoto = false;
                                    checklist.clear();
                                  }
                                }),
                          ),
                          if (requiresInspection) ...[
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Exigir foto na vistoria'),
                              value: inspectionRequiresPhoto,
                              onChanged:
                                  (value) => setDialogState(
                                    () =>
                                        inspectionRequiresPhoto =
                                            value ?? false,
                                  ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: checklistController,
                                    decoration: const InputDecoration(
                                      labelText: 'Item do checklist',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  tooltip: 'Adicionar item',
                                  onPressed:
                                      () => setDialogState(() {
                                        final value =
                                            checklistController.text.trim();
                                        if (value.isEmpty ||
                                            checklist.contains(value)) {
                                          return;
                                        }
                                        checklist.add(value);
                                        checklistController.clear();
                                      }),
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  checklist
                                      .map(
                                        (item) => InputChip(
                                          label: Text(item),
                                          onDeleted:
                                              () => setDialogState(
                                                () => checklist.remove(item),
                                              ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        final pergunta = perguntaController.text.trim();
                        if (pergunta.length < 3) return;
                        final prazo =
                            int.tryParse(prazoController.text.trim()) ?? 2;
                        Navigator.pop(
                          context,
                          _AdditionalRequirementInput(
                            pergunta: pergunta,
                            observacoes:
                                observacoesController.text.trim().isEmpty
                                    ? null
                                    : observacoesController.text.trim(),
                            prazoRespostaDiasUteis: prazo.clamp(1, 30),
                            requiresInspection: requiresInspection,
                            checklistVistoria: List<String>.from(checklist),
                            inspectionRequiresPhoto: inspectionRequiresPhoto,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    final rawUrl = attachment['arquivo_url']?.toString() ?? '';
    if (rawUrl.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anexo sem URL disponível.')),
      );
      return;
    }
    final uri = Uri.parse(_api.resolveFileUrl(rawUrl));
    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o anexo.')),
      );
    }
  }

  Future<String?> _askObservation(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Observação',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Confirmar'),
              ),
            ],
          ),
    );
  }

  Set<String> _initialStatusFilter() {
    final value = Uri.base.queryParameters['status'];
    if (value == null || value.trim().isEmpty) {
      return Set<String>.from(_openStatuses);
    }
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  Future<void> _attachWorkflowDocument({
    required Map<String, dynamic> request,
    required String title,
    required String action,
  }) async {
    final attachment = await _askAttachment(
      title: title,
      description:
          action == 'dam'
              ? 'Selecione o DAM gerado pela Receita Municipal.'
              : 'Selecione o alvará final em PDF. Esse arquivo ficará disponível para o cidadão visualizar, baixar ou compartilhar.',
      allowedExtensions: const ['pdf'],
      submitLabel: action == 'dam' ? 'Anexar DAM' : 'Anexar alvará final',
    );
    if (attachment == null) return;
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      final requestId = request['formId'] as int? ?? request['id'] as int?;
      if (requestId == null) return;
      if (action == 'dam') {
        await _api.attachDam(
          accessToken: token,
          requestId: requestId,
          fileName: attachment.fileName,
          fileUrl: attachment.fileUrl,
          mimeType: attachment.mimeType,
        );
      } else {
        await _api.attachFinalPermit(
          accessToken: token,
          requestId: requestId,
          fileName: attachment.fileName,
          fileUrl: attachment.fileUrl,
          mimeType: attachment.mimeType,
        );
      }
      await _loadRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'dam' ? 'DAM anexado.' : 'Alvará anexado.'),
        ),
      );
      if (action != 'dam') {
        final updatedRequest = _requests.firstWhere(
          (item) =>
              (item['formId'] ?? item['id']) ==
              (request['formId'] ?? request['id']),
          orElse: () => request,
        );
        await _openCredential(updatedRequest);
      }
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openCredential(Map<String, dynamic> request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EventCredentialPage(
              permitForm: request,
              userType: widget.userType,
            ),
      ),
    );
    if (mounted) await _loadRequests();
  }

  Future<_AttachmentInput?> _askAttachment({
    required String title,
    required String description,
    required List<String> allowedExtensions,
    required String submitLabel,
  }) async {
    var uploading = false;
    return showDialog<_AttachmentInput>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(title),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(description),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              uploading
                                  ? null
                                  : () async {
                                    final result = await FilePicker.platform
                                        .pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions: allowedExtensions,
                                          withData: true,
                                        );
                                    final file =
                                        result == null || result.files.isEmpty
                                            ? null
                                            : result.files.single;
                                    if (file == null) return;
                                    final extension =
                                        file.name.split('.').last.toLowerCase();
                                    if (!allowedExtensions.contains(
                                      extension,
                                    )) {
                                      return;
                                    }
                                    setDialogState(() => uploading = true);
                                    final token =
                                        await SessionExpiration.readAccessToken();
                                    if (token == null || token.isEmpty) {
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                      return;
                                    }
                                    final upload = await _api.uploadFile(
                                      accessToken: token,
                                      kind: 'solicitacoes/anexos',
                                      file: file,
                                    );
                                    if (!context.mounted) return;
                                    Navigator.pop(
                                      context,
                                      _AttachmentInput(
                                        fileName:
                                            upload['file_name']?.toString() ??
                                            file.name,
                                        fileUrl:
                                            upload['file_url']?.toString() ??
                                            '',
                                        mimeType:
                                            upload['mime_type']?.toString(),
                                      ),
                                    );
                                  },
                          icon:
                              uploading
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.upload_file),
                          label: Text(uploading ? 'Enviando...' : submitLabel),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          uploading ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final visibleRequests = _filterRequestsForUser(
      _requests,
      user,
      _statusFilter,
      _dateFilter,
    );
    final totalPages = _totalPages(visibleRequests.length);
    final safePage = _currentPage >= totalPages ? totalPages - 1 : _currentPage;
    if (safePage != _currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentPage = safePage);
      });
    }
    final pagedRequests = _pageItems(visibleRequests, safePage);
    final byType = _groupByType(pagedRequests);

    return AppScaffold(
      userType: widget.userType,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed:
              () => Navigator.pushReplacementNamed(context, AppRoutes.home),
        ),
        title: const Text('Central de solicitações'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(user: user, total: visibleRequests.length),
                    const SizedBox(height: 16),
                    _StatusFilters(
                      selected: _statusFilter,
                      openStatuses: _openStatuses,
                      onChanged:
                          (next) => setState(() {
                            _statusFilter = next;
                            _currentPage = 0;
                          }),
                    ),
                    const SizedBox(height: 12),
                    _DateFilters(
                      period: _dateFilter,
                      onPickPeriod: _pickDateFilter,
                      onClear:
                          () => setState(() {
                            _dateFilter = null;
                            _currentPage = 0;
                          }),
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_error != null)
                      _EmptyState(
                        icon: Icons.error_outline,
                        title: _error!,
                        action: _loadRequests,
                      )
                    else if (byType.isEmpty)
                      _EmptyState(
                        icon: Icons.inbox_outlined,
                        title:
                            'Nenhuma solicitação aguardando esta secretaria.',
                        action: _loadRequests,
                      )
                    else ...[
                      _PaginationControls(
                        totalItems: visibleRequests.length,
                        currentPage: safePage,
                        totalPages: totalPages,
                        rowsPerPage: _rowsPerPage,
                        onRowsPerPageChanged:
                            (value) => setState(() {
                              _rowsPerPage = value;
                              _currentPage = 0;
                            }),
                        onPrevious:
                            safePage <= 0
                                ? null
                                : () => setState(() => _currentPage--),
                        onNext:
                            safePage >= totalPages - 1
                                ? null
                                : () => setState(() => _currentPage++),
                      ),
                      const SizedBox(height: 12),
                      ...byType.entries.map(
                        (entry) => _ServiceGroup(
                          title: entry.key,
                          requests: entry.value,
                          currentUser: user,
                          onApprove:
                              (id) => _updateRequirement(
                                requirementId: id,
                                status: 'aprovada',
                                title: 'Aprovar exigência',
                              ),
                          onPending:
                              (id) => _updateRequirement(
                                requirementId: id,
                                status: 'pendente_documento',
                                title: 'Solicitar correção/documento',
                              ),
                          onReject:
                              (id) => _updateRequirement(
                                requirementId: id,
                                status: 'recusada',
                                title: 'Recusar exigência',
                              ),
                          onScheduleInspection: _scheduleRequirementInspection,
                          onConfirmInspection: _confirmRequirementInspection,
                          onAttachDam:
                              (request) => _attachWorkflowDocument(
                                request: request,
                                title: 'Anexar DAM gerado',
                                action: 'dam',
                              ),
                          onAttachFinalPermit:
                              (request) => _attachWorkflowDocument(
                                request: request,
                                title: 'Anexar alvará final',
                                action: 'alvara',
                              ),
                          onOpenDetails: _showRequestDetails,
                          onOpenAttachment: _openAttachment,
                          onCreateAdditionalRequirement:
                              _createAdditionalRequirement,
                          onReclassify: _reclassifyRequest,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _PaginationControls(
                        totalItems: visibleRequests.length,
                        currentPage: safePage,
                        totalPages: totalPages,
                        rowsPerPage: _rowsPerPage,
                        compact: true,
                        onRowsPerPageChanged:
                            (value) => setState(() {
                              _rowsPerPage = value;
                              _currentPage = 0;
                            }),
                        onPrevious:
                            safePage <= 0
                                ? null
                                : () => setState(() => _currentPage--),
                        onNext:
                            safePage >= totalPages - 1
                                ? null
                                : () => setState(() => _currentPage++),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<Map<String, dynamic>> _filterRequestsForUser(
    List<Map<String, dynamic>> requests,
    UserModel? user,
    Set<String> statusFilter,
    DateTimeRange? dateFilter,
  ) {
    bool matchesStatus(Map<String, dynamic> request) =>
        statusFilter.isEmpty ||
        statusFilter.contains(request['status']?.toString() ?? '');
    bool matchesDate(Map<String, dynamic> request) {
      if (dateFilter == null) return true;
      final date = DateTime.tryParse(
        request['data_do_evento']?.toString() ?? '',
      );
      if (date == null) return false;
      final start = DateTime(
        dateFilter.start.year,
        dateFilter.start.month,
        dateFilter.start.day,
      );
      final end = DateTime(
        dateFilter.end.year,
        dateFilter.end.month,
        dateFilter.end.day,
        23,
        59,
        59,
      );
      return !date.isBefore(start) && !date.isAfter(end);
    }

    if (user?.userType == 'admin') {
      return requests
          .where((request) => matchesStatus(request) && matchesDate(request))
          .toList();
    }
    final secretaria = user?.secretaria;
    if (secretaria == null || secretaria.isEmpty) return const [];
    return requests.where((request) {
      if (!matchesStatus(request)) return false;
      if (!matchesDate(request)) return false;
      if (secretaria == 'desenvolvimento_economico') return true;
      final requirements = request['perguntas'] as List<dynamic>? ?? [];
      return requirements.any(
        (item) =>
            item is Map<String, dynamic> &&
            item['secretaria_slug'] == secretaria,
      );
    }).toList();
  }

  Future<void> _pickDateFilter() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _dateFilter,
      firstDate: DateTime(now.year - 6),
      lastDate: DateTime(now.year + 2),
      helpText: 'Filtrar por data do evento',
      saveText: 'Aplicar',
      builder:
          (context, child) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
    );
    if (selected == null) return;
    setState(() {
      _dateFilter = selected;
      _currentPage = 0;
    });
  }

  int _totalPages(int totalItems) {
    if (totalItems == 0) return 1;
    return (totalItems / _rowsPerPage).ceil();
  }

  List<Map<String, dynamic>> _pageItems(
    List<Map<String, dynamic>> items,
    int page,
  ) {
    final start = page * _rowsPerPage;
    if (start >= items.length) return const [];
    final end = (start + _rowsPerPage).clamp(0, items.length);
    return items.sublist(start, end);
  }

  static Map<String, List<Map<String, dynamic>>> _groupByType(
    List<Map<String, dynamic>> requests,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final request in requests) {
      final type = request['permitType']?.toString() ?? 'Serviço';
      grouped.putIfAbsent(type, () => []).add(request);
    }
    return grouped;
  }

  Future<void> _showRequestDetails(Map<String, dynamic> request) {
    return showDialog<void>(
      context: context,
      builder:
          (context) => _RequestDetailsDialog(
            request: request,
            onOpenAttachment: _openAttachment,
          ),
    );
  }

  static String _dateToIso(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _timeToText(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.total});

  final UserModel? user;
  final int total;

  @override
  Widget build(BuildContext context) {
    final secretaria =
        user?.userType == 'admin'
            ? 'Todas as secretarias'
            : _formatSecretaria(user?.secretaria);
    return Row(
      children: [
        Image.asset('assets/images/logo_prefeitura_1.png', height: 64),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                secretaria,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text('$total solicitação(ões) com exigências vinculadas.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({
    required this.selected,
    required this.openStatuses,
    required this.onChanged,
  });

  final Set<String> selected;
  final Set<String> openStatuses;
  final ValueChanged<Set<String>> onChanged;

  static const _filters = [
    'aguardando_geracao_dam',
    'aguardando_pagamento_dam',
    'aguardando_geracao_alvara',
    'em_analise',
    'pendente_correcao',
    'autorizada',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Filtrar:'),
        FilterChip(
          label: const Text('Todos'),
          selected: selected.isEmpty,
          onSelected: (_) => onChanged(<String>{}),
        ),
        FilterChip(
          label: const Text('Em aberto'),
          selected:
              selected.length == openStatuses.length &&
              selected.containsAll(openStatuses),
          onSelected: (_) => onChanged(Set<String>.from(openStatuses)),
        ),
        ..._filters.map((status) {
          final isSelected = selected.contains(status);
          return FilterChip(
            label: Text(_formatStatus(status)),
            selected: isSelected,
            onSelected: (value) {
              final next = Set<String>.from(selected);
              if (value) {
                next.add(status);
              } else {
                next.remove(status);
              }
              onChanged(next);
            },
          );
        }),
      ],
    );
  }
}

class _DateFilters extends StatelessWidget {
  const _DateFilters({
    required this.period,
    required this.onPickPeriod,
    required this.onClear,
  });

  final DateTimeRange? period;
  final VoidCallback onPickPeriod;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Data do evento:'),
        OutlinedButton.icon(
          onPressed: onPickPeriod,
          icon: const Icon(Icons.date_range_outlined),
          label: Text(
            period == null ? 'Todos os períodos' : _formatPeriod(period),
          ),
        ),
        if (period != null)
          IconButton(
            tooltip: 'Limpar período',
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.totalItems,
    required this.currentPage,
    required this.totalPages,
    required this.rowsPerPage,
    required this.onRowsPerPageChanged,
    required this.onPrevious,
    required this.onNext,
    this.compact = false,
  });

  final int totalItems;
  final int currentPage;
  final int totalPages;
  final int rowsPerPage;
  final ValueChanged<int> onRowsPerPageChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : currentPage * rowsPerPage + 1;
    final end =
        totalItems == 0
            ? 0
            : ((currentPage + 1) * rowsPerPage).clamp(0, totalItems);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$start-$end de $totalItems'),
        if (!compact)
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<int>(
              initialValue: rowsPerPage,
              decoration: const InputDecoration(
                labelText: 'Por página',
                border: OutlineInputBorder(),
              ),
              items:
                  const [10, 25, 50]
                      .map(
                        (value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(value.toString()),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) onRowsPerPageChanged(value);
              },
            ),
          ),
        IconButton.outlined(
          tooltip: 'Página anterior',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Página ${currentPage + 1} de $totalPages'),
        IconButton.outlined(
          tooltip: 'Próxima página',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _ServiceGroup extends StatelessWidget {
  const _ServiceGroup({
    required this.title,
    required this.requests,
    required this.currentUser,
    required this.onApprove,
    required this.onPending,
    required this.onReject,
    required this.onScheduleInspection,
    required this.onConfirmInspection,
    required this.onAttachDam,
    required this.onAttachFinalPermit,
    required this.onOpenDetails,
    required this.onOpenAttachment,
    required this.onCreateAdditionalRequirement,
    required this.onReclassify,
  });

  final String title;
  final List<Map<String, dynamic>> requests;
  final UserModel? currentUser;
  final void Function(int requirementId) onApprove;
  final void Function(int requirementId) onPending;
  final void Function(int requirementId) onReject;
  final void Function(int requirementId) onScheduleInspection;
  final void Function(int requirementId) onConfirmInspection;
  final ValueChanged<Map<String, dynamic>> onAttachDam;
  final ValueChanged<Map<String, dynamic>> onAttachFinalPermit;
  final ValueChanged<Map<String, dynamic>> onOpenDetails;
  final ValueChanged<Map<String, dynamic>> onOpenAttachment;
  final ValueChanged<Map<String, dynamic>> onCreateAdditionalRequirement;
  final ValueChanged<Map<String, dynamic>> onReclassify;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${requests.length} solicitação(ões)'),
        children:
            requests.map((request) {
              final requirements = _visibleRequirements(request, currentUser);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: _RequestCard(
                  request: request,
                  requirements: requirements,
                  currentUser: currentUser,
                  onApprove: onApprove,
                  onPending: onPending,
                  onReject: onReject,
                  onScheduleInspection: onScheduleInspection,
                  onConfirmInspection: onConfirmInspection,
                  onAttachDam: onAttachDam,
                  onAttachFinalPermit: onAttachFinalPermit,
                  onOpenDetails: onOpenDetails,
                  onOpenAttachment: onOpenAttachment,
                  onCreateAdditionalRequirement: onCreateAdditionalRequirement,
                  onReclassify: onReclassify,
                ),
              );
            }).toList(),
      ),
    );
  }

  static List<Map<String, dynamic>> _visibleRequirements(
    Map<String, dynamic> request,
    UserModel? user,
  ) {
    final requirements =
        (request['perguntas'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
    if (user?.userType == 'admin') return requirements;
    return requirements
        .where((item) => item['secretaria_slug'] == user?.secretaria)
        .toList();
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.requirements,
    required this.currentUser,
    required this.onApprove,
    required this.onPending,
    required this.onReject,
    required this.onScheduleInspection,
    required this.onConfirmInspection,
    required this.onAttachDam,
    required this.onAttachFinalPermit,
    required this.onOpenDetails,
    required this.onOpenAttachment,
    required this.onCreateAdditionalRequirement,
    required this.onReclassify,
  });

  final Map<String, dynamic> request;
  final List<Map<String, dynamic>> requirements;
  final UserModel? currentUser;
  final void Function(int requirementId) onApprove;
  final void Function(int requirementId) onPending;
  final void Function(int requirementId) onReject;
  final void Function(int requirementId) onScheduleInspection;
  final void Function(int requirementId) onConfirmInspection;
  final ValueChanged<Map<String, dynamic>> onAttachDam;
  final ValueChanged<Map<String, dynamic>> onAttachFinalPermit;
  final ValueChanged<Map<String, dynamic>> onOpenDetails;
  final ValueChanged<Map<String, dynamic>> onOpenAttachment;
  final ValueChanged<Map<String, dynamic>> onCreateAdditionalRequirement;
  final ValueChanged<Map<String, dynamic>> onReclassify;

  @override
  Widget build(BuildContext context) {
    final requestStatus = request['status']?.toString() ?? '';
    final isViewMode = _isAuthorizedViewStatus(requestStatus);
    final canCreateQuestion = requestStatus == 'autorizada';
    final eventTypeName = _requestEventTypeName(request);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _compactText(request['nome_do_evento']?.toString() ?? 'Evento'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              _StatusChip(status: requestStatus),
              if (isViewMode)
                const Chip(
                  avatar: Icon(Icons.visibility_outlined, size: 16),
                  label: Text('Modo visualização'),
                ),
              Text('Protocolo: ${request['protocolo'] ?? '-'}'),
              if (eventTypeName.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.category_outlined, size: 16),
                  label: Text(eventTypeName),
                ),
              OutlinedButton.icon(
                onPressed: () => onOpenDetails(request),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver detalhes'),
              ),
              OutlinedButton.icon(
                onPressed: () => onReclassify(request),
                icon: const Icon(Icons.swap_horiz_outlined),
                label: const Text('Reclassificar'),
              ),
              if (canCreateQuestion)
                OutlinedButton.icon(
                  onPressed: () => onCreateAdditionalRequirement(request),
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Incluir pergunta'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Tooltip(
            message:
                '${request['responsavel'] ?? '-'} | ${request['data_do_evento'] ?? '-'} | ${request['local_evento'] ?? '-'}',
            child: Text(
              '${_compactText(request['responsavel']?.toString() ?? '-')} | ${request['data_do_evento'] ?? '-'} | ${_compactText(request['local_evento']?.toString() ?? '-')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 24),
          _WorkflowActions(
            request: request,
            readOnly: isViewMode,
            onAttachDam: onAttachDam,
            onAttachFinalPermit: onAttachFinalPermit,
          ),
          if (requirements.isNotEmpty) const Divider(height: 24),
          ...requirements.map(
            (requirement) => _RequirementRow(
              requirement: requirement,
              requestStatus: requestStatus,
              readOnly: isViewMode,
              currentUser: currentUser,
              onApprove: onApprove,
              onPending: onPending,
              onReject: onReject,
              onScheduleInspection: onScheduleInspection,
              onConfirmInspection: onConfirmInspection,
              onOpenAttachment: onOpenAttachment,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestDetailsDialog extends StatelessWidget {
  const _RequestDetailsDialog({
    required this.request,
    required this.onOpenAttachment,
  });

  final Map<String, dynamic> request;
  final ValueChanged<Map<String, dynamic>> onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final requirements =
        (request['perguntas'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    final respostas = (request['respostas'] as Map<dynamic, dynamic>? ??
            const {})
        .map((key, value) => MapEntry(key.toString(), value));
    final attachments =
        (request['attachments'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    return AlertDialog(
      title: const Text('Detalhes da solicitação'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogRow(
                label: 'Evento',
                value: request['nome_do_evento']?.toString() ?? '-',
              ),
              _DialogRow(
                label: 'Protocolo',
                value: request['protocolo']?.toString() ?? '-',
              ),
              _DialogRow(
                label: 'Status geral',
                value: _formatStatus(request['status']?.toString() ?? ''),
              ),
              _DialogRow(
                label: 'Responsável',
                value: request['responsavel']?.toString() ?? '-',
              ),
              _DialogRow(
                label: 'Data',
                value: request['data_do_evento']?.toString() ?? '-',
              ),
              _DialogRow(
                label: 'Local',
                value: request['local_evento']?.toString() ?? '-',
              ),
              _DialogRow(
                label: 'Público',
                value: request['publico_estimado']?.toString() ?? '-',
              ),
              const Divider(height: 24),
              Text(
                'Respostas do cidadão',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (respostas.isEmpty)
                const Text('Nenhuma resposta registrada.')
              else
                ...respostas.entries.map(
                  (entry) => _AnswerTile(
                    label: _formatAnswerKey(entry.key),
                    value: entry.value,
                  ),
                ),
              const Divider(height: 24),
              Text(
                'Documentos anexados',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (attachments.isEmpty)
                const Text('Nenhum documento anexado.')
              else
                ...attachments.map(
                  (attachment) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_file_outlined),
                    title: Text(
                      attachment['nome_arquivo']?.toString() ??
                          'Documento anexado',
                    ),
                    subtitle: Text(
                      [attachment['tipo_documento']?.toString()]
                          .where((item) => item != null && item.isNotEmpty)
                          .join(' | '),
                    ),
                    trailing: TextButton.icon(
                      onPressed: () => onOpenAttachment(attachment),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Ver'),
                    ),
                  ),
                ),
              const Divider(height: 24),
              Text(
                'Perguntas e validações',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (requirements.isEmpty)
                const Text('Nenhuma exigência vinculada.')
              else
                ...requirements.map(
                  (requirement) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.fact_check_outlined),
                    title: Text(
                      requirement['pergunta']?.toString() ?? 'Exigência',
                    ),
                    subtitle: Text(
                      [
                            requirement['secretaria']?.toString(),
                            _formatStatus(
                              requirement['status']?.toString() ?? '',
                            ),
                            _formatStatus(
                              requirement['inspection_status']?.toString() ??
                                  '',
                            ),
                          ]
                          .where((item) => item != null && item.isNotEmpty)
                          .join(' | '),
                    ),
                  ),
                ),
            ],
          ),
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

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_formatAnswerValue(value))),
        ],
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  const _DialogRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}

class _WorkflowActions extends StatelessWidget {
  const _WorkflowActions({
    required this.request,
    required this.readOnly,
    required this.onAttachDam,
    required this.onAttachFinalPermit,
  });

  final Map<String, dynamic> request;
  final bool readOnly;
  final ValueChanged<Map<String, dynamic>> onAttachDam;
  final ValueChanged<Map<String, dynamic>> onAttachFinalPermit;

  @override
  Widget build(BuildContext context) {
    if (readOnly) return const SizedBox.shrink();
    final status = request['status']?.toString() ?? '';
    final actions = <Widget>[];
    if (status == 'aguardando_geracao_dam') {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => onAttachDam(request),
          icon: const Icon(Icons.upload_file),
          label: const Text('Anexar DAM gerado'),
        ),
      );
    }
    if (status == 'aguardando_geracao_alvara' || status == 'isenta_dam') {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => onAttachFinalPermit(request),
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Anexar alvará final'),
        ),
      );
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(spacing: 10, runSpacing: 8, children: actions),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.requirement,
    required this.requestStatus,
    required this.readOnly,
    required this.currentUser,
    required this.onApprove,
    required this.onPending,
    required this.onReject,
    required this.onScheduleInspection,
    required this.onConfirmInspection,
    required this.onOpenAttachment,
  });

  final Map<String, dynamic> requirement;
  final String requestStatus;
  final bool readOnly;
  final UserModel? currentUser;
  final void Function(int requirementId) onApprove;
  final void Function(int requirementId) onPending;
  final void Function(int requirementId) onReject;
  final void Function(int requirementId) onScheduleInspection;
  final void Function(int requirementId) onConfirmInspection;
  final ValueChanged<Map<String, dynamic>> onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final id = _requirementId(requirement['id']);
    final status = requirement['status']?.toString() ?? '';
    final attachments =
        (requirement['anexos'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    final requiresInspection = requirement['requires_inspection'] == true;
    final inspectionStatus =
        requirement['inspection_status']?.toString() ?? 'nao_agendada';
    final inspectionDate =
        requirement['inspection_scheduled_for']?.toString() ?? '';
    final inspectionTime =
        requirement['inspection_scheduled_time']?.toString() ?? '';
    final isCancelled = requestStatus == 'cancelada';
    final isLocked = status == 'aprovada' || status == 'recusada';
    final canManageLocked =
        currentUser?.userType == 'admin' ||
        currentUser?.userType == 'gestor_secretaria';
    final canAct =
        id != null &&
        !readOnly &&
        !isCancelled &&
        (!isLocked || canManageLocked);
    final canScheduleInspection =
        canAct &&
        requiresInspection &&
        (inspectionStatus == 'nao_agendada' ||
            inspectionStatus == 'vistoria_agendada' ||
            inspectionStatus == 'agendada' ||
            inspectionStatus == 'vistoria_confirmada');
    final canConfirmInspection =
        canAct &&
        requiresInspection &&
        inspectionDate.isNotEmpty &&
        (inspectionStatus == 'vistoria_agendada' ||
            inspectionStatus == 'agendada');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 330,
                child: _TooltipText(
                  requirement['pergunta']?.toString() ?? 'Exigência',
                ),
              ),
              SizedBox(
                width: 180,
                child: _TooltipText(
                  requirement['secretaria']?.toString() ?? '',
                ),
              ),
              if ((requirement['due_date']?.toString() ?? '').isNotEmpty)
                SizedBox(
                  width: 150,
                  child: Text(
                    'Prazo: ${requirement['due_date']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              if ((requirement['due_date']?.toString() ?? '').isNotEmpty)
                _DeadlineChip(dueDate: requirement['due_date']?.toString()),
              _StatusChip(status: status),
              if (requiresInspection && inspectionStatus != 'nao_agendada')
                _StatusChip(status: inspectionStatus),
              if (requiresInspection && inspectionDate.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.event_outlined, size: 16),
                  label: Text(
                    [
                      inspectionDate,
                      if (inspectionTime.isNotEmpty) inspectionTime,
                    ].join(' '),
                  ),
                ),
              if (id == null)
                const Tooltip(
                  message: 'A exigência veio sem identificador do backend.',
                  child: Icon(Icons.info_outline, size: 18),
                ),
              if (canAct) ...[
                if (canScheduleInspection)
                  OutlinedButton.icon(
                    onPressed: () => onScheduleInspection(id),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      inspectionDate.isEmpty
                          ? 'Agendar vistoria'
                          : 'Reagendar vistoria',
                    ),
                  ),
                if (canConfirmInspection)
                  OutlinedButton.icon(
                    onPressed: () => onConfirmInspection(id),
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Confirmar vistoria'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => onPending(id),
                  icon: const Icon(Icons.assignment_late_outlined),
                  label: const Text('Correção'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onReject(id),
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Recusar'),
                ),
                ElevatedButton.icon(
                  onPressed: () => onApprove(id),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Aprovar'),
                ),
              ] else if (isLocked)
                const Chip(
                  avatar: Icon(Icons.lock_outline, size: 16),
                  label: Text('Ações bloqueadas'),
                )
              else if (isCancelled)
                const Chip(
                  avatar: Icon(Icons.lock_outline, size: 16),
                  label: Text('Solicitação cancelada'),
                ),
            ],
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  attachments.map((attachment) {
                    final fileName =
                        attachment['nome_arquivo']?.toString() ??
                        'Documento anexado';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Chip(
                              avatar: const Icon(Icons.attach_file, size: 16),
                              label: Tooltip(
                                message: fileName,
                                child: Text(
                                  fileName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => onOpenAttachment(attachment),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                            ),
                            label: const Text('Ver'),
                          ),
                          if (canAct) ...[
                            OutlinedButton.icon(
                              onPressed: () => onPending(id),
                              icon: const Icon(
                                Icons.assignment_late_outlined,
                                size: 18,
                              ),
                              label: const Text('Solicitar ajuste'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => onApprove(id),
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                              ),
                              label: const Text('Aprovar documento'),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  int? _requirementId(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'aprovada' || 'autorizada' || 'isenta_dam' => Colors.green,
      'vistoria_concluida' => Colors.green,
      'recusada' || 'indeferida' || 'cancelada' => Colors.red,
      'vistoria_reprovada' => Colors.red,
      'pendente_documento' || 'pendente_correcao' => Colors.orange,
      'vistoria_agendada' || 'agendada' || 'vistoria_confirmada' => Colors.teal,
      'dam_pendente' ||
      'aguardando_geracao_dam' ||
      'aguardando_pagamento_dam' ||
      'aguardando_geracao_alvara' => Colors.blueGrey,
      _ => Colors.blue,
    };
    return Chip(
      label: Text(_formatStatus(status)),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.09),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class _DeadlineChip extends StatelessWidget {
  const _DeadlineChip({required this.dueDate});

  final String? dueDate;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(dueDate ?? '');
    if (parsed == null) return const SizedBox.shrink();
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final deadline = DateTime(parsed.year, parsed.month, parsed.day);
    final days = deadline.difference(currentDay).inDays;
    final (label, color) = switch (days) {
      < 0 => ('Prazo vencido', Colors.red),
      0 => ('Vence hoje', Colors.deepOrange),
      1 => ('Prazo próximo', Colors.orange),
      2 => ('Prazo próximo', Colors.orange),
      _ => ('No prazo', Colors.green),
    };
    return Chip(
      avatar: Icon(Icons.schedule_outlined, size: 16, color: color),
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.09),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.action,
  });

  final IconData icon;
  final String title;
  final Future<void> Function() action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: action,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentInput {
  const _AttachmentInput({
    required this.fileName,
    required this.fileUrl,
    this.mimeType,
  });

  final String fileName;
  final String fileUrl;
  final String? mimeType;
}

class _EventTypeChoice {
  const _EventTypeChoice({required this.key, required this.name});

  final String key;
  final String name;
}

class _AdditionalRequirementInput {
  const _AdditionalRequirementInput({
    required this.pergunta,
    required this.prazoRespostaDiasUteis,
    required this.requiresInspection,
    required this.checklistVistoria,
    required this.inspectionRequiresPhoto,
    this.observacoes,
  });

  final String pergunta;
  final String? observacoes;
  final int prazoRespostaDiasUteis;
  final bool requiresInspection;
  final List<String> checklistVistoria;
  final bool inspectionRequiresPhoto;
}

bool _isAuthorizedViewStatus(String status) {
  return status == 'autorizada';
}

Map<String, dynamic> _requestEventData(Map<String, dynamic> request) {
  final raw = request['dados_evento'] ?? request['eventData'];
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return request;
}

String _requestEventTypeKey(Map<String, dynamic> request) {
  final eventData = _requestEventData(request);
  return eventData['tipo_evento']?.toString() ??
      eventData['event_type_key']?.toString() ??
      '';
}

String _requestEventTypeName(Map<String, dynamic> request) {
  final eventData = _requestEventData(request);
  return eventData['tipo_evento_nome']?.toString() ??
      eventData['event_type_name']?.toString() ??
      _requestEventTypeKey(request);
}

String _formatSecretaria(String? slug) {
  switch (slug) {
    case 'meio_ambiente':
      return 'Meio Ambiente';
    case 'infraestrutura':
      return 'Infraestrutura';
    case 'desenvolvimento_economico':
      return 'Desenvolvimento Econômico';
    case 'dmtran':
      return 'DMTRAN';
    case 'vigilancia_sanitaria':
      return 'Vigilância Sanitária';
    case 'guarda_civil':
      return 'Guarda Civil Municipal';
    case 'receita_municipal':
      return 'Receita Municipal';
    default:
      return slug ?? 'Secretaria';
  }
}

String _formatStatus(String status) {
  switch (status) {
    case 'aguardando_analise':
      return 'Aguardando análise';
    case 'aprovada':
      return 'Aprovada';
    case 'recusada':
      return 'Recusada';
    case 'pendente_documento':
      return 'Pendente de documento';
    case 'em_analise':
      return 'Em análise';
    case 'aguardando_geracao_dam':
      return 'Aguardando geração do DAM';
    case 'aguardando_pagamento_dam':
      return 'Aguardando pagamento do DAM';
    case 'aguardando_geracao_alvara':
      return 'Aguardando geração do alvará';
    case 'dam_pendente':
      return 'DAM pendente';
    case 'autorizada':
      return 'Autorizada';
    case 'isenta_dam':
      return 'Isenta de DAM';
    case 'indeferida':
      return 'Indeferida';
    case 'pendente_correcao':
      return 'Pendente de correção';
    case 'cancelada':
      return 'Cancelada';
    case 'nao_agendada':
      return '';
    case 'agendada':
    case 'vistoria_agendada':
      return 'Vistoria agendada';
    case 'vistoria_confirmada':
      return 'Vistoria confirmada';
    case 'vistoria_concluida':
      return 'Vistoria concluída';
    case 'reprovada':
    case 'vistoria_reprovada':
      return 'Vistoria reprovada';
    case 'reagendada':
      return 'Vistoria reagendada';
    default:
      return status.isEmpty ? 'Status' : status;
  }
}

String _formatPeriod(DateTimeRange? period) {
  if (period == null) return 'Todos os períodos';
  return '${_formatDate(period.start)} a ${_formatDate(period.end)}';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _compactText(String value, {int maxLength = 80}) {
  final text = value.trim();
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 3)}...';
}

class _TooltipText extends StatelessWidget {
  const _TooltipText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: value,
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

String _formatAnswerKey(String key) {
  return key
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _formatAnswerValue(Object? value) {
  if (value == null) return '-';
  if (value is bool) return value ? 'Sim' : 'Não';
  if (value is List) {
    if (value.isEmpty) return '-';
    return value.map(_formatAnswerValue).join('\n');
  }
  if (value is Map) {
    if (value.isEmpty) return '-';
    return value.entries
        .map(
          (entry) =>
              '${_formatAnswerKey(entry.key.toString())}: ${_formatAnswerValue(entry.value)}',
        )
        .join('\n');
  }
  final text = value.toString().trim();
  return text.isEmpty ? '-' : text;
}
