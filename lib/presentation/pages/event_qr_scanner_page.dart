import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _manualController = TextEditingController();
  bool _handledScan = false;
  String? _message;

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
    _openCredentialFromQr(rawValue);
  }

  Future<void> _openCredentialFromQr(String value) async {
    final credential = _CredentialQrData.tryParse(value.trim());
    if (credential == null) {
      setState(
        () =>
            _message =
                'QR Code inválido. Use o QR Code gerado no alvará de evento.',
      );
      return;
    }
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
            onSubmit: () => _openCredentialFromQr(_manualController.text),
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child:
                    isWide
                        ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: scanner),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: manual),
                          ],
                        )
                        : Column(
                          children: [
                            scanner,
                            const SizedBox(height: 16),
                            manual,
                          ],
                        ),
              ),
            ),
          );
        },
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
                labelText: 'Link ou código do QR Code',
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
