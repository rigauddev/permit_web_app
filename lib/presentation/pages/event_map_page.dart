import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/permit_api_service.dart';
import '../../core/routes/app_routes.dart';
import '../../core/session_expiration.dart';
import '../../shared/widgets/app_scaffold.dart';

class EventMapPage extends StatefulWidget {
  const EventMapPage({super.key, required this.userType});

  final String userType;

  @override
  State<EventMapPage> createState() => _EventMapPageState();
}

class _EventMapPageState extends State<EventMapPage> {
  final _api = PermitApiService();
  final _storage = const FlutterSecureStorage();

  bool _loading = true;
  String? _error;
  List<_MapEvent> _events = [];
  _MapEvent? _selected;
  DateTimeRange? _period;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _period = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day).add(const Duration(days: 90)),
    );
    _loadEvents();
  }

  Future<void> _loadEvents() async {
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
      final requests = await _api.listEventMapRequests(token);
      final events =
          requests
              .map(_MapEvent.fromRequest)
              .whereType<_MapEvent>()
              .where((event) => event.isAuthorized)
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      if (!mounted) return;
      setState(() {
        _events = events;
        _selected = events.isNotEmpty ? events.first : null;
      });
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível carregar os eventos autorizados.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_MapEvent> get _filteredEvents {
    final period = _period;
    if (period == null) return _events;
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
    return _events.where((event) {
      return !event.date.isBefore(start) && !event.date.isAfter(end);
    }).toList();
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _period,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Filtrar eventos por período',
      saveText: 'Aplicar',
    );
    if (selected == null) return;
    setState(() {
      _period = selected;
      final filtered = _filteredEvents;
      _selected =
          filtered.contains(_selected)
              ? _selected
              : filtered.isNotEmpty
              ? filtered.first
              : null;
    });
  }

  Future<void> _openAddress(_MapEvent event) async {
    final query = Uri.encodeComponent('${event.address}, Valença, BA');
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openFullMap() {
    final events = _filteredEvents;
    if (events.isEmpty) return;
    showDialog<void>(
      context: context,
      builder:
          (context) => Dialog.fullscreen(
            child: _FullMapView(
              events: events,
              selected: _selected,
              onSelect: (event) {
                setState(() => _selected = event);
              },
            ),
          ),
    );
  }

  void _openRequest(_MapEvent event) {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.secretariaRequests,
      arguments: {'requestId': event.requestId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = _filteredEvents;
    return AppScaffold(
      userType: widget.userType,
      appBar: AppBar(
        title: const Text('Mapa de eventos autorizados'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loadEvents,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    total: events.length,
                    period: _period,
                    onPickPeriod: _pickPeriod,
                    onOpenFullMap: events.isEmpty ? null : _openFullMap,
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
                    _MessagePanel(
                      icon: Icons.error_outline,
                      title: _error!,
                      actionLabel: 'Tentar novamente',
                      onPressed: _loadEvents,
                    )
                  else if (events.isEmpty)
                    const _MessagePanel(
                      icon: Icons.map_outlined,
                      title:
                          'Nenhum evento autorizado encontrado para o período.',
                    )
                  else
                    _MapLayout(
                      events: events,
                      selected: _selected,
                      onSelect: (event) => setState(() => _selected = event),
                      onOpenAddress: _openAddress,
                      onOpenRequest: _openRequest,
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

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.period,
    required this.onPickPeriod,
    this.onOpenFullMap,
  });

  final int total;
  final DateTimeRange? period;
  final VoidCallback onPickPeriod;
  final VoidCallback? onOpenFullMap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Eventos autorizados',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Acompanhe eventos aprovados por período no mapa gratuito do app e abra o endereço no Google Maps quando precisar navegar.',
              ),
            ],
          ),
        ),
        Chip(
          avatar: const Icon(Icons.event_available_outlined, size: 18),
          label: Text('$total evento(s)'),
        ),
        OutlinedButton.icon(
          onPressed: onPickPeriod,
          icon: const Icon(Icons.date_range_outlined),
          label: Text(_periodLabel(period)),
        ),
        ElevatedButton.icon(
          onPressed: onOpenFullMap,
          icon: const Icon(Icons.fullscreen),
          label: const Text('Ver todos'),
        ),
      ],
    );
  }

  static String _periodLabel(DateTimeRange? period) {
    if (period == null) return 'Selecionar período';
    return '${_formatDate(period.start)} a ${_formatDate(period.end)}';
  }
}

class _MapLayout extends StatelessWidget {
  const _MapLayout({
    required this.events,
    required this.selected,
    required this.onSelect,
    required this.onOpenAddress,
    required this.onOpenRequest,
  });

