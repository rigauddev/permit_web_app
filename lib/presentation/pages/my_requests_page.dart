import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/permit_api_service.dart';
import '../../core/session_expiration.dart';
import '../../shared/widgets/custom_drawer.dart';
import 'event_credential_page.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key, required this.userType});

  final String userType;

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  final _storage = const FlutterSecureStorage();
  final _api = PermitApiService();
  late Future<List<Map<String, dynamic>>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = _loadRequests();
  }

  Future<List<Map<String, dynamic>>> _loadRequests() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      if (mounted) await SessionExpiration.logout(context);
      return const [];
    }
    try {
      return await _api.listRequests(token);
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return const [];
      }
      rethrow;
    }
  }

  void _refresh() {
    setState(() {
      _requestsFuture = _loadRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas solicitações'),
        actions: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => _goBack(context),
            icon: const Icon(Icons.arrow_back),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: CustomDrawer(userType: widget.userType),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final requests = snapshot.data ?? const <Map<String, dynamic>>[];
          final grouped = _groupByType(requests);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Acompanhamento por tipo de serviço',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Aqui ficam separadas as solicitações feitas por você. Neste MVP, o serviço ativo é Alvará de Evento.',
                    ),
                    const SizedBox(height: 18),
                    _RequestTypeSection(
                      title: 'Alvarás',
                      serviceName: 'Alvará de Evento',
                      description:
                          'Autorizações municipais para festas e eventos, com análise das secretarias responsáveis.',
                      requests: grouped['Alvará de Evento'] ?? const [],
                      onOpenCredential: _openCredential,
                    ),
                    const SizedBox(height: 14),
                    const _FutureTypeSection(
                      title: 'Outros serviços municipais',
                      description:
                          'Novos tipos de solicitação aparecerão aqui em versões futuras, agrupados por secretaria e categoria.',
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCredential(Map<String, dynamic> request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventCredentialPage(permitForm: request),
      ),
    );
    if (mounted) _refresh();
  }

  static Map<String, List<Map<String, dynamic>>> _groupByType(
    List<Map<String, dynamic>> requests,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final request in requests) {
      final type = request['permitType'] as String? ?? 'Outros';
      grouped.putIfAbsent(type, () => []).add(request);
    }
    return grouped;
  }

  static void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}

class _RequestTypeSection extends StatelessWidget {
  const _RequestTypeSection({
    required this.title,
    required this.serviceName,
    required this.description,
    required this.requests,
    required this.onOpenCredential,
  });

  final String title;
  final String serviceName;
  final String description;
  final List<Map<String, dynamic>> requests;
  final ValueChanged<Map<String, dynamic>> onOpenCredential;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(serviceName),
                    ],
                  ),
                ),
                Chip(label: Text('${requests.length}')),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 12),
            if (requests.isEmpty)
              const Text('Você ainda não possui solicitações deste tipo.')
            else
              ...requests.map(
                (request) => _RequestListTile(
                  request: request,
                  onOpenCredential: onOpenCredential,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestListTile extends StatelessWidget {
  const _RequestListTile({
    required this.request,
    required this.onOpenCredential,
  });

  final Map<String, dynamic> request;
  final ValueChanged<Map<String, dynamic>> onOpenCredential;

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? 'enviada';
    final canOpenCredential =
        status == 'autorizada' ||
        status == 'isenta_dam' ||
        (request['credentials'] as List<dynamic>? ?? const []).isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        leading: const Icon(Icons.event_note_outlined),
        title: Text(request['nome_do_evento']?.toString() ?? 'Evento'),
        subtitle: Text(
          [
            'Protocolo: ${request['protocolo'] ?? '-'}',
            'Data: ${request['data_do_evento'] ?? '-'}',
            'Tipo: ${request['permitType'] ?? 'Alvará de Evento'}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Chip(label: Text(_formatStatus(status))),
            if (canOpenCredential)
              IconButton(
                tooltip: 'Ver autorização',
                onPressed: () => onOpenCredential(request),
                icon: const Icon(Icons.qr_code_2),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatStatus(String status) {
    switch (status) {
      case 'em_analise':
        return 'Em análise';
      case 'dam_pendente':
        return 'DAM pendente';
      case 'autorizada':
        return 'Autorizada';
      case 'recusada':
        return 'Recusada';
      case 'correcao_solicitada':
        return 'Correção solicitada';
      default:
        return status;
    }
  }
}

class _FutureTypeSection extends StatelessWidget {
  const _FutureTypeSection({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.more_horiz),
        title: Text(title),
        subtitle: Text(description),
      ),
    );
  }
}
