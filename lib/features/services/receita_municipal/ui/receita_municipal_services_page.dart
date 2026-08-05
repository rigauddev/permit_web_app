import 'package:flutter/material.dart';
import '../../../../shared/widgets/custom_drawer.dart';

class ReceitaMunicipalServicesPage extends StatelessWidget {
  final String userType;
  final String? userProfile;
  final String? userName;

  const ReceitaMunicipalServicesPage({
    super.key,
    required this.userType,
    this.userProfile,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount =
        screenWidth < 600
            ? 1
            : screenWidth < 900
            ? 2
            : 3;

    final services = [
      {
        'title': 'Solicitação de Alvará',
        'description':
            'Solicite permissões para eventos e atividades públicas.',
        'icon': Icons.assignment,
        'onTap': () => _showPermitTypeModal(context),
      },
      {
        'title': 'IPTU',
        'description': 'Consultar e emitir segunda via de IPTU.',
        'icon': Icons.home,
        'onTap': () {
          // Aqui depois você pode navegar para a página de IPTU
        },
      },
      {
        'title': 'Notas Fiscais',
        'description': 'Consultar e gerenciar notas fiscais emitidas.',
        'icon': Icons.receipt_long,
        'onTap': () {
          // Aqui depois você pode navegar para a página de Notas Fiscais
        },
      },
    ];

    return Scaffold(
      // appBar: const CustomAppBar(title: 'Serviços - Receita Municipal', actions: []),
      appBar: AppBar(title: Text('Serviços da Receita Municipal')),
      drawer: CustomDrawer(userType: userType),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children:
              services.map((service) {
                return _buildServiceCard(
                  context,
                  title: service['title'] as String,
                  description: service['description'] as String,
                  icon: service['icon'] as IconData,
                  onTap: service['onTap'] as VoidCallback,
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
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: onTap, child: const Text('Acessar')),
          ],
        ),
      ),
    );
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
              _buildPermitTypeOption(
                dialogContext,
                parentContext,
                'Alvará de Evento',
              ),
              _buildPermitTypeOption(
                dialogContext,
                parentContext,
                'Alvará de Construção',
              ),
              _buildPermitTypeOption(
                dialogContext,
                parentContext,
                'Alvará de Funcionamento',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermitTypeOption(
    BuildContext dialogContext,
    BuildContext parentContext,
    String type,
  ) {
    return ListTile(
      title: Text(type),
      leading: const Icon(Icons.assignment_outlined),
      onTap: () async {
        Navigator.of(dialogContext).pop();

        // Mock: Busca de perguntas e formulários
        final questions = await _fetchPerguntasPorTipo(type);
        final forms = await _fetchUserForms(userType);

        if (parentContext.mounted) {
          Navigator.pushNamed(
            parentContext,
            '/permit-dashboard',
            arguments: {
              'userType': userType,
              'userProfile': userProfile ?? '',
              'permitType': type,
              'userName': userName ?? '',
              'questions': questions,
              'forms': forms,
            },
          );
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPerguntasPorTipo(
    String tipoFormulario,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    return [
      {
        "id": 1,
        "pergunta": "O evento terá carro de som?",
        "descricao": "Se sim, informe detalhes e anexe a documentação",
        "secretaria": "Infraestrutura",
        "tipo_formulario": tipoFormulario,
        "tipos_resposta": [
          "Sim/Não",
          "Calendário",
          "Anexar Documento",
          "Texto",
        ],
        "status": "ativo",
      },
      {
        "id": 2,
        "pergunta": "Será vendida comida no evento?",
        "descricao": "Requer vistoria da Vigilância Sanitária",
        "secretaria": "Saúde",
        "tipo_formulario": tipoFormulario,
        "tipos_resposta": ["Sim/Não", "Texto"],
        "status": "ativo",
      },
    ];
  }

  Future<List<Map<String, dynamic>>> _fetchUserForms(String userType) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return [
      {
        "formId": 001,
        "user_id": 0012,
        "nome_do_evento": "Evento 1",
        "permitType": "Alvará de Evento",
        "local_evento": "Centro de conferência",
        "data_do_evento": "10/05/2025",
        "status": "aguardando aprovaçoes",
        "perguntas": [
          {
            "id": 001,
            "pergunta": "Vai ter som?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ],
          },
          {
            "id": 002,
            "pergunta": "Vai ter palco?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Meio Ambiente",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
          {
            "id": 003,
            "pergunta": "Vai fechar rua ou desviar transito?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Infraestrutura",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
          {
            "id": 004,
            "pergunta": "Vai ter trio eletrico?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
          {
            "id": 005,
            "pergunta": "Vai ter venda ou servico de alimentação?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
          {
            "id": 006,
            "pergunta": "Solicitar ambulancia?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
        ], // aguardando, aprovado, recusado
      },
      {
        "formId": 002,
        "user_id": 0011,
        "nome_do_evento": "Evento 2",
        "permitType": "Alvará de Evento",
        "local_evento": "Centro de conferência",
        "data_do_evento": "2025-05-20",
        "status": "aguardando",
        "perguntas": [
          {
            "id": 001,
            "pergunta": "Vai ter som?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ],
          },
          {
            "id": 002,
            "pergunta": "Vai ter palco?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Meio Ambiente",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
          {
            "id": 003,
            "pergunta": "Vai fechar rua ou desviar transito?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Infraestrutura",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
          {
            "id": 004,
            "pergunta": "Vai ter trio eletrico?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
          {
            "id": 005,
            "pergunta": "Vai ter venda ou servico de alimentação?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
          {
            "id": 006,
            "pergunta": "Solicitar ambulancia?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
        ], // aguardando, aprovado, recusado
      },
      {
        "formId": 003,
        "user_id": 001,
        "nome_do_evento": "Evento 3",
        "permitType": "Alvará de Evento",
        "local_evento": "Centro de conferência",
        "data_do_evento": "2025-05-20",
        "status": "aguardando aprovaçoes",
        "perguntas": [
          {
            "id": 001,
            "pergunta": "Vai ter som?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ],
          },
          {
            "id": 002,
            "pergunta": "Vai ter palco?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Meio Ambiente",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
          {
            "id": 003,
            "pergunta": "Vai fechar rua ou desviar transito?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Infraestrutura",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
          {
            "id": 004,
            "pergunta": "Vai ter trio eletrico?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
          {
            "id": 005,
            "pergunta": "Vai ter venda ou servico de alimentação?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
          {
            "id": 006,
            "pergunta": "Solicitar ambulancia?",
            "descricao": "Isso requer vistoria da Vigilância Sanitária",
            "secretaria": "Saúde",
            "anexos": ["Anexo 1", "Anexo 2"],
            "data_do_evento": "10/05/2025",
            "local_evento": "Centro de conferência",
            "status": "aguardando aprovaçao",
            "observacoes": [
              {
                "user_type": "Usuario",
                "user_name": "Joaquim",
                "descricao": "texto da Observação 1",
              },
              {
                "user_type": "operador",
                "user_name": "Monica",
                "descricao": "texto da Observação 2",
              },
            ], // Aqui vamos criar logica para aparecer com se fosse um chat
          },
        ], // aguardando, aprovado, recusado
      },
    ];
  }
}
