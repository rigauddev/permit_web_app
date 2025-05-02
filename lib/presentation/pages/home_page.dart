import 'package:flutter/material.dart';
import 'package:permit_web_app/widgets/custom_appbar.dart';

import '../../widgets/custom_drawer.dart';

class UserHomePage extends StatelessWidget {
  const UserHomePage({super.key, required this.userType, this.userProfile});

  final String userType;
  final String? userProfile;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600
        ? 1
        : screenWidth < 900
            ? 2
            : 3;
    return Scaffold(
      appBar: CustomAppBar(
        title:  'Bem-vindo ao Sistema de Serviços da Prefeitura',
        actions: []),
      drawer: CustomDrawer(userType: userType),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.asset(
                'assets/images/logo_prefeitura_1.png',
                height: 100,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Todos os serviços da Prefeitura em um só lugar.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nosso objetivo é facilitar o atendimento ao público reunindo, em um único aplicativo, todos os serviços das secretarias municipais.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 12),
            const Text(
              'Aqui você pode solicitar alvarás, acompanhar eventos, acessar informações das secretarias, agendar serviços, entrar em contato com a prefeitura e muito mais.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 28),
            const Text(
              'Acesse os serviços:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildServiceCard(
                  context,
                  icon: Icons.assignment,
                  title: 'Receita Municipal',
                  route: '/services',
                ),
                _buildServiceCard(
                  context,
                  icon: Icons.apartment,
                  title: 'Secretarias',
                  route: '/secretarias',
                ),
                _buildServiceCard(
                  context,
                  icon: Icons.calendar_month,
                  title: 'Agendamentos',
                  route: '/eventos',
                ),
                _buildServiceCard(
                  context,
                  icon: Icons.support_agent,
                  title: 'Atendimento',
                  route: '/atendimento',
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context,
      {required IconData icon, required String title, required String route}) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.green[800]),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
