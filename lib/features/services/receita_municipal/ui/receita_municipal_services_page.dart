import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/permit_api_service.dart';
import '../../../../shared/widgets/custom_drawer.dart';

class ReceitaMunicipalServicesPage extends StatefulWidget {
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
  State<ReceitaMunicipalServicesPage> createState() =>
      _ReceitaMunicipalServicesPageState();
}

class _ReceitaMunicipalServicesPageState
    extends State<ReceitaMunicipalServicesPage> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Serviços da Receita Municipal')),
      drawer: CustomDrawer(userType: widget.userType),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Alvará de Evento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Solicite autorização para eventos no município com análise das secretarias responsáveis.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _openEventPermit,
                        icon: const Icon(Icons.assignment),
                        label: Text(_loading ? 'Carregando...' : 'Acessar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEventPermit() async {
    setState(() => _loading = true);
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        throw PermitApiException('Sessão expirada. Faça login novamente.');
      }

      final forms = await PermitApiService().listRequests(token);
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/permit-dashboard',
        arguments: {
          'userType': widget.userType,
          'userProfile': widget.userProfile ?? '',
          'permitType': 'Alvará de Evento',
          'userName': widget.userName ?? '',
          'questions': PermitApiService.eventPermitQuestions,
          'forms': forms,
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
