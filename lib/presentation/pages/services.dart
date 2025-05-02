import 'package:flutter/material.dart';

import '../../widgets/custom_appbar.dart';
import '../../widgets/custom_drawer.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key, required this.userType, this.userProfile, this.permitType, this.questions});
  final String userType;
  final String? userProfile;
  final String? permitType;
  final List<Map<String, dynamic>>? questions;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final crossAxisCount = screenWidth < 600
        ? 1
        : screenWidth < 900
            ? 2
            : 3;

    final services = [
      {
        'title': 'Solicitação de Alvará',
        'description': 'Solicite permissões para eventos e atividades públicas.',
        'icon': Icons.assignment,
        'route': '/permit-dashboard',
      },
      {
        'title': 'IPTU',
        'description': 'Acesse informações e gere boletos do seu IPTU.',
        'icon': Icons.home_work,
        'route': '/iptu',
      },
      {
        'title': 'Certidões',
        'description': 'Solicite certidões negativas ou outros documentos oficiais.',
        'icon': Icons.description,
        'route': '/certidoes',
      },
      {
        'title': 'Nota Fiscal',
        'description': 'Emita ou consulte notas fiscais de serviços prestados.',
        'icon': Icons.receipt_long,
        'route': '/nota-fiscal',
      },
    ];

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Serviços',
        actions: [],
      ),
      drawer: CustomDrawer(userType: userType),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: services.map((service) {
            return _buildServiceCard(
              context,
              title: service['title'] as String,
              description: service['description'] as String,
              icon: service['icon'] as IconData,
              route: service['route'] as String,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required String route,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Center(
                  child: Icon(
                    icon,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  tooltip: 'Descrição do serviço',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(title),
                        content: Text(description),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Fechar'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                if (title == 'Solicitação de Alvará') {
                  _showPermitTypeModal(context);
                } else {
                  Navigator.pushNamed(context, route);
                }
              },
              child: const Text('Acessar'),
            )
          ],
        ),
      ),
    );
  }
  void _showPermitTypeModal(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Selecione o tipo de alvará'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPermitTypeOption(dialogContext, parentContext, 'Alvará de Evento'),
              _buildPermitTypeOption(dialogContext, parentContext, 'Alvará de Construção'),
              _buildPermitTypeOption(dialogContext, parentContext, 'Alvará de Funcionamento'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Fecha só o modal
              },
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermitTypeOption(BuildContext dialogContext, BuildContext parentContext, String type) {
    return ListTile(
      title: Text(type),
      leading: const Icon(Icons.assignment_outlined),
      onTap: () async {
        Navigator.of(dialogContext).pop(); // Fecha o modal
        
        final perguntas = await _fetchPerguntasPorTipo(type);

        if (parentContext.mounted) {
          String route;
          switch (type) {
            case 'Alvará de Evento':
              route = '/permit-dashboard'
              ;
              break;
            case 'Alvará de Construção':
              route = '/permit-dashboard';
              break;
            case 'Alvará de Funcionamento':
              route = '/permit-dashboard';
              break;
            default:
              route = '/permit-dashboard';
          }

          Navigator.pushNamed(
            parentContext,
            route,
            // arguments: perguntas,
            arguments: {
              'userType': userType,
              'userProfile': userProfile,
              'permitType': permitType, // ou o tipo que você selecionou
              'questions': perguntas, // as perguntas que você buscou
            },
          );
        }
      },
    );
  }


  Future<List<Map<String, dynamic>>> _fetchPerguntasPorTipo(String tipoFormulario) async {
    try {
      // Aqui você deveria chamar sua API de verdade
      // Vou simular com um Future.delayed para demonstrar:
      await Future.delayed(const Duration(seconds: 1)); // simula chamada HTTP

      // Simulando resposta
      return [
        {'pergunta': 'Qual o nome do evento?', 'tipoResposta': 'Texto'},
        {'pergunta': 'Data do evento', 'tipoResposta': 'Data'},
        {'pergunta': 'Anexe a autorização', 'tipoResposta': 'Arquivo'},
      ];
    } catch (e) {
      // Tratar erro aqui
      debugPrint('Erro ao buscar perguntas: $e');
      return [];
    }
  }

}
