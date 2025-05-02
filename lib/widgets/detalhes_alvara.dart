import 'package:flutter/material.dart';

class DetalhesSolicitacao extends StatelessWidget {
  final String evento;
  final String data;
  final String empresa;

  const DetalhesSolicitacao({super.key, required this.evento, required this.data, required this.empresa});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Detalhes - $evento"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Data: $data"),
          Text("Empresa Responsável: $empresa"),
          const SizedBox(height: 10),
          const Text("Anexos:"),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.file_download),
            label: const Text("Baixar Documento"),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fechar")),
      ],
    );
  }

  void show(BuildContext context) {}
}
