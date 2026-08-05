import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/user_provider.dart';

class CustomDrawer extends ConsumerWidget implements PreferredSizeWidget {
  final String userType; // user, operador, gestor, admin
  final String? userProfile; // null, ou 'admin' para gestor admin

  const CustomDrawer({super.key, required this.userType, this.userProfile});

  bool get isAdmin => userType == 'admin';
  bool get isUser => userType == 'user';
  bool get isOperatorOrManager =>
      userType == 'operador' || userType == 'gestor';
  bool get isGestorAdmin => userType == 'gestor' && userProfile == 'admin';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primaryColor),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage('assets/images/avatar.jpg'),
                ),
                const SizedBox(height: 10),
                Text(
                  user!.name,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),

          /// Início - todos acessam
          _buildTile(
            context,
            icon: Icons.home,
            title: 'Início',
            route: '/home',
          ),

          /// Alvará (usuário comum)
          if (isUser || isOperatorOrManager || isAdmin)
            ExpansionTile(
              leading: Icon(Icons.event, color: primaryColor),
              title: const Text('Serviços'),
              children: [
                _buildSubTile(context, 'Serviços', '/services'),
                _buildSubTile(
                  context,
                  'Secretaria de Cultura',
                  '/solicitacoes',
                ),
                _buildSubTile(
                  context,
                  'secreatria de Desenvolvimento Social',
                  '/vistorias',
                ),
                _buildSubTile(
                  context,
                  'Secretaria de Desenvolvimento Urbano',
                  '/dam',
                ),
                _buildSubTile(context, 'Secretaria de Educação', '/dam'),
                _buildSubTile(context, 'Secretaria de Segurança', '/dam'),
                _buildSubTile(context, 'Secretaria de Transporte', '/dam'),
              ],
            ),

          /// Submenu: Serviços (Operador, Gestor e Admin)
          if (isOperatorOrManager || isAdmin)
            ExpansionTile(
              leading: Icon(Icons.work, color: primaryColor),
              title: const Text('Gestão'),
              children: [
                _buildSubTile(context, 'Solicitações', '/solicitacoes'),
                _buildSubTile(context, 'Vistorias', '/vistorias'),
                // _buildSubTile(context, 'Geração de DAM', '/dam'),
              ],
            ),

          /// Usuários (Apenas gestor admin e admin)
          if (isAdmin)
            _buildTile(
              context,
              icon: Icons.people,
              title: 'Usuarios',
              route: '/users',
            ),

          ExpansionTile(
            leading: Icon(Icons.people, color: primaryColor),
            title: const Text('Secretaria'),
            children: [
              _buildSubTile(context, 'Cadastrar Secretaria', '/users'),
              _buildSubTile(context, 'Gestão de Operadores', '/users'),
              _buildSubTile(context, 'Gestão de Gestor', '/users'),
            ],
          ),

          ExpansionTile(
            leading: Icon(Icons.people, color: primaryColor),
            title: const Text('Configurações'),
            children: [
              _buildSubTile(context, 'Permissões', '/users'),
              _buildSubTile(context, 'Tipo de Usuários', '/users'),
              _buildSubTile(context, 'Criar perguntas', '/questtions'),
            ],
          ),

          const Divider(),

          /// Sair
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sair'),
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
    );
  }

  /// Utilitário para criar ListTiles padrão
  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      onTap: () {
        Navigator.pushReplacementNamed(context, route);
      },
    );
  }

  /// Utilitário para itens de submenu
  Widget _buildSubTile(BuildContext context, String title, String route) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      title: Text(title),
      onTap: () {
        Navigator.pushReplacementNamed(context, route);
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
