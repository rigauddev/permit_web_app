import 'package:flutter/material.dart';
import '../widgets/detalhes_alvara.dart';

class SolicitacoesList extends StatelessWidget {
  const SolicitacoesList({super.key, required String evento, required String data, required String empresa});

  void _mostrarDetalhes(BuildContext context, String evento, String data, String empresa) {
    showDialog(
      context: context,
      builder: (context) => DetalhesSolicitacao(evento: evento, data: data, empresa: empresa),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Solicitações de Alvará", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildSolicitacao(context, 'Evento 001', '20/12/2025', 'Secretaria de Transporte, aguardando aprovação'),
                _buildSolicitacao(context, 'Evento 002', '22/12/2025', 'Secretaria de Segurança, pendente de aprovação'),
                _buildSolicitacao(context, 'Evento 003', '25/12/2025', 'Secretaria de Cultura, aprovado'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitacao(BuildContext context, String evento, String data, String empresa) {
    return ListTile(
      title: Text(evento),
      subtitle: Text("Data: $data\nEmpresa: $empresa"),
      trailing: IconButton(
        icon: const Icon(Icons.info, color: Colors.blue),
        onPressed: () => _mostrarDetalhes(context, evento, data, empresa),
      ),
    );
  }
}
