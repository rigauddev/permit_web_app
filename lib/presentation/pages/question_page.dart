import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/permit_api_service.dart';
import '../../core/session_expiration.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/custom_appbar.dart';

class PerguntasPage extends StatefulWidget {
  const PerguntasPage({super.key, required this.userType, this.userProfile});
  final String userType;
  final String? userProfile;

  @override
  State<PerguntasPage> createState() => _PerguntasPageState();
}

class _PerguntasPageState extends State<PerguntasPage> {
  final _formKey = GlobalKey<FormState>();

  final List<Map<String, dynamic>> _perguntas = [];
  final List<Map<String, dynamic>> _publicRanges = [];

  String? _key;
  String? _pergunta;
  String? _descricao;
  String? _secretaria;
  String? _tipoFormulario;
  String? _secretariaDam;
  String? _modeloDocumentoNome;
  String? _modeloDocumentoUrl;
  int _prazoRespostaDiasUteis = 2;
  bool _requerVistoria = false;
  final List<String> _checklistVistoria = [];
  final TextEditingController _checklistController = TextEditingController();
  final TextEditingController _rangeLabelController = TextEditingController();
  final TextEditingController _rangeMinController = TextEditingController();
  final TextEditingController _rangeMaxController = TextEditingController();
  final TextEditingController _rangeDaysController = TextEditingController();
  final Map<String, bool> _selectedResponseFields = {};
  final Map<String, bool> _requiredResponseFields = {};
  int _formVersion = 0;
  int? _rangeEditId;
  bool _isSaving = false;
  bool _isSavingRange = false;

  int? _indiceEdicao;

  final List<String> _secretarias = [
    'Desenvolvimento Econômico',
    'Meio Ambiente',
    'Infraestrutura',
    'DMTRAN',
    'Vigilância Sanitária',
    'Guarda Civil Municipal',
    'Receita Municipal',
    'Secretaria de Saúde',
  ];
  final List<String> _secretariasDam = [
    'Desenvolvimento Econômico',
    'Receita Municipal',
  ];
  final List<String> _tiposFormulario = ['Alvará de Eventos'];
  final List<String> _additionalResponseFields = [
    'Texto',
    'Anexar Documento',
    'Calendário',
    'Botão de Baixar',
    'Assinatura impressa',
    'Assinatura gov.br',
  ];

  @override
  void initState() {
    super.initState();
    _fetchQuestionDefinitions();
    _fetchPublicRanges();
  }

