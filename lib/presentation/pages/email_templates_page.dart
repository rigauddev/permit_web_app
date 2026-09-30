import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/permit_api_service.dart';
import '../../core/session_expiration.dart';
import '../../shared/widgets/app_scaffold.dart';

class EmailTemplatesPage extends StatefulWidget {
  const EmailTemplatesPage({super.key, required this.userType});

  final String userType;

  @override
  State<EmailTemplatesPage> createState() => _EmailTemplatesPageState();
}

class _EmailTemplatesPageState extends State<EmailTemplatesPage> {
  final _api = PermitApiService();
  final _subject = TextEditingController();
  final _header = TextEditingController();
  final _body = TextEditingController();
  final _footer = TextEditingController();
  final _logoUrl = TextEditingController();
  final _templates = <String, Map<String, dynamic>>{};
  String _selected = 'welcome';
  String _logoMode = 'system';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _labels = {
    'welcome': 'Boas-vindas',
    'blocked': 'Conta bloqueada',
    'password_recovery': 'Recuperação de senha',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _header.dispose();
    _body.dispose();
    _footer.dispose();
    _logoUrl.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await SessionExpiration.readAccessToken();
    if (token == null) throw PermitApiException('Sessão expirada.');
    return token;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.getEmailTemplates(accessToken: await _token());
      _templates
        ..clear()
        ..addAll(
          result.map(
            (key, value) =>
                MapEntry(key, Map<String, dynamic>.from(value as Map)),
          ),
        );
      _fillForm();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fillForm() {
    final template = _templates[_selected] ?? const <String, dynamic>{};
    _subject.text = template['subject']?.toString() ?? '';
    _header.text = template['header_text']?.toString() ?? '';
    _body.text = template['body_text']?.toString() ?? '';
    _footer.text = template['footer_text']?.toString() ?? '';
    _logoUrl.text = template['logo_url']?.toString() ?? '';
    _logoMode = template['logo_mode']?.toString() ?? 'system';
  }

  void _storeCurrent() {
    _templates[_selected] = {
      'subject': _subject.text.trim(),
      'header_text': _header.text.trim(),
      'body_text': _body.text.trim(),
      'footer_text': _footer.text.trim(),
      'logo_mode': _logoMode,
      'logo_url':
          _logoMode == 'custom' && _logoUrl.text.trim().isNotEmpty
              ? _logoUrl.text.trim()
              : null,
    };
  }

  Future<void> _selectTemplate(String value) async {
    _storeCurrent();
    setState(() {
      _selected = value;
      _fillForm();
    });
  }

  Future<void> _uploadLogo() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    try {
      setState(() => _saving = true);
      final result = await _api.uploadFile(
        accessToken: await _token(),
        kind: 'emails/logos',
        file: picked.files.single,
      );
      if (!mounted) return;
      setState(() {
        _logoMode = 'custom';
        _logoUrl.text = result['file_url']?.toString() ?? '';
      });
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    _storeCurrent();
    if (_templates.values.any(
      (item) =>
          (item['subject']?.toString().length ?? 0) < 3 ||
          (item['header_text']?.toString().length ?? 0) < 3 ||
          (item['body_text']?.toString().length ?? 0) < 5 ||
          (item['footer_text']?.toString().length ?? 0) < 3,
    )) {
      _message(
        'Preencha todos os campos obrigatórios dos três modelos.',
        error: true,
      );
      return;
    }
    try {
      setState(() => _saving = true);
      final saved = await _api.updateEmailTemplates(
        accessToken: await _token(),
        templates: _templates,
      );
      _templates
        ..clear()
        ..addAll(
          saved.map(
            (key, value) =>
                MapEntry(key, Map<String, dynamic>.from(value as Map)),
          ),
        );
      _fillForm();
      _message('Modelos de e-mail salvos.');
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    userType: widget.userType,
    appBar: AppBar(title: const Text('Modelos de e-mail')),
    body:
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(_error!),
              ),
            )
            : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Comunicação por e-mail',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Use {{nome}} para o nome do usuário e {{codigo}} no modelo de recuperação. A logo do sistema usa a imagem institucional já configurada no servidor.',
                            ),
                            const SizedBox(height: 18),
                            SegmentedButton<String>(
                              segments:
                                  _labels.entries
                                      .map(
                                        (item) => ButtonSegment(
                                          value: item.key,
                                          label: Text(item.value),
                                        ),
                                      )
                                      .toList(),
                              selected: {_selected},
                              onSelectionChanged:
                                  _saving
                                      ? null
                                      : (value) => _selectTemplate(value.first),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _subject,
                              decoration: const InputDecoration(
                                labelText: 'Assunto do e-mail',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _header,
                              decoration: const InputDecoration(
                                labelText: 'Texto do cabeçalho',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _body,
                              minLines: 6,
                              maxLines: 10,
                              decoration: const InputDecoration(
                                labelText: 'Texto do corpo do e-mail',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _footer,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Texto do rodapé',
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Logo',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'system',
                                  icon: Icon(Icons.account_balance_outlined),
                                  label: Text('Logo do sistema'),
                                ),
                                ButtonSegment(
                                  value: 'custom',
                                  icon: Icon(Icons.upload_file_outlined),
                                  label: Text('Outra logo'),
                                ),
                              ],
                              selected: {_logoMode},
                              onSelectionChanged:
                                  _saving
                                      ? null
                                      : (value) => setState(
                                        () => _logoMode = value.first,
                                      ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _logoMode == 'system'
                                  ? 'Imagem institucional configurada no ambiente.'
                                  : 'Envie PNG ou JPG para este modelo.',
                            ),
                            if (_logoMode == 'custom') ...[
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _saving ? null : _uploadLogo,
                                    icon: const Icon(
                                      Icons.upload_file_outlined,
                                    ),
                                    label: const Text('Upload de imagem'),
                                  ),
                                  if (_logoUrl.text.isNotEmpty)
                                    const Chip(
                                      label: Text(
                                        'Logo personalizada selecionada',
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _logoUrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Arquivo da logo',
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(
                                  _saving ? 'Salvando...' : 'Salvar modelos',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
  );
}
