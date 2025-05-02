import 'package:flutter/material.dart';

import '../../widgets/custom_appbar.dart';
import '../../widgets/custom_drawer.dart';

class PerguntasPage extends StatefulWidget {
  const PerguntasPage({super.key, required this.userType, this.userProfile});
  final String userType;
  final String? userProfile;

  @override
  State<PerguntasPage> createState() => _PerguntasPageState();
}

class _PerguntasPageState extends State<PerguntasPage> {
  final _formKey = GlobalKey<FormState>();

  final List<Map<String, String>> _perguntas = [];

  String? _pergunta;
  String? _descricao;
  String? _secretaria;
  String? _tipoFormulario;
  List<String> _tiposSelecionados = [];

  int? _indiceEdicao;

  final List<String> _secretarias = ['Meio Ambiente', 'Segurança', 'Eventos'];
  final List<String> _tiposFormulario = ['Alvará de Eventos', 'Táxi', 'Estabelecimento'];
  final List<String> _tiposResposta = ['Anexar Documento', 'Selecionar Data', 'Botão de Baixar', 'calendario'];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: CustomAppBar(title: 'Cadastrar Nova Pergunta', actions: []),
      drawer: CustomDrawer(userType: widget.userType, userProfile: widget.userProfile),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cadastrar Nova Pergunta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Wrap(
                    runSpacing: 16,
                    spacing: 16,
                    children: [
                      _buildTextField(label: 'Pergunta', onChanged: (v) => _pergunta = v, initialValue: _pergunta),
                      _buildTextField(label: 'Descrição', onChanged: (v) => _descricao = v, maxLines: 2, initialValue: _descricao),
                      _buildDropdown('Secretaria', _secretaria, _secretarias, (v) => _secretaria = v),
                      _buildDropdown('Tipo de Formulário', _tipoFormulario, _tiposFormulario, (v) => _tipoFormulario = v),
                      _buildCheckboxList('Tipo de Resposta', _tiposResposta),
                      SizedBox(
                        width: isMobile ? double.infinity : 200,
                        child: ElevatedButton(
                          onPressed: _adicionarOuAtualizarPergunta,
                          child: Text(_indiceEdicao != null ? 'Atualizar' : 'Salvar'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text('Perguntas Cadastradas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _perguntas.isEmpty
                    ? const Text('Nenhuma pergunta cadastrada.')
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Pergunta')),
                            DataColumn(label: Text('Secretaria')),
                            DataColumn(label: Text('Tipo')),
                            DataColumn(label: Text('Ações')),
                          ],
                          rows: List.generate(_perguntas.length, (index) {
                            final p = _perguntas[index];
                            return DataRow(cells: [
                              DataCell(Text(p['pergunta']!)),
                              DataCell(Text(p['secretaria']!)),
                              DataCell(Text(p['tipo']!)),
                              DataCell(Row(
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
                              )),
                            ]);
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

  Widget _buildTextField({required String label, int maxLines = 1, required ValueChanged<String> onChanged, String? initialValue}) {
    return SizedBox(
      width: MediaQuery.of(context).size.width < 600 ? double.infinity : 400,
      child: TextFormField(
        initialValue: initialValue,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: MediaQuery.of(context).size.width < 600 ? double.infinity : 400,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCheckboxList(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 10,
          children: items.map((item) {
            return FilterChip(
              label: Text(item),
              selected: _tiposSelecionados.contains(item),
              onSelected: (selected) {
                setState(() {
                  selected ? _tiposSelecionados.add(item) : _tiposSelecionados.remove(item);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _adicionarOuAtualizarPergunta() {
    if (_formKey.currentState!.validate() && _pergunta != null) {
      final novaPergunta = {
        'pergunta': _pergunta!,
        'descricao': _descricao ?? '',
        'secretaria': _secretaria ?? '',
        'tipo': _tipoFormulario ?? '',
        'resposta': _tiposSelecionados.join(', '),
      };

      setState(() {
        if (_indiceEdicao != null) {
          _perguntas[_indiceEdicao!] = novaPergunta;
          _enviarParaAPIEditar(novaPergunta);
        } else {
          _perguntas.add(novaPergunta);
          _enviarParaAPISalvar(novaPergunta);
        }
        _resetarFormulario();
      });
    }
  }

  void _editarPergunta(int index) {
    final pergunta = _perguntas[index];
    setState(() {
      _indiceEdicao = index;
      _pergunta = pergunta['pergunta'];
      _descricao = pergunta['descricao'];
      _secretaria = pergunta['secretaria'];
      _tipoFormulario = pergunta['tipo'];
      _tiposSelecionados = (pergunta['resposta'] ?? '').split(', ').where((e) => e.isNotEmpty).toList();
    });
  }

  void _excluirPergunta(int index) {
    final pergunta = _perguntas[index];
    setState(() {
      _perguntas.removeAt(index);
      _enviarParaAPIDeletar(pergunta);
    });
  }

  void _resetarFormulario() {
    _formKey.currentState?.reset();
    _indiceEdicao = null;
    _pergunta = _descricao = _secretaria = _tipoFormulario = null;
    _tiposSelecionados = [];
  }

  // Simulações de API
  void _enviarParaAPISalvar(Map<String, String> pergunta) {
    print('Salvar na API: $pergunta');
  }

  void _enviarParaAPIEditar(Map<String, String> pergunta) {
    print('Editar na API: $pergunta');
  }

  void _enviarParaAPIDeletar(Map<String, String> pergunta) {
    print('Deletar na API: $pergunta');
  }
}