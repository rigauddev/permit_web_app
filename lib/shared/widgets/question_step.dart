import 'package:flutter/material.dart';

class QuestionStep extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final Map<int, dynamic> answers;
  final void Function(int questionId, dynamic answer) onAnswerChanged;
  final GlobalKey<FormState> formKey;

  const QuestionStep({
    super.key,
    required this.questions,
    required this.answers,
    required this.onAnswerChanged,
    required this.formKey,
    required controller,
  });

  @override
  State<QuestionStep> createState() => _QuestionStepState();
}

class _QuestionStepState extends State<QuestionStep> {
  Widget _buildQuestionField(Map<String, dynamic> question) {
    final questionId = question['id'] as int;
    final tiposResposta = question['tipos_resposta'] as List<dynamic>;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question['pergunta'] ?? '',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (question['descricao'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: Text(
                question['descricao'],
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (tiposResposta.contains('Anexar Documento'))
            ElevatedButton(
              onPressed: () {
                // Aqui você pode implementar o picker de arquivos
                widget.onAnswerChanged(questionId, 'Documento Anexado');
              },
              child: const Text('Anexar Documento'),
            ),
          if (tiposResposta.contains('Calendário'))
            TextFormField(
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Selecione Data',
                border: OutlineInputBorder(),
              ),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  widget.onAnswerChanged(
                    questionId,
                    pickedDate.toIso8601String(),
                  );
                  setState(() {});
                }
              },
              validator: (value) {
                if (widget.answers[questionId] == null) {
                  return 'Selecione a data';
                }
                return null;
              },
              controller: TextEditingController(
                text:
                    widget.answers[questionId] != null
                        ? widget.answers[questionId].toString()
                        : '',
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.questions.map(_buildQuestionField).toList(),
      ),
    );
  }
}
