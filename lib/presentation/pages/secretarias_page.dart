import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/permit_api_service.dart';
import '../../core/session_expiration.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/custom_appbar.dart';

class SecretariasPage extends StatefulWidget {
  const SecretariasPage({super.key, required this.userType});

  final String userType;

  @override
  State<SecretariasPage> createState() => _SecretariasPageState();
}

class _SecretariasPageState extends State<SecretariasPage> {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _slugController = TextEditingController();
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _emailController = TextEditingController();
  final _logoController = TextEditingController();
  final _emailHeaderController = TextEditingController();
  final _documentHeaderController = TextEditingController();
  final _documentFooterController = TextEditingController();

  List<Map<String, dynamic>> _secretarias = [];
  int? _editingId;
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isAdmin => widget.userType == 'admin';

  @override
  void initState() {
    super.initState();
    _loadSecretarias();
  }

  @override
  void dispose() {
    _slugController.dispose();
    _nomeController.dispose();
    _descricaoController.dispose();
    _emailController.dispose();
    _logoController.dispose();
    _emailHeaderController.dispose();
    _documentHeaderController.dispose();
    _documentFooterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      userType: widget.userType,
      appBar: CustomAppBar(
        title: 'Secretarias',
        actions: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            icon: const Icon(Icons.arrow_back),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loadSecretarias,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildForm(),
                        const SizedBox(height: 24),
                        const Text(
                          'Secretarias cadastradas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._secretarias.map(_buildSecretariaCard),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editingId == null ? 'Nova secretaria' : 'Editar secretaria',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _field('Slug', _slugController, enabled: _isAdmin),
              _field('Nome', _nomeController, enabled: _isAdmin),
              _field('E-mail', _emailController),
              _field('URL da logo', _logoController),
              _field('Descrição', _descricaoController, maxLines: 2),
              _field(
                'Cabeçalho do e-mail',
                _emailHeaderController,
                maxLines: 3,
              ),
              _field(
                'Cabeçalho dos documentos',
                _documentHeaderController,
                maxLines: 3,
              ),
              _field(
                'Rodapé dos documentos',
                _documentFooterController,
                maxLines: 3,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _clearForm,
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('Limpar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool enabled = true,
  }) {
    return SizedBox(
      width: MediaQuery.of(context).size.width < 720 ? double.infinity : 430,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if ((label == 'Slug' || label == 'Nome') &&
              (value == null || value.trim().isEmpty)) {
            return 'Campo obrigatório.';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSecretariaCard(Map<String, dynamic> secretaria) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.account_balance_outlined),
        title: Text(secretaria['nome']?.toString() ?? ''),
        subtitle: Text(secretaria['email']?.toString() ?? 'Sem e-mail'),
        trailing: IconButton(
          tooltip: 'Editar',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _edit(secretaria),
        ),
      ),
    );
  }

  Future<String?> _token() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      if (mounted) await SessionExpiration.logout(context);
      return null;
    }
    return token;
  }

  Future<void> _loadSecretarias() async {
    final token = await _token();
    if (token == null) return;
    setState(() => _isLoading = true);
    try {
      final secretarias = await PermitApiService().listSecretarias(
        accessToken: token,
      );
      if (!mounted) return;
      setState(() {
        _secretarias = secretarias;
        _isLoading = false;
      });
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(error.toString());
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final token = await _token();
    if (token == null) return;
    setState(() => _isSaving = true);
    final payload = {
      'slug': _slugController.text.trim(),
      'nome': _nomeController.text.trim(),
      'descricao': _descricaoController.text.trim(),
      'email': _emailController.text.trim(),
      'logo_url': _logoController.text.trim(),
      'email_header_text': _emailHeaderController.text.trim(),
      'document_header_text': _documentHeaderController.text.trim(),
      'document_footer_text': _documentFooterController.text.trim(),
      'is_active': true,
    };
    try {
      if (_editingId == null) {
        await PermitApiService().createSecretaria(
          accessToken: token,
          payload: payload,
        );
      } else {
        await PermitApiService().updateSecretaria(
          accessToken: token,
          secretariaId: _editingId!,
          payload: payload,
        );
      }
      _clearForm();
      await _loadSecretarias();
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _edit(Map<String, dynamic> secretaria) {
    setState(() {
      _editingId = secretaria['id'] as int?;
      _slugController.text = secretaria['slug']?.toString() ?? '';
      _nomeController.text = secretaria['nome']?.toString() ?? '';
      _descricaoController.text = secretaria['descricao']?.toString() ?? '';
      _emailController.text = secretaria['email']?.toString() ?? '';
      _logoController.text = secretaria['logo_url']?.toString() ?? '';
      _emailHeaderController.text =
          secretaria['email_header_text']?.toString() ?? '';
      _documentHeaderController.text =
          secretaria['document_header_text']?.toString() ?? '';
      _documentFooterController.text =
          secretaria['document_footer_text']?.toString() ?? '';
    });
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _slugController.clear();
      _nomeController.clear();
      _descricaoController.clear();
      _emailController.clear();
      _logoController.clear();
      _emailHeaderController.clear();
      _documentHeaderController.clear();
      _documentFooterController.clear();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
