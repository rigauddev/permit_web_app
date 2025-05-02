import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  final String userType; // user, operador, gestor, admin
  final String? userProfile; // null, ou 'admin' para gestor admin

  const CustomDrawer({
    super.key,
    required this.userType,
    this.userProfile,
  });

  bool get isAdmin => userType == 'admin';
  bool get isUser => userType == 'user';
  bool get isOperatorOrManager => userType == 'operador' || userType == 'gestor';
  bool get isGestorAdmin => userType == 'gestor' && userProfile == 'admin';

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primaryColor),
            child: const Center(
              child: Text(
                'Prefeitura de Valença',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          /// Início - todos acessam
          _buildTile(context, icon: Icons.home, title: 'Início', route: '/home'),

          /// Alvará (usuário comum)
          if (isUser || isOperatorOrManager || isAdmin)
            _buildTile(context, icon: Icons.event, title: 'Serviços', route: '/services'),

            ExpansionTile(
              leading: Icon(Icons.event, color: primaryColor), 
              title: const Text('Agendamentos'), 
              children: [
                _buildSubTile(context, 'Solicitar Alvará', '/event-permit'),
                _buildSubTile(context, 'Meus Alvarás', '/my-permits'),
                _buildSubTile(context, 'Certidão', '/my-permits'),
              ]), 


          /// Submenu: Serviços (Operador, Gestor e Admin)
          if (isOperatorOrManager || isAdmin)
            ExpansionTile(
              leading: Icon(Icons.work, color: primaryColor),
              title: const Text('Gestão'),
              children: [
                _buildSubTile(context, 'Solicitações', '/solicitacoes'),
                _buildSubTile(context, 'Vistorias', '/vistorias'),
                _buildSubTile(context, 'Geração de DAM', '/dam'),
              ],
            ),

          /// Usuários (Apenas gestor admin e admin)
          if (isGestorAdmin || isAdmin)
          ExpansionTile(
            leading: Icon(Icons.people, color: primaryColor),
            title: const Text('Usuários'),
            children: [
              _buildSubTile(context, 'Cadastrar Usuários', '/user-create'),
              _buildSubTile(context, 'Permissões de Usuários', '/users'),
            ],
          ),
          
          ExpansionTile(
            leading: Icon(Icons.people, color: primaryColor),
            title: const Text('Secretaria'),
            children: [
              _buildSubTile(context, 'Cadastrar Secretaria', '/users'),
              _buildSubTile(context, 'Gestão de Operadores', '/users'),
              _buildSubTile(context, 'Gestão de Gestor', '/users'),
            ]
            ),
            ExpansionTile(
            leading: Icon(Icons.people, color: primaryColor),
            title: const Text('Configurações'),
            children: [
              
              _buildSubTile(context, 'Permissões', '/users'),
              _buildSubTile(context, 'Tipo de Usuários', '/users'),
              _buildSubTile(context, 'Criar perguntas', '/questtions'),

            ]
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
  Widget _buildTile(BuildContext context, {required IconData icon, required String title, required String route}) {
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
}
