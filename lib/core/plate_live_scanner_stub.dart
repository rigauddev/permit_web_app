import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<String?> scanPlateWithLiveCameraImpl(
  BuildContext context, {
  Future<String?> Function(XFile image)? recognize,
}) async {
  await showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Leitura de placa no celular'),
          content: const Text(
            'A leitura automática pela câmera está disponível no aplicativo Android e iPhone. Nesta versão, consulte a placa digitando os caracteres.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendi'),
            ),
          ],
        ),
  );
  return null;
}
