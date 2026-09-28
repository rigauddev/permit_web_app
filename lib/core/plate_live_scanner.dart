import 'package:flutter/material.dart';

import 'plate_live_scanner_stub.dart'
    if (dart.library.io) 'plate_live_scanner_mobile.dart';

/// Abre o leitor contínuo de placas. A imagem não é salva nem enviada.
Future<String?> scanPlateWithLiveCamera(BuildContext context) =>
    scanPlateWithLiveCameraImpl(context);
