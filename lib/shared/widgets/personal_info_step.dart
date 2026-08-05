import 'package:flutter/material.dart';

class PersonalInfoStep extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController cpfController;
  final TextEditingController addressController;
  final TextEditingController phoneController;
  final GlobalKey<FormState> formKey;

  const PersonalInfoStep({
    super.key,
    required this.nameController,
    required this.cpfController,
    required this.addressController,
    required this.phoneController,
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
          _buildTextField(label: 'Nome', controller: nameController),
          _buildTextField(label: 'CPF', controller: cpfController),
          _buildTextField(label: 'Endereço', controller: addressController),
          _buildTextField(label: 'Telefone', controller: phoneController),
        ],
      ),
    );
  }
}
