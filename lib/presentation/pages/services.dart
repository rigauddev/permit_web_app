import 'package:flutter/material.dart';
import '../../widgets/custom_appbar.dart';
import '../../widgets/custom_drawer.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({
    super.key,
    required this.userType,
    this.userProfile,
  });
  
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

    final services = [
      {
        'title': 'Solicitação de Alvará',
        'description': 'Solicite permissões para eventos e atividades públicas.',
        'icon': Icons.assignment,
      },
      // ... outros serviços ...
    ];

    return Scaffold(
      appBar: const CustomAppBar(title: 'Serviços', actions: []),
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
                Center(child: Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary)),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  tooltip: 'Descrição do serviço',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(title),
                      content: Text(description),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _onTapAlvara(context),
              child: const Text('Acessar'),
            ),
          ],
        ),
      ),
    );
  }

  void _onTapAlvara(BuildContext context) {
    _showPermitTypeModal(context);
  }

  void _showPermitTypeModal(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) {
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
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
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
        Navigator.of(dialogContext).pop();

        // 1. Requisições paralelas:
        final questionsFuture = _fetchPerguntasPorTipo(type);
        final formsFuture = _fetchUserForms(userType);

        final results = await Future.wait([questionsFuture, formsFuture]);
        final questions = results[0];
        final forms = results[1];

        if (parentContext.mounted) {
          Navigator.pushNamed(
            parentContext,
            '/permit-dashboard',
            arguments: {
              'userType': userType,
              'userProfile': userProfile ?? '',
              'permitType': type,
              'questions': questions,
              'forms': forms,
            },
          );
        }
      },
    );
  }

  /// Mock do endpoint GET /question?permitType=...
  Future<List<Map<String, dynamic>>> _fetchPerguntasPorTipo(String tipoFormulario) async {
    await Future.delayed(const Duration(seconds: 1));
    return [
      {
        "id": "001",
        "pergunta": "O evento vai ter carro de som?",
        "descricao": "Informe se o evento terá carro de som",
        "secretaria": "Infraestrutura",
        "tipo_formulario": tipoFormulario,
        "tipos_resposta": ["Sim/Não", "Calendário", "Anexar Documento"],
        "status": "ativo",
      },
      {
        "id": "002",
        "pergunta": "Será vendida comida no evento?",
        "descricao": "Isso requer vistoria da Vigilância Sanitária",
        "secretaria": "Saúde",
        "tipo_formulario": tipoFormulario,
        "tipos_resposta": ["Sim/Não"],
        "status": "ativo",
      },
    ];
  }

  /// Mock do endpoint GET /user-forms?userType=...
  Future<List<Map<String, dynamic>>> _fetchUserForms(String userType) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return [
      {
        "formId": "F001",
        "user_id": "U001",
        "nome_do_evento": "Evento 1",
        "permitType": "Alvará de Evento",
        "local_evento": "Centro de conferência",
        "data_do_evento": "10/05/2025",
        "status": "aguardando aprovaçoes",
        "perguntas": [
          {
            "id": "002",
            "pergunta": "Será vendida comida no evento?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [{"user_type": "Usuario", "user_name": "Joaquim", "descricao": "texto da Observação 1"}, {"user_type": "operador", "user_name": "Monica", "descricao": "texto da Observação 2"},]
          },
          {
            "id": "002",
            "pergunta": "Será vendida comida no evento?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [{"user_type": "Usuario", "user_name": "Joaquim", "descricao": "texto da Observação 1"}, {"user_type": "operador", "user_name": "Monica", "descricao": "texto da Observação 2"},] // Aqui vamos criar logica para aparecer com se fosse um chat 
          },
        ] // aguardando, aprovado, recusado
      },
      {
        "formId": "F002",
        "user_id": "U001",
        "nome_do_evento": "Evento 1",
        "permitType": "Alvará de Evento",
        "local_evento": "Centro de conferência",
        "data_do_evento": "2025-05-20",
        "status": "aguardando",
        "perguntas": [
          {
            "id": "002",
            "pergunta": "Será vendida comida no evento?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [{"user_type": "Usuario", "user_name": "Joaquim", "descricao": "texto da Observação 1"}, {"user_type": "operador", "user_name": "Monica", "descricao": "texto da Observação 2"},]
          },
          {
            "id": "002",
            "pergunta": "Será vendida comida no evento?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [{"user_type": "Usuario", "user_name": "Joaquim", "descricao": "texto da Observação 1"}, {"user_type": "operador", "user_name": "Monica", "descricao": "texto da Observação 2"},]
          },
        ] // aguardando, aprovado, recusado
      },
      {
        "formId": "F003",
        "user_id": "U001",
        "nome_do_evento": "Evento 1",
        "permitType": "Alvará de Evento",
        "local_evento": "Centro de conferência",
        "data_do_evento": "2025-05-20",
        "status": "aguardando",
        "perguntas": [
          {
            "id": "002",
            "pergunta": "Será vendida comida no evento?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [{"user_type": "Usuario", "user_name": "Joaquim", "descricao": "texto da Observação 1"}, {"user_type": "operador", "user_name": "Monica", "descricao": "texto da Observação 2"},]
          },
          {
            "id": "002",
            "pergunta": "Será vendida comida no evento?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [{"user_type": "Usuario", "user_name": "Joaquim", "descricao": "texto da Observação 1"}, {"user_type": "operador", "user_name": "Monica", "descricao": "texto da Observação 2"},]
          },
        ] // aguardando, aprovado, recusado
      },
    ];
  }
}
