import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/permit_api_service.dart';
import '../../core/session_expiration.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/custom_appbar.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key, required this.userType});

  final String userType;

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  static const _storage = FlutterSecureStorage();

  final _api = PermitApiService();
  final Map<String, Set<String>> _rolePermissions = {};
  final Map<String, dynamic> _rolesBySlug = {};
  List<Map<String, dynamic>> _permissions = [];
  String? _selectedRole;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      userType: widget.userType,
      appBar: CustomAppBar(
        title: 'Tipos de usuário e permissões',
        actions: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            icon: const Icon(Icons.arrow_back),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRoleSelector(),
                        const SizedBox(height: 16),
                        if (_selectedRole != null) _buildPermissionGroups(),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildRoleSelector() {
    final roles =
        _rolesBySlug.values
            .where((role) => role['slug'] != 'admin')
            .cast<Map<String, dynamic>>()
            .toList();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width:
              MediaQuery.of(context).size.width < 720 ? double.infinity : 420,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de usuário',
              border: OutlineInputBorder(),
            ),
            items:
                roles
                    .map(
                      (role) => DropdownMenuItem<String>(
                        value: role['slug']?.toString(),
                        child: Text(role['nome']?.toString() ?? ''),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _selectedRole = value),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _saving || _selectedRole == null ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Salvando...' : 'Salvar permissões'),
        ),
        OutlinedButton.icon(
          onPressed: _saving ? null : _createRole,
          icon: const Icon(Icons.add),
          label: const Text('Novo tipo'),
        ),
      ],
    );
  }

  Widget _buildPermissionGroups() {
    final permissionsByCategory = <String, List<Map<String, dynamic>>>{};
    for (final permission in _permissions) {
      final category = permission['categoria']?.toString() ?? 'Geral';
      permissionsByCategory.putIfAbsent(category, () => []).add(permission);
    }
    final selectedPermissions = _rolePermissions[_selectedRole] ?? <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          permissionsByCategory.entries.map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                children:
                    entry.value.map((permission) {
                      final slug = permission['slug']?.toString() ?? '';
                      return CheckboxListTile(
                        value: selectedPermissions.contains(slug),
                        onChanged:
                            (value) => setState(() {
                              final current = _rolePermissions.putIfAbsent(
                                _selectedRole!,
                                () => <String>{},
                              );
                              if (value == true) {
                                current.add(slug);
                              } else {
                                current.remove(slug);
                              }
                            }),
                        title: Text(permission['nome']?.toString() ?? slug),
                        subtitle: Text(
                          permission['descricao']?.toString() ?? slug,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }).toList(),
              ),
            );
          }).toList(),
    );
  }

  Future<String?> _token() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      if (mounted) await SessionExpiration.logout(context);
      return null;
    }
    return token;
  }

  Future<void> _load() async {
    final token = await _token();
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final matrix = await _api.getPermissionMatrix(accessToken: token);
      final permissions = List<Map<String, dynamic>>.from(
        matrix['permissions'] as List<dynamic>? ?? const [],
      );
      final roles = List<Map<String, dynamic>>.from(
        matrix['roles'] as List<dynamic>? ?? const [],
      );
      if (!mounted) return;
      setState(() {
        _permissions = permissions;
        _rolesBySlug
          ..clear()
          ..addEntries(
            roles.map((role) => MapEntry(role['slug']?.toString() ?? '', role)),
          );
        _rolePermissions
          ..clear()
          ..addEntries(
            roles.map(
              (role) => MapEntry(
                role['slug']?.toString() ?? '',
                Set<String>.from(role['permissions'] as List<dynamic>? ?? []),
              ),
            ),
          );
        _selectedRole ??=
            roles
                .firstWhere(
                  (role) => role['slug'] != 'admin',
                  orElse: () => const {},
                )['slug']
                ?.toString();
        _loading = false;
      });
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(error.toString());
    }
  }

  Future<void> _save() async {
    final token = await _token();
    final role = _selectedRole;
    if (token == null || role == null) return;
    setState(() => _saving = true);
    try {
      final updated = await _api.updateRolePermissions(
        accessToken: token,
        roleSlug: role,
        permissions: (_rolePermissions[role] ?? <String>{}).toList()..sort(),
      );
      if (!mounted) return;
      setState(() {
        _rolesBySlug[role] = updated;
        _rolePermissions[role] = Set<String>.from(
          updated['permissions'] as List<dynamic>? ?? [],
        );
      });
      _showMessage('Permissões atualizadas.');
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createRole() async {
    final token = await _token();
    if (token == null) return;
    if (!mounted) return;
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    final descriptionController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Novo tipo de usuário'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome do tipo'),
                  onChanged: (value) {
                    if (slugController.text.trim().isEmpty) {
                      slugController.text = _slugFrom(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: slugController,
                  decoration: const InputDecoration(
                    labelText: 'Chave',
                    helperText: 'Use letras minúsculas, números e underline.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.add),
                label: const Text('Criar'),
              ),
            ],
          ),
    );

    if (created != true) return;
    setState(() => _saving = true);
    try {
      final role = await _api.createRole(
        accessToken: token,
        slug: slugController.text.trim(),
        nome: nameController.text.trim(),
        descricao: descriptionController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        final slug = role['slug']?.toString() ?? '';
        _rolesBySlug[slug] = role;
        _rolePermissions[slug] = Set<String>.from(
          role['permissions'] as List<dynamic>? ?? [],
        );
        _selectedRole = slug;
      });
      _showMessage('Tipo de usuário criado.');
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.toString());
    } finally {
      nameController.dispose();
      slugController.dispose();
      descriptionController.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  String _slugFrom(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
