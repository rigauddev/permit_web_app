import 'package:flutter/material.dart';
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

  String? _key;
  String? _pergunta;
  String? _descricao;
  String? _secretaria;
  String? _tipoFormulario;
  String? _secretariaDam;
  String? _modeloDocumentoNome;
  String? _modeloDocumentoUrl;
  final Map<String, bool> _selectedResponseFields = {};
  final Map<String, bool> _requiredResponseFields = {};

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
                        label: 'Descrição',
                        onChanged: (v) => _descricao = v,
                        maxLines: 2,
                        initialValue: _descricao,
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
                        hintText: 'Exemplo: /modelos/oficio-bloqueio-via.pdf',
                      ),
                      _buildDropdown(
                        'Secretaria',
                        _secretaria,
                        _secretarias,
                        (v) => _secretaria = v,
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
                      SizedBox(
                        width: isMobile ? double.infinity : 200,
                        child: ElevatedButton(
                          onPressed: _adicionarOuAtualizarPergunta,
                          child: Text(
                            _indiceEdicao != null ? 'Atualizar' : 'Salvar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                          DataColumn(label: Text('Respostas')),
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
                              DataCell(Text(_formatResponseSummary(p))),
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
        key: ValueKey('$label-${initialValue ?? ''}'),
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

  void _resetarFormulario() {
    _formKey.currentState?.reset();
    _indiceEdicao = null;
    _key =
        _pergunta =
            _descricao = _secretaria = _tipoFormulario = _secretariaDam = null;
    _modeloDocumentoNome = _modeloDocumentoUrl = null;
    _selectedResponseFields.clear();
    _requiredResponseFields.clear();
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

  Future<void> _enviarParaAPISalvar(Map<String, dynamic> pergunta) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      await SessionExpiration.logout(context);
      return;
    }

    try {
      final created = await PermitApiService().createQuestionDefinition(
        accessToken: token,
        payload: pergunta,
      );
      if (!mounted) return;
      setState(() {
        _perguntas.add(created);
        _resetarFormulario();
      });
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.toString());
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

    final currentIndex = _indiceEdicao;
    try {
      final updated = await PermitApiService().updateQuestionDefinition(
        accessToken: token,
        questionId: questionId,
        payload: pergunta,
      );
      if (!mounted || currentIndex == null) return;
      setState(() {
        _perguntas[currentIndex] = updated;
        _resetarFormulario();
      });
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.toString());
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
