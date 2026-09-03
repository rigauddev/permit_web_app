// ignore_for_file: deprecated_member_use

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class QuestionFieldWidget extends StatefulWidget {
  final int questionId;
  final String? questionKey;
  final String questionText;
  final String? descricao;
  final List<String> tiposResposta;
  final List<String> opcoesResposta;
  final Map<String, dynamic> camposObrigatorios;
  final String? modeloDocumentoNome;
  final String? modeloDocumentoUrl;
  final dynamic currentValue;
  final void Function(dynamic) onChanged;

  const QuestionFieldWidget({
    super.key,
    required this.questionId,
    this.questionKey,
    required this.questionText,
    this.descricao,
    required this.tiposResposta,
    this.opcoesResposta = const [],
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
  final Map<String, TextEditingController> customControllers = {};
  final List<_StreetSegmentControllers> percursoControllers = [];
  DateTime? dataSelecionada;
  TimeOfDay? horaSelecionada;
  String? arquivoSelecionado;
  String? assinaturaSelecionada;
  String? percursoUrl;
  final Set<String> opcoesSelecionadas = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentValue();
  }

  @override
  void didUpdateWidget(covariant QuestionFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionId != widget.questionId) {
      _loadCurrentValue();
    }
  }

  void _loadCurrentValue() {
    respostaSimNao = null;
    textoController.clear();
    dataSelecionada = null;
    horaSelecionada = null;
    arquivoSelecionado = null;
    assinaturaSelecionada = null;
    percursoUrl = null;
    opcoesSelecionadas.clear();
    _resetRouteControllers();
    for (final controller in customControllers.values) {
      controller.dispose();
    }
    customControllers.clear();

    if (widget.currentValue is Map) {
      respostaSimNao = widget.currentValue['resposta'];
      textoController.text = widget.currentValue['texto'] ?? '';
      dataSelecionada = widget.currentValue['data'];
      horaSelecionada = widget.currentValue['hora'];
      arquivoSelecionado = widget.currentValue['arquivo'];
      assinaturaSelecionada = widget.currentValue['assinatura'];
      percursoUrl = widget.currentValue['percurso_url'];
      final selectedOptions =
          widget.currentValue['opcoes_selecionadas'] ??
          widget.currentValue['Opções selecionáveis'];
      if (selectedOptions is List) {
        opcoesSelecionadas.addAll(
          selectedOptions.map((item) => item.toString()),
        );
      }
      _loadRouteSegments(widget.currentValue['percurso_ruas']);
      for (final label in _customResponseLabels) {
        customControllers[label] = TextEditingController(
          text: widget.currentValue[label]?.toString() ?? '',
        );
      }
    }

    if (_usesRouteAnswer && percursoControllers.isEmpty) {
      _addRouteSegmentControllers();
    }
    _syncCustomControllers();
  }

  @override
  void dispose() {
    textoController.dispose();
    for (final controller in customControllers.values) {
      controller.dispose();
    }
    _disposeRouteControllers();
    super.dispose();
  }

  void salvarResposta() {
    final payload = {
      'resposta': respostaSimNao,
      'texto': textoController.text,
      'data': dataSelecionada,
      'hora': horaSelecionada,
      'arquivo': arquivoSelecionado,
      'assinatura': assinaturaSelecionada,
    };
    for (final entry in customControllers.entries) {
      payload[entry.key] = entry.value.text.trim();
    }
    if (_usesRouteAnswer) {
      payload['percurso_ruas'] = _routeSegments();
      payload['percurso_url'] = percursoUrl;
    }
    if (widget.tiposResposta.contains('Opções selecionáveis')) {
      payload['opcoes_selecionadas'] = opcoesSelecionadas.toList();
    }
    widget.onChanged(payload);
  }

  bool get _isRouteQuestion => widget.questionKey == 'bloqueia_via';
  bool get _usesRouteAnswer =>
      _isRouteQuestion || widget.tiposResposta.contains('Rota do Evento');
  List<String> get _customResponseLabels =>
      widget.tiposResposta
          .where(
            (field) =>
                field != 'Sim/Não' &&
                field != 'Texto' &&
                field != 'Anexar Documento' &&
                field != 'Calendário' &&
                field != 'Rota do Evento' &&
                field != 'Opções selecionáveis' &&
                field != 'Botão de Baixar' &&
                field != 'Assinatura impressa' &&
                field != 'Assinatura gov.br',
          )
          .toList();

  void _syncCustomControllers() {
    final labels = _customResponseLabels.toSet();
    final removedLabels =
        customControllers.keys
            .where((label) => !labels.contains(label))
            .toList();
    for (final label in removedLabels) {
      customControllers.remove(label)?.dispose();
    }
    for (final label in labels) {
      customControllers.putIfAbsent(label, () => TextEditingController());
    }
  }

  void _loadRouteSegments(dynamic rawSegments) {
    if (rawSegments is! List) return;
    for (final item in rawSegments) {
      if (item is! Map) continue;
      final inicio = item['inicio']?.toString() ?? '';
      final fim = item['fim']?.toString() ?? '';
      if (inicio.trim().isEmpty && fim.trim().isEmpty) continue;
      _addRouteSegmentControllers(inicio: inicio, fim: fim);
    }
  }

  void _addRouteSegmentControllers({String inicio = '', String fim = ''}) {
    percursoControllers.add(
      _StreetSegmentControllers(
        inicio: TextEditingController(text: inicio),
        fim: TextEditingController(text: fim),
      ),
    );
  }

  void _resetRouteControllers() {
    _disposeRouteControllers();
    percursoControllers.clear();
  }

  void _disposeRouteControllers() {
    for (final segment in percursoControllers) {
      segment.dispose();
    }
  }

  List<Map<String, String>> _routeSegments() {
    return percursoControllers
        .map(
          (segment) => {
            'inicio': segment.inicio.text.trim(),
            'fim': segment.fim.text.trim(),
          },
        )
        .where(
          (segment) =>
              segment['inicio']!.isNotEmpty || segment['fim']!.isNotEmpty,
        )
        .toList();
  }

  Future<void> _generateRoutePreview() async {
    final segments =
        _routeSegments()
            .where(
              (segment) =>
                  segment['inicio']!.isNotEmpty && segment['fim']!.isNotEmpty,
            )
            .toList();

    if (segments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe pelo menos uma rua de início e fim.'),
        ),
      );
      return;
    }

    final stops = <String>[
      '${segments.first['inicio']}, Valença - BA',
      ...segments.map((segment) => '${segment['fim']}, Valença - BA'),
    ];
    final origin = Uri.encodeComponent(stops.first);
    final destination = Uri.encodeComponent(stops.last);
    final waypoints =
        stops.length > 2
            ? '&waypoints=${Uri.encodeComponent(stops.sublist(1, stops.length - 1).join('|'))}'
            : '';
    setState(() {
      percursoUrl =
          'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination$waypoints';
      salvarResposta();
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
          for (final label in _customResponseLabels) ...[
            TextFormField(
              controller: customControllers[label],
              maxLength: 255,
              decoration: InputDecoration(
                labelText: _labelWithRequired(label, label),
              ),
              onChanged: (_) => salvarResposta(),
            ),
          ],
          if (widget.tiposResposta.contains('Opções selecionáveis') &&
              widget.opcoesResposta.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildSelectableOptions(),
          ],
          if (_usesRouteAnswer) ...[
            const SizedBox(height: 10),
            _buildRouteBuilder(context),
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

  Widget _buildRouteBuilder(BuildContext context) {
    final theme = Theme.of(context);
    final segments = _routeSegments();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF7),
        border: Border.all(color: const Color(0xFFD8E0D8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Percurso de bloqueio ou desvio',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Informe os trechos do percurso. Use o botão + para incluir outras ruas.',
          ),
          const SizedBox(height: 12),
          ...List.generate(percursoControllers.length, (index) {
            final segment = percursoControllers[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: segment.inicio,
                      decoration: InputDecoration(
                        labelText: 'Rua início ${index + 1}',
                      ),
                      onChanged: (_) => salvarResposta(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: segment.fim,
                      decoration: InputDecoration(
                        labelText: 'Rua final ${index + 1}',
                      ),
                      onChanged: (_) => salvarResposta(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remover trecho',
                    onPressed:
                        percursoControllers.length <= 1
                            ? null
                            : () {
                              setState(() {
                                final removed = percursoControllers.removeAt(
                                  index,
                                );
                                removed.dispose();
                                salvarResposta();
                              });
                            },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            );
          }),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _addRouteSegmentControllers();
                    salvarResposta();
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Adicionar trecho'),
              ),
              ElevatedButton.icon(
                onPressed: _generateRoutePreview,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Gerar percurso'),
              ),
            ],
          ),
          if (percursoUrl != null && segments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE0E6E0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Prévia do percurso gerado',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...segments.map(
                    (segment) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.route_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${segment['inicio']} -> ${segment['fim']}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openGeneratedRoute,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ver no mapa'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectableOptions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF7),
        border: Border.all(color: const Color(0xFFD8E0D8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _labelWithRequired(
              'Selecione as opções aplicáveis',
              'Opções selecionáveis',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                widget.opcoesResposta.map((option) {
                  final selected = opcoesSelecionadas.contains(option);
                  return FilterChip(
                    label: Text(option),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          opcoesSelecionadas.add(option);
                        } else {
                          opcoesSelecionadas.remove(option);
                        }
                        salvarResposta();
                      });
                    },
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  String _labelWithRequired(String label, String field) {
    return widget.camposObrigatorios[field] == true ? '$label *' : label;
  }

  Future<void> _openGeneratedRoute() async {
    final rawUrl = percursoUrl;
    if (rawUrl == null || rawUrl.isEmpty) return;
    await launchUrl(Uri.parse(rawUrl), mode: LaunchMode.externalApplication);
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

class _StreetSegmentControllers {
  final TextEditingController inicio;
  final TextEditingController fim;

  _StreetSegmentControllers({required this.inicio, required this.fim});

  void dispose() {
    inicio.dispose();
    fim.dispose();
  }
}
