import 'package:image_picker/image_picker.dart';

import 'plate_ocr_stub.dart' if (dart.library.io) 'plate_ocr_mobile.dart';

/// Identifica placas brasileiras em uma foto capturada pelo aparelho.
///
/// Na web, a leitura é feita pela API como alternativa, pois o ML Kit é
/// disponibilizado somente para Android e iOS.
Future<List<String>> recognizePlateCandidates(XFile image) =>
    recognizePlateCandidatesImpl(image);