  final List<_MapEvent> events;
  final _MapEvent? selected;
  final ValueChanged<_MapEvent> onSelect;
  final ValueChanged<_MapEvent> onOpenAddress;
  final ValueChanged<_MapEvent> onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final map = _OperationalMap(
          events: events,
          selected: selected,
          onSelect: onSelect,
        );
        final details = _EventDetails(
          event: selected ?? events.first,
          onOpenAddress: onOpenAddress,
          onOpenRequest: onOpenRequest,
        );
        if (narrow) {
          return Column(
            children: [
              map,
              const SizedBox(height: 12),
              details,
              const SizedBox(height: 12),
              _EventTable(
                events: events,
                selected: selected,
                onSelect: onSelect,
              ),
            ],
          );
        }
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: map),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: details),
              ],
            ),
            const SizedBox(height: 16),
            _EventTable(events: events, selected: selected, onSelect: onSelect),
          ],
        );
      },
    );
  }
}

class _OperationalMap extends StatelessWidget {
  const _OperationalMap({
    required this.events,
    required this.selected,
    required this.onSelect,
  });

  final List<_MapEvent> events;
  final _MapEvent? selected;
  final ValueChanged<_MapEvent> onSelect;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8F2EC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC9D9CF)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: _OsmMapSurface(
                events: events,
                selected: selected,
                onSelect: onSelect,
              ),
            ),
            Positioned(left: 18, top: 16, child: _Legend(events: events)),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.events});

  final List<_MapEvent> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children:
            _TimelineStatus.values
                .map(
                  (status) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 10, color: status.color),
                      const SizedBox(width: 5),
                      Text(status.label, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _EventDetails extends StatelessWidget {
  const _EventDetails({
    required this.event,
    required this.onOpenAddress,
    required this.onOpenRequest,
  });

  final _MapEvent event;
  final ValueChanged<_MapEvent> onOpenAddress;
  final ValueChanged<_MapEvent> onOpenRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E7E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _TimelineChip(status: event.timeline),
            ],
          ),
          const SizedBox(height: 12),
          _DetailLine(
            icon: Icons.confirmation_number_outlined,
            text: event.protocol,
          ),
          _DetailLine(
            icon: Icons.event_outlined,
            text: _formatDate(event.date),
          ),
          _DetailLine(
            icon: Icons.schedule_outlined,
            text: '${event.startTime} às ${event.endTime}',
          ),
          _DetailLine(icon: Icons.place_outlined, text: event.address),
          _DetailLine(icon: Icons.people_outline, text: event.publicLabel),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => onOpenAddress(event),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver no Google Maps'),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpenRequest(event),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Central de solicitações'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventTable extends StatelessWidget {
  const _EventTable({
    required this.events,
    required this.selected,
    required this.onSelect,
  });

  final List<_MapEvent> events;
  final _MapEvent? selected;
  final ValueChanged<_MapEvent> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E7E2)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: events.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final event = events[index];
          final isSelected = selected?.requestId == event.requestId;
          return ListTile(
            selected: isSelected,
            selectedTileColor: const Color(0xFFEAF5EF),
            leading: CircleAvatar(
              backgroundColor: event.timeline.color.withValues(alpha: 0.12),
              child: Icon(Icons.location_on, color: event.timeline.color),
            ),
            title: Text(event.name),
            subtitle: Text('${_formatDate(event.date)} | ${event.address}'),
            trailing: _TimelineChip(status: event.timeline),
            onTap: () => onSelect(event),
          );
        },
      ),
    );
  }
}

class _FullMapView extends StatelessWidget {
  const _FullMapView({
    required this.events,
    required this.selected,
    required this.onSelect,
  });

  final List<_MapEvent> events;
  final _MapEvent? selected;
  final ValueChanged<_MapEvent> onSelect;

  @override
  Widget build(BuildContext context) {
    final controller = TransformationController();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa da cidade'),
        actions: [
          IconButton(
            tooltip: 'Fechar',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: controller,
              minScale: 1,
              maxScale: 4,
              panEnabled: true,
              scaleEnabled: true,
              child: _OsmMapSurface(
                events: events,
                selected: selected,
                onSelect: (event) {
                  onSelect(event);
                },
                fullScreen: true,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _FullMapEventStrip(
              events: events,
              selected: selected,
              onSelect: onSelect,
            ),
          ),
        ],
      ),
    );
  }
}

class _OsmMapSurface extends StatelessWidget {
  const _OsmMapSurface({
    required this.events,
    required this.selected,
    required this.onSelect,
    this.fullScreen = false,
  });

  static const _zoom = 14;
  static const _centerLat = -13.3704;
  static const _centerLng = -39.0733;

