import 'package:flutter/material.dart';

import 'plate_live_scanner_stub.dart'
    if (dart.library.io) 'plate_live_scanner_mobile.dart';

/// Abre o leitor contínuo do aplicativo nativo.
Future<String?> scanPlateWithLiveCamera(
  BuildContext context, {
  String vehicleType = 'carro',
}) => scanPlateWithLiveCameraImpl(context, vehicleType: vehicleType);
