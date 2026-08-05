import 'package:flutter/material.dart';
import 'package:permit_web_app/widgets/custom_appbar.dart';
import '../../widgets/back_to_services_button.dart';
import '../../widgets/custom_drawer.dart';

class PermitDashboardPage extends StatelessWidget {
  final String userType;
  final String userProfile;
  final String permitType;
  final List<Map<String, dynamic>> questions;
  final List<Map<String, dynamic>> forms;

  const PermitDashboardPage({
    super.key,
    required this.userType,
    required this.userProfile,
    required this.permitType,
    required this.questions,
    required this.forms,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Alvará', actions: []),
      drawer: CustomDrawer(userType: userType),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BackNavigationButton(
              route: '/services',
              label: 'Voltar para Serviços',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
              child: ExpansionTile(
                title: Text(
                  'O que preciso para solicitar um alvará para evento?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solicitar o alvará com pelo menos 15 dias de antecedência!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        SizedBox(height: 4),
                        _buildBullet('Nome do solicitante / Responsável pelo evento'),
                        _buildBullet('CPF'),
                        _buildBullet('Endereço residencial'),
                        _buildBullet('Telefone de contato'),
                        _buildBullet('Nome do evento'),
                        _buildBullet('Data, local e horário do evento'),
                        _buildBullet('Expectativa de público'),
                        SizedBox(height: 8),
                        Text('Documentos obrigatórios:', style: TextStyle(fontWeight: FontWeight.bold)),
                        _buildBullet('Foto ou cópia do RG e CPF'),
                        _buildBullet('Comprovante de residência'),
                        _buildBullet('Alvará de funcionamento do local'),
                        SizedBox(height: 8),
                        _buildBullet('Termo de Responsabilidade Ambiental (Meio Ambiente)'),
                        _buildBullet('Vistoria de palco/gerador (Infraestrutura)'),
                        _buildBullet('Vistoria de trio elétrico e motorista + mapa do circuito (DMTRAN)'),
                        _buildBullet('Autorização para uso/bloqueio de vias públicas (DMTRAN)'),
                        _buildBullet('Vistoria da alimentação (Vigilância Sanitária)'),
                        _buildBullet('Ofício à Guarda Civil Municipal, se necessário'),
                        _buildBullet('Contratação de brigadista, se exigido'),
                        SizedBox(height: 8),
                        Text(
                          'Após todas as autorizações, realizar o pagamento do DAM na Receita Municipal para emissão da Licença/Alvará.',
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Observação: Eventos beneficentes são isentos do pagamento, mas devem encaminhar uma declaração com a instituição beneficiada.',
                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.red),
                        ),
                        SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Minhas Solicitações',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/event-permit',
                            arguments: {
                              'userType': userType,
                              'userProfile': userProfile,
                              'permitType': permitType,
                              'questions': questions,
                              'forms': forms,
                            },
                          );
                        },
                        icon: Icon(Icons.add),
                        label: Text('Nova Solicitação'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER personalizado com campos mapeados
                      // Card(
                      //   color: Colors.grey[200],
                      //   margin: const EdgeInsets.symmetric(vertical: 8),
                      //   child: Padding(
                      //     padding: const EdgeInsets.all(12.0),
                      //     child: Row(
                      //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //       children: const [
                      //         Expanded(child: Text("Evento", style: TextStyle(fontWeight: FontWeight.bold))),
                      //         Expanded(child: Text("Data", style: TextStyle(fontWeight: FontWeight.bold))),
                      //         Expanded(child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
                      //         // Text("Ações", style: TextStyle(fontWeight: FontWeight.bold)),
                      //       ],
                      //     ),
                      //   ),
                      // ),
                      
                      // LISTVIEW COM OS DADOS
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: forms.length,
                        itemBuilder: (context, index) {
                          final form = forms[index];
                          final status = form['status'] ?? 'pendente';
                          Color statusColor;
                          if (status == 'aprovado') {
                            statusColor = Colors.green;
                          } else if (status == 'pendente') {
                            statusColor = Colors.amber;
                          } else {
                            statusColor = Colors.red;
                          }

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12),
                              child: ExpansionTile(title: Text(form['formId'] ?? 'N/A'),
                              subtitle: Text(form['data_do_evento'] ?? 'N/A'), 
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(form['data_do_evento'] ?? 'N/A')),
                                    Expanded(
                                      child: Text(
                                        status,
                                        style: TextStyle(color: statusColor),
                                      ),
                                    ),
                                    // IconButton(
                                    //   icon: const Icon(Icons.arrow_downward_outlined, color: Colors.blue),
                                    //   onPressed: () => _showSolicitacaoDetalhes(context, form),
                                    // ),
                                  ],
                                ),
                              ]),
                              // child: Row(
                              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              //   children: [
                              //     Expanded(child: Text(form['formId'] ?? 'N/A')),
                              //     Expanded(child: Text(form['data_do_evento'] ?? 'N/A')),
                              //     Expanded(
                              //       child: Text(
                              //         status, ),
                              //     )
                              //     // Expanded(
                              //     //   child: TextButton(
                              //     //     onPressed: () => _showStatusDetalhes(context, form),
                              //     //     child: Text(
                              //     //       status,
                              //     //       style: TextStyle(color: statusColor),
                              //     //     ),
                              //     //   ),
                              //     // ),
                              //     // IconButton(
                              //     //   icon: const Icon(Icons.arrow_downward_outlined, color: Colors.blue),
                              //     //   onPressed: () => _showSolicitacaoDetalhes(context, form),
                              //     // ),
                              //   ],
                              // ),
                            ),
                          );
                        },
                      ),
                    ],
                  )

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSolicitacaoDetalhes(BuildContext context, Map<String, dynamic> form) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Detalhes da Solicitação'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Evento: ${form['nome_do_evento']}'),
              Text('Data: ${form['data_do_evento']}'),
              Text('Local: ${form['local_evento']}'),
              Text('Status: ${form['status']}'),
              // Adicione mais campos se quiser
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  void _showStatusDetalhes(BuildContext context, Map<String, dynamic> form) {
    final List<dynamic> perguntas = form['perguntas'] ?? [];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Detalhes do Status - ${form['formId']}'),
          content: SizedBox(
            // limita altura para rolagem, caso muitas perguntas
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho da "tabela"
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Pergunta', style: TextStyle(fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Orgão responsável', style: TextStyle(fontWeight: FontWeight.bold))),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('status', style: TextStyle(fontWeight: FontWeight.bold))),
                        const Text('Observações', style: TextStyle(fontWeight: FontWeight.bold)),                        
                      ],
                    ),
                  ),
                  const Divider(),

                  // Para cada pergunta, uma "linha"
                  ...perguntas.map<Widget>((q) {
                    final pergunta = q['pergunta'] ?? '';
                    final secretaria = q['secretaria'] ?? '';
                    final status = q['status'] ?? '';
                    final observacoes = q['observacoes'] ?? '';

                    // define cor do texto de status
                    Color statusColor;
                    switch (status.toLowerCase()) {
                      case 'aprovado':
                        statusColor = Colors.green;
                        break;
                      case 'aguardando aprovação':
                      case 'aguardando aprovaçao':
                      case 'aguardando':
                        statusColor = Colors.amber;
                        break;
                      case 'recusado':
                        statusColor = Colors.red;
                        break;
                      default:
                        statusColor = Colors.black;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(pergunta)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(secretaria)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(status)),
                          const SizedBox(width: 8),
                          TextButton.icon(onPressed: () => _showObservacoesDetalhes(context, q as Map<String, dynamic>), label: observacoes.isEmpty ? const Text('Sem Observação') : const Text('Observações')),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }


  void _showObservacoesDetalhes(BuildContext context, Map<String, dynamic> form) {
    final List<dynamic> perguntas = form['perguntas'] ?? [];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Observações da Solicitação - ${form['formId']}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: perguntas.map<Widget>((q) {
                final observacoes = q['observacoes'] ?? '';
                return _buildBullet(observacoes);
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• ", style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
