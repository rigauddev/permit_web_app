// // lib/pages/permit_request/permit_request_page.dart
// import 'package:flutter/material.dart';

// import '../../presentation/pages/permit_request_page.dart';
// import '../../widgets/custom_appbar.dart';
// import '../../widgets/custom_drawer.dart';
// import '../../widgets/personal_info_step.dart';
// import '../../widgets/event_info_step.dart';
// import '../../widgets/question_step.dart';
// // import '../../presentation/controllers/permit_request_controller.dart';

// class PermitRequestPage extends StatefulWidget {
//   final String userType;
//   final String userProfile;
//   final String permitType;
//   final List<Map<String, dynamic>> questions;

//   const PermitRequestPage({
//     super.key,
//     required this.userType,
//     required this.userProfile,
//     required this.permitType,
//     required this.questions,
//   });

//   @override
//   State<PermitRequestPage> createState() => _PermitRequestPageState();
// }

// class _PermitRequestPageState extends State<PermitRequestPage> {
//   final _formKey = GlobalKey<FormState>();
//   final PermitRequestController _controller = PermitRequestController();
//   int _currentStep = 0;

//   @override
//   void initState() {
//     super.initState();
//     _controller.initialize(widget.questions, widget.permitType);
//   }

//   void _nextStep() {
//     if (_formKey.currentState!.validate()) {
//       if (_currentStep < 2) {
//         setState(() => _currentStep++);
//       } else {
//         _controller.submitRequest(context);
//       }
//     }
//   }

//   void _previousStep() {
//     if (_currentStep > 0) {
//       setState(() => _currentStep--);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: CustomAppBar(title: 'Solicitação de ${widget.permitType}', actions: []),
//       drawer: CustomDrawer(userType: widget.userType, userProfile: widget.userProfile),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Center(
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 700),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     _controller.stepTitles[_currentStep],
//                     style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 16),
//                   if (_currentStep == 0) PersonalInfoStep(controller: _controller),
//                   if (_currentStep == 1) EventInfoStep(controller: _controller),
//                   if (_currentStep == 2) QuestionStep(controller: _controller),
//                   const SizedBox(height: 32),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       if (_currentStep > 0)
//                         OutlinedButton(
//                           onPressed: _previousStep,
//                           style: OutlinedButton.styleFrom(
//                             side: BorderSide(color: Theme.of(context).colorScheme.primary),
//                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                           ),
//                           child: const Text('Voltar'),
//                         ),
//                       ElevatedButton(
//                         onPressed: _nextStep,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Theme.of(context).colorScheme.primary,
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                           padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                         ),
//                         child: Text(_currentStep == 2 ? 'Enviar' : 'Avançar'),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
