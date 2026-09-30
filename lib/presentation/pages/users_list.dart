import 'package:flutter/material.dart';

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
  final _searchController = TextEditingController();
  late Future<List<UserModel>> _usersFuture;
  String _selectedRole = 'todos';
  String _selectedSecretaria = 'todas';

  static const _secretariaLabels = {
    'desenvolvimento_economico': 'Desenvolvimento Econômico',
    'meio_ambiente': 'Meio Ambiente',
    'infraestrutura': 'Infraestrutura',
    'semop': 'SEMOP',
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<UserModel>> _loadUsers() async {
    final token = await SessionExpiration.readAccessToken();
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

  List<UserModel> _filterUsers(List<UserModel> users) {
    final query = _searchController.text.trim().toLowerCase();
    return users
        .where((user) {
          final matchesQuery =
              query.isEmpty ||
              _fullName(user).toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query) ||
              user.cpfCnpj.toLowerCase().contains(query) ||
              user.phone.toLowerCase().contains(query);
          final matchesRole =
              _selectedRole == 'todos' || user.role == _selectedRole;
          final secretaria = user.role == 'admin' ? 'todas' : user.secretaria;
          final matchesSecretaria =
              _selectedSecretaria == 'todas' ||
              secretaria == _selectedSecretaria;
          return matchesQuery && matchesRole && matchesSecretaria;
        })
        .toList(growable: false);
  }

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
            final filteredUsers = _filterUsers(users);
            return _UsersManagementView(
              users: filteredUsers,
              allUsers: users,
              searchController: _searchController,
              selectedRole: _selectedRole,
              selectedSecretaria: _selectedSecretaria,
              roleLabels: _roleLabels,
              secretariaLabels: _secretariaLabels,
              canManageUsers: _canManageUsers,
              onSearchChanged: (_) => setState(() {}),
              onRoleChanged:
                  (value) => setState(() => _selectedRole = value ?? 'todos'),
              onSecretariaChanged:
                  (value) =>
                      setState(() => _selectedSecretaria = value ?? 'todas'),
              onClearFilters:
                  () => setState(() {
                    _searchController.clear();
                    _selectedRole = 'todos';
                    _selectedSecretaria = 'todas';
                  }),
              onEdit: _editUser,
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
    final token = await SessionExpiration.readAccessToken();
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

class _UsersManagementView extends StatelessWidget {
  const _UsersManagementView({
    required this.users,
    required this.allUsers,
    required this.searchController,
    required this.selectedRole,
    required this.selectedSecretaria,
    required this.roleLabels,
    required this.secretariaLabels,
    required this.canManageUsers,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onSecretariaChanged,
    required this.onClearFilters,
    required this.onEdit,
  });

  final List<UserModel> users;
  final List<UserModel> allUsers;
  final TextEditingController searchController;
  final String selectedRole;
  final String selectedSecretaria;
  final Map<String, String> roleLabels;
  final Map<String, String> secretariaLabels;
  final bool canManageUsers;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String?> onSecretariaChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<UserModel> onEdit;

  @override
  Widget build(BuildContext context) {
    final rolesCount = <String, int>{};
    final secretariasCount = <String, int>{};
    for (final user in allUsers) {
      rolesCount[user.role] = (rolesCount[user.role] ?? 0) + 1;
      final secretaria = user.role == 'admin' ? 'todas' : user.secretaria;
      if (secretaria != null && secretaria.isNotEmpty) {
        secretariasCount[secretaria] = (secretariasCount[secretaria] ?? 0) + 1;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        return ListView(
          children: [
            _UsersHeader(total: allUsers.length, filtered: users.length),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _UserMetricCard(
                  icon: Icons.groups_2_outlined,
                  label: 'Total de usuários',
                  value: allUsers.length.toString(),
                ),
                _UserMetricCard(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Administradores',
                  value: (rolesCount['admin'] ?? 0).toString(),
                ),
                _UserMetricCard(
                  icon: Icons.badge_outlined,
                  label: 'Gestão e operação',
                  value:
                      ((rolesCount['gestor_secretaria'] ?? 0) +
                              (rolesCount['operador_secretaria'] ?? 0))
                          .toString(),
                ),
                _UserMetricCard(
                  icon: Icons.apartment_outlined,
                  label: 'Secretarias',
                  value:
                      secretariasCount.keys
                          .where((item) => item != 'todas')
                          .length
                          .toString(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _UsersFilters(
              compact: compact,
              searchController: searchController,
              selectedRole: selectedRole,
              selectedSecretaria: selectedSecretaria,
              roleLabels: roleLabels,
              secretariaLabels: secretariaLabels,
              onSearchChanged: onSearchChanged,
              onRoleChanged: onRoleChanged,
              onSecretariaChanged: onSecretariaChanged,
              onClearFilters: onClearFilters,
            ),
            const SizedBox(height: 14),
            if (allUsers.isEmpty)
              const _UsersEmptyState(
                message: 'Nenhum usuário encontrado para sua secretaria.',
              )
            else if (users.isEmpty)
              const _UsersEmptyState(
                message: 'Nenhum usuário encontrado com os filtros aplicados.',
              )
            else if (compact)
              ...users.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _UserCard(
                    user: user,
                    secretariaLabel: _UsersListPageState._formatSecretaria(
                      user,
                    ),
                    roleLabel: _UsersListPageState._formatRole(user.role),
                    onEdit: canManageUsers ? () => onEdit(user) : null,
                  ),
                ),
              )
            else
              _UsersTable(
                users: users,
                canManageUsers: canManageUsers,
                onEdit: onEdit,
              ),
          ],
        );
      },
    );
  }
}

class _UsersHeader extends StatelessWidget {
  const _UsersHeader({required this.total, required this.filtered});

  final int total;
  final int filtered;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E5F2F), Color(0xFF1F8F4A)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white24,
              child: Icon(Icons.manage_accounts, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Usuários do sistema',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Controle perfis, secretarias e acessos internos com filtros rápidos.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
            Chip(
              label: Text('$filtered de $total'),
              backgroundColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserMetricCard extends StatelessWidget {
  const _UserMetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE5F4EA),
                child: Icon(icon, color: const Color(0xFF0E5F2F)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsersFilters extends StatelessWidget {
  const _UsersFilters({
    required this.compact,
    required this.searchController,
    required this.selectedRole,
    required this.selectedSecretaria,
    required this.roleLabels,
    required this.secretariaLabels,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onSecretariaChanged,
    required this.onClearFilters,
  });

  final bool compact;
  final TextEditingController searchController;
  final String selectedRole;
  final String selectedSecretaria;
  final Map<String, String> roleLabels;
  final Map<String, String> secretariaLabels;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String?> onSecretariaChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: compact ? double.infinity : 360,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Buscar usuário',
                  hintText: 'Nome, e-mail, CPF/CNPJ ou telefone',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 240,
              child: DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Perfil'),
                items: [
                  const DropdownMenuItem(value: 'todos', child: Text('Todos')),
                  ...roleLabels.entries.map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  ),
                ],
                onChanged: onRoleChanged,
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 260,
              child: DropdownButtonFormField<String>(
                initialValue: selectedSecretaria,
                decoration: const InputDecoration(labelText: 'Secretaria'),
                items: [
                  const DropdownMenuItem(value: 'todas', child: Text('Todas')),
                  ...secretariaLabels.entries.map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  ),
                ],
                onChanged: onSecretariaChanged,
              ),
            ),
            OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersTable extends StatelessWidget {
  const _UsersTable({
    required this.users,
    required this.canManageUsers,
    required this.onEdit,
  });

  final List<UserModel> users;
  final bool canManageUsers;
  final ValueChanged<UserModel> onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFE5F4EA)),
          columns: const [
            DataColumn(label: Text('Usuário')),
            DataColumn(label: Text('Contato')),
            DataColumn(label: Text('Perfil')),
            DataColumn(label: Text('Secretaria')),
            DataColumn(label: Text('Ações')),
          ],
          rows:
              users
                  .map(
                    (user) => DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFE5F4EA),
                                child: Text(_initials(user)),
                              ),
                              const SizedBox(width: 10),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 220,
                                ),
                                child: Text(
                                  _UsersListPageState._fullName(user).isEmpty
                                      ? 'Sem nome'
                                      : _UsersListPageState._fullName(user),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(
                              [user.email, user.phone]
                                  .where((item) => item.trim().isNotEmpty)
                                  .join('\n'),
                            ),
                          ),
                        ),
                        DataCell(
                          _RoleChip(
                            label: _UsersListPageState._formatRole(user.role),
                            role: user.role,
                          ),
                        ),
                        DataCell(
                          Text(_UsersListPageState._formatSecretaria(user)),
                        ),
                        DataCell(
                          IconButton.filledTonal(
                            tooltip: 'Editar usuário',
                            onPressed:
                                canManageUsers ? () => onEdit(user) : null,
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.role});

  final String label;
  final String role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'admin' => const Color(0xFF6A1B9A),
      'gestor_secretaria' => const Color(0xFF1565C0),
      'operador_secretaria' => const Color(0xFFEF6C00),
      _ => const Color(0xFF2E7D32),
    };
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(color: color.withValues(alpha: 0.20)),
    );
  }
}

class _UsersEmptyState extends StatelessWidget {
  const _UsersEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE5F4EA),
              child: Text(_initials(user)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _UsersListPageState._fullName(user).isEmpty
                        ? 'Sem nome'
                        : _UsersListPageState._fullName(user),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _RoleChip(label: roleLabel, role: user.role),
                      Chip(
                        label: Text(secretariaLabel),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      user.email,
                      user.phone,
                    ].where((item) => item.trim().isNotEmpty).join(' • '),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton.filledTonal(
                tooltip: 'Editar usuário',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
      ),
    );
  }
}

String _initials(UserModel user) {
  final name = _UsersListPageState._fullName(user).trim();
  if (name.isEmpty) return 'U';
  final parts = name.split(RegExp(r'\s+'));
  final first = parts.first.characters.first;
  final second = parts.length > 1 ? parts.last.characters.first : '';
  return (first + second).toUpperCase();
}
