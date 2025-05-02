import 'package:flutter/material.dart';
// import 'dart:math';

import '../../widgets/custom_appbar.dart';
import '../../widgets/custom_drawer.dart';

class UsersListPage extends StatefulWidget {
  final String userType;

  const UsersListPage({super.key, required this.userType});

  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  List<Map<String, String>> users = [
    {
      'nome': 'João',
      'sobrenome': 'Silva',
      'telefone': '11999999999',
      'endereco': 'Rua A, 123',
      'email': 'joao@exemplo.com',
    },
    {
      'nome': 'Maria',
      'sobrenome': 'Oliveira',
      'telefone': '11888888888',
      'endereco': 'Rua B, 456',
      'email': 'maria@exemplo.com',
      'empresa': 'Empresa 1',
    },
    {
      'nome': 'Maria',
      'sobrenome': 'Oliveira',
      'telefone': '11888888888',
      'endereco': 'Rua B, 456',
      'email': 'maria@exemplo.com',
      'empresa': 'Empresa 2',
    },
  ];

  void _openUserForm(Map<String, String> user) {
    final nomeController = TextEditingController(text: user['nome']);
    final sobrenomeController = TextEditingController(text: user['sobrenome']);
    final telefoneController = TextEditingController(text: user['telefone']);
    final enderecoController = TextEditingController(text: user['endereco']);
    final emailController = TextEditingController(text: user['email']);
    final empresaController = TextEditingController(text: user['empresa'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar Usuário'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome')),
              TextField(controller: sobrenomeController, decoration: const InputDecoration(labelText: 'Sobrenome')),
              TextField(controller: telefoneController, decoration: const InputDecoration(labelText: 'Telefone')),
              TextField(controller: enderecoController, decoration: const InputDecoration(labelText: 'Endereço')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: empresaController, decoration: const InputDecoration(labelText: 'Empresa')),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  // final novaSenha = _gerarSenha();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Nova senha enviada para ${emailController.text}')),
                  );
                },
                icon: const Icon(Icons.lock_reset),
                label: const Text('Gerar nova senha e enviar'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                user['nome'] = nomeController.text;
                user['sobrenome'] = sobrenomeController.text;
                user['telefone'] = telefoneController.text;
                user['endereco'] = enderecoController.text;
                user['email'] = emailController.text;
                user['empresa'] = empresaController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  // String _gerarSenha() {
  //   const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  //   return List.generate(10, (index) => chars[Random().nextInt(chars.length)]).join();
  // }

  @override
  Widget build(BuildContext context) {
    final isAdminOrGestor = widget.userType == 'admin' || widget.userType == 'gestor';

    return Scaffold(
      appBar: CustomAppBar(
        title:  'Lista de Usuários',
        actions: []),
      drawer: CustomDrawer(userType: widget.userType),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (isAdminOrGestor) ...[
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Navegar para página de cadastro comum
                      Navigator.pushNamed(context, '/cadastro_usuario');
                    },
                    child: const Text('Cadastrar Usuário'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      // Navegar para página de cadastro com empresa
                      Navigator.pushNamed(context, '/cadastro_usuario_empresa');
                    },
                    child: const Text('Usuário da Empresa'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Card(
                    child: ListTile(
                      title: Text('${user['nome']} ${user['sobrenome']}'),
                      subtitle: Text(user['email']!),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _openUserForm(user),
                    ),
                  );
                },
              ),
            ),
            if (isAdminOrGestor)
              Align(
                alignment: Alignment.bottomRight,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/cadastro_usuario');
                  },
                  child: const Icon(Icons.add),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
