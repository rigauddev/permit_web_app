import 'package:flutter/material.dart';

import '../../widgets/custom_appbar.dart';
import '../../widgets/custom_drawer.dart';

class PermitRequestPage extends StatefulWidget {
  final String userType;
  final String userProfile;
  final String permitType; // Tipo do alvará selecionado
  final List<Map<String, dynamic>> questions; // Perguntas carregadas da API

  const PermitRequestPage({
    super.key,
    required this.userType,
    required this.userProfile,
    required this.permitType,
    required this.questions,
  });

  @override
  State<PermitRequestPage> createState() => _PermitRequestPageState();
}

class _PermitRequestPageState extends State<PermitRequestPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Controladores dos campos fixos
  final _nameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _eventNameController = TextEditingController();
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();
  final _publicSizeController = TextEditingController();
  final _timeController = TextEditingController();

  // Respostas dinâmicas das perguntas
  final Map<int, dynamic> _answers = {};

  late List<Map<String, dynamic>> _steps;

  @override
  void initState() {
    super.initState();

    _steps = [
      {
        'title': 'Informações Pessoais',
        'fields': [
          _buildTextField(label: 'Nome', controller: _nameController),
          _buildTextField(label: 'CPF', controller: _cpfController),
          _buildTextField(label: 'Endereço', controller: _addressController),
          _buildTextField(label: 'Telefone', controller: _phoneController),
        ],
      },
      {
        'title': 'Informações do Evento',
        'fields': [
          _buildTextField(label: 'Nome do Evento', controller: _eventNameController),
          _buildTextField(label: 'Data do Evento', controller: _dateController),
          _buildTextField(label: 'Local do Evento', controller: _locationController),
          _buildTextField(label: 'Tamanho do Público', controller: _publicSizeController),
          _buildTextField(label: 'Horário do Evento', controller: _timeController),
        ],
      },
      {
        'title': 'Informações Específicas',
        'fields': widget.questions.map((q) => _buildQuestionField(q)).toList(),
      },
    ];
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      if (_currentStep < _steps.length - 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        _submitRequest();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _submitRequest() {
    // Aqui você pode montar o body do request
    final requestBody = {
      'nome': _nameController.text,
      'cpf': _cpfController.text,
      'endereco': _addressController.text,
      'telefone': _phoneController.text,
      'nome_evento': _eventNameController.text,
      'data_evento': _dateController.text,
      'local_evento': _locationController.text,
      'tamanho_publico': _publicSizeController.text,
      'horario_evento': _timeController.text,
      'tipo_alvara': widget.permitType,
      'respostas_perguntas': _answers,
    };

    print('Request Body: $requestBody');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitação enviada com sucesso!')),
    );

    Navigator.pop(context); // volta para dashboard
  }

  Widget _buildTextField({required String label, required TextEditingController controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Preencha o campo "$label"';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildQuestionField(Map<String, dynamic> question) {
    final questionId = question['id'];
    final tiposResposta = question['tipos_resposta'] as List<dynamic>;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question['pergunta'],
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                // Lógica para anexar documento
                setState(() {
                  _answers[questionId] = 'Documento Anexado';
                });
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
                  setState(() {
                    _answers[questionId] = pickedDate.toIso8601String();
                  });
                }
              },
              validator: (value) {
                if (_answers[questionId] == null) {
                  return 'Selecione a data';
                }
                return null;
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Solicitação de ${widget.permitType}', actions: []),
      drawer: CustomDrawer(userType: widget.userType, userProfile: widget.userProfile),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _steps[_currentStep]['title'],
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...(_steps[_currentStep]['fields'] as List<Widget>),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0)
                        OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Theme.of(context).colorScheme.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Voltar'),
                        ),
                      ElevatedButton(
                        onPressed: _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: Text(_currentStep == _steps.length - 1 ? 'Enviar' : 'Avançar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
