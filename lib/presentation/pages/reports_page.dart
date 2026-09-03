import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/permit_api_service.dart';
import '../../core/session_expiration.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/user_provider.dart';
import '../../shared/widgets/app_scaffold.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key, required this.userType});

  final String userType;

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  final _api = PermitApiService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _eventTypes = [];
  DateTimeRange? _period;
  int _selectedYear = DateTime.now().year;
  String _filterMode = 'period';
  String? _selectedEventType;
  int _eventsPage = 0;
  int _eventsPerPage = 15;
  bool _printingPdf = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _period = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
    _loadReports();
  }

  Future<void> _loadReports() async {
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
      final requests = await _api.listRequests(token);
      var eventTypes = <Map<String, dynamic>>[];
      try {
        eventTypes = await _api.listEventTypes(accessToken: token);
      } catch (_) {
        eventTypes = const [];
      }
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _eventTypes = eventTypes;
      });
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar os relatórios.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_ReportEvent> get _visibleEvents {
    final user = ref.watch(userProvider);
    return _requests
        .map((request) => _ReportEvent.fromRequest(request, _eventTypes))
        .whereType<_ReportEvent>()
        .where((event) => _matchesUserScope(event, user))
        .where(_matchesDateFilter)
        .where(_matchesEventTypeFilter)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  bool _matchesUserScope(_ReportEvent event, UserModel? user) {
    if (user?.userType == 'admin') return true;
    final secretaria = user?.secretaria;
    if (secretaria == null || secretaria.isEmpty) return false;
    if (secretaria == 'desenvolvimento_economico') return true;
    return event.secretariaSlugs.contains(secretaria);
  }

  bool _matchesDateFilter(_ReportEvent event) {
    if (_filterMode == 'year') return event.date.year == _selectedYear;
    final period = _period;
    if (period == null) return true;
    final start = DateTime(
      period.start.year,
      period.start.month,
      period.start.day,
    );
    final end = DateTime(
      period.end.year,
      period.end.month,
      period.end.day,
      23,
      59,
    );
    return !event.date.isBefore(start) && !event.date.isAfter(end);
  }

  bool _matchesEventTypeFilter(_ReportEvent event) {
    final selected = _selectedEventType;
    return selected == null ||
        selected.isEmpty ||
        event.eventTypeKey == selected;
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _period,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      helpText: 'Filtrar relatórios por período',
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
      _period = selected;
      _filterMode = 'period';
      _eventsPage = 0;
    });
  }

  Future<void> _printReport() async {
    final events = _visibleEvents;
    if (events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum evento para gerar o PDF.')),
      );
      return;
    }
    setState(() => _printingPdf = true);
    try {
      final user = ref.read(userProvider);
      final stats = _ReportStats(events);
      await Printing.layoutPdf(
        name: 'relatorio_eventos.pdf',
        onLayout:
            (_) => _buildReportPdf(
              events: events,
              stats: stats,
              secretaria:
                  user?.userType == 'admin'
                      ? 'Todas as secretarias'
                      : _formatSecretaria(user?.secretaria),
              periodo:
                  _filterMode == 'year'
                      ? _selectedYear.toString()
                      : _formatPeriod(_period),
              tipoEvento: _selectedEventTypeLabel,
            ),
      );
    } finally {
      if (mounted) setState(() => _printingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _visibleEvents;
    final stats = _ReportStats(events);
    return AppScaffold(
      userType: widget.userType,
      appBar: AppBar(
        title: const Text('Relatórios de eventos'),
        actions: [
          IconButton(
            tooltip: 'Gerar PDF',
            onPressed: _printingPdf ? null : _printReport,
            icon:
                _printingPdf
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(total: events.length),
                  const SizedBox(height: 16),
                  _Filters(
                    mode: _filterMode,
                    period: _period,
                    year: _selectedYear,
                    years: _availableYears,
                    eventType: _selectedEventType,
                    eventTypes: _eventTypeOptions,
                    onModeChanged:
                        (value) => setState(() {
                          _filterMode = value;
                          _eventsPage = 0;
                        }),
                    onPickPeriod: _pickPeriod,
                    onYearChanged:
                        (value) => setState(() {
                          _selectedYear = value;
                          _eventsPage = 0;
                        }),
                    onEventTypeChanged:
                        (value) => setState(() {
                          _selectedEventType = value;
                          _eventsPage = 0;
                        }),
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    _MessagePanel(
                      icon: Icons.error_outline,
                      title: _error!,
                      actionLabel: 'Tentar novamente',
                      onPressed: _loadReports,
                    )
                  else if (events.isEmpty)
                    const _MessagePanel(
                      icon: Icons.analytics_outlined,
                      title:
                          'Nenhum evento encontrado para os filtros selecionados.',
                    )
                  else ...[
                    _KpiGrid(stats: stats),
                    const SizedBox(height: 16),
                    _ChartsGrid(stats: stats),
                    const SizedBox(height: 16),
                    _EventsTable(
                      events: events,
                      currentPage: _eventsPage,
                      rowsPerPage: _eventsPerPage,
                      onPageChanged:
                          (value) => setState(() => _eventsPage = value),
                      onRowsPerPageChanged:
                          (value) => setState(() {
                            _eventsPerPage = value;
                            _eventsPage = 0;
                          }),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<int> get _availableYears {
    final years =
        _requests
            .map(
              (request) =>
                  _ReportEvent.fromRequest(request, _eventTypes)?.date.year,
            )
            .whereType<int>()
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (!years.contains(_selectedYear)) years.insert(0, _selectedYear);
    return years;
  }

  List<MapEntry<String, String>> get _eventTypeOptions {
    final options = <String, String>{};
    for (final eventType in _eventTypes) {
      final key = eventType['key']?.toString() ?? '';
      if (key.isEmpty) continue;
      options[key] = eventType['name']?.toString() ?? key;
    }
    for (final request in _requests) {
      final event = _ReportEvent.fromRequest(request, _eventTypes);
      if (event == null || event.eventTypeKey.isEmpty) continue;
      options.putIfAbsent(event.eventTypeKey, () => event.eventTypeName);
    }
    return options.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
  }

  String get _selectedEventTypeLabel {
    final selected = _selectedEventType;
    if (selected == null || selected.isEmpty) return 'Todos os tipos';
    for (final item in _eventTypeOptions) {
      if (item.key == selected) return item.value;
    }
    return selected;
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.total});

  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
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
                'Relatórios',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('$secretaria - $total evento(s) no recorte selecionado.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.mode,
    required this.period,
    required this.year,
    required this.years,
    required this.eventType,
    required this.eventTypes,
    required this.onModeChanged,
    required this.onPickPeriod,
    required this.onYearChanged,
    required this.onEventTypeChanged,
  });

  final String mode;
  final DateTimeRange? period;
  final int year;
  final List<int> years;
  final String? eventType;
  final List<MapEntry<String, String>> eventTypes;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onPickPeriod;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<String?> onEventTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'period',
                  icon: Icon(Icons.date_range),
                  label: Text('Período'),
                ),
                ButtonSegment(
                  value: 'year',
                  icon: Icon(Icons.calendar_today),
                  label: Text('Ano'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (value) => onModeChanged(value.first),
            ),
            if (mode == 'period')
              OutlinedButton.icon(
                onPressed: onPickPeriod,
                icon: const Icon(Icons.tune),
                label: Text(_formatPeriod(period)),
              )
            else
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<int>(
                  initialValue: year,
                  decoration: const InputDecoration(
                    labelText: 'Ano',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      years
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item,
                              child: Text(item.toString()),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) onYearChanged(value);
                  },
                ),
              ),
            SizedBox(
              width: 280,
              child: DropdownButtonFormField<String>(
                initialValue: eventType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tipo de evento',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Todos os tipos'),
                  ),
                  ...eventTypes.map(
                    (item) => DropdownMenuItem<String>(
                      value: item.key,
                      child: Text(item.value),
                    ),
                  ),
                ],
                onChanged: onEventTypeChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});

  final _ReportStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth < 640
                ? 1
                : constraints.maxWidth < 940
                ? 2
                : constraints.maxWidth < 1140
                ? 4
                : 5;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 4 : 2.1,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _KpiCard(
              icon: Icons.event_available_outlined,
              label: 'Eventos',
              value: stats.total.toString(),
            ),
            _KpiCard(
              icon: Icons.account_tree_outlined,
              label: 'Área com mais eventos',
              value: stats.topArea?.key ?? '-',
            ),
            _KpiCard(
              icon: Icons.category_outlined,
              label: 'Tipo com mais solicitações',
              value: stats.topType?.key ?? '-',
            ),
            _KpiCard(
              icon: Icons.calendar_month_outlined,
              label: 'Mês mais frequente',
              value: stats.topMonth?.key ?? '-',
            ),
            _KpiCard(
              icon: Icons.location_city_outlined,
              label: 'Bairro com mais eventos',
              value: stats.topNeighborhood?.key ?? '-',
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
              foregroundColor: colorScheme.primary,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartsGrid extends StatelessWidget {
  const _ChartsGrid({required this.stats});

  final _ReportStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 840;
        final children = [
          _BarChart(title: 'Eventos por área/secretaria', values: stats.byArea),
          _BarChart(
            title: 'Solicitações por tipo de evento',
            values: stats.byType,
          ),
          _BarChart(
            title: 'Bairros com mais eventos',
            values: stats.byNeighborhood,
          ),
          _NeighborhoodTypesPanel(stats: stats),
          _BarChart(title: 'Eventos por mês', values: stats.byMonth),
          _BarChart(
            title: 'Eventos mais frequentes',
            values: stats.byEventName,
          ),
        ];
        if (!twoColumns) {
          return Column(
            children:
                children
                    .map(
                      (child) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: child,
                      ),
                    )
                    .toList(),
          );
        }
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.7,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.title, required this.values});

  final String title;
  final List<MapEntry<String, int>> values;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxValue =
        values.isEmpty
            ? 1
            : values.map((item) => item.value).reduce((a, b) => a > b ? a : b);
    return Card(
      color: colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (values.isEmpty)
              const Expanded(child: Center(child: Text('Sem dados.')))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: values.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = values[index];
                    final ratio = item.value / maxValue;
                    final color = _chartColors[index % _chartColors.length];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              item.value.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Stack(
                            children: [
                              Container(
                                height: 12,
                                color: color.withValues(alpha: 0.12),
                              ),
                              FractionallySizedBox(
                                widthFactor: ratio.clamp(0.0, 1.0),
                                child: Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NeighborhoodTypesPanel extends StatelessWidget {
  const _NeighborhoodTypesPanel({required this.stats});

  final _ReportStats stats;

  @override
  Widget build(BuildContext context) {
    final neighborhood = stats.topNeighborhood?.key;
    final values = stats.topNeighborhoodTypes;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              neighborhood == null
                  ? 'Tipos por bairro'
                  : 'Tipos de evento em $neighborhood',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (values.isEmpty)
              const Expanded(child: Center(child: Text('Sem dados.')))
            else
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      values.asMap().entries.map((entry) {
                        final color =
                            _chartColors[entry.key % _chartColors.length];
                        final item = entry.value;
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            child: Text(
                              item.value.toString(),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          label: Text(item.key),
                        );
                      }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventsTable extends StatelessWidget {
  const _EventsTable({
    required this.events,
    required this.currentPage,
    required this.rowsPerPage,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
  });

  final List<_ReportEvent> events;
  final int currentPage;
  final int rowsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onRowsPerPageChanged;

  @override
  Widget build(BuildContext context) {
    final totalPages =
        events.isEmpty ? 1 : (events.length / rowsPerPage).ceil();
    final safePage = currentPage >= totalPages ? totalPages - 1 : currentPage;
    final start = safePage * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, events.length);
    final pageEvents = events.sublist(start, end);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Eventos do período',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _ReportPagination(
              totalItems: events.length,
              currentPage: safePage,
              totalPages: totalPages,
              rowsPerPage: rowsPerPage,
              onPageChanged: onPageChanged,
              onRowsPerPageChanged: onRowsPerPageChanged,
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Data')),
                  DataColumn(label: Text('Evento')),
                  DataColumn(label: Text('Tipo')),
                  DataColumn(label: Text('Bairro')),
                  DataColumn(label: Text('Local')),
                  DataColumn(label: Text('Status')),
                ],
                rows:
                    pageEvents
                        .map(
                          (event) => DataRow(
                            cells: [
                              DataCell(Text(_formatDate(event.date))),
                              DataCell(_TableCellText(event.name, width: 220)),
                              DataCell(
                                _TableCellText(event.eventTypeName, width: 180),
                              ),
                              DataCell(
                                _TableCellText(event.neighborhood, width: 150),
                              ),
                              DataCell(
                                _TableCellText(event.location, width: 240),
                              ),
                              DataCell(Text(_formatStatus(event.status))),
                            ],
                          ),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(height: 12),
            _ReportPagination(
              totalItems: events.length,
              currentPage: safePage,
              totalPages: totalPages,
              rowsPerPage: rowsPerPage,
              compact: true,
              onPageChanged: onPageChanged,
              onRowsPerPageChanged: onRowsPerPageChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportPagination extends StatelessWidget {
  const _ReportPagination({
    required this.totalItems,
    required this.currentPage,
    required this.totalPages,
    required this.rowsPerPage,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
    this.compact = false,
  });

  final int totalItems;
  final int currentPage;
  final int totalPages;
  final int rowsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onRowsPerPageChanged;
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
                  const [15, 30, 50]
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
          onPressed:
              currentPage <= 0 ? null : () => onPageChanged(currentPage - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Página ${currentPage + 1} de $totalPages'),
        IconButton.outlined(
          tooltip: 'Próxima página',
          onPressed:
              currentPage >= totalPages - 1
                  ? null
                  : () => onPageChanged(currentPage + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _TableCellText extends StatelessWidget {
  const _TableCellText(this.value, {required this.width});

  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Tooltip(
        message: value,
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center),
              if (actionLabel != null && onPressed != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onPressed, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportStats {
  _ReportStats(this.events);

  final List<_ReportEvent> events;

  int get total => events.length;
  List<MapEntry<String, int>> get byArea => _top(_countAreas(), limit: 8);
  List<MapEntry<String, int>> get byType =>
      _top(_count((event) => event.eventTypeName), limit: 8);
  List<MapEntry<String, int>> get byMonth =>
      _top(_count((event) => _monthName(event.date.month)), limit: 12);
  List<MapEntry<String, int>> get byNeighborhood =>
      _top(_count((event) => event.neighborhood), limit: 8);
  List<MapEntry<String, int>> get byEventName =>
      _top(_count((event) => event.name), limit: 8);
  MapEntry<String, int>? get topArea => byArea.isEmpty ? null : byArea.first;
  MapEntry<String, int>? get topType => byType.isEmpty ? null : byType.first;
  MapEntry<String, int>? get topMonth => byMonth.isEmpty ? null : byMonth.first;
  MapEntry<String, int>? get topNeighborhood =>
      byNeighborhood.isEmpty ? null : byNeighborhood.first;
  List<MapEntry<String, int>> get topNeighborhoodTypes {
    final neighborhood = topNeighborhood?.key;
    if (neighborhood == null) return const [];
    return _top(
      _count(
        (event) =>
            event.neighborhood == neighborhood ? event.eventTypeName : '',
      )..remove('Não informado'),
      limit: 8,
    );
  }

  Map<String, int> _count(String Function(_ReportEvent event) selector) {
    final result = <String, int>{};
    for (final event in events) {
      final key =
          selector(event).trim().isEmpty ? 'Não informado' : selector(event);
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  Map<String, int> _countAreas() {
    final result = <String, int>{};
    for (final event in events) {
      final areas =
          event.secretarias.isEmpty
              ? const ['Não informado']
              : event.secretarias;
      for (final area in areas) {
        result[area] = (result[area] ?? 0) + 1;
      }
    }
    return result;
  }

  static List<MapEntry<String, int>> _top(
    Map<String, int> values, {
    required int limit,
  }) {
    final entries =
        values.entries.toList()..sort((a, b) {
          final byValue = b.value.compareTo(a.value);
          return byValue == 0 ? a.key.compareTo(b.key) : byValue;
        });
    return entries.take(limit).toList();
  }
}

class _ReportEvent {
  const _ReportEvent({
    required this.name,
    required this.date,
    required this.location,
    required this.neighborhood,
    required this.eventTypeKey,
    required this.eventTypeName,
    required this.status,
    required this.secretarias,
    required this.secretariaSlugs,
  });

  final String name;
  final DateTime date;
  final String location;
  final String neighborhood;
  final String eventTypeKey;
  final String eventTypeName;
  final String status;
  final List<String> secretarias;
  final List<String> secretariaSlugs;

  static _ReportEvent? fromRequest(
    Map<String, dynamic> request,
    List<Map<String, dynamic>> eventTypes,
  ) {
    final rawDate = request['data_do_evento']?.toString() ?? '';
    final date = DateTime.tryParse(rawDate);
    if (date == null) return null;
    final eventData = request['dados_evento'] as Map<String, dynamic>? ?? {};
    final typeKey = eventData['tipo_evento']?.toString() ?? '';
    final fallbackName =
        eventData['tipo_evento_nome']?.toString() ??
        (typeKey.isEmpty ? 'Não informado' : typeKey);
    final eventType = eventTypes.firstWhere(
      (item) => item['key']?.toString() == typeKey,
      orElse: () => const <String, dynamic>{},
    );
    final requirements =
        (request['perguntas'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
    final location =
        request['local_evento']?.toString().trim().isNotEmpty == true
            ? request['local_evento'].toString()
            : 'Não informado';
    return _ReportEvent(
      name: request['nome_do_evento']?.toString() ?? 'Evento',
      date: date,
      location: location,
      neighborhood: _extractNeighborhood(location),
      eventTypeKey: typeKey,
      eventTypeName: eventType['name']?.toString() ?? fallbackName,
      status: request['status']?.toString() ?? 'enviada',
      secretarias:
          requirements
              .map((item) => item['secretaria']?.toString() ?? '')
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList(),
      secretariaSlugs:
          requirements
              .map((item) => item['secretaria_slug']?.toString() ?? '')
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList(),
    );
  }
}

const _chartColors = [
  Color(0xFF1B8A5A),
  Color(0xFF2563EB),
  Color(0xFFE11D48),
  Color(0xFFF59E0B),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFF65A30D),
  Color(0xFFDB2777),
];

String _extractNeighborhood(String location) {
  final normalized = location.toLowerCase();
  const known = {
    'bolívia': 'Bolívia',
    'bolivia': 'Bolívia',
    'centro': 'Centro',
    'são félix': 'São Félix',
    'sao felix': 'São Félix',
    'guaibim': 'Guaibim',
    'jacaré': 'Jacaré',
    'jacare': 'Jacaré',
    'areal': 'Areal',
    'graça': 'Graça',
    'graca': 'Graça',
    'maricoabo': 'Maricoabo',
    'jambeiro': 'Jambeiro',
    'novo horizonte': 'Novo Horizonte',
    'cajaiba': 'Cajaíba',
    'cajaíba': 'Cajaíba',
    'serra grande': 'Serra Grande',
    'piau': 'Piau',
    'bonfim': 'Bonfim',
    'terra preta': 'Terra Preta',
    'vila operária': 'Vila Operária',
    'vila operaria': 'Vila Operária',
  };
  for (final entry in known.entries) {
    if (normalized.contains(entry.key)) return entry.value;
  }
  final parts =
      location
          .split(RegExp(r'[-,()]'))
          .map((part) => part.trim())
          .where((part) => part.length >= 3)
          .toList();
  return parts.isEmpty ? 'Não informado' : parts.last;
}

String _formatPeriod(DateTimeRange? period) {
  if (period == null) return 'Selecionar período';
  return '${_formatDate(period.start)} a ${_formatDate(period.end)}';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _monthName(int month) {
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
  return months[month - 1];
}

String _formatStatus(String status) {
  switch (status) {
    case 'enviada':
      return 'Enviada';
    case 'em_analise':
      return 'Em análise';
    case 'pendente_correcao':
      return 'Pendente de correção';
    case 'aguardando_geracao_dam':
      return 'Aguardando DAM';
    case 'aguardando_pagamento_dam':
      return 'Aguardando pagamento';
    case 'aguardando_geracao_alvara':
      return 'Aguardando alvará';
    case 'autorizada':
      return 'Autorizada';
    case 'isenta_dam':
      return 'Isenta de DAM';
    case 'recusada':
      return 'Recusada';
    default:
      return status;
  }
}

String _formatSecretaria(String? slug) {
  switch (slug) {
    case 'desenvolvimento_economico':
      return 'Desenvolvimento Econômico';
    case 'meio_ambiente':
      return 'Meio Ambiente';
    case 'infraestrutura':
      return 'Infraestrutura';
    case 'dmtran':
      return 'DMTRAN';
    case 'vigilancia_sanitaria':
      return 'Vigilância Sanitária';
    case 'secretaria_saude':
      return 'Secretaria de Saúde';
    case 'guarda_civil':
      return 'Guarda Civil Municipal';
    case 'receita_municipal':
      return 'Receita Municipal';
    default:
      return slug ?? 'Sem secretaria vinculada';
  }
}

Future<Uint8List> _buildReportPdf({
  required List<_ReportEvent> events,
  required _ReportStats stats,
  required String secretaria,
  required String periodo,
  required String tipoEvento,
}) async {
  final document = pw.Document();
  final logoBytes =
      (await rootBundle.load(
        'assets/images/logo_prefeitura_1.png',
      )).buffer.asUint8List();
  final logo = pw.MemoryImage(logoBytes);
  final generatedAt = DateTime.now();

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build:
          (context) => [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Image(logo, width: 72),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Relatório de Eventos',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(secretaria),
                      pw.Text('Prefeitura Municipal de Valença'),
                    ],
                  ),
                ),
              ],
            ),
            pw.Divider(height: 28),
            _pdfInfoRow('Período', periodo),
            _pdfInfoRow('Tipo de evento', tipoEvento),
            _pdfInfoRow('Gerado em', _formatDate(generatedAt)),
            pw.SizedBox(height: 16),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pdfKpi('Eventos', stats.total.toString()),
                _pdfKpi('Área com mais eventos', stats.topArea?.key ?? '-'),
                _pdfKpi('Tipo mais solicitado', stats.topType?.key ?? '-'),
                _pdfKpi('Mês mais frequente', stats.topMonth?.key ?? '-'),
                _pdfKpi(
                  'Bairro com mais eventos',
                  stats.topNeighborhood?.key ?? '-',
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Eventos listados',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.8),
                1: pw.FlexColumnWidth(1.7),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(1.5),
                5: pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell('Data', bold: true),
                    _pdfCell('Evento', bold: true),
                    _pdfCell('Tipo', bold: true),
                    _pdfCell('Bairro', bold: true),
                    _pdfCell('Local', bold: true),
                    _pdfCell('Status', bold: true),
                  ],
                ),
                ...events.map(
                  (event) => pw.TableRow(
                    children: [
                      _pdfCell(_formatDate(event.date)),
                      _pdfCell(event.name),
                      _pdfCell(event.eventTypeName),
                      _pdfCell(event.neighborhood),
                      _pdfCell(event.location),
                      _pdfCell(_formatStatus(event.status)),
                    ],
                  ),
                ),
              ],
            ),
          ],
    ),
  );
  return document.save();
}

pw.Widget _pdfInfoRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(child: pw.Text(value.isEmpty ? '-' : value)),
      ],
    ),
  );
}

pw.Widget _pdfKpi(String label, String value) {
  return pw.Container(
    width: 150,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          maxLines: 2,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
}

pw.Widget _pdfCell(Object? value, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      value?.toString().trim().isEmpty == false ? value.toString() : '-',
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}
