import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'plate_live_scanner_stub.dart'
    if (dart.library.io) 'plate_live_scanner_mobile.dart'
    if (dart.library.html) 'plate_live_scanner_web.dart';

/// Abre o leitor de placas com câmera. No navegador, usa captura contínua
/// de quadros para o OCR interno; no aplicativo, usa OCR nativo.
Future<String?> scanPlateWithLiveCamera(
  BuildContext context, {
  String vehicleType = 'carro',
  Future<String?> Function(XFile image)? recognize,
}) => scanPlateWithLiveCameraImpl(
  context,
  vehicleType: vehicleType,
  recognize: recognize,
);
