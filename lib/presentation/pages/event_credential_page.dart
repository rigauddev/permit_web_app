import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/permit_api_service.dart';

class EventCredentialPage extends StatefulWidget {
  final Map<String, dynamic>? permitForm;
  final String userProfile;
  final String? publicCode;
  final String? token;

  const EventCredentialPage({
    super.key,
    this.permitForm,
    this.userProfile = '',
    this.publicCode,
    this.token,
  });

  @override
  State<EventCredentialPage> createState() => _EventCredentialPageState();
}

class _EventCredentialPageState extends State<EventCredentialPage> {
  final _api = PermitApiService();
  final _storage = const FlutterSecureStorage();
  late final TextEditingController _publicCodeController;
  late final TextEditingController _tokenController;

  Map<String, dynamic>? _authorization;
  Map<String, dynamic>? _validation;
  String? _message;
  bool _loadingAuthorization = false;
  bool _issuingAuthorization = false;
  bool _validatingCredential = false;
  bool _printingPdf = false;

  @override
  void initState() {
    super.initState();
    _publicCodeController = TextEditingController(
      text: widget.publicCode ?? '',
    );
    _tokenController = TextEditingController(text: widget.token ?? '');
    if (widget.publicCode != null && widget.token != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _validateCredential(),
      );
    } else if (widget.permitForm != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAuthorization());
    }
  }

  @override
  void dispose() {
    _publicCodeController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  bool get _canIssueAuthorization {
    final profile = widget.userProfile;
    return profile == 'admin' ||
        profile == 'gestor_secretaria' ||
        profile == 'operador_secretaria';
  }

  int? get _requestId {
    final value = widget.permitForm?['formId'];
    return value is int ? value : int.tryParse(value.toString());
  }

  String? get _validationUrl => _authorization?['validation_url'] as String?;

  Future<void> _loadAuthorization() async {
    final requestId = _requestId;
    if (requestId == null) return;
    setState(() {
      _loadingAuthorization = true;
      _message = null;
    });
    try {
      final accessToken = await _readAccessToken();
      final authorization = await _api.getAuthorization(
        accessToken: accessToken,
        requestId: requestId,
      );
      _setAuthorization(authorization);
    } on PermitApiException catch (error) {
      setState(() {
        _message =
            error.statusCode == 404
                ? 'Credencial ainda não emitida para esta solicitação.'
                : error.message;
      });
    } catch (_) {
      setState(() => _message = 'Não foi possível carregar a autorização.');
    } finally {
      if (mounted) setState(() => _loadingAuthorization = false);
    }
  }

  Future<void> _issueAuthorization() async {
    final requestId = _requestId;
    if (requestId == null) return;
    setState(() {
      _issuingAuthorization = true;
      _message = null;
    });
    try {
      final accessToken = await _readAccessToken();
      final authorization = await _api.issueAuthorization(
        accessToken: accessToken,
        requestId: requestId,
      );
      _setAuthorization(authorization);
    } on PermitApiException catch (error) {
      setState(() => _message = error.message);
    } catch (_) {
      setState(() => _message = 'Não foi possível emitir a autorização.');
    } finally {
      if (mounted) setState(() => _issuingAuthorization = false);
    }
  }

  Future<void> _validateCredential() async {
    final publicCode = _publicCodeController.text.trim();
    final token = _tokenController.text.trim();
    if (publicCode.isEmpty || token.isEmpty) {
      setState(() => _message = 'Informe o código público e o token.');
      return;
    }
    setState(() {
      _validatingCredential = true;
      _message = null;
    });
    try {
      final validation = await _api.validateEventCredential(
        publicCode: publicCode,
        token: token,
      );
      setState(() => _validation = validation);
    } on PermitApiException catch (error) {
      setState(() => _message = error.message);
    } catch (_) {
      setState(() => _message = 'Não foi possível validar a credencial.');
    } finally {
      if (mounted) setState(() => _validatingCredential = false);
    }
  }

  Future<String> _readAccessToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      throw PermitApiException('Sessão expirada. Faça login novamente.');
    }
    return token;
  }

  void _setAuthorization(Map<String, dynamic> authorization) {
    final url = authorization['validation_url'] as String? ?? '';
    _publicCodeController.text =
        authorization['codigo_publico'] as String? ?? _publicCodeFromUrl(url);
    _tokenController.text = _tokenFromUrl(url);
    setState(() {
      _authorization = authorization;
      _message = null;
    });
    final publicCode = _publicCodeController.text.trim();
    final token = _tokenController.text.trim();
    if (publicCode.isNotEmpty && token.isNotEmpty) {
      Future.microtask(_validateCredential);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.permitForm;
    return Scaffold(
      appBar: AppBar(title: const Text('Credencial do Evento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_message != null) _StatusBanner(message: _message!),
                if (form != null) ...[
                  _AuthorizationDocument(
                    form: form,
                    authorization: _authorization,
                    validationUrl: _validationUrl,
                    loading: _loadingAuthorization,
                    canIssue: _canIssueAuthorization,
                    issuing: _issuingAuthorization,
                    printingPdf: _printingPdf,
                    onIssue: _issueAuthorization,
                    onCopyUrl: _copyValidationUrl,
                    onPrintPdf: _printAuthorizationPdf,
                  ),
                  const SizedBox(height: 16),
                ],
                _ValidationPanel(
                  publicCodeController: _publicCodeController,
                  tokenController: _tokenController,
                  loading: _validatingCredential,
                  validation: _validation,
                  onValidate: _validateCredential,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyValidationUrl() async {
    final url = _validationUrl;
    if (url == null || url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link de validação copiado.')));
  }

  Future<void> _printAuthorizationPdf() async {
    final form = widget.permitForm;
    final url = _validationUrl;
    if (form == null || url == null || url.isEmpty) return;
    setState(() => _printingPdf = true);
    try {
      await Printing.layoutPdf(
        name: 'autorizacao_evento_${form['protocolo'] ?? 'alvara'}.pdf',
        onLayout:
            (format) => _buildAuthorizationPdf(
              format: format,
              form: form,
              validation: _validation,
              validationUrl: url,
            ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível gerar o PDF.')),
      );
    } finally {
      if (mounted) setState(() => _printingPdf = false);
    }
  }
}

class _AuthorizationDocument extends StatelessWidget {
  final Map<String, dynamic> form;
  final Map<String, dynamic>? authorization;
  final String? validationUrl;
  final bool loading;
  final bool canIssue;
  final bool issuing;
  final bool printingPdf;
  final VoidCallback onIssue;
  final VoidCallback onCopyUrl;
  final VoidCallback onPrintPdf;

  const _AuthorizationDocument({
    required this.form,
    required this.authorization,
    required this.validationUrl,
    required this.loading,
    required this.canIssue,
    required this.issuing,
    required this.printingPdf,
    required this.onIssue,
    required this.onCopyUrl,
    required this.onPrintPdf,
  });

  bool get _hasQr => validationUrl != null && validationUrl!.contains('?t=');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = form['status']?.toString() ?? '';
    final isAuthorized = status == 'autorizada' || status == 'isenta_dam';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Autorização de Evento',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('Protocolo ${form['protocolo'] ?? '-'}'),
                  ],
                ),
                _StatusChip(label: _statusLabel(status), status: status),
              ],
            ),
            const Divider(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final details = _DocumentDetails(form: form);
                final qr = _QrBox(
                  validationUrl: validationUrl,
                  hasQr: _hasQr,
                  loading: loading,
                );
                return wide
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: details),
                        const SizedBox(width: 20),
                        qr,
                      ],
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [details, const SizedBox(height: 16), qr],
                    );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Esta autorização deve ser apresentada às autoridades fiscais quando solicitada. '
              'A Receita/Fazenda atua no DAM após anuências completas; no MVP, o DAM é anexado ao processo.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (_hasQr)
                  OutlinedButton.icon(
                    onPressed: onCopyUrl,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar link'),
                  ),
                if (_hasQr)
                  OutlinedButton.icon(
                    onPressed: printingPdf ? null : onPrintPdf,
                    icon:
                        printingPdf
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Gerar PDF'),
                  ),
                if (isAuthorized && canIssue)
                  ElevatedButton.icon(
                    onPressed: issuing ? null : onIssue,
                    icon:
                        issuing
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.verified),
                    label: Text(
                      authorization == null
                          ? 'Emitir credencial'
                          : 'Reemitir link seguro',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentDetails extends StatelessWidget {
  final Map<String, dynamic> form;

  const _DocumentDetails({required this.form});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DetailRow(label: 'Evento', value: form['nome_do_evento']),
        _DetailRow(label: 'Responsável', value: form['responsavel']),
        _DetailRow(label: 'Data', value: form['data_do_evento']),
        _DetailRow(
          label: 'Horário',
          value: _timeRange(form['horario_inicio'], form['horario_termino']),
        ),
        _DetailRow(label: 'Local', value: form['local_evento']),
        _DetailRow(label: 'DAM', value: _damLabel(form['dam_status'])),
      ],
    );
  }
}