  @override
  void dispose() {
    _checklistController.dispose();
    _rangeLabelController.dispose();
    _rangeMinController.dispose();
    _rangeMaxController.dispose();
    _rangeDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AppScaffold(
      userType: widget.userType,
      userProfile: widget.userProfile,
      appBar: CustomAppBar(
        title: 'Cadastrar Nova Pergunta',
        actions: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => _goBack(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cadastrar Nova Pergunta',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Wrap(
                    runSpacing: 16,
                    spacing: 16,
                    children: [
                      _buildTextField(
                        label: 'Chave de identificação',
                        onChanged: (v) => _key = v,
                        initialValue: _key,
                        hintText: 'Exemplo: tem_som',
                      ),
                      _buildTextField(
                        label: 'Pergunta',
                        onChanged: (v) {
                          _pergunta = v;
                          if (_key == null || _key!.isEmpty) {
                            _key = _generateKeyFromPergunta(v);
                          }
                        },
                        initialValue: _pergunta,
                      ),
                      _buildTextField(
                        label: 'Descrição e orientação ao cidadão',
                        onChanged: (v) => _descricao = v,
                        maxLines: 3,
                        initialValue: _descricao,
                        hintText:
                            'Explique quando marcar Sim, como preencher o modelo e quais documentos devem ser anexados.',
                      ),
                      _buildTextField(
                        label: 'Nome do modelo para baixar',
                        onChanged: (v) => _modeloDocumentoNome = v,
                        initialValue: _modeloDocumentoNome,
                        hintText: 'Exemplo: Ofício de bloqueio de via',
                      ),
                      _buildTextField(
                        label: 'URL ou referência do modelo',
                        onChanged: (v) => _modeloDocumentoUrl = v,
                        initialValue: _modeloDocumentoUrl,
                        hintText:
                            'Exemplo: assets/docs/arquivos/solicitacao_de_bloqueio_de_via.pdf',
                      ),
                      _buildModelUploadButton(),
                      _buildDropdown(
                        'Secretaria',
                        _secretaria,
                        _secretarias,
                        (v) => _secretaria = v,
                      ),
                      _buildTextField(
                        label: 'Prazo interno de resposta (dias úteis)',
                        onChanged:
                            (v) =>
                                _prazoRespostaDiasUteis =
                                    int.tryParse(v.trim()) ?? 2,
                        initialValue: _prazoRespostaDiasUteis.toString(),
                        hintText: 'Exemplo: 2',
                      ),
                      _buildDropdown(
                        'Serviço',
                        _tipoFormulario,
                        _tiposFormulario,
                        (v) => _tipoFormulario = v,
                      ),
                      if (_tipoFormulario == 'Alvará de Eventos') ...[
                        const Text(
                          'Para serviço de alvará, selecione também a secretaria responsável por gerar o DAM.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          'Secretaria geradora do DAM',
                          _secretariaDam,
                          _secretariasDam,
                          (v) => _secretariaDam = v,
                        ),
                      ],
                      _buildResponseFieldSelection(),
                      _buildInspectionChecklistSection(),
                      SizedBox(
                        width: isMobile ? double.infinity : 200,
                        child: ElevatedButton(
                          onPressed:
                              _isSaving ? null : _adicionarOuAtualizarPergunta,
                          child: Text(
                            _isSaving
                                ? 'Salvando...'
                                : _indiceEdicao != null
                                ? 'Atualizar'
                                : 'Salvar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildPublicRangeSection(),
                const SizedBox(height: 32),
                const Text(
                  'Perguntas Cadastradas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _perguntas.isEmpty
                    ? const Text('Nenhuma pergunta cadastrada.')
                    : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Chave')),
                          DataColumn(label: Text('Pergunta')),
                          DataColumn(label: Text('Secretaria')),
                          DataColumn(label: Text('Secretaria DAM')),
                          DataColumn(label: Text('Prazo')),
                          DataColumn(label: Text('Respostas')),
                          DataColumn(label: Text('Vistoria')),
                          DataColumn(label: Text('Tipo')),
                          DataColumn(label: Text('Ações')),
                        ],
                        rows: List.generate(_perguntas.length, (index) {
                          final p = _perguntas[index];
                          return DataRow(
                            cells: [
                              DataCell(Text(p['key'] ?? '')),
                              DataCell(Text(p['pergunta']!)),
                              DataCell(Text(p['secretaria']!)),
                              DataCell(Text(p['secretaria_dam'] ?? '')),
                              DataCell(
                                Text(
                                  '${p['prazo_resposta_dias_uteis'] ?? 2} dia(s) úteis',
                                ),
                              ),
                              DataCell(Text(_formatResponseSummary(p))),
                              DataCell(
                                Text(
                                  p['requer_vistoria'] == true
                                      ? '${(p['checklist_vistoria'] as List<dynamic>? ?? []).length} item(ns)'
                                      : 'Não',
                                ),
                              ),
                              DataCell(Text(p['tipo']!)),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editarPergunta(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _excluirPergunta(index),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    int maxLines = 1,
    required ValueChanged<String> onChanged,
    String? initialValue,
    String? hintText,
  }) {
    return SizedBox(
      width: MediaQuery.of(context).size.width < 600 ? double.infinity : 400,
      child: TextFormField(
        key: ValueKey('$label-$_formVersion-${initialValue ?? ''}'),
        initialValue: initialValue,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
        validator: (value) {
          if ((label == 'Pergunta' || label == 'Chave de identificação') &&
              (value == null || value.trim().isEmpty)) {
            return 'Este campo não pode ficar vazio.';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width < 600 ? double.infinity : 400,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items:
            items
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
        onChanged: (selected) => setState(() => onChanged(selected)),
      ),
    );
  }

  Widget _buildResponseFieldSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Campos de resposta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sim/Não será sempre incluído por padrão. Selecione campos adicionais abaixo e marque quais são obrigatórios.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        Column(
          children:
              _additionalResponseFields.map((field) {
                final selected = _selectedResponseFields[field] ?? false;
                final required = _requiredResponseFields[field] ?? false;
                return Column(
                  children: [
                    CheckboxListTile(
                      title: Text(field),
                      value: selected,
                      onChanged: (value) {
                        setState(() {
                          _selectedResponseFields[field] = value ?? false;
                          if (!(value ?? false)) {
                            _requiredResponseFields[field] = false;
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (selected)
                      Padding(
                        padding: const EdgeInsets.only(left: 48.0, bottom: 8.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: required,
                              onChanged: (value) {
                                setState(() {
                                  _requiredResponseFields[field] =
                                      value ?? false;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text('Obrigatório'),
                          ],
                        ),
                      ),
                  ],
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildModelUploadButton() {
    final hasModel = (_modeloDocumentoUrl ?? '').trim().isNotEmpty;
    return Container(
      width: MediaQuery.of(context).size.width < 600 ? double.infinity : 400,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD8E0D8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: _pickModelFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload do modelo da pergunta'),
          ),
          const SizedBox(height: 8),
          Text(
            hasModel
                ? 'Modelo: ${_modeloDocumentoNome ?? _modeloDocumentoUrl}'
                : 'Opcional. Use quando a pergunta precisar disponibilizar um documento para o cidadão baixar, preencher, assinar e anexar.',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Future<void> _pickModelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
    );
    final file =
        result == null || result.files.isEmpty ? null : result.files.single;
    if (file == null) return;
    setState(() {
      _modeloDocumentoNome =
          _modeloDocumentoNome?.trim().isNotEmpty == true
              ? _modeloDocumentoNome
              : file.name;
      _modeloDocumentoUrl = _modelReferenceFromFile(file);
      _selectedResponseFields['Botão de Baixar'] = true;
      _formVersion++;
    });
  }

  String _modelReferenceFromFile(PlatformFile file) {
    final fileName = file.name;
    final path = file.path ?? '';
    if (path.contains('/docs/arquivos/') ||
        path.contains('\\docs\\arquivos\\')) {
      return 'assets/docs/arquivos/$fileName';
    }
    return path.isNotEmpty ? path : 'assets/docs/arquivos/$fileName';
  }

  Widget _buildInspectionChecklistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Esta pergunta exige vistoria?'),
          subtitle: const Text(
            'Quando o cidadão responder Sim, será criada uma vistoria para a secretaria responsável.',
          ),
          value: _requerVistoria,
          onChanged:
              (value) => setState(() => _requerVistoria = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_requerVistoria) ...[
          const SizedBox(height: 8),
          const Text(
            'Itens do checklist da vistoria',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _checklistController,
                  decoration: const InputDecoration(
                    labelText: 'Item do checklist',
                    hintText: 'Exemplo: Conferir saídas de emergência',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addChecklistItem(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Adicionar item',
                onPressed: _addChecklistItem,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_checklistVistoria.isEmpty)
            const Text(
              'Inclua ao menos um item para orientar a equipe de vistoria.',
              style: TextStyle(color: Colors.black54),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _checklistVistoria
                      .map(
                        (item) => InputChip(
                          label: Text(item),
                          onDeleted:
                              () => setState(
                                () => _checklistVistoria.remove(item),
                              ),
                        ),
                      )
                      .toList(),
            ),
        ],
      ],
    );
  }

  Widget _buildPublicRangeSection() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prazo de solicitação por público',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure as faixas de público que o cidadão seleciona no formulário e o prazo mínimo em dias úteis para cada faixa.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _rangeField(_rangeLabelController, 'Rótulo', isMobile),
                _rangeField(
                  _rangeMinController,
                  'Público inicial',
                  isMobile,
                  number: true,
                ),
                _rangeField(
                  _rangeMaxController,
                  'Público final',
                  isMobile,
                  number: true,
                ),
                _rangeField(
                  _rangeDaysController,
                  'Prazo em dias úteis',
                  isMobile,
                  number: true,
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 180,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingRange ? null : _savePublicRange,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _isSavingRange
                          ? 'Salvando...'
                          : _rangeEditId == null
                          ? 'Adicionar'
                          : 'Atualizar',
                    ),
                  ),
                ),
                if (_rangeEditId != null)
                  TextButton(
                    onPressed: _resetPublicRangeForm,
                    child: const Text('Cancelar edição'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_publicRanges.isEmpty)
              const Text('Nenhuma faixa cadastrada.')
            else
              ..._publicRanges.map(
                (range) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(range['label']?.toString() ?? ''),
                  subtitle: Text(
                    '${range['min_publico']} a ${range['max_publico']} pessoas • ${range['prazo_dias_uteis']} dias úteis',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Editar faixa',
                        onPressed: () => _editPublicRange(range),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Inativar faixa',
                        onPressed: () => _deletePublicRange(range),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rangeField(
    TextEditingController controller,
    String label,
    bool isMobile, {
    bool number = false,
  }) {
    return SizedBox(
      width: isMobile ? double.infinity : 180,
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  void _addChecklistItem() {
    final value = _checklistController.text.trim();
    if (value.isEmpty || _checklistVistoria.contains(value)) return;
    setState(() {
      _checklistVistoria.add(value);
      _checklistController.clear();
    });
  }

  void _adicionarOuAtualizarPergunta() {
    if (!_formKey.currentState!.validate()) return;
    if (_key == null || _key!.trim().isEmpty) {
      _showError('Informe uma chave válida para a pergunta.');
      return;
    }
    if (_pergunta == null || _pergunta!.trim().isEmpty) {
      _showError('Informe uma pergunta válida.');
      return;
    }
    if (_secretaria == null || _secretaria!.isEmpty) {
      _showError('Selecione a secretaria responsável.');
      return;
    }
    if (_tipoFormulario == null || _tipoFormulario!.isEmpty) {
      _showError('Selecione o serviço associado à pergunta.');
      return;
    }

    if (_tipoFormulario == 'Alvará de Eventos' &&
        (_secretariaDam == null || _secretariaDam!.isEmpty)) {
      _showError(
        'Selecione a secretaria responsável pela geração do DAM para alvará.',
      );
      return;
    }
    if (_requerVistoria && _checklistVistoria.isEmpty) {
      _showError('Informe ao menos um item de checklist para a vistoria.');
      return;
    }
    if (_prazoRespostaDiasUteis < 1 || _prazoRespostaDiasUteis > 30) {
      _showError('Informe prazo de resposta entre 1 e 30 dias úteis.');
      return;
    }

    final tiposResposta = [
      'Sim/Não',
      ..._additionalResponseFields.where(
        (field) => _selectedResponseFields[field] == true,
      ),
    ];

    final obrigatorios = {
      for (final field in _additionalResponseFields)
        if (_selectedResponseFields[field] == true)
          field: _requiredResponseFields[field] == true,
    };
    final needsModel =
        _selectedResponseFields['Botão de Baixar'] == true ||
        _selectedResponseFields['Assinatura impressa'] == true ||
        _selectedResponseFields['Assinatura gov.br'] == true;
    if (needsModel && (_modeloDocumentoUrl ?? '').trim().isEmpty) {
      _showError(
        'Informe a URL ou referência do modelo quando houver botão de baixar ou assinatura.',
      );
      return;
    }

    final novaPergunta = {
      'id': _indiceEdicao != null ? _perguntas[_indiceEdicao!]['id'] : null,
      'key': _key!.trim(),
      'pergunta': _pergunta!.trim(),
      'descricao': _descricao ?? '',
      'secretaria': _secretaria ?? '',
      'tipo': _tipoFormulario ?? '',
      'secretaria_dam': _secretariaDam ?? '',
      'tipos_resposta': tiposResposta,
      'campos_obrigatorios': obrigatorios,
      'modelo_documento_nome': _modeloDocumentoNome?.trim(),
      'modelo_documento_url': _modeloDocumentoUrl?.trim(),
      'requer_vistoria': _requerVistoria,
      'checklist_vistoria': _checklistVistoria,
      'prazo_resposta_dias_uteis': _prazoRespostaDiasUteis,
    };

    final payload = Map<String, dynamic>.from(novaPergunta);
    if (payload['id'] == null) {
      payload.remove('id');
    }

    if (_indiceEdicao != null) {
      _enviarParaAPIEditar(payload);
    } else {
      _enviarParaAPISalvar(payload);
    }
  }

  void _editarPergunta(int index) {
    final pergunta = _perguntas[index];
    setState(() {
      _indiceEdicao = index;
      _key = pergunta['key'];
      _pergunta = pergunta['pergunta'];
      _descricao = pergunta['descricao'];
      _secretaria = pergunta['secretaria'];
      _tipoFormulario = pergunta['tipo'];
      _secretariaDam = pergunta['secretaria_dam'];
      _modeloDocumentoNome = pergunta['modelo_documento_nome'];
      _modeloDocumentoUrl = pergunta['modelo_documento_url'];
      _prazoRespostaDiasUteis =
          int.tryParse(
            pergunta['prazo_resposta_dias_uteis']?.toString() ?? '',
          ) ??
          2;
      _requerVistoria = pergunta['requer_vistoria'] == true;
      _checklistVistoria
        ..clear()
        ..addAll(List<String>.from(pergunta['checklist_vistoria'] ?? []));
      _checklistController.clear();
      _selectedResponseFields.clear();
      _requiredResponseFields.clear();
      final tiposResposta = List<String>.from(pergunta['tipos_resposta'] ?? []);
      for (final field in _additionalResponseFields) {
        _selectedResponseFields[field] = tiposResposta.contains(field);
        _requiredResponseFields[field] =
            (pergunta['campos_obrigatorios']
                as Map<String, dynamic>?)?[field] ==
            true;
      }
    });
  }

  void _excluirPergunta(int index) {
    final pergunta = _perguntas[index];
    _enviarParaAPIDeletar(pergunta, index);
  }

  void _resetFields() {
    _formKey.currentState?.reset();
    _indiceEdicao = null;
    _key =
        _pergunta =
            _descricao = _secretaria = _tipoFormulario = _secretariaDam = null;
    _modeloDocumentoNome = _modeloDocumentoUrl = null;
    _prazoRespostaDiasUteis = 2;
    _requerVistoria = false;
    _checklistVistoria.clear();
    _checklistController.clear();
    _selectedResponseFields.clear();
    _requiredResponseFields.clear();
    _formVersion++;
  }

  String _formatResponseSummary(Map<String, dynamic> p) {
    final tipos = List<String>.from(p['tipos_resposta'] ?? ['Sim/Não']);
    final obrigatorios =
        (p['campos_obrigatorios'] as Map<String, dynamic>?)?.entries
            .where((entry) => entry.value == true)
            .map((entry) => entry.key)
            .toList() ??
        <String>[];
    final summary = tipos.join(', ');
    if (obrigatorios.isEmpty) return summary;
    return '$summary • Obrigatórios: ${obrigatorios.join(', ')}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _fetchQuestionDefinitions() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      await SessionExpiration.logout(context);
      return;
    }

    try {
      final definitions = await PermitApiService().listQuestionDefinitions(
        accessToken: token,
      );
      if (!mounted) return;
      setState(() {
        _perguntas
          ..clear()
          ..addAll(definitions);
      });
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) {
        _showError(error.toString());
      }
    }
  }

  Future<String?> _accessToken() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      if (mounted) await SessionExpiration.logout(context);
      return null;
    }
    return token;
  }

  Future<void> _fetchPublicRanges() async {
    final token = await _accessToken();
    if (token == null) return;
    try {
      final ranges = await PermitApiService().listPublicRanges(
        accessToken: token,
      );
      if (!mounted) return;
      setState(() {
        _publicRanges
          ..clear()
          ..addAll(ranges);
      });
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.toString());
    }
  }

  Future<void> _savePublicRange() async {
    final token = await _accessToken();
    if (token == null) return;
    final minPublico = int.tryParse(_rangeMinController.text.trim());
    final maxPublico = int.tryParse(_rangeMaxController.text.trim());
    final prazo = int.tryParse(_rangeDaysController.text.trim());
    final label = _rangeLabelController.text.trim();
    if (label.isEmpty ||
        minPublico == null ||
        maxPublico == null ||
        prazo == null) {
      _showError('Preencha rótulo, público inicial, público final e prazo.');
      return;
    }
    final payload = {
      'label': label,
      'min_publico': minPublico,
      'max_publico': maxPublico,
      'prazo_dias_uteis': prazo,
      'is_active': true,
    };
    setState(() => _isSavingRange = true);
    try {
      if (_rangeEditId == null) {
        await PermitApiService().createPublicRange(
          accessToken: token,
          payload: payload,
        );
      } else {
        await PermitApiService().updatePublicRange(
          accessToken: token,
          rangeId: _rangeEditId!,
          payload: payload,
        );
      }
      if (!mounted) return;
      _resetPublicRangeForm();
      await _fetchPublicRanges();
      if (mounted) _showSuccess('Faixa de público salva.');
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSavingRange = false);
    }
  }

  void _editPublicRange(Map<String, dynamic> range) {
    setState(() {
      _rangeEditId = range['id'] as int?;
      _rangeLabelController.text = range['label']?.toString() ?? '';
      _rangeMinController.text = range['min_publico']?.toString() ?? '';
      _rangeMaxController.text = range['max_publico']?.toString() ?? '';
      _rangeDaysController.text = range['prazo_dias_uteis']?.toString() ?? '';
    });
  }

  Future<void> _deletePublicRange(Map<String, dynamic> range) async {
    final token = await _accessToken();
    final rangeId = range['id'] as int?;
    if (token == null || rangeId == null) return;
    try {
      await PermitApiService().deletePublicRange(
        accessToken: token,
        rangeId: rangeId,
      );
      if (!mounted) return;
      await _fetchPublicRanges();
      _showSuccess('Faixa inativada.');
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.toString());
    }
  }

  void _resetPublicRangeForm() {
    setState(() {
      _rangeEditId = null;
      _rangeLabelController.clear();
      _rangeMinController.clear();
      _rangeMaxController.clear();
      _rangeDaysController.clear();
    });
  }

  Future<void> _enviarParaAPISalvar(Map<String, dynamic> pergunta) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      await SessionExpiration.logout(context);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await PermitApiService().createQuestionDefinition(
        accessToken: token,
        payload: pergunta,
      );
      if (!mounted) return;
      setState(_resetFields);
      await _fetchQuestionDefinitions();
      if (mounted) _showSuccess('Pergunta salva no banco com sucesso.');
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _enviarParaAPIEditar(Map<String, dynamic> pergunta) async {
    final questionId = pergunta['id'] as int?;
    if (questionId == null) return;
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      await SessionExpiration.logout(context);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await PermitApiService().updateQuestionDefinition(
        accessToken: token,
        questionId: questionId,
        payload: pergunta,
      );
      if (!mounted) return;
      setState(_resetFields);
      await _fetchQuestionDefinitions();
      if (mounted) _showSuccess('Pergunta atualizada no banco com sucesso.');
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _enviarParaAPIDeletar(
    Map<String, dynamic> pergunta,
    int index,
  ) async {
    final questionId = pergunta['id'] as int?;
    if (questionId == null) return;
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      await SessionExpiration.logout(context);
      return;
    }

    try {
      await PermitApiService().deleteQuestionDefinition(
        accessToken: token,
        questionId: questionId,
      );
      if (!mounted) return;
      setState(() {
        _perguntas.removeAt(index);
      });
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.toString());
    }
  }

  String _generateKeyFromPergunta(String pergunta) {
    final key = pergunta
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return key;
  }

  static void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}
