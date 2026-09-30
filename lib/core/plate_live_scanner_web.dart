import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Mantém a prévia da câmera aberta no navegador e envia quadros periódicos
/// ao OCR interno. Nenhuma imagem é persistida pelo aplicativo.
Future<String?> scanPlateWithLiveCameraImpl(
  BuildContext context, {
  String vehicleType = 'carro',
  Future<String?> Function(XFile image)? recognize,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder:
        (_) => _PlateWebLiveScanner(
          vehicleType: vehicleType,
          recognize: recognize,
        ),
  ),
);

class _PlateWebLiveScanner extends StatefulWidget {
  const _PlateWebLiveScanner({required this.vehicleType, this.recognize});

  final String vehicleType;
  final Future<String?> Function(XFile image)? recognize;

  @override
  State<_PlateWebLiveScanner> createState() => _PlateWebLiveScannerState();
}

class _PlateWebLiveScannerState extends State<_PlateWebLiveScanner> {
  CameraController? _controller;
  Timer? _timer;
  bool get _isMotorcycle => widget.vehicleType == 'motocicleta';

  bool _initializing = true;
  bool _reading = false;
  bool _completed = false;
  String _message = 'Posicione a placa dentro da moldura';
  String? _lastPlate;
  int _matches = 0;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('Nenhuma câmera encontrada.');
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() => _initializing = false);
      _timer = Timer.periodic(
        const Duration(milliseconds: 1100),
        (_) => _readFrame(),
      );
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _message =
              error.code == 'CameraAccessDenied'
                  ? 'Permita o acesso à câmera para ler a placa.'
                  : 'Não foi possível abrir a câmera.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _message = 'Não foi possível abrir a câmera do navegador.';
        });
      }
    }
  }

  Future<void> _readFrame() async {
    final controller = _controller;
    final recognize = widget.recognize;
    if (_reading ||
        _completed ||
        controller == null ||
        !controller.value.isInitialized ||
        recognize == null) {
      return;
    }
    _reading = true;
    try {
      if (mounted) {
        setState(() => _message = 'Lendo a placa automaticamente...');
      }
      final image = await controller.takePicture();
      final plate = await recognize(image);
      if (plate == null || plate.isEmpty) {
        if (mounted) {
          setState(
            () => _message = 'Aproxime e mantenha a placa dentro da moldura',
          );
        }
        return;
      }
      if (plate == _lastPlate) {
        _matches += 1;
      } else {
        _lastPlate = plate;
        _matches = 1;
      }
      if (_matches < 2) {
        if (mounted) {
          setState(
            () => _message = 'Placa $plate identificada. Confirmando...',
          );
        }
        return;
      }
      _completed = true;
      _timer?.cancel();
      if (!mounted) return;
      setState(() => _message = 'Placa $plate identificada. Validando...');
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (mounted) Navigator.of(context).pop(plate);
    } catch (_) {
      if (mounted && !_completed) {
        setState(() => _message = 'Continue apontando para a placa');
      }
    } finally {
      _reading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && controller.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: CameraPreview(controller),
                ),
              )
            else
              const ColoredBox(color: Colors.black),
            ColoredBox(color: Colors.black.withValues(alpha: .18)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isMotorcycle
                              ? 'Leitura automática de placa de moto'
                              : 'Leitura automática de placa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    height: _isMotorcycle ? 150 : 112,
                    width: _isMotorcycle ? 230 : double.infinity,
                    constraints: const BoxConstraints(maxWidth: 410),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .12),
                      border: Border.all(
                        color: const Color(0xFFFFD54F),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Icon(
                        _isMotorcycle
                            ? Icons.two_wheeler_outlined
                            : Icons.directions_car_outlined,
                        color: const Color(0xFFFFD54F),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .76),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        if (_initializing)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        Text(
                          _message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isMotorcycle
                              ? 'Mantenha o celular na horizontal e centralize a placa inteira da moto na moldura vertical.'
                              : 'Mantenha o celular na horizontal e centralize a placa na moldura. A leitura acontece automaticamente; nenhuma foto é salva.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFD9E3E8),
                            fontSize: 12,
                          ),
                        ),
                      ],
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
