// ignore_for_file: deprecated_member_use

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class QuestionFieldWidget extends StatefulWidget {
  final int questionId;
  final String questionText;
  final String? descricao;
  final List<String> tiposResposta;
  final Map<String, dynamic> camposObrigatorios;
  final String? modeloDocumentoNome;
  final String? modeloDocumentoUrl;
  final dynamic currentValue;
  final void Function(dynamic) onChanged;

  const QuestionFieldWidget({
    super.key,
    required this.questionId,
    required this.questionText,
    this.descricao,
    required this.tiposResposta,
    this.camposObrigatorios = const {},
    this.modeloDocumentoNome,
    this.modeloDocumentoUrl,
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
  String? assinaturaSelecionada;

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
      assinaturaSelecionada = widget.currentValue['assinatura'];
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
      'assinatura': assinaturaSelecionada,
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
        if ((widget.descricao ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.descricao!.trim(),
            style: const TextStyle(color: Colors.black87, height: 1.35),
          ),
        ],
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
          if ((widget.modeloDocumentoUrl ?? '').isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD8E0D8)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.modeloDocumentoNome ?? 'Modelo do documento',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openModelDocument,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Baixar modelo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (widget.tiposResposta.contains('Texto')) ...[
            TextFormField(
              controller: textoController,
              maxLength: 255,
              decoration: InputDecoration(
                labelText: _labelWithRequired('Descreva...', 'Texto'),
              ),
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
              child: Text(
                _labelWithRequired('Selecionar Data e Hora', 'Calendário'),
              ),
            ),
            if (dataSelecionada != null)
              Text(
                'Data selecionada: ${dataSelecionada!.toLocal()} ${horaSelecionada != null ? '- ${horaSelecionada!.format(context)}' : ''}',
              ),
          ],
          const SizedBox(height: 10),
          if (widget.tiposResposta.contains('Anexar Documento')) ...[
            ElevatedButton(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                );
                final file =
                    result == null || result.files.isEmpty
                        ? null
                        : result.files.single;
                if (file == null) return;
                setState(() {
                  arquivoSelecionado = file.path ?? file.name;
                  salvarResposta();
                });
              },
              child: Text(
                _labelWithRequired('Anexar Documento', 'Anexar Documento'),
              ),
            ),
            if (arquivoSelecionado != null)
              Text('Arquivo: $arquivoSelecionado'),
          ],
          if (widget.tiposResposta.contains('Assinatura impressa') ||
              widget.tiposResposta.contains('Assinatura gov.br')) ...[
            const SizedBox(height: 10),
            const Text(
              'Forma de assinatura',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (widget.tiposResposta.contains('Assinatura impressa'))
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Imprimir, assinar e anexar'),
                value: 'impressa',
                groupValue: assinaturaSelecionada,
                onChanged: (value) {
                  setState(() {
                    assinaturaSelecionada = value;
                    salvarResposta();
                  });
                },
              ),
            if (widget.tiposResposta.contains('Assinatura gov.br'))
              Tooltip(
                message:
                    'Baixe o modelo, assine no aplicativo gov.br e anexe o arquivo assinado nesta pergunta.',
                child: RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Assinar eletronicamente pelo gov.br'),
                  value: 'gov_br',
                  groupValue: assinaturaSelecionada,
                  onChanged: (value) {
                    setState(() {
                      assinaturaSelecionada = value;
                      salvarResposta();
                    });
                  },
                ),
              ),
          ],
        ],
      ],
    );
  }

  String _labelWithRequired(String label, String field) {
    return widget.camposObrigatorios[field] == true ? '$label *' : label;
  }

  Future<void> _openModelDocument() async {
    final rawReference = widget.modeloDocumentoUrl?.trim();
    if (rawReference == null || rawReference.isEmpty) return;

    final uri = _documentUri(rawReference);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;

    await Clipboard.setData(ClipboardData(text: rawReference));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível abrir o modelo. A referência foi copiada.',
        ),
      ),
    );
  }

  Uri _documentUri(String rawReference) {
    final parsed = Uri.tryParse(rawReference);
    if (parsed != null && parsed.hasScheme) return parsed;
    return Uri.base.resolve(rawReference);
  }
}
