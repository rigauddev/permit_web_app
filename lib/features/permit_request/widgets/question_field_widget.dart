// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class QuestionFieldWidget extends StatefulWidget {
  final int questionId;
  final String questionText;
  final List<String> tiposResposta;
  final dynamic currentValue;
  final void Function(dynamic) onChanged;

  const QuestionFieldWidget({
    super.key,
    required this.questionId,
    required this.questionText,
    required this.tiposResposta,
    required this.onChanged,
    required this.currentValue,
  });

  @override
  State<QuestionFieldWidget> createState() => _QuestionFieldWidgetState();
}

class _QuestionFieldWidgetState extends State<QuestionFieldWidget> {
  String? respostaSimNao;
  final TextEditingController textoController = TextEditingController();
  DateTime? dataSelecionada;
  TimeOfDay? horaSelecionada;
  String? arquivoSelecionado;

  @override
  void initState() {
    super.initState();
    _loadCurrentValue();
  }

  @override
  void didUpdateWidget(covariant QuestionFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionId != widget.questionId ||
        oldWidget.currentValue != widget.currentValue) {
      _loadCurrentValue();
    }
  }

  void _loadCurrentValue() {
    respostaSimNao = null;
    textoController.clear();
    dataSelecionada = null;
    horaSelecionada = null;
    arquivoSelecionado = null;

    if (widget.currentValue is Map) {
      respostaSimNao = widget.currentValue['resposta'];
      textoController.text = widget.currentValue['texto'] ?? '';
      dataSelecionada = widget.currentValue['data'];
      horaSelecionada = widget.currentValue['hora'];
      arquivoSelecionado = widget.currentValue['arquivo'];
    }
  }

  @override
  void dispose() {
    textoController.dispose();
    super.dispose();
  }

  void salvarResposta() {
    widget.onChanged({
      'resposta': respostaSimNao,
      'texto': textoController.text,
      'data': dataSelecionada,
      'hora': horaSelecionada,
      'arquivo': arquivoSelecionado,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.questionText,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Sim'),
                value: 'Sim',
                groupValue: respostaSimNao,
                onChanged: (value) {
                  setState(() {
                    respostaSimNao = value;
                    salvarResposta();
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Não'),
                value: 'Não',
                groupValue: respostaSimNao,
                onChanged: (value) {
                  setState(() {
                    respostaSimNao = value;
                    salvarResposta();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (respostaSimNao == 'Sim') ...[
          if (widget.tiposResposta.contains('Texto')) ...[
            TextFormField(
              controller: textoController,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Descreva...'),
              onChanged: (_) => salvarResposta(),
            ),
          ],
          const SizedBox(height: 10),
          if (widget.tiposResposta.contains('Calendário')) ...[
            ElevatedButton(
              onPressed: () async {
                final data = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (data != null) {
                  if (!context.mounted) return;
                  final hora = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (!context.mounted) return;
                  setState(() {
                    dataSelecionada = data;
                    horaSelecionada = hora;
                    salvarResposta();
                  });
                }
              },
              child: const Text('Selecionar Data e Hora'),
            ),
            if (dataSelecionada != null)
              Text(
                'Data selecionada: ${dataSelecionada!.toLocal()} ${horaSelecionada != null ? '- ${horaSelecionada!.format(context)}' : ''}',
              ),
          ],
          const SizedBox(height: 10),
          if (widget.tiposResposta.contains('Anexar Documento')) ...[
            ElevatedButton(
              onPressed: () {
                setState(() {
                  arquivoSelecionado = 'documento.pdf';
                  salvarResposta();
                });
              },
              child: const Text('Anexar Documento'),
            ),
            if (arquivoSelecionado != null)
              Text('Arquivo: $arquivoSelecionado'),
          ],
        ],
      ],
    );
  }
}
