import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/auth_service.dart';
import '../../core/session_expiration.dart';

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
  String? _currentRole;
  String? _currentSecretaria;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserScope();
  }

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
      if (!mounted) return;
      await SessionExpiration.logout(context);
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
      if (error.statusCode == 401) {
        if (!mounted) return;
        await SessionExpiration.logout(context);
        return;
      }
      _showError(error.message);
    } catch (_) {
      _showError('Não foi possível cadastrar o usuário interno');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCurrentUserScope() async {
    final rawUser = await _secureStorage.read(key: 'user');
    if (rawUser == null || !mounted) return;
    final user = jsonDecode(rawUser) as Map<String, dynamic>;
    setState(() {
      _currentRole = user['role'] as String?;
      _currentSecretaria = user['secretaria'] as String?;
      if (_currentRole == 'gestor_secretaria') {
        _selectedRole = 'operador_secretaria';
        _selectedSecretaria = _currentSecretaria;
      }
    });
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
      appBar: AppBar(
        title: const Text('Cadastro de usuário interno'),
        actions: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => _goBack(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ],
      ),
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
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(labelText: 'Perfil'),
                    items:
                        _availableRoles.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() {
                          _selectedRole = value;
                          if (value == 'admin') {
                            _selectedSecretaria = null;
                          } else {
                            _selectedSecretaria ??=
                                _currentSecretaria ??
                                'desenvolvimento_economico';
                          }
                        }),
                  ),
                  if (_selectedRole != 'admin') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSecretaria,
                      decoration: const InputDecoration(
                        labelText: 'Secretaria',
                      ),
                      items:
                          _availableSecretarias.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                      onChanged:
                          _currentRole == 'gestor_secretaria'
                              ? null
                              : (value) =>
                                  setState(() => _selectedSecretaria = value),
                    ),
                    if (_currentRole == 'gestor_secretaria')
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Gestores criam usuários apenas para sua secretaria.',
                        ),
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

  Map<String, String> get _availableRoles {
    if (_currentRole == 'gestor_secretaria') {
      return const {
        'gestor_secretaria': 'Gestor de secretaria',
        'operador_secretaria': 'Operador de secretaria',
      };
    }
    return _roles;
  }

  Map<String, String> get _availableSecretarias {
    if (_currentRole == 'gestor_secretaria' &&
        _currentSecretaria != null &&
        _secretarias.containsKey(_currentSecretaria)) {
      return {_currentSecretaria!: _secretarias[_currentSecretaria]!};
    }
    return _secretarias;
  }

  static void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/users');
    }
  }
}
