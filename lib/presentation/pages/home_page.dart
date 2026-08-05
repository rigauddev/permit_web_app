import 'package:flutter/material.dart';

import '../../shared/widgets/custom_drawer.dart';

class UserHomePage extends StatelessWidget {
  const UserHomePage({super.key, required this.userType, this.userProfile});

  final String userType;
  final String? userProfile;

  bool get _isCitizen => userType == 'user' || userType == 'cidadao';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCitizen ? 'Meus serviços' : 'Painel interno'),
      ),
      drawer: CustomDrawer(userType: userType, userProfile: userProfile),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/logo_prefeitura_1.png',
                    height: 92,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isCitizen
                      ? 'Olá, acompanhe seus serviços municipais.'
                      : 'Olá, acompanhe as demandas da sua área.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isCitizen
                      ? 'Solicite alvará de evento, acompanhe protocolos e responda pendências da prefeitura.'
                      : 'Analise solicitações, acompanhe pendências por secretaria e gerencie usuários conforme suas permissões.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount =
                        constraints.maxWidth < 680
                            ? 1
                            : constraints.maxWidth < 980
                            ? 2
                            : 3;
                    final cards =
                        _isCitizen
                            ? _citizenCards(context)
                            : _internalCards(context);
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: constraints.maxWidth < 680 ? 2.7 : 1.55,
                      physics: const NeverScrollableScrollPhysics(),
                      children: cards,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _citizenCards(BuildContext context) {
    return [
      _buildServiceCard(
        context,
        icon: Icons.event_available_outlined,
        title: 'Solicitar alvará de evento',
        description:
            'Preencha o formulário, envie documentos e acompanhe o protocolo.',
        route: '/services',
      ),
      _buildServiceCard(
        context,
        icon: Icons.folder_copy_outlined,
        title: 'Minhas solicitações',
        description: 'Consulte status, pendências e autorizações emitidas.',
        route: '/services',
      ),
    ];
  }

  List<Widget> _internalCards(BuildContext context) {
    return [
      _buildServiceCard(
        context,
        icon: Icons.assignment_turned_in_outlined,
        title: 'Solicitações da secretaria',
        description: 'Analise aprovações, recusas e pedidos de correção.',
        route: '/services',
      ),
      _buildServiceCard(
        context,
        icon: Icons.people_outline,
        title: 'Usuários internos',
        description: 'Cadastre operadores, gestores e administradores.',
        route: '/user-create',
      ),
      if (userType == 'admin')
        _buildServiceCard(
          context,
          icon: Icons.tune_outlined,
          title: 'Perguntas e permissões',
          description:
              'Configure perguntas condicionais e regras por secretaria.',
          route: '/questtions',
        ),
    ];
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String route,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                icon,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
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
