import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/user_provider.dart';
import '../controller/permit_request_controller.dart';
import '../widgets/question_field_widget.dart';

class PermitRequestFormBuilder extends ConsumerStatefulWidget {
  const PermitRequestFormBuilder({super.key});

  @override
  ConsumerState<PermitRequestFormBuilder> createState() =>
      _PermitRequestFormBuilderState();
}

class _PermitRequestFormBuilderState
    extends ConsumerState<PermitRequestFormBuilder> {
  late TextEditingController nomeController;
  late TextEditingController cpfCnpjController;
  late TextEditingController addressController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  late TextEditingController eventDateController;
  late TextEditingController eventNameController;
  late TextEditingController eventAddressController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(permitRequestControllerProvider);
    final user = ref.read(userProvider); // ← Pega o usuário logado

    nomeController = TextEditingController(
      text: user?.name ?? state.answers[-1] ?? '',
    );
    cpfCnpjController = TextEditingController(
      text: user?.cpfCnpj ?? state.answers[-2] ?? '',
    );
    addressController = TextEditingController(
      text: user?.address ?? state.answers[-5] ?? '',
    );
    emailController = TextEditingController(
      text: user?.email ?? state.answers[-5] ?? '',
    );
    phoneController = TextEditingController(
      text: user?.phone ?? state.answers[-6] ?? '',
    );

    eventNameController = TextEditingController(text: state.answers[-3] ?? '');
    eventDateController = TextEditingController(text: state.answers[-4] ?? '');
    eventAddressController = TextEditingController(
      text: state.answers[-5] ?? state.answers[-5] ?? '',
    );
  }

  @override
  void dispose() {
    nomeController.dispose();
    cpfCnpjController.dispose();
    addressController.dispose();
    phoneController.dispose();
    emailController.dispose();

    eventNameController.dispose();
    eventDateController.dispose();
    eventAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(permitRequestControllerProvider);
    final controller = ref.read(permitRequestControllerProvider.notifier);

    if (state.currentStep == 0) {
      return Column(
        children: [
          TextFormField(
            controller: nomeController,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Informe seu nome',
            ),
            onChanged: (value) => controller.updateBasicInfo(name: value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: cpfCnpjController,
            decoration: const InputDecoration(labelText: 'CPF'),
            onChanged: (value) => controller.updateBasicInfo(cpfCnpj: value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneController,
            decoration: const InputDecoration(labelText: 'Telefone'),
            onChanged: (value) => controller.updateBasicInfo(phone: value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            onChanged: (value) => controller.updateBasicInfo(email: value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: addressController,
            decoration: const InputDecoration(labelText: 'Endereço'),
            onChanged: (value) => controller.updateBasicInfo(address: value),
          ),
        ],
      );
    } else if (state.currentStep == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Anexos de Documentação',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: true,
                type: FileType.custom,
                allowedExtensions: ['pdf', 'jpg', 'png'],
              );
              if (result != null) {
                controller.addAttachments(result.files);
              }
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Selecionar arquivos'),
          ),
          const SizedBox(height: 10),
          ...state.attachments.map(
            (file) => ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: Text(file.name),
            ),
          ),
        ],
      );
    } else if (state.currentStep == 2) {
      return Column(
        children: [
          TextFormField(
            controller: eventNameController,
            decoration: const InputDecoration(labelText: 'Nome do Evento'),
            onChanged: (value) => controller.updateEventInfo(eventName: value),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: eventDateController,
            decoration: const InputDecoration(labelText: 'Data'),
            onChanged: (value) => controller.updateEventInfo(eventDate: value),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: eventAddressController,
            decoration: const InputDecoration(labelText: 'Endereço do Evento'),
            onChanged:
                (value) => controller.updateEventInfo(eventAddress: value),
          ),
        ],
      );
    } else if (state.currentStep >= 3) {
      final questionIndex = state.currentStep - 2;
      if (questionIndex < state.questions.length) {
        final question = state.questions[questionIndex];
        final questionId = question['id'] as int;
        final questionText = question['pergunta'] as String;
        final tiposResposta = List<String>.from(
          question['tipos_resposta'] ?? [],
        );

        return QuestionFieldWidget(
          questionId: questionId,
          questionText: questionText,
          tiposResposta: tiposResposta,
          onChanged: (value) => controller.updateAnswer(questionId, value),
          currentValue: state.answers[questionId],
        );
      }
    }
    return const SizedBox();
  }
}
