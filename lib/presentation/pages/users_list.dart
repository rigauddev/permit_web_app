import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/auth_service.dart';
import '../../core/session_expiration.dart';
import '../../data/models/user_model.dart';
import '../../shared/widgets/custom_appbar.dart';
import '../../shared/widgets/app_scaffold.dart';

class UsersListPage extends StatefulWidget {
  final String userType;

  const UsersListPage({super.key, required this.userType});

  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  final _authService = AuthService();
  final _secureStorage = const FlutterSecureStorage();
  late Future<List<UserModel>> _usersFuture;

  static const _secretariaLabels = {
    'desenvolvimento_economico': 'Desenvolvimento Econômico',
    'meio_ambiente': 'Meio Ambiente',
    'infraestrutura': 'Infraestrutura',
    'dmtran': 'DMTRAN',
    'vigilancia_sanitaria': 'Vigilância Sanitária',
    'guarda_civil': 'Guarda Civil Municipal',
    'receita_municipal': 'Receita Municipal',
  };

  static const _roleLabels = {
    'admin': 'Administrador',
    'gestor_secretaria': 'Gestor de secretaria',
    'operador_secretaria': 'Operador de secretaria',
    'cidadao': 'Cidadão',
  };

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<UserModel>> _loadUsers() async {
    final token = await _secureStorage.read(key: 'access_token');
    if (token == null) {
      if (mounted) await SessionExpiration.logout(context);
      return const [];
    }
    try {
      return await _authService.listUsers(accessToken: token);
    } on AuthException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return const [];
      }
      rethrow;
    }
  }

  void _refresh() {
    setState(() {
      _usersFuture = _loadUsers();
    });
  }

  bool get _canManageUsers =>
      widget.userType == 'admin' || widget.userType == 'gestor';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      userType: widget.userType,
      appBar: CustomAppBar(
        title: 'Gestão de usuários',
        actions: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => _goBack(context),
            icon: const Icon(Icons.arrow_back),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton:
          _canManageUsers
              ? FloatingActionButton.extended(
                onPressed: () async {
                  await Navigator.pushNamed(context, '/cadastro_usuario');
                  if (mounted) _refresh();
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Novo usuário'),
              )
              : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<UserModel>>(
          future: _usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              );
            }

            final users = snapshot.data ?? const <UserModel>[];
            if (users.isEmpty) {
              return const Center(
                child: Text('Nenhum usuário encontrado para sua secretaria.'),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder:
                        (context, index) => _UserCard(
                          user: users[index],
                          secretariaLabel: _formatSecretaria(users[index]),
                          roleLabel: _formatRole(users[index].role),
                          onEdit:
                              _canManageUsers
                                  ? () => _editUser(users[index])
                                  : null,
                        ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Nome')),
                      DataColumn(label: Text('E-mail')),
                      DataColumn(label: Text('Perfil')),
                      DataColumn(label: Text('Secretaria')),
                      DataColumn(label: Text('Telefone')),
                      DataColumn(label: Text('Ações')),
                    ],
                    rows:
                        users
                            .map(
                              (user) => DataRow(
                                cells: [
                                  DataCell(Text(_fullName(user))),
                                  DataCell(Text(user.email)),
                                  DataCell(Text(_formatRole(user.role))),
                                  DataCell(Text(_formatSecretaria(user))),
                                  DataCell(Text(user.phone)),
                                  DataCell(
                                    IconButton(
                                      tooltip: 'Editar usuário',
                                      onPressed:
                                          _canManageUsers
                                              ? () => _editUser(user)
                                              : null,
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  static String _fullName(UserModel user) {
    final parts = [user.name, user.lastName].where((item) => item.isNotEmpty);
    return parts.join(' ');
  }

  static String _formatRole(String role) => _roleLabels[role] ?? role;

  static String _formatSecretaria(UserModel user) {
    if (user.role == 'admin') return 'Todas';
    final secretaria = user.secretaria;
    if (secretaria == null || secretaria.isEmpty) return 'Sem secretaria';
    return _secretariaLabels[secretaria] ?? secretaria;
  }

  static void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _editUser(UserModel user) async {
    final token = await _secureStorage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      if (mounted) await SessionExpiration.logout(context);
      return;
    }
    if (!mounted) return;
    final nameController = TextEditingController(text: user.name);
    final lastNameController = TextEditingController(text: user.lastName);
    final emailController = TextEditingController(text: user.email);
    final phoneController = TextEditingController(text: user.phone);
    final addressController = TextEditingController(text: user.address);
    var selectedRole = user.role;
    var selectedSecretaria = user.secretaria;

    final saved = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Editar usuário'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Nome'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Sobrenome',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Telefone',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: addressController,
                          decoration: const InputDecoration(
                            labelText: 'Endereço',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue:
                              _roleLabels.containsKey(selectedRole)
                                  ? selectedRole
                                  : null,
                          decoration: const InputDecoration(
                            labelText: 'Perfil',
                          ),
                          items:
                              _roleLabels.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (value) => setDialogState(() {
                                selectedRole = value ?? selectedRole;
                                if (selectedRole == 'admin') {
                                  selectedSecretaria = null;
                                }
                              }),
                        ),
                        if (selectedRole != 'admin') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue:
                                _secretariaLabels.containsKey(
                                      selectedSecretaria,
                                    )
                                    ? selectedSecretaria
                                    : null,
                            decoration: const InputDecoration(
                              labelText: 'Secretaria',
                            ),
                            items:
                                _secretariaLabels.entries
                                    .map(
                                      (entry) => DropdownMenuItem(
                                        value: entry.key,
                                        child: Text(entry.value),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) => setDialogState(
                                  () => selectedSecretaria = value,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Salvar'),
                    ),
                  ],
                ),
          ),
    );

    if (saved != true) return;
    try {
      await _authService.updateUser(
        accessToken: token,
        userId: user.id!,
        nome: nameController.text.trim(),
        sobrenome: lastNameController.text.trim(),
        email: emailController.text.trim(),
        telefone: phoneController.text.trim(),
        endereco: addressController.text.trim(),
        role: selectedRole,
        secretaria: selectedRole == 'admin' ? null : selectedSecretaria,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuário atualizado.')));
      _refresh();
    } on AuthException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      nameController.dispose();
      lastNameController.dispose();
      emailController.dispose();
      phoneController.dispose();
      addressController.dispose();
    }
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.secretariaLabel,
    required this.roleLabel,
    this.onEdit,
  });

  final UserModel user;
  final String secretariaLabel;
  final String roleLabel;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.account_circle_outlined),
        title: Text('${user.name} ${user.lastName}'.trim()),
        subtitle: Text('$roleLabel\n$secretariaLabel\n${user.email}'),
        isThreeLine: true,
        trailing:
            onEdit == null
                ? null
                : IconButton(
                  tooltip: 'Editar usuário',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
      ),
    );
  }
}
