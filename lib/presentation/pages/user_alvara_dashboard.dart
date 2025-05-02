// import 'dart:math';

import 'package:flutter/material.dart';
import 'package:permit_web_app/widgets/custom_appbar.dart';

import '../../widgets/back_to_services_button.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/detalhes_alvara.dart';

class PermitDashboardPage extends StatelessWidget {
  final String userType;
  final String userProfile;
  final String permitType;
  final List<Map<String, dynamic>> questions;

  const PermitDashboardPage({super.key, required this.userType, required this.userProfile, required this.permitType, required this.questions});

  @override
  Widget build(BuildContext context) {
    double cardWidth = MediaQuery.of(context).size.width * 0.9;
    double cardHeight = MediaQuery.of(context).size.height * 0.15;

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
            // Padding(
            //   padding: const EdgeInsets.all(8.0),
            //   child: Wrap(
            //     spacing: 8,
            //     runSpacing: 8,
            //     alignment: WrapAlignment.center,
            //     children: [
            //       if (userType == 'admin' || userType == 'gestor' || userType == 'operador')
            //         _buildCard('Eventos do Dia', Icons.event, Colors.blue, cardWidth, cardHeight),
                  
            //       _buildCard('Solicitações Pendentes', Icons.pending, Colors.orange, cardWidth, cardHeight),
            //     ],
            //   ),
            // ),
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
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontStyle: FontStyle.italic),
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
                        // Text('2. Após envio da solicitação, verifique a necessidade de:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Minhas Solicitações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context, '/event-permit',
                          arguments: {
                            'userType': userType,
                            'userProfile': userProfile,
                            'permitType': permitType, // ou o tipo que você selecionou
                            'questions': questions, // as perguntas que você buscou
                          },
                        ); // ajuste conforme sua rota
                      },
                      icon: Icon(Icons.add),
                      label: Text('Nova Solicitação'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ), 
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return Card(
                        child: ListTile(
                          title: Text('Solicitação #$index'),
                          subtitle: Text('Status: $index'),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            DetalhesSolicitacao(evento: 'Evento $index', data: 'Data $index', empresa: 'Empresa $index',).show(context);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildCard(String title, IconData icon, Color color, double width, double height) {
  //   return Container(
  //     width: width * 0.45,
  //     height: height,
  //     decoration: BoxDecoration(
  //       color: color,
  //       borderRadius: BorderRadius.circular(12),
  //       boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
  //     ),
  //     child: Center(
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           Icon(icon, size: 30, color: Colors.white),
  //           SizedBox(height: 8),
  //           Text(title, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
  //           Text( '10', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  void _showSolicitacaoDetalhes(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Fechar')),
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
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 14)),
        ),
      ],
    ),
  );
}

}
