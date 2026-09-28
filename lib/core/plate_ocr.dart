import 'package:image_picker/image_picker.dart';

import 'plate_ocr_stub.dart' if (dart.library.io) 'plate_ocr_mobile.dart';

/// Identifica placas brasileiras em uma foto capturada pelo aparelho.
///
/// A imagem permanece no aparelho. O resultado é enviado somente como texto
/// para a consulta de autorização no banco do sistema.
Future<List<String>> recognizePlateCandidates(XFile image) =>
    recognizePlateCandidatesImpl(image);