  final List<_MapEvent> events;
  final _MapEvent? selected;
  final ValueChanged<_MapEvent> onSelect;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center = _project(_centerLat, _centerLng, _zoom);
        return Stack(
          fit: StackFit.expand,
          children: [
            ..._tiles(size, center),
            Container(color: Colors.black.withValues(alpha: 0.02)),
            ...events.asMap().entries.map((entry) {
              final index = entry.key;
              final event = entry.value;
              final point = _eventPoint(event, index);
              final projected = _project(point.$1, point.$2, _zoom);
              final left = (projected.dx - center.dx) + size.width / 2;
              final top = (projected.dy - center.dy) + size.height / 2;
              final isSelected = selected?.requestId == event.requestId;
              return Positioned(
                left: left.clamp(18, size.width - 54).toDouble(),
                top: top.clamp(54, size.height - 72).toDouble(),
                child: Tooltip(
                  message: '${event.name}\n${event.address}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onSelect(event),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: isSelected ? 48 : 40,
                      height: isSelected ? 48 : 40,
                      decoration: BoxDecoration(
                        color: event.timeline.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: isSelected ? 4 : 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.24),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                  ),
                ),
              );
            }),
            Positioned(
              right: 10,
              bottom: fullScreen ? 104 : 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Text(
                    'OpenStreetMap',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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

  (double, double) _eventPoint(_MapEvent event, int index) {
    if (event.latitude != null && event.longitude != null) {
      return (event.latitude!, event.longitude!);
    }
    final ring = index ~/ 8;
    final angle = (index % 8) * (math.pi / 4);
    final radius = 0.003 + ring * 0.002;
    return (
      _centerLat + math.sin(angle) * radius,
      _centerLng + math.cos(angle) * radius,
    );
  }

  static Offset _project(double lat, double lng, int zoom) {
    final scale = 256 * math.pow(2, zoom).toDouble();
    final x = (lng + 180) / 360 * scale;
    final sinLat = math.sin(lat * math.pi / 180);
    final y =
        (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale;
    return Offset(x, y);
  }
}

class _FullMapEventStrip extends StatelessWidget {
  const _FullMapEventStrip({
    required this.events,
    required this.selected,
    required this.onSelect,
  });

  final List<_MapEvent> events;
  final _MapEvent? selected;
  final ValueChanged<_MapEvent> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 72 : 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final event = events[index];
          final isSelected = selected?.requestId == event.requestId;
          return InkWell(
            onTap: () => onSelect(event),
            child: Container(
              width: compact ? 184 : 260,
              padding: EdgeInsets.all(compact ? 9 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFFE0E7E2),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 12 : null,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 4),
                  Text(
                    '${_formatDate(event.date)} | ${event.address}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: compact ? 10.5 : 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool get compact => events.length > 4;
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text.isEmpty ? '-' : text)),
        ],
      ),
    );
  }
}

class _TimelineChip extends StatelessWidget {
  const _TimelineChip({required this.status});

  final _TimelineStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.label),
      side: BorderSide(color: status.color.withValues(alpha: 0.3)),
      backgroundColor: status.color.withValues(alpha: 0.08),
      labelStyle: TextStyle(color: status.color, fontWeight: FontWeight.w700),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            if (actionLabel != null && onPressed != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onPressed, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapEvent {
  const _MapEvent({
    required this.requestId,
    required this.protocol,
    required this.name,
    required this.address,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.publicLabel,
    required this.hasFinalPermit,
    required this.hasCredential,
    this.latitude,
    this.longitude,
  });

  final int requestId;
  final String protocol;
  final String name;
  final String address;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String status;
  final String publicLabel;
  final bool hasFinalPermit;
  final bool hasCredential;
  final double? latitude;
  final double? longitude;

  bool get isAuthorized =>
      status == 'autorizada' ||
      status == 'isenta_dam' ||
      hasFinalPermit ||
      hasCredential;

  _TimelineStatus get timeline {
    final now = DateTime.now();
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    if (now.isBefore(start)) return _TimelineStatus.future;
    if (now.isAfter(end)) return _TimelineStatus.finished;
    return _TimelineStatus.happening;
  }

  static _MapEvent? fromRequest(Map<String, dynamic> request) {
    final requestId = request['formId'] as int? ?? request['id'] as int?;
    final date = DateTime.tryParse(request['data_do_evento']?.toString() ?? '');
    final address = request['local_evento']?.toString().trim() ?? '';
    if (requestId == null || date == null || address.isEmpty) return null;
    final attachments =
        (request['attachments'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>();
    final hasFinalPermit = attachments.any(
      (attachment) => attachment['tipo_documento'] == 'alvara_evento',
    );
    final hasCredential =
        (request['credentials'] as List<dynamic>? ?? const []).isNotEmpty;
    return _MapEvent(
      requestId: requestId,
      protocol: request['protocolo']?.toString() ?? '-',
      name: request['nome_do_evento']?.toString() ?? 'Evento',
      address: address,
      date: date,
      startTime: request['horario_inicio']?.toString() ?? '--:--',
      endTime: request['horario_termino']?.toString() ?? '--:--',
      status: request['status']?.toString() ?? '',
      hasFinalPermit: hasFinalPermit,
      hasCredential: hasCredential,
      latitude: double.tryParse(request['latitude_evento']?.toString() ?? ''),
      longitude: double.tryParse(request['longitude_evento']?.toString() ?? ''),
      publicLabel:
          request['publico_estimado']?.toString().isNotEmpty == true
              ? '${request['publico_estimado']} pessoas'
              : 'Público não informado',
    );
  }
}

enum _TimelineStatus {
  finished('Realizado', Color(0xFF667085)),
  happening('Acontecendo', Color(0xFF0E7C3A)),
  future('Programado', Color(0xFFB7791F));

  const _TimelineStatus(this.label, this.color);

  final String label;
  final Color color;
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
