import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/permit_api_service.dart';
import '../../core/session_expiration.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/custom_appbar.dart';
import 'event_credential_page.dart';

class EventQrScannerPage extends StatefulWidget {
  const EventQrScannerPage({
    super.key,
    required this.userType,
    required this.userProfile,
  });

  final String userType;
  final String userProfile;

  @override
  State<EventQrScannerPage> createState() => _EventQrScannerPageState();
}

class _EventQrScannerPageState extends State<EventQrScannerPage> {
  final _api = PermitApiService();
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _manualController = TextEditingController();
  List<Map<String, dynamic>> _requests = [];
  bool _loadingEvents = true;
  bool _handledScan = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_handledScan) return;
    final rawValue = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (rawValue.isEmpty) return;
    _openCredentialFromInput(rawValue);
  }

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      final requests = await _api.listRequests(token);
      if (!mounted) return;
      setState(() => _requests = requests);
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'Não foi possível carregar eventos do dia.');
    } finally {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  Future<void> _openCredentialFromInput(String value) async {
    final credential = _CredentialQrData.tryParse(value.trim());
    if (credential != null) {
      await _openCredentialByCode(credential);
      return;
    }
    final request = _findRequestByNumber(value);
    if (request != null) {
      await _openCredentialByRequest(request);
      return;
    }
    setState(
      () =>
          _message =
              'Informe um QR Code válido ou o protocolo/número da solicitação.',
    );
  }

  Map<String, dynamic>? _findRequestByNumber(String value) {
    final query = value.trim().replaceAll('#', '').toLowerCase();
    if (query.isEmpty) return null;
    for (final request in _requests) {
      final candidates = [
        request['protocolo'],
        request['formId'],
        request['id'],
      ].map((item) => item?.toString().toLowerCase() ?? '');
      if (candidates.any((candidate) => candidate == query)) return request;
    }
    return null;
  }

  Future<void> _openCredentialByCode(_CredentialQrData credential) async {
    setState(() {
      _handledScan = true;
      _message = null;
    });
    await _controller.stop();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EventCredentialPage(
              publicCode: credential.publicCode,
              token: credential.token,
              userType: widget.userType,
              userProfile: widget.userProfile,
            ),
      ),
    );
    if (!mounted) return;
    setState(() => _handledScan = false);
    await _controller.start();
  }

  Future<void> _openCredentialByRequest(Map<String, dynamic> request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EventCredentialPage(
              permitForm: request,
              userType: widget.userType,
              userProfile: widget.userProfile,
            ),
      ),
    );
    if (mounted) await _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      userType: widget.userType,
      userProfile: widget.userProfile,
      appBar: CustomAppBar(title: 'Verificar evento', actions: const []),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 860;
          final scanner = _ScannerPanel(
            controller: _controller,
            onDetect: _handleCapture,
            message: _message,
            paused: _handledScan,
          );
          final manual = _ManualQrPanel(
            controller: _manualController,
            onSubmit: () => _openCredentialFromInput(_manualController.text),
          );
          final dailyEvents = _DailyEventsPanel(
            loading: _loadingEvents,
            events: _todayEvents,
            onRefresh: _loadEvents,
            onOpen: _openCredentialByRequest,
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child:
                    isWide
                        ? Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: scanner),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: manual),
                              ],
                            ),
                            const SizedBox(height: 16),
                            dailyEvents,
                          ],
                        )
                        : Column(
                          children: [
                            scanner,
                            const SizedBox(height: 16),
                            manual,
                            const SizedBox(height: 16),
                            dailyEvents,
                          ],
                        ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> get _todayEvents {
    final now = DateTime.now();
    return _requests.where((request) {
        final date = DateTime.tryParse(
          request['data_do_evento']?.toString() ?? '',
        );
        return date != null &&
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      }).toList()
      ..sort(
        (a, b) => (a['horario_inicio']?.toString() ?? '').compareTo(
          b['horario_inicio']?.toString() ?? '',
        ),
      );
  }
}

