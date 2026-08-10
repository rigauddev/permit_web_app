import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/permit_api_service.dart';
import '../../core/session_expiration.dart';
import '../../shared/widgets/app_scaffold.dart';
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
    return AppScaffold(
      userType: widget.userType,
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
                      onAttachPaymentProof: _attachPaymentProof,
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
        builder:
            (_) => EventCredentialPage(
              permitForm: request,
              userType: widget.userType,
            ),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _attachPaymentProof(Map<String, dynamic> request) async {
    final attachment = await _askAttachment(
      title: 'Anexar comprovante',
      description:
          'Anexe o comprovante de pagamento do seu DAM. Pagamento em PIX até 24h para geração do alvará, ou boleto com prazo de 72h para confirmação e emissão.',
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (attachment == null) return;
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      final requestId = request['formId'] as int? ?? request['id'] as int?;
      if (requestId == null) return;
      await _api.attachDamPaymentProof(
        accessToken: token,
        requestId: requestId,
        fileName: attachment.fileName,
        fileUrl: attachment.fileUrl,
        mimeType: attachment.mimeType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Comprovante anexado. Solicitação em aguardando confirmação de pagamento.',
          ),
        ),
      );
      _refresh();
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<_AttachmentInput?> _askAttachment({
    required String title,
    required String description,
    required List<String> allowedExtensions,
  }) {
    final fileController = TextEditingController();
    final urlController = TextEditingController();
    final mimeController = TextEditingController(text: 'application/pdf');
    return showDialog<_AttachmentInput>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description),
                const SizedBox(height: 12),
                TextField(
                  controller: fileController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do arquivo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL ou referência do arquivo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: allowedExtensions,
                    );
                    final file =
                        result == null || result.files.isEmpty
                            ? null
                            : result.files.single;
                    if (file == null) return;
                    fileController.text = file.name;
                    urlController.text = file.path ?? file.name;
                    final extension = file.name.split('.').last.toLowerCase();
                    mimeController.text =
                        extension == 'pdf'
                            ? 'application/pdf'
                            : extension == 'png'
                            ? 'image/png'
                            : 'image/jpeg';
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Selecionar arquivo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mimeController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo MIME',
                    helperText: 'Use application/pdf, image/jpeg ou image/png',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final fileName = fileController.text.trim();
                  final fileUrl = urlController.text.trim();
                  final mimeType = mimeController.text.trim();
                  final extension = fileName.split('.').last.toLowerCase();

                  if (fileName.length < 3 || fileUrl.length < 3) return;
                  if (!allowedExtensions.contains(extension)) return;
                  if (mimeType.isEmpty) return;

                  Navigator.pop(
                    context,
                    _AttachmentInput(
                      fileName: fileName,
                      fileUrl: fileUrl,
                      mimeType: mimeType,
                    ),
                  );
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Enviar comprovante'),
              ),
            ],
          ),
    );
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
    required this.onAttachPaymentProof,
    required this.onOpenCredential,
  });

  final String title;
  final String serviceName;
  final String description;
  final List<Map<String, dynamic>> requests;
  final ValueChanged<Map<String, dynamic>> onAttachPaymentProof;
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
                  onAttachPaymentProof: onAttachPaymentProof,
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
    required this.onAttachPaymentProof,
    required this.onOpenCredential,
  });

  final Map<String, dynamic> request;
  final ValueChanged<Map<String, dynamic>> onAttachPaymentProof;
  final ValueChanged<Map<String, dynamic>> onOpenCredential;

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? 'enviada';
    final canOpenCredential =
        status == 'autorizada' ||
        status == 'isenta_dam' ||
        (request['credentials'] as List<dynamic>? ?? const []).isNotEmpty;
    final canAttachPayment = status == 'aguardando_pagamento_dam';
    final verified = _isCredentialVerified(request);

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
            if (verified)
              const Chip(
                avatar: Icon(Icons.verified, size: 16),
                label: Text('Verificado'),
              ),
            if (canAttachPayment)
              IconButton(
                tooltip: 'Anexar comprovante do DAM',
                onPressed: () => onAttachPaymentProof(request),
                icon: const Icon(Icons.upload_file),
              ),
            if (canOpenCredential)
              IconButton(
                tooltip: verified ? 'Evento verificado' : 'Validar evento',
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
      case 'aguardando_geracao_dam':
        return 'Aguardando geração do DAM';
      case 'aguardando_pagamento_dam':
        return 'Aguardando pagamento do DAM';
      case 'aguardando_geracao_alvara':
        return 'Aguardando geração do alvará';
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

  static bool _isCredentialVerified(Map<String, dynamic> request) {
    final credentials = request['credentials'] as List<dynamic>? ?? const [];
    return credentials.any((credential) {
      if (credential is! Map<String, dynamic>) return false;
      final count = credential['verification_count'];
      final verifiedAt = credential['verified_at'];
      return verifiedAt != null ||
          (count is int && count > 0) ||
          (count is String &&
              int.tryParse(count) != null &&
              int.parse(count) > 0);
    });
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

class _AttachmentInput {
  const _AttachmentInput({
    required this.fileName,
    required this.fileUrl,
    this.mimeType,
  });

  final String fileName;
  final String fileUrl;
  final String? mimeType;
}