class _QrBox extends StatelessWidget {
  final String? validationUrl;
  final bool hasQr;
  final bool loading;

  const _QrBox({
    required this.validationUrl,
    required this.hasQr,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD8E0D8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 160,
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasQr)
            QrImageView(
              data: validationUrl!,
              version: QrVersions.auto,
              size: 168,
              backgroundColor: Colors.white,
            )
          else
            const SizedBox(
              width: 160,
              height: 160,
              child: Center(
                child: Text(
                  'QR Code disponível após emissão da credencial.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Validação fiscal',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ValidationPanel extends StatelessWidget {
  final TextEditingController publicCodeController;
  final TextEditingController tokenController;
  final bool loading;
  final Map<String, dynamic>? validation;
  final VoidCallback onValidate;

  const _ValidationPanel({
    required this.publicCodeController,
    required this.tokenController,
    required this.loading,
    required this.validation,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Validar Credencial de Evento',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: publicCodeController,
              decoration: const InputDecoration(
                labelText: 'Código público',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Token do QR Code',
                prefixIcon: Icon(Icons.qr_code_2),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: loading ? null : onValidate,
                icon:
                    loading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.fact_check_outlined),
                label: const Text('Validar'),
              ),
            ),
            if (validation != null) ...[
              const SizedBox(height: 16),
              _ValidationResult(validation: validation!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValidationResult extends StatelessWidget {
  final Map<String, dynamic> validation;

  const _ValidationResult({required this.validation});

  @override
  Widget build(BuildContext context) {
    final valid = validation['valid'] == true;
    final requirements = validation['requirements'] as List<dynamic>? ?? [];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: valid ? const Color(0xFFEAF7EF) : const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: valid ? const Color(0xFF0B7A35) : const Color(0xFFE30613),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                valid ? Icons.verified : Icons.error_outline,
                color:
                    valid ? const Color(0xFF0B7A35) : const Color(0xFFE30613),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  valid
                      ? 'Credencial válida'
                      : validation['reason']?.toString() ??
                          'Credencial inválida',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(label: 'Protocolo', value: validation['protocolo']),
          _DetailRow(label: 'Evento', value: validation['nome_evento']),
          _DetailRow(label: 'Data', value: validation['data_evento']),
          _DetailRow(
            label: 'Horário',
            value: _timeRange(
              validation['horario_inicio'],
              validation['horario_termino'],
            ),
          ),
          _DetailRow(label: 'Local', value: validation['local_evento']),
          _DetailRow(label: 'Responsável', value: validation['responsavel']),
          _DetailRow(label: 'DAM', value: _damLabel(validation['dam_status'])),
          if (validation['dam_attachment'] != null)
            _DetailRow(
              label: 'Arquivo DAM',
              value:
                  (validation['dam_attachment']
                      as Map<String, dynamic>)['nome_arquivo'],
            ),
          if (requirements.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Anuências',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...requirements.map((item) {
              final requirement = item as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${requirement['secretaria']}: ${requirement['tipo_exigencia']} - ${requirement['status']}',
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final Object? value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = value?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(text.isEmpty ? '-' : text)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String status;

  const _StatusChip({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final color =
        status == 'autorizada' || status == 'isenta_dam'
            ? const Color(0xFF0B7A35)
            : const Color(0xFFE37B00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;

  const _StatusBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF8A5A00)),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'autorizada':
      return 'Autorizada';
    case 'isenta_dam':
      return 'Isenta de DAM';
    case 'dam_pendente':
      return 'DAM pendente';
    default:
      return status.isEmpty ? 'Em análise' : status;
  }
}

String _damLabel(Object? status) {
  switch (status?.toString()) {
    case 'anexado':
      return 'DAM anexado';
    case 'isento':
      return 'Isento';
    case 'pendente_prefeitura':
      return 'DAM pendente na Receita Municipal';
    case 'pago':
      return 'Pago';
    default:
      return status?.toString() ?? '-';
  }
}

String _timeRange(Object? start, Object? end) {
  final startText = start?.toString() ?? '';
  final endText = end?.toString() ?? '';
  if (startText.isEmpty && endText.isEmpty) return '';
  if (startText.isEmpty) return endText;
  if (endText.isEmpty) return startText;
  return '$startText às $endText';
}

String _tokenFromUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri?.queryParameters['t'] ?? '';
}

String _publicCodeFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.pathSegments.isEmpty) return '';
  return uri.pathSegments.last;
}

Future<Uint8List> _buildAuthorizationPdf({
  required PdfPageFormat format,
  required Map<String, dynamic> form,
  required Map<String, dynamic>? validation,
  required String validationUrl,
}) async {
  final document = pw.Document();
  final requirements = _pdfRequirements(form, validation);
  final isValid = validation?['valid'] == true;

  document.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(32),
      build:
          (context) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Prefeitura Municipal de Valença',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Central de Eventos - Autorização de Evento',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: isValid ? PdfColors.green800 : PdfColors.orange800,
                    ),
                  ),
                  child: pw.Text(
                    isValid ? 'CREDENCIAL VÁLIDA' : 'VALIDAR NO APP',
                    style: pw.TextStyle(
                      color: isValid ? PdfColors.green800 : PdfColors.orange800,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.Divider(height: 28),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      _pdfRow('Protocolo', form['protocolo']),
                      _pdfRow('Evento', form['nome_do_evento']),
                      _pdfRow('Responsável', form['responsavel']),
                      _pdfRow('Data', form['data_do_evento']),
                      _pdfRow(
                        'Horário',
                        _timeRange(
                          form['horario_inicio'],
                          form['horario_termino'],
                        ),
                      ),
                      _pdfRow('Local', form['local_evento']),
                      _pdfRow('DAM', _damLabel(form['dam_status'])),
                    ],
                  ),
                ),
                pw.SizedBox(width: 24),
                pw.Column(
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: validationUrl,
                      width: 112,
                      height: 112,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Validação fiscal',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Esta autorização fica mantida no sistema. A via em PDF deve ser usada apenas quando houver necessidade de impressão. '
              'A verificação oficial deve ser feita no aplicativo por meio do QR Code.',
              style: const pw.TextStyle(fontSize: 10),
            ),
            if (requirements.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Text(
                'Anuências e exigências',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.2),
                  2: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _pdfCell('Secretaria', bold: true),
                      _pdfCell('Exigência', bold: true),
                      _pdfCell('Status', bold: true),
                    ],
                  ),
                  ...requirements.map(
                    (item) => pw.TableRow(
                      children: [
                        _pdfCell(item['secretaria']),
                        _pdfCell(item['tipo_exigencia']),
                        _pdfCell(item['status']),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
    ),
  );

  return document.save();
}

pw.Widget _pdfRow(String label, Object? value) {
  final text = value?.toString().trim() ?? '';
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 86,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(child: pw.Text(text.isEmpty ? '-' : text)),
      ],
    ),
  );
}

pw.Widget _pdfCell(Object? value, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      value?.toString() ?? '-',
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

List<Map<String, dynamic>> _pdfRequirements(
  Map<String, dynamic> form,
  Map<String, dynamic>? validation,
) {
  final validationRequirements =
      validation?['requirements'] as List<dynamic>? ?? const [];
  if (validationRequirements.isNotEmpty) {
    return validationRequirements
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  final formRequirements = form['perguntas'] as List<dynamic>? ?? const [];
  return formRequirements.map((item) {
    final requirement = item as Map<String, dynamic>;
    return {
      'secretaria': requirement['secretaria'],
      'tipo_exigencia': requirement['pergunta'],
      'status': requirement['status'],
    };
  }).toList();
}
