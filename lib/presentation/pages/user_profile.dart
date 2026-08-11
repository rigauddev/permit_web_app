import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/auth_service.dart';
import '../../core/session_expiration.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/user_provider.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/custom_appbar.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, required this.userType});

  final String userType;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _storage = const FlutterSecureStorage();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _saving = false;
  bool _loading = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _hydrate(UserModel? user) {
    if (_loaded || user == null) return;
    _nameController.text = user.name;
    _lastNameController.text = user.lastName;
    _phoneController.text = user.phone;
    _addressController.text = user.address;
    _loaded = true;
  }

  Future<void> _loadProfile() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      if (mounted) await SessionExpiration.logout(context);
      return;
    }
    try {
      final user = await _authService.currentUser(accessToken: token);
      if (!mounted) return;
      ref.read(userProvider.notifier).setUser(user);
      _loaded = false;
      _hydrate(user);
    } on AuthException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      if (mounted) await SessionExpiration.logout(context);
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await _authService.updateCurrentUser(
        accessToken: token,
        nome: _nameController.text.trim(),
        sobrenome: _lastNameController.text.trim(),
        telefone: _phoneController.text.trim(),
        endereco: _addressController.text.trim(),
      );
      await _storage.write(key: 'user', value: jsonEncode(updated.toJson()));
      ref.read(userProvider.notifier).setUser(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
    } on AuthException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    _hydrate(user);

    return AppScaffold(
      userType: widget.userType,
      appBar: CustomAppBar(title: 'Perfil', actions: []),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Dados do usuário',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nome',
                                ),
                                validator:
                                    (value) =>
                                        value == null || value.trim().length < 2
                                            ? 'Informe o nome'
                                            : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _lastNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Sobrenome',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Contato / telefone',
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: 'Endereço',
                                ),
                              ),
                              const SizedBox(height: 16),
                              _lockedField('E-mail', user?.email ?? ''),
                              _lockedField('CPF/CNPJ', user?.cpfCnpj ?? ''),
                              _lockedField('Perfil', user?.role ?? ''),
                              _lockedField(
                                'Secretaria',
                                user?.secretaria ?? 'Não se aplica',
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(
                                  _saving ? 'Salvando...' : 'Salvar perfil',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
          ),
        ),
      ),
    );
  }

  Widget _lockedField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
