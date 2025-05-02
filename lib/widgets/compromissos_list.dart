import 'package:flutter/material.dart';

class CompromissosList extends StatelessWidget {
  final DateTime selectedDate;

  const CompromissosList({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Compromissos do Dia", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildCompromisso("Reunião de Segurança", "09:00"),
                _buildCompromisso("Evento Comunitário", "15:00"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompromisso(String titulo, String hora) {
    return ListTile(
      leading: const Icon(Icons.event, color: Colors.blue),
      title: Text(titulo),
      subtitle: Text("Horário: $hora"),
    );
  }
}
