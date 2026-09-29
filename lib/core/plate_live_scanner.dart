import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';

import 'plate_live_scanner_stub.dart'
    if (dart.library.io) 'plate_live_scanner_mobile.dart'
    if (dart.library.html) 'plate_live_scanner_web.dart';

/// Abre o leitor contínuo de placas. No navegador, os quadros são usados
/// somente durante a consulta ao OCR interno e não são persistidos.
Future<String?> scanPlateWithLiveCamera(
  BuildContext context, {
  Future<String?> Function(XFile image)? recognize,
}) => scanPlateWithLiveCameraImpl(context, recognize: recognize);
