import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

final _platePattern = RegExp(r'[A-Z]{3}[0-9][A-Z0-9][0-9]{2}');

/// Usa o reconhecimento de texto do próprio Android/iOS. Não envia a imagem
/// para um serviço externo apenas para obter a placa.
Future<List<String>> recognizePlateCandidatesImpl(XFile image) async {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return const [];
  }

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(
      InputImage.fromFilePath(image.path),
    );
    final candidates = <String>{};

    void collect(String value) {
      final normalized = value.toUpperCase();
      for (final match in _platePattern.allMatches(normalized)) {
        candidates.add(match.group(0)!);
      }

      // OCR costuma separar os grupos com espaço, hífen ou quebra de linha.
      final compact = normalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      for (final match in _platePattern.allMatches(compact)) {
        candidates.add(match.group(0)!);
      }
    }

    collect(result.text);
    for (final block in result.blocks) {
      for (final line in block.lines) {
        collect(line.text);
      }
    }
    return candidates.toList(growable: false);
  } finally {
    await recognizer.close();
  }
}