class _ScannerPanel extends StatelessWidget {
  const _ScannerPanel({
    required this.controller,
    required this.onDetect,
    required this.paused,
    this.message,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture capture) onDetect;
  final bool paused;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ler QR Code do alvará',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(controller: controller, onDetect: onDetect),
                    CustomPaint(
                      painter: _ScanFramePainter(colorScheme.primary),
                    ),
                    if (paused)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            if ((message ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(message!, style: TextStyle(color: colorScheme.error)),
            ],
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              const Text(
                'Se o navegador bloquear a câmera, cole o link do QR Code no campo ao lado.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManualQrPanel extends StatelessWidget {
  const _ManualQrPanel({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Entrada manual',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Link do QR Code ou protocolo/número',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Verificar evento'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyEventsPanel extends StatelessWidget {
  const _DailyEventsPanel({
    required this.loading,
    required this.events,
    required this.onRefresh,
    required this.onOpen,
  });

  final bool loading;
  final List<Map<String, dynamic>> events;
  final VoidCallback onRefresh;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Eventos de hoje',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Atualizar',
                  onPressed: loading ? null : onRefresh,
                  icon:
                      loading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Nenhum evento previsto para hoje.'),
              )
            else
              ...events.map(
                (event) => _DailyEventTile(event: event, onOpen: onOpen),
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyEventTile extends StatelessWidget {
  const _DailyEventTile({required this.event, required this.onOpen});

  final Map<String, dynamic> event;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    final credentials = event['credentials'] as List<dynamic>? ?? const [];
    final verified = credentials.any((item) {
      if (item is! Map) return false;
      return (item['verified_at']?.toString() ?? '').isNotEmpty ||
          ((item['verification_count'] as int?) ?? 0) > 0;
    });
    final hasCredential = credentials.isNotEmpty;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            verified ? const Color(0xFFEAF7EF) : const Color(0xFFFFF7E6),
        foregroundColor:
            verified ? const Color(0xFF0B7A35) : const Color(0xFFB7791F),
        child: Icon(verified ? Icons.verified : Icons.event_available),
      ),
      title: Text(event['nome_do_evento']?.toString() ?? 'Evento'),
      subtitle: Text(
        [
          event['protocolo']?.toString() ?? '-',
          _timeRange(event),
          _formatStatus(event['status']?.toString() ?? ''),
        ].where((item) => item.trim().isNotEmpty).join(' | '),
      ),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(verified ? 'Verificado' : 'Pendente'),
          ),
          IconButton.outlined(
            tooltip:
                hasCredential ? 'Abrir alvará' : 'Credencial ainda não emitida',
            onPressed: hasCredential ? () => onOpen(event) : null,
            icon: const Icon(Icons.qr_code_2),
          ),
        ],
      ),
    );
  }

  static String _timeRange(Map<String, dynamic> event) {
    final start = event['horario_inicio']?.toString() ?? '';
    final end = event['horario_termino']?.toString() ?? '';
    if (start.isEmpty && end.isEmpty) return '';
    return '$start-$end';
  }
}

String _formatStatus(String status) {
  switch (status) {
    case 'autorizada':
      return 'Autorizada';
    case 'isenta_dam':
      return 'Isenta de DAM';
    case 'aguardando_geracao_alvara':
      return 'Aguardando alvará';
    case 'aguardando_pagamento_dam':
      return 'Aguardando pagamento';
    case 'em_analise':
      return 'Em análise';
    case 'enviada':
      return 'Enviada';
    default:
      return status;
  }
}

class _CredentialQrData {
  const _CredentialQrData({required this.publicCode, required this.token});

  final String publicCode;
  final String token;

  static _CredentialQrData? tryParse(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.pathSegments.contains('validar-evento')) {
      final index = uri.pathSegments.indexOf('validar-evento');
      final publicCode =
          uri.pathSegments.length > index + 1
              ? uri.pathSegments[index + 1]
              : '';
      final token = uri.queryParameters['t'] ?? '';
      if (publicCode.isNotEmpty && token.isNotEmpty) {
        return _CredentialQrData(publicCode: publicCode, token: token);
      }
    }
    final pieces = value.split(RegExp(r'[\s|;]+'));
    if (pieces.length >= 2 && pieces[0].length >= 6 && pieces[1].length >= 10) {
      return _CredentialQrData(publicCode: pieces[0], token: pieces[1]);
    }
    return null;
  }
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    final frame = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.68,
      height: size.height * 0.68,
    );
    const length = 34.0;
    final paths = [
      Path()
        ..moveTo(frame.left, frame.top + length)
        ..lineTo(frame.left, frame.top)
        ..lineTo(frame.left + length, frame.top),
      Path()
        ..moveTo(frame.right - length, frame.top)
        ..lineTo(frame.right, frame.top)
        ..lineTo(frame.right, frame.top + length),
      Path()
        ..moveTo(frame.right, frame.bottom - length)
        ..lineTo(frame.right, frame.bottom)
        ..lineTo(frame.right - length, frame.bottom),
      Path()
        ..moveTo(frame.left + length, frame.bottom)
        ..lineTo(frame.left, frame.bottom)
        ..lineTo(frame.left, frame.bottom - length),
    ];
    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) =>
      oldDelegate.color != color;
}
