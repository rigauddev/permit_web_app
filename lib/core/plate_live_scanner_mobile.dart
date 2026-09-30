import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

final _platePattern = RegExp(r'[A-Z]{3}[0-9][A-Z0-9][0-9]{2}');
const _orientations = <DeviceOrientation, int>{
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

Future<String?> scanPlateWithLiveCameraImpl(
  BuildContext context, {
  String vehicleType = 'carro',
  Future<String?> Function(XFile image)? recognize,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute(
    builder: (_) => _PlateLiveScanner(vehicleType: vehicleType),
  ),
);

class _PlateLiveScanner extends StatefulWidget {
  const _PlateLiveScanner({required this.vehicleType});

  final String vehicleType;

  @override
  State<_PlateLiveScanner> createState() => _PlateLiveScannerState();
}

class _PlateLiveScannerState extends State<_PlateLiveScanner>
    with WidgetsBindingObserver {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  CameraController? _controller;
  CameraDescription? _camera;
  bool _initializing = true;
  bool _processing = false;
  bool _captured = false;
  bool _torchOn = false;
  String? _lastPlate;
  int _repeatedFrames = 0;
  String _message = 'Centralize a placa dentro da moldura';
  DateTime _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _message =
        widget.vehicleType == 'motocicleta'
            ? 'Mantenha o celular na horizontal e centralize a placa da moto'
            : 'Mantenha o celular na horizontal e centralize a placa na moldura';
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.stopImageStream().catchError((_) {});
    } else if (state == AppLifecycleState.resumed && !_captured) {
      controller.startImageStream(_processFrame).catchError((_) {});
    }
  }

  Future<void> _startCamera() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        throw StateError('Leitura contínua disponível apenas no aplicativo.');
      }
      final cameras = await availableCameras();
      _camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        _camera!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid
                ? ImageFormatGroup.nv21
                : ImageFormatGroup.bgra8888,
      );
      _controller = controller;
      await controller.initialize();
      await controller.setFocusMode(FocusMode.auto).catchError((_) {});
      await controller.setExposureMode(ExposureMode.auto).catchError((_) {});
      await controller.startImageStream(_processFrame);
      if (mounted) setState(() => _initializing = false);
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
          _message = 'Não foi possível iniciar a leitura da câmera.';
        });
      }
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_processing || _captured) return;
    if (DateTime.now().difference(_lastAnalysis) <
        const Duration(milliseconds: 350)) {
      return;
    }
    _lastAnalysis = DateTime.now();
    final inputImage = _inputImage(image);
    if (inputImage == null) return;

    _processing = true;
    try {
      final result = await _recognizer.processImage(inputImage);
      final candidate = _findPlate(result.text);
      if (candidate == null) return;
      if (candidate == _lastPlate) {
        _repeatedFrames += 1;
      } else {
        _lastPlate = candidate;
        _repeatedFrames = 1;
      }
      if (_repeatedFrames < 2 || _captured) return;

      _captured = true;
      await _controller?.stopImageStream();
      if (!mounted) return;
      setState(() => _message = 'Placa $candidate identificada. Validando...');
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) Navigator.of(context).pop(candidate);
    } catch (_) {
      // Um frame inválido não deve interromper a leitura contínua.
    } finally {
      _processing = false;
    }
  }

  InputImage? _inputImage(CameraImage image) {
    final controller = _controller;
    final camera = _camera;
    if (controller == null || camera == null || image.planes.length != 1) {
      return null;
    }
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    } else {
      var compensation = _orientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      compensation =
          camera.lensDirection == CameraLensDirection.front
              ? (camera.sensorOrientation + compensation) % 360
              : (camera.sensorOrientation - compensation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null ||
        format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  String? _findPlate(String text) {
    final normalized = text.toUpperCase();
    final direct = _platePattern.firstMatch(normalized);
    if (direct != null) return direct.group(0);
    final compact = normalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return _platePattern.firstMatch(compact)?.group(0);
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    final enabled = !_torchOn;
    try {
      await controller.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
      if (mounted) {
        setState(() => _torchOn = enabled);
      }
    } on CameraException {
      if (mounted) {
        setState(() => _message = 'O flash não está disponível nesta câmera.');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _recognizer.close();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
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
              CameraPreview(controller)
            else
              const ColoredBox(color: Colors.black),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .28),
              ),
            ),
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.vehicleType == 'motocicleta'
                              ? 'Leitura automática • moto'
                              : 'Leitura automática • carro',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _initializing ? null : _toggleTorch,
                        icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
                      ),
                    ],
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 390),
                    height: widget.vehicleType == 'motocicleta' ? 165 : 115,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            _captured
                                ? const Color(0xFF6CB77D)
                                : Colors.white.withValues(alpha: .95),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .36),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Center(
                      child:
                          _captured
                              ? const CircularProgressIndicator(
                                color: Color(0xFF6CB77D),
                              )
                              : const Icon(
                                Icons.center_focus_strong,
                                color: Colors.white,
                                size: 42,
                              ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .62),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      _initializing ? 'Preparando câmera...' : _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.vehicleType == 'motocicleta'
                        ? 'Mantenha a placa inteira da moto dentro da moldura. A leitura é automática.'
                        : 'Aproxime até a placa preencher a moldura. A leitura é automática.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
