import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/permit_api_service.dart';
import '../../core/routes/app_routes.dart';
import '../../core/session_expiration.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/user_provider.dart';
import '../../shared/widgets/app_scaffold.dart';

class InspectionSchedulePage extends ConsumerStatefulWidget {
  const InspectionSchedulePage({super.key, required this.userType});

  final String userType;

  @override
  ConsumerState<InspectionSchedulePage> createState() =>
      _InspectionSchedulePageState();
}

class _InspectionSchedulePageState
    extends ConsumerState<InspectionSchedulePage> {
  final _api = PermitApiService();
  final _storage = const FlutterSecureStorage();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
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
        setState(() => _error = 'Não foi possível carregar as vistorias.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final inspections = _buildInspections(_requests, user);
    final today = DateUtils.dateOnly(DateTime.now());
    final performed =
        inspections
            .where((item) => item.date != null && item.date!.isBefore(today))
            .toList();
    final todayItems =
        inspections
            .where((item) => DateUtils.isSameDay(item.date, today))
            .toList();
    final future =
        inspections
            .where((item) => item.date == null || item.date!.isAfter(today))
            .toList();

    return AppScaffold(
      userType: widget.userType,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed:
              () => Navigator.pushReplacementNamed(context, AppRoutes.home),
        ),
        title: const Text('Vistorias e pendências'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child:
                    _loading
                        ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                        : _error != null
                        ? _MessageState(
                          icon: Icons.error_outline,
                          title: _error!,
                          onRefresh: _loadRequests,
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Header(total: inspections.length),
                            const SizedBox(height: 16),
                            _Calendar(
                              inspections: inspections,
                              onDateSelected:
                                  (date, items) => _showInspectionsForDate(
                                    context,
                                    date,
                                    items,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _InspectionSection(
                              title: 'Vistorias de hoje',
                              icon: Icons.today_outlined,
                              items: todayItems,
                              onOpenDetails: _showInspectionDetails,
                            ),
                            _InspectionSection(
                              title: 'Vistorias futuras',
                              icon: Icons.event_available_outlined,
                              items: future,
                              onOpenDetails: _showInspectionDetails,
                            ),
                            _InspectionSection(
                              title: 'Vistorias realizadas',
                              icon: Icons.fact_check_outlined,
                              items: performed,
                              onOpenDetails: _showInspectionDetails,
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

  static List<_InspectionItem> _buildInspections(
    List<Map<String, dynamic>> requests,
    UserModel? user,
  ) {
    final items = <_InspectionItem>[];
    for (final request in requests) {
      final requirements =
          (request['perguntas'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>();
      for (final requirement in requirements) {
        if (!_isVisibleToUser(requirement, user)) continue;
        if (requirement['requires_inspection'] != true &&
            !_requiresInspection(requirement['pergunta']?.toString() ?? '')) {
          continue;
        }
        items.add(
          _InspectionItem(
            requirementId: requirement['id'] as int?,
            request: request,
            eventName: request['nome_do_evento']?.toString() ?? 'Evento',
            protocol: request['protocolo']?.toString() ?? '-',
            secretaria: requirement['secretaria']?.toString() ?? '',
            requirement: requirement['pergunta']?.toString() ?? '',
            status: requirement['status']?.toString() ?? 'aguardando_analise',
            inspectionStatus:
                requirement['inspection_status']?.toString() ?? 'nao_agendada',
            checklist: List<String>.from(
              requirement['inspection_checklist'] ?? const [],
            ),
            requiresPhoto: requirement['inspection_requires_photo'] == true,
            inspectionResult:
                requirement['inspection_result'] as Map<String, dynamic>?,
            date: _parseDate(
              requirement['inspection_scheduled_for']?.toString(),
            ),
          ),
        );
      }
    }
    items.sort((a, b) {
      final aDate = a.date ?? DateTime(9999);
      final bDate = b.date ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return items;
  }

  static bool _isVisibleToUser(
    Map<String, dynamic> requirement,
    UserModel? user,
  ) {
    if (user?.userType == 'admin') return true;
    return requirement['secretaria_slug'] == user?.secretaria;
  }

  static bool _requiresInspection(String text) {
    final value = text.toLowerCase();
    return value.contains('vistoria') ||
        value.contains('avcb') ||
        value.contains('palco') ||
        value.contains('gerador') ||
        value.contains('trio') ||
        value.contains('alimentação') ||
        value.contains('alimentacao');
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  void _showInspectionsForDate(
    BuildContext context,
    DateTime date,
    List<_InspectionItem> items,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vistorias em ${_formatDate(date)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('Nenhuma vistoria marcada para esta data.'),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder:
                              (context, index) => _InspectionTile(
                                item: items[index],
                                onOpenDetails: (item) {
                                  Navigator.pop(context);
                                  _showInspectionDetails(item);
                                },
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  void _showInspectionDetails(_InspectionItem item) {
    final request = item.request;
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(item.eventName),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailLine(label: 'Protocolo', value: item.protocol),
                  _DetailLine(
                    label: 'Status da solicitação',
                    value: request['status']?.toString() ?? '-',
                  ),
                  _DetailLine(label: 'Secretaria', value: item.secretaria),
                  _DetailLine(label: 'Exigência', value: item.requirement),
                  _DetailLine(label: 'Status da exigência', value: item.status),
                  _DetailLine(
                    label: 'Status da vistoria',
                    value: _formatInspectionStatus(item.inspectionStatus),
                  ),
                  _DetailLine(label: 'Data da vistoria', value: item.dateLabel),
                  _DetailLine(
                    label: 'Local',
                    value: request['local_evento']?.toString() ?? '-',
                  ),
                  _DetailLine(
                    label: 'Responsável',
                    value: request['responsavel']?.toString() ?? '-',
                  ),
                  if (item.checklist.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Checklist',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ...item.checklist.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_box_outline_blank, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(entry)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (item.inspectionResult != null) ...[
                    const SizedBox(height: 8),
                    _DetailLine(
                      label: 'Resultado',
                      value:
                          item.inspectionResult?['approved'] == true
                              ? 'Aprovada'
                              : 'Negativa / correção solicitada',
                    ),
                    _DetailLine(
                      label: 'Observações',
                      value:
                          item.inspectionResult?['observacoes']?.toString() ??
                          '-',
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
              OutlinedButton.icon(
                onPressed:
                    item.requirementId == null
                        ? null
                        : () {
                          Navigator.pop(context);
                          _scheduleInspection(item);
                        },
                icon: const Icon(Icons.event_outlined),
                label: const Text('Agendar'),
              ),
              ElevatedButton.icon(
                onPressed:
                    item.requirementId == null
                        ? null
                        : () {
                          Navigator.pop(context);
                          _performInspection(item);
                        },
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Realizar vistoria'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    AppRoutes.secretariaRequests,
                    arguments: {'protocolo': item.protocol},
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir central'),
              ),
            ],
          ),
    );
  }

  Future<void> _scheduleInspection(_InspectionItem item) async {
    final initialDate = item.date ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null || item.requirementId == null) return;
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      await _api.scheduleInspection(
        accessToken: token,
        requirementId: item.requirementId!,
        scheduledFor: _dateToIso(selected),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vistoria agendada.')));
      _loadRequests();
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _performInspection(_InspectionItem item) async {
    final result = await showDialog<_InspectionResultInput>(
      context: context,
      builder: (context) => _InspectionFormDialog(item: item),
    );
    if (result == null || item.requirementId == null) return;
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      await _api.completeInspection(
        accessToken: token,
        requirementId: item.requirementId!,
        approved: result.approved,
        checklist: result.checklist,
        observacoes: result.observacoes,
        fotos: result.fotos,
        novaData: result.novaData == null ? null : _dateToIso(result.novaData!),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.approved
                ? 'Vistoria aprovada.'
                : 'Vistoria registrada com correção pendente.',
          ),
        ),
      );
      _loadRequests();
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _dateToIso(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatInspectionStatus(String status) {
    return switch (status) {
      'agendada' => 'Agendada',
      'aprovada' => 'Aprovada',
      'reprovada' => 'Reprovada',
      'reagendada' => 'Reagendada',
      _ => 'Não agendada',
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/images/logo_prefeitura_1.png', height: 64),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Agenda técnica',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text('$total exigência(s) técnicas encontradas.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.inspections, required this.onDateSelected});

  final List<_InspectionItem> inspections;
  final void Function(DateTime date, List<_InspectionItem> items)
  onDateSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final monthDays = DateUtils.getDaysInMonth(now.year, now.month);
    final leading = firstDay.weekday % 7;
    final byDay = <int, List<_InspectionItem>>{};
    for (final item in inspections) {
      final date = item.date;
      if (date == null || date.month != now.month || date.year != now.year) {
        continue;
      }
      byDay.putIfAbsent(date.day, () => []).add(item);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calendário do mês atual',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(_monthLabel(now)),
              const SizedBox(height: 12),
              Row(
                children:
                    _weekDays
                        .map(
                          (day) => Expanded(
                            child: Center(
                              child: Text(
                                day,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 6),
              GridView.builder(
                itemCount: leading + monthDays,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  if (index < leading) return const SizedBox.shrink();
                  final day = index - leading + 1;
                  final date = DateTime(now.year, now.month, day);
                  final items = byDay[day] ?? const <_InspectionItem>[];
                  final selected = items.isNotEmpty;
                  final isToday = DateUtils.isSameDay(date, now);
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: selected ? () => onDateSelected(date, items) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              selected || isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor,
                        ),
                        color:
                            selected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontWeight:
                                    isToday ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (selected)
                            Positioned(
                              right: 5,
                              bottom: 4,
                              child: Container(
                                width: 18,
                                height: 18,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${items.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _monthLabel(DateTime date) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return '${months[date.month - 1]} de ${date.year}';
  }

  static const _weekDays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
}

class _InspectionSection extends StatelessWidget {
  const _InspectionSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.onOpenDetails,
  });

  final String title;
  final IconData icon;
  final List<_InspectionItem> items;
  final ValueChanged<_InspectionItem> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: title == 'Vistorias de hoje',
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${items.length} registro(s)'),
        children:
            items.isEmpty
                ? const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum registro nesta categoria.'),
                  ),
                ]
                : items
                    .map(
                      (item) => _InspectionTile(
                        item: item,
                        onOpenDetails: onOpenDetails,
                      ),
                    )
                    .toList(),
      ),
    );
  }
}

class _InspectionTile extends StatelessWidget {
  const _InspectionTile({required this.item, required this.onOpenDetails});

  final _InspectionItem item;
  final ValueChanged<_InspectionItem> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => onOpenDetails(item),
      title: Text(item.requirement),
      subtitle: Text(
        '${item.eventName} | Protocolo ${item.protocol} | ${item.secretaria}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(item.dateLabel),
          Text(item.status, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '-' : value),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.onRefresh,
  });

  final IconData icon;
  final String title;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }
}

class _InspectionFormDialog extends StatefulWidget {
  const _InspectionFormDialog({required this.item});

  final _InspectionItem item;

  @override
  State<_InspectionFormDialog> createState() => _InspectionFormDialogState();
}

class _InspectionFormDialogState extends State<_InspectionFormDialog> {
  late final Map<String, bool> _checks = {
    for (final item in widget.item.checklist) item: false,
  };
  final _observacoesController = TextEditingController();
  final List<String> _fotos = [];
  bool _approved = true;
  DateTime? _novaData;

  @override
  void dispose() {
    _observacoesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Realizar vistoria - ${widget.item.protocol}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.item.eventName),
              const SizedBox(height: 12),
              if (_checks.isEmpty)
                const Text('Nenhum item de checklist definido.')
              else
                ..._checks.entries.map(
                  (entry) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key),
                    value: entry.value,
                    onChanged:
                        (value) =>
                            setState(() => _checks[entry.key] = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vistoria aprovada'),
                subtitle: const Text(
                  'Desative para registrar negativa e abrir prazo de correção.',
                ),
                value: _approved,
                onChanged: (value) => setState(() => _approved = value),
              ),
              TextField(
                controller: _observacoesController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText:
                      _approved ? 'Observações técnicas' : 'Motivo da negativa',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickPhotos,
                    icon: Icon(
                      widget.item.requiresPhoto
                          ? Icons.photo_camera
                          : Icons.photo_camera_outlined,
                    ),
                    label: Text(
                      widget.item.requiresPhoto
                          ? 'Registrar imagem obrigatória'
                          : 'Anexar fotos',
                    ),
                  ),
                  if (!_approved)
                    OutlinedButton.icon(
                      onPressed: _pickNewDate,
                      icon: const Icon(Icons.event_repeat_outlined),
                      label: Text(
                        _novaData == null
                            ? 'Definir nova data'
                            : 'Nova data: ${_formatDate(_novaData!)}',
                      ),
                    ),
                ],
              ),
              if (widget.item.requiresPhoto && _approved) ...[
                const SizedBox(height: 8),
                const Text(
                  'Esta vistoria exige ao menos uma imagem para aprovação.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              if (_fotos.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._fotos.map(
                  (foto) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.image_outlined),
                    title: Text(foto, overflow: TextOverflow.ellipsis),
                  ),
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
          onPressed: _submit,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Finalizar vistoria'),
        ),
      ],
    );
  }

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result == null) return;
    setState(() {
      _fotos
        ..clear()
        ..addAll(result.files.map((file) => file.path ?? file.name));
    });
  }

  Future<void> _pickNewDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    setState(() => _novaData = selected);
  }

  void _submit() {
    if (_approved && _checks.values.any((checked) => !checked)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marque todos os itens para aprovar a vistoria.'),
        ),
      );
      return;
    }
    if (!_approved && _observacoesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o motivo da negativa.')),
      );
      return;
    }
    if (_approved && widget.item.requiresPhoto && _fotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registre ao menos uma imagem para aprovar a vistoria.',
          ),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _InspectionResultInput(
        approved: _approved,
        checklist: _checks,
        observacoes: _observacoesController.text.trim(),
        fotos: _fotos,
        novaData: _novaData,
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _InspectionResultInput {
  const _InspectionResultInput({
    required this.approved,
    required this.checklist,
    required this.observacoes,
    required this.fotos,
    required this.novaData,
  });

  final bool approved;
  final Map<String, bool> checklist;
  final String observacoes;
  final List<String> fotos;
  final DateTime? novaData;
}

class _InspectionItem {
  const _InspectionItem({
    required this.requirementId,
    required this.request,
    required this.eventName,
    required this.protocol,
    required this.secretaria,
    required this.requirement,
    required this.status,
    required this.inspectionStatus,
    required this.checklist,
    required this.requiresPhoto,
    required this.inspectionResult,
    required this.date,
  });

  final int? requirementId;
  final Map<String, dynamic> request;
  final String eventName;
  final String protocol;
  final String secretaria;
  final String requirement;
  final String status;
  final String inspectionStatus;
  final List<String> checklist;
  final bool requiresPhoto;
  final Map<String, dynamic>? inspectionResult;
  final DateTime? date;

  String get dateLabel {
    final value = date;
    if (value == null) return 'Sem data';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}
