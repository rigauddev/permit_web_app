import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/auth_service.dart';

class UserCreatePage extends StatefulWidget {
  final String userType;
  const UserCreatePage({super.key, required this.userType});

  @override
  State<UserCreatePage> createState() => _UserCreatePageState();
}

class _UserCreatePageState extends State<UserCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _secureStorage = const FlutterSecureStorage();

  final _roles = const {
    'admin': 'Administrador',
    'gestor_secretaria': 'Gestor de secretaria',
    'operador_secretaria': 'Operador de secretaria',
  };

  final _secretarias = const {
    'desenvolvimento_economico': 'Desenvolvimento Econômico',
    'meio_ambiente': 'Meio Ambiente',
    'infraestrutura': 'Infraestrutura',
    'dmtran': 'DMTRAN',
    'vigilancia_sanitaria': 'Vigilância Sanitária',
    'guarda_civil': 'Guarda Civil Municipal',
    'receita_municipal': 'Receita Municipal',
  };

  String? _selectedRole = 'operador_secretaria';
  String? _selectedSecretaria = 'desenvolvimento_economico';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _cpfController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    final token = await _secureStorage.read(key: 'access_token');
    if (token == null) {
      _showError('Sessão expirada. Entre novamente.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.createCompanyUser(
        accessToken: token,
        nome: _nameController.text,
        sobrenome: _surnameController.text,
        cpfCnpj: _cpfController.text,
        email: _emailController.text,
        senha: _passwordController.text,
        role: _selectedRole!,
        secretaria: _selectedRole == 'admin' ? null : _selectedSecretaria,
        telefone: _phoneController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário interno cadastrado com sucesso.'),
        ),
      );
      Navigator.pop(context);
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Não foi possível cadastrar o usuário interno');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de usuário interno')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator:
                        (value) => value!.isEmpty ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _surnameController,
                    decoration: const InputDecoration(labelText: 'Sobrenome'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cpfController,
                    decoration: const InputDecoration(labelText: 'CPF'),
                    validator:
                        (value) => value!.isEmpty ? 'Informe o CPF' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Telefone'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    validator:
                        (value) => value!.isEmpty ? 'Informe o e-mail' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Senha inicial',
                    ),
                    obscureText: true,
                    validator:
                        (value) =>
                            value!.length < 6
                                ? 'A senha deve ter pelo menos 6 caracteres'
                                : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(labelText: 'Perfil'),
                    items:
                        _roles.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => _selectedRole = value),
                  ),
                  if (_selectedRole != 'admin') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedSecretaria,
                      decoration: const InputDecoration(
                        labelText: 'Secretaria',
                      ),
                      items:
                          _secretarias.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (value) =>
                              setState(() => _selectedSecretaria = value),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _registerUser,
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Cadastrar usuário interno'),
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
