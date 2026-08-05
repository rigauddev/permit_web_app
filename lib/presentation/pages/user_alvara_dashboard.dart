import 'package:flutter/material.dart';
import '../../features/permit_request/pages/permit_request_page.dart';
import '../../shared/widgets/back_to_services_button.dart';
import '../../shared/widgets/chat_comentarios.dart';
import '../../shared/widgets/custom_drawer.dart';

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
      // appBar: CustomAppBar(title: 'Alvará', actions: []),
      appBar: AppBar(title: Text('Alvará')),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8,
              ),
              child: ExpansionTile(
                title: Text(
                  'O que preciso para solicitar um alvará para evento?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4,
                    ),
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
                        _buildBullet(
                          'Nome do solicitante / Responsável pelo evento',
                        ),
                        _buildBullet('CPF'),
                        _buildBullet('Endereço residencial'),
                        _buildBullet('Telefone de contato'),
                        _buildBullet('Nome do evento'),
                        _buildBullet('Data, local e horário do evento'),
                        _buildBullet('Expectativa de público'),
                        SizedBox(height: 8),
                        Text(
                          'Documentos obrigatórios:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        _buildBullet('Foto ou cópia do RG e CPF'),
                        _buildBullet('Comprovante de residência'),
                        _buildBullet('Alvará de funcionamento do local'),
                        SizedBox(height: 8),
                        _buildBullet(
                          'Termo de Responsabilidade Ambiental (Meio Ambiente)',
                        ),
                        _buildBullet(
                          'Vistoria de palco/gerador (Infraestrutura)',
                        ),
                        _buildBullet(
                          'Vistoria de trio elétrico e motorista + mapa do circuito (DMTRAN)',
                        ),
                        _buildBullet(
                          'Autorização para uso/bloqueio de vias públicas (DMTRAN)',
                        ),
                        _buildBullet(
                          'Vistoria da alimentação (Vigilância Sanitária)',
                        ),
                        _buildBullet(
                          'Ofício à Guarda Civil Municipal, se necessário',
                        ),
                        _buildBullet('Contratação de brigadista, se exigido'),
                        SizedBox(height: 8),
                        Text(
                          'Após todas as autorizações, realizar o pagamento do DAM na Receita Municipal para emissão da Licença/Alvará.',
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Observação: Eventos beneficentes são isentos do pagamento, mas devem encaminhar uma declaração com a instituição beneficiada.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.red,
                          ),
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => PermitRequestPage(
                                    userType: userType,
                                    userProfile: userProfile,
                                    permitType: permitType,
                                    questions:
                                        questions, // Sua lista vinda do backend
                                  ),
                            ),
                          );
                        },
                        icon: Icon(Icons.add),
                        label: Text('Nova Solicitação'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
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
                      // LISTVIEW COM OS DADOS
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: forms.length,
                        itemBuilder: (context, index) {
                          final form = forms[index];

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 12,
                              ),
                              child: ExpansionTile(
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        form['nome_do_evento'] ?? 'Evento',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        form['data_do_evento'] ?? 'Data',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        form['status'] ?? 'Status',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: _getStatusColor(
                                            form['status'],
                                          ),
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),

                                children: [
                                  // Cabeçalho
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: const [
                                        Expanded(
                                          child: Text(
                                            'Pergunta',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Secretaria',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Status',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            'Detalhes',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(),
                                  // Linha para cada pergunta
                                  ...((form['perguntas'] as List<dynamic>?) ??
                                          [])
                                      .map<Widget>((q) {
                                        final pergunta = q['pergunta'] ?? '';
                                        final secretaria =
                                            q['secretaria'] ?? '';
                                        final statusText = q['status'] ?? '';
                                        final observacoes =
                                            q['observacoes'] ?? '';

                                        // Define cor de acordo com o status
                                        Color statusColor;
                                        switch (statusText.toLowerCase()) {
                                          case 'aprovado':
                                            statusColor = Colors.green;
                                            break;
                                          case 'aguardando aprovação':
                                          case 'aguardando aprovaçao':
                                          case 'aguardando':
                                            statusColor = Colors.deepOrange;
                                            break;
                                          case 'recusado':
                                            statusColor = Colors.red;
                                            break;
                                          default:
                                            statusColor = Colors.black;
                                        }

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4.0,
                                            horizontal: 16,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: Text(pergunta)),
                                              const SizedBox(width: 8),
                                              Expanded(child: Text(secretaria)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  statusText,
                                                  style: TextStyle(
                                                    color: statusColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width: 80,
                                                child: TextButton(
                                                  onPressed:
                                                      observacoes.isEmpty
                                                          ? null
                                                          : () =>
                                                              _openChatObservacoes(
                                                                context,
                                                                q
                                                                    as Map<
                                                                      String,
                                                                      dynamic
                                                                    >,
                                                              ),
                                                  child: Text(
                                                    observacoes.isEmpty
                                                        ? '—'
                                                        : 'Ver',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChatObservacoes(
    BuildContext context,
    Map<String, dynamic> pergunta,
  ) {
    final observacoes = pergunta['observacoes'] as List<dynamic>? ?? [];
    final anexosExistentes = List<String>.from(pergunta['anexos'] ?? []);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (ctx, scrollCtrl) {
            return ChatObservacoesWidget(
              perguntaId: pergunta['id'].toString(),
              observacoes: observacoes,
              anexosExistentes: anexosExistentes,
              scrollController: scrollCtrl,
              userType: '',
            );
          },
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
          Text("• ", style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

Color _getStatusColor(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'aprovado':
      return Colors.green;
    case 'aguardando':
    case 'aguardando aprovação':
    case 'aguardando aprovaçao':
      return Colors.amber;
    case 'recusado':
      return Colors.red;
    default:
      return Colors.black;
  }
}
