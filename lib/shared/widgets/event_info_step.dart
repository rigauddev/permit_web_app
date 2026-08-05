import 'package:flutter/material.dart';

class EventInfoStep extends StatelessWidget {
  final TextEditingController eventNameController;
  final TextEditingController dateController;
  final TextEditingController locationController;
  final TextEditingController publicSizeController;
  final TextEditingController timeController;
  final GlobalKey<FormState> formKey;

  const EventInfoStep({
    super.key,
    required this.eventNameController,
    required this.dateController,
    required this.locationController,
    required this.publicSizeController,
    required this.timeController,
    required this.formKey,
    required controller,
  });

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Preencha o campo "$label"';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            label: 'Nome do Evento',
            controller: eventNameController,
          ),
          _buildTextField(label: 'Data do Evento', controller: dateController),
          _buildTextField(
            label: 'Local do Evento',
            controller: locationController,
          ),
          _buildTextField(
            label: 'Tamanho do Público',
            controller: publicSizeController,
          ),
          _buildTextField(
            label: 'Horário do Evento',
            controller: timeController,
          ),
        ],
      ),
    );
  }
}
