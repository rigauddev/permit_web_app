import 'package:flutter/material.dart';

class UserCreatePage extends StatefulWidget {
  final String userType;
  const UserCreatePage({super.key, required this.userType});

  @override
  State<UserCreatePage> createState() => _UserCreatePageState();
}

class _UserCreatePageState extends State<UserCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final List<String> _companyList = [
    'Empresa 1',
    'Empresa 2', 
    'Empresa 3',
  ];

  final List<String> _userTypeList = [
    'admin',
    'gestor', 
    'operador',
  ];
  String? _selectedUserType;
  String? _selectedCompany;

  void _registerUser() {
    if (_formKey.currentState!.validate()) {
      // Simulação do cadastro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuário cadastrado para $_selectedCompany com sucesso!'),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Usuário')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) => value!.isEmpty ? 'Informe seu nome' : null,
              ),
              TextFormField(
                controller: _surnameController,
                decoration: const InputDecoration(labelText: 'Sobrenome'),
                validator: (value) => value!.isEmpty ? 'Informe seu sobrenome' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty ? 'Informe seu email' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
                validator: (value) => value!.length < 6 ? 'A senha deve ter pelo menos 6 caracteres' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedCompany,
                decoration: const InputDecoration(labelText: 'Empresa'),
                items: _companyList.map((empresa) {
                  return DropdownMenuItem(
                    value: empresa,
                    child: Text(empresa),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCompany = value;
                  });
                },
                validator: (value) => value == null ? 'Selecione uma empresa' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedUserType,
                decoration: const InputDecoration(labelText: 'Tipo de Usuário'),
                items: _userTypeList.map((userType) {
                  return DropdownMenuItem(
                    value: userType,
                    child: Text(userType),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedUserType = value;
                  });
                },
                validator: (value) => value == null ? 'Selecione um tipo de usuário' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _registerUser,
                child: const Text('Cadastrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
