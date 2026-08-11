import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  final _storage = const FlutterSecureStorage();

  bool _loading = true;
  List<Map<String, dynamic>> _requests = [];
  String? _error;
  late Set<String> _statusFilter;

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
      final token = await _storage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      final requests = await _api.listRequests(token);
      if (!mounted) return;
      setState(() => _requests = requests);
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
      final token = await _storage.read(key: 'access_token');
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
    if (value == null || value.trim().isEmpty) return <String>{};
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
      final token = await _storage.read(key: 'access_token');
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
    final fileController = TextEditingController();
    final urlController = TextEditingController();
    final mimeController = TextEditingController(text: 'application/pdf');
    return showDialog<_AttachmentInput>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description),
                const SizedBox(height: 12),
                TextField(
                  controller: fileController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do arquivo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: allowedExtensions,
                    );
                    final file =
                        result == null || result.files.isEmpty
                            ? null
                            : result.files.single;
                    if (file == null) return;
                    fileController.text = file.name;
                    urlController.text = file.path ?? file.name;
                    final extension = file.name.split('.').last.toLowerCase();
                    mimeController.text =
                        extension == 'pdf' ? 'application/pdf' : '';
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Selecionar arquivo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL ou referência do arquivo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mimeController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo MIME',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (fileController.text.trim().length < 3 ||
                      urlController.text.trim().length < 3) {
                    return;
                  }
                  final extension =
                      fileController.text.trim().split('.').last.toLowerCase();
                  if (!allowedExtensions.contains(extension)) return;
                  if (mimeController.text.trim() != 'application/pdf') return;
                  Navigator.pop(
                    context,
                    _AttachmentInput(
                      fileName: fileController.text.trim(),
                      fileUrl: urlController.text.trim(),
                      mimeType:
                          mimeController.text.trim().isEmpty
                              ? null
                              : mimeController.text.trim(),
                    ),
                  );
                },
                icon: const Icon(Icons.upload_file),
                label: Text(submitLabel),
              ),
            ],
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
    );
    final byType = _groupByType(visibleRequests);

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
                      onChanged: (next) => setState(() => _statusFilter = next),
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
                    else
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
                        ),
                      ),
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
  ) {
    bool matchesStatus(Map<String, dynamic> request) =>
        statusFilter.isEmpty ||
        statusFilter.contains(request['status']?.toString() ?? '');
    if (user?.userType == 'admin') {
      return requests.where(matchesStatus).toList();
    }
    final secretaria = user?.secretaria;
    if (secretaria == null || secretaria.isEmpty) return const [];
    return requests.where((request) {
      if (!matchesStatus(request)) return false;
      if (secretaria == 'desenvolvimento_economico') return true;
      final requirements = request['perguntas'] as List<dynamic>? ?? [];
      return requirements.any(
        (item) =>
            item is Map<String, dynamic> &&
            item['secretaria_slug'] == secretaria,
      );
    }).toList();
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
      builder: (context) => _RequestDetailsDialog(request: request),
    );
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
  const _StatusFilters({required this.selected, required this.onChanged});

  final Set<String> selected;
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

class _ServiceGroup extends StatelessWidget {
  const _ServiceGroup({
    required this.title,
    required this.requests,
    required this.currentUser,
    required this.onApprove,
    required this.onPending,
    required this.onReject,
    required this.onAttachDam,
    required this.onAttachFinalPermit,
    required this.onOpenDetails,
  });

  final String title;
  final List<Map<String, dynamic>> requests;
  final UserModel? currentUser;
  final void Function(int requirementId) onApprove;
  final void Function(int requirementId) onPending;
  final void Function(int requirementId) onReject;
  final ValueChanged<Map<String, dynamic>> onAttachDam;
  final ValueChanged<Map<String, dynamic>> onAttachFinalPermit;
  final ValueChanged<Map<String, dynamic>> onOpenDetails;

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
                  onApprove: onApprove,
                  onPending: onPending,
                  onReject: onReject,
                  onAttachDam: onAttachDam,
                  onAttachFinalPermit: onAttachFinalPermit,
                  onOpenDetails: onOpenDetails,
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
    required this.onApprove,
    required this.onPending,
    required this.onReject,
    required this.onAttachDam,
    required this.onAttachFinalPermit,
    required this.onOpenDetails,
  });

  final Map<String, dynamic> request;
  final List<Map<String, dynamic>> requirements;
  final void Function(int requirementId) onApprove;
  final void Function(int requirementId) onPending;
  final void Function(int requirementId) onReject;
  final ValueChanged<Map<String, dynamic>> onAttachDam;
  final ValueChanged<Map<String, dynamic>> onAttachFinalPermit;
  final ValueChanged<Map<String, dynamic>> onOpenDetails;

  @override
  Widget build(BuildContext context) {
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
                request['nome_do_evento']?.toString() ?? 'Evento',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              _StatusChip(status: request['status']?.toString() ?? ''),
              Text('Protocolo: ${request['protocolo'] ?? '-'}'),
              OutlinedButton.icon(
                onPressed: () => onOpenDetails(request),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver detalhes'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${request['responsavel'] ?? '-'} | ${request['data_do_evento'] ?? '-'} | ${request['local_evento'] ?? '-'}',
          ),
          const Divider(height: 24),
          _WorkflowActions(
            request: request,
            onAttachDam: onAttachDam,
            onAttachFinalPermit: onAttachFinalPermit,
          ),
          if (requirements.isNotEmpty) const Divider(height: 24),
          ...requirements.map(
            (requirement) => _RequirementRow(
              requirement: requirement,
              onApprove: onApprove,
              onPending: onPending,
              onReject: onReject,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestDetailsDialog extends StatelessWidget {
  const _RequestDetailsDialog({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final requirements =
        (request['perguntas'] as List<dynamic>? ?? const [])
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
    required this.onAttachDam,
    required this.onAttachFinalPermit,
  });

  final Map<String, dynamic> request;
  final ValueChanged<Map<String, dynamic>> onAttachDam;
  final ValueChanged<Map<String, dynamic>> onAttachFinalPermit;

  @override
  Widget build(BuildContext context) {
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
    required this.onApprove,
    required this.onPending,
    required this.onReject,
  });

  final Map<String, dynamic> requirement;
  final void Function(int requirementId) onApprove;
  final void Function(int requirementId) onPending;
  final void Function(int requirementId) onReject;

  @override
  Widget build(BuildContext context) {
    final id = _requirementId(requirement['id']);
    final status = requirement['status']?.toString() ?? '';
    final canAct = id != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 330,
            child: Text(requirement['pergunta']?.toString() ?? 'Exigência'),
          ),
          SizedBox(
            width: 180,
            child: Text(requirement['secretaria']?.toString() ?? ''),
          ),
          _StatusChip(status: status),
          if (!canAct)
            const Tooltip(
              message: 'A exigência veio sem identificador do backend.',
              child: Icon(Icons.info_outline, size: 18),
            ),
          OutlinedButton.icon(
            onPressed: canAct ? () => onPending(id) : null,
            icon: const Icon(Icons.assignment_late_outlined),
            label: const Text('Correção'),
          ),
          OutlinedButton.icon(
            onPressed: canAct ? () => onReject(id) : null,
            icon: const Icon(Icons.block_outlined),
            label: const Text('Recusar'),
          ),
          ElevatedButton.icon(
            onPressed: canAct ? () => onApprove(id) : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Aprovar'),
          ),
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
      'recusada' || 'indeferida' || 'cancelada' => Colors.red,
      'pendente_documento' || 'pendente_correcao' => Colors.orange,
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
    default:
      return status.isEmpty ? 'Status' : status;
  }
}
