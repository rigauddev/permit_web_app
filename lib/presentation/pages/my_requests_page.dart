import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

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
                      onOpenDetails: _openRequestDetails,
                      onCancelRequest: _cancelRequest,
                      onAttachPaymentProof: _attachPaymentProof,
                      onOpenCredential: _openCredential,
                      onOpenAttachment: _openAttachment,
                      onShareAttachment: _shareAttachment,
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

  Future<void> _openRequestDetails(Map<String, dynamic> request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => _RequestDetailsPage(
              request: request,
              userType: widget.userType,
              onAttachPaymentProof: _attachPaymentProof,
              onCancelRequest: _cancelRequest,
              onOpenCredential: _openCredential,
              onOpenAttachment: _openAttachment,
              onShareAttachment: _shareAttachment,
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

  Future<void> _cancelRequest(Map<String, dynamic> request) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancelar solicitação'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Após cancelar, esta solicitação ficará encerrada e não seguirá para análise.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Motivo (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Voltar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Cancelar solicitação'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      final requestId = request['formId'] as int? ?? request['id'] as int?;
      if (requestId == null) return;
      await _api.cancelRequest(
        accessToken: token,
        requestId: requestId,
        motivo: reasonController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solicitação cancelada.')));
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

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    final rawUrl = attachment['arquivo_url']?.toString() ?? '';
    if (rawUrl.isEmpty) return;
    final url = _api.resolveFileUrl(rawUrl);
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o arquivo.')),
      );
    }
  }

  Future<void> _shareAttachment(Map<String, dynamic> attachment) async {
    final rawUrl = attachment['arquivo_url']?.toString() ?? '';
    if (rawUrl.isEmpty) return;
    final url = _api.resolveFileUrl(rawUrl);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referência do alvará copiada para compartilhamento.'),
      ),
    );
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
    required this.onOpenDetails,
    required this.onCancelRequest,
    required this.onAttachPaymentProof,
    required this.onOpenCredential,
    required this.onOpenAttachment,
    required this.onShareAttachment,
  });

  final String title;
  final String serviceName;
  final String description;
  final List<Map<String, dynamic>> requests;
  final ValueChanged<Map<String, dynamic>> onOpenDetails;
  final ValueChanged<Map<String, dynamic>> onCancelRequest;
  final ValueChanged<Map<String, dynamic>> onAttachPaymentProof;
  final ValueChanged<Map<String, dynamic>> onOpenCredential;
  final ValueChanged<Map<String, dynamic>> onOpenAttachment;
  final ValueChanged<Map<String, dynamic>> onShareAttachment;

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
                  onOpenDetails: onOpenDetails,
                  onCancelRequest: onCancelRequest,
                  onAttachPaymentProof: onAttachPaymentProof,
                  onOpenCredential: onOpenCredential,
                  onOpenAttachment: onOpenAttachment,
                  onShareAttachment: onShareAttachment,
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
    required this.onOpenDetails,
    required this.onCancelRequest,
    required this.onAttachPaymentProof,
    required this.onOpenCredential,
    required this.onOpenAttachment,
    required this.onShareAttachment,
  });

  final Map<String, dynamic> request;
  final ValueChanged<Map<String, dynamic>> onOpenDetails;
  final ValueChanged<Map<String, dynamic>> onCancelRequest;
  final ValueChanged<Map<String, dynamic>> onAttachPaymentProof;
  final ValueChanged<Map<String, dynamic>> onOpenCredential;
  final ValueChanged<Map<String, dynamic>> onOpenAttachment;
  final ValueChanged<Map<String, dynamic>> onShareAttachment;

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? 'enviada';
    final canOpenCredential =
        status == 'autorizada' ||
        status == 'isenta_dam' ||
        (request['credentials'] as List<dynamic>? ?? const []).isNotEmpty;
    final canAttachPayment = status == 'aguardando_pagamento_dam';
    final canCancel = _canCancel(status);
    final verified = _isCredentialVerified(request);
    final finalPermit = _finalPermitAttachment(request);

    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onOpenDetails(request),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.event_note_outlined, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['nome_do_evento']?.toString() ?? 'Evento',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text('Protocolo: ${request['protocolo'] ?? '-'}'),
                        Text('Data: ${request['data_do_evento'] ?? '-'}'),
                        Text(
                          'Tipo: ${request['permitType'] ?? 'Alvará de Evento'}',
                        ),
                        if (finalPermit != null)
                          Text(
                            'Alvará: ${finalPermit['nome_arquivo'] ?? 'PDF disponível'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusBadge(status: status),
                  if (verified) const _VerifiedBadge(compact: true),
                  OutlinedButton.icon(
                    onPressed: () => onOpenDetails(request),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ver detalhes'),
                  ),
                  if (canCancel)
                    OutlinedButton.icon(
                      onPressed: () => onCancelRequest(request),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancelar'),
                    ),
                  if (canAttachPayment)
                    OutlinedButton.icon(
                      onPressed: () => onAttachPaymentProof(request),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Comprovante'),
                    ),
                  if (finalPermit != null)
                    IconButton(
                      tooltip: 'Visualizar ou baixar alvará',
                      onPressed: () => onOpenAttachment(finalPermit),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                  if (finalPermit != null)
                    IconButton(
                      tooltip: 'Compartilhar alvará',
                      onPressed: () => onShareAttachment(finalPermit),
                      icon: const Icon(Icons.share_outlined),
                    ),
                  if (canOpenCredential)
                    IconButton(
                      tooltip:
                          verified ? 'Evento verificado' : 'Validar evento',
                      onPressed: () => onOpenCredential(request),
                      icon: const Icon(Icons.qr_code_2),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Map<String, dynamic>? _finalPermitAttachment(
    Map<String, dynamic> request,
  ) {
    final attachments =
        (request['attachments'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>();
    for (final attachment in attachments) {
      if (attachment['tipo_documento'] == 'alvara_evento') {
        return attachment;
      }
    }
    return null;
  }

  static String _formatStatus(String status) {
    switch (status) {
      case 'em_analise':
        return 'Em análise';
      case 'enviada':
        return 'Enviada';
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
      case 'indeferida':
        return 'Indeferida';
      case 'correcao_solicitada':
      case 'pendente_correcao':
        return 'Correção solicitada';
      case 'isenta_dam':
        return 'Isenta de DAM';
      case 'cancelada':
        return 'Cancelada';
      default:
        return status;
    }
  }

  static bool _canCancel(String status) {
    return !{
      'autorizada',
      'isenta_dam',
      'indeferida',
      'cancelada',
    }.contains(status);
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = _RequestListTile._formatStatus(status);
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      'autorizada' || 'isenta_dam' => Colors.green,
      'indeferida' || 'recusada' || 'cancelada' => Colors.red,
      'pendente_correcao' || 'correcao_solicitada' => Colors.orange,
      _ => colorScheme.primary,
    };
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Colors.green.shade700;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: compact ? 15 : 16, color: color),
          const SizedBox(width: 5),
          Text(
            compact ? 'Verificado' : 'Evento verificado',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RequestDetailsPage extends StatelessWidget {
  const _RequestDetailsPage({
    required this.request,
    required this.userType,
    required this.onAttachPaymentProof,
    required this.onCancelRequest,
    required this.onOpenCredential,
    required this.onOpenAttachment,
    required this.onShareAttachment,
  });

  final Map<String, dynamic> request;
  final String userType;
  final ValueChanged<Map<String, dynamic>> onAttachPaymentProof;
  final ValueChanged<Map<String, dynamic>> onCancelRequest;
  final ValueChanged<Map<String, dynamic>> onOpenCredential;
  final ValueChanged<Map<String, dynamic>> onOpenAttachment;
  final ValueChanged<Map<String, dynamic>> onShareAttachment;

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? 'enviada';
    final finalPermit = _RequestListTile._finalPermitAttachment(request);
    final verified = _RequestListTile._isCredentialVerified(request);
    final canAttachPayment = status == 'aguardando_pagamento_dam';
    final canCancel = _RequestListTile._canCancel(status);
    final canOpenCredential =
        status == 'autorizada' ||
        status == 'isenta_dam' ||
        (request['credentials'] as List<dynamic>? ?? const []).isNotEmpty;

    return AppScaffold(
      userType: userType,
      appBar: AppBar(
        title: const Text('Detalhes da solicitação'),
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _StatusBadge(status: status),
                            if (verified) const _VerifiedBadge(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          request['nome_do_evento']?.toString() ?? 'Evento',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: 'Protocolo',
                          value: request['protocolo']?.toString() ?? '-',
                        ),
                        _DetailRow(
                          label: 'Serviço',
                          value:
                              request['permitType']?.toString() ??
                              'Alvará de Evento',
                        ),
                        _DetailRow(
                          label: 'Data do evento',
                          value: request['data_do_evento']?.toString() ?? '-',
                        ),
                        _DetailRow(
                          label: 'Local',
                          value:
                              request['endereco_do_evento']?.toString() ??
                              request['local_evento']?.toString() ??
                              '-',
                        ),
                        _DetailRow(
                          label: 'Público esperado',
                          value:
                              request['publico_estimado']?.toString() ??
                              request['expectativa_publico']?.toString() ??
                              '-',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _DetailsSection(
                  title: 'Ações disponíveis',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canAttachPayment)
                        ElevatedButton.icon(
                          onPressed: () => onAttachPaymentProof(request),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Anexar comprovante'),
                        ),
                      if (canCancel)
                        OutlinedButton.icon(
                          onPressed: () => onCancelRequest(request),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancelar solicitação'),
                        ),
                      if (finalPermit != null)
                        OutlinedButton.icon(
                          onPressed: () => onOpenAttachment(finalPermit),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Visualizar alvará'),
                        ),
                      if (finalPermit != null)
                        OutlinedButton.icon(
                          onPressed: () => onShareAttachment(finalPermit),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Compartilhar'),
                        ),
                      if (canOpenCredential)
                        OutlinedButton.icon(
                          onPressed: () => onOpenCredential(request),
                          icon: const Icon(Icons.qr_code_2),
                          label: Text(
                            verified ? 'Ver credencial' : 'Validar evento',
                          ),
                        ),
                      if (!canAttachPayment &&
                          !canCancel &&
                          finalPermit == null &&
                          !canOpenCredential)
                        const Text(
                          'Nenhuma ação disponível neste status. Acompanhe as próximas etapas por aqui.',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DetailsSection(
                  title: 'Exigências e validações',
                  child: _RequirementList(request: request),
                ),
                const SizedBox(height: 12),
                _DetailsSection(
                  title: 'Anexos',
                  child: _AttachmentList(
                    request: request,
                    onOpenAttachment: onOpenAttachment,
                    onShareAttachment: onShareAttachment,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}

class _RequirementList extends StatelessWidget {
  const _RequirementList({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final requirements =
        (request['requirements'] as List<dynamic>? ??
                request['exigencias'] as List<dynamic>? ??
                const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    if (requirements.isEmpty) {
      return const Text('Nenhuma exigência registrada para esta solicitação.');
    }
    return Column(
      children:
          requirements.map((requirement) {
            final status =
                requirement['status']?.toString() ??
                requirement['status_secretaria']?.toString() ??
                'pendente';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(
                requirement['exigencia']?.toString() ??
                    requirement['pergunta']?.toString() ??
                    'Exigência',
              ),
              subtitle: Text(_RequestListTile._formatStatus(status)),
            );
          }).toList(),
    );
  }
}

class _AttachmentList extends StatelessWidget {
  const _AttachmentList({
    required this.request,
    required this.onOpenAttachment,
    required this.onShareAttachment,
  });

  final Map<String, dynamic> request;
  final ValueChanged<Map<String, dynamic>> onOpenAttachment;
  final ValueChanged<Map<String, dynamic>> onShareAttachment;

  @override
  Widget build(BuildContext context) {
    final attachments =
        (request['attachments'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    if (attachments.isEmpty) {
      return const Text('Nenhum anexo disponível.');
    }
    return Column(
      children:
          attachments.map((attachment) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_file),
              title: Text(
                attachment['nome_arquivo']?.toString() ?? 'Arquivo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(attachment['tipo_documento']?.toString() ?? ''),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Abrir',
                    onPressed: () => onOpenAttachment(attachment),
                    icon: const Icon(Icons.open_in_new),
                  ),
                  IconButton(
                    tooltip: 'Compartilhar',
                    onPressed: () => onShareAttachment(attachment),
                    icon: const Icon(Icons.share_outlined),
                  ),
                ],
              ),
            );
          }).toList(),
    );
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
