import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/permit_api_service.dart';
import '../../shared/widgets/custom_drawer.dart';

class HomeContentPage extends StatefulWidget {
  const HomeContentPage({super.key, required this.userType});

  final String userType;

  @override
  State<HomeContentPage> createState() => _HomeContentPageState();
}

class _HomeContentPageState extends State<HomeContentPage> {
  final _api = PermitApiService();
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _imageController = TextEditingController();
  final _orderController = TextEditingController(text: '0');

  static const _secretarias = {
    'prefeitura': 'Prefeitura',
    'desenvolvimento_economico': 'Desenvolvimento Econômico',
    'meio_ambiente': 'Meio Ambiente',
    'infraestrutura': 'Infraestrutura',
    'dmtran': 'DMTRAN',
    'vigilancia_sanitaria': 'Vigilância Sanitária',
    'guarda_civil': 'Guarda Civil Municipal',
    'receita_municipal': 'Receita Municipal',
  };

  List<Map<String, dynamic>> _cards = [];
  String _selectedScope = 'prefeitura';
  String? _currentRole;
  String? _currentSecretaria;
  int? _editingId;
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _imageController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rawUser = await _storage.read(key: 'user');
      if (rawUser != null) {
        final user = jsonDecode(rawUser) as Map<String, dynamic>;
        _currentRole = user['role'] as String?;
        _currentSecretaria = user['secretaria'] as String?;
        if (_currentRole == 'gestor_secretaria' && _currentSecretaria != null) {
          _selectedScope = _currentSecretaria!;
        }
      }
      final token = await _storage.read(key: 'access_token');
      if (token == null) throw PermitApiException('Sessão expirada.');
      final cards = await _api.listHomeContent(token);
      if (!mounted) return;
      setState(() => _cards = cards);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final token = await _storage.read(key: 'access_token');
    if (token == null) {
      _showMessage('Sessão expirada.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final order = int.tryParse(_orderController.text) ?? 0;
      if (_editingId == null) {
        await _api.createHomeContent(
          accessToken: token,
          scope: _selectedScope,
          title: _titleController.text,
          body: _bodyController.text,
          imageUrl: _imageController.text,
          displayOrder: order,
          isActive: _isActive,
        );
      } else {
        await _api.updateHomeContent(
          accessToken: token,
          cardId: _editingId!,
          scope: _selectedScope,
          title: _titleController.text,
          body: _bodyController.text,
          imageUrl: _imageController.text,
          displayOrder: order,
          isActive: _isActive,
        );
      }
      _clearForm();
      await _load();
      _showMessage('Conteúdo salvo com sucesso.');
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _edit(Map<String, dynamic> card) {
    setState(() {
      _editingId = card['id'] as int?;
      _selectedScope = card['scope'] as String? ?? _selectedScope;
      _titleController.text = card['title'] as String? ?? '';
      _bodyController.text = card['body'] as String? ?? '';
      _imageController.text = card['image_url'] as String? ?? '';
      _orderController.text = '${card['display_order'] ?? 0}';
      _isActive = card['is_active'] as bool? ?? true;
    });
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      if (_currentRole == 'gestor_secretaria' && _currentSecretaria != null) {
        _selectedScope = _currentSecretaria!;
      } else {
        _selectedScope = 'prefeitura';
      }
      _titleController.clear();
      _bodyController.clear();
      _imageController.clear();
      _orderController.text = '0';
      _isActive = true;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Map<String, String> get _availableScopes {
    if (_currentRole == 'gestor_secretaria' &&
        _currentSecretaria != null &&
        _secretarias.containsKey(_currentSecretaria)) {
      return {_currentSecretaria!: _secretarias[_currentSecretaria]!};
    }
    return _secretarias;
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        _cards
            .where(
              (card) =>
                  card['scope'] == _selectedScope && card['is_active'] == true,
            )
            .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Conteúdo da página inicial')),
      drawer: CustomDrawer(userType: widget.userType),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    _editingId == null
                                        ? 'Novo card do carrossel'
                                        : 'Editar card do carrossel',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 14),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedScope,
                                    decoration: const InputDecoration(
                                      labelText: 'Prefeitura ou secretaria',
                                    ),
                                    items:
                                        _availableScopes.entries
                                            .map(
                                              (entry) => DropdownMenuItem(
                                                value: entry.key,
                                                child: Text(entry.value),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _selectedScope = value);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cards ativos neste escopo: $activeCount/5',
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _titleController,
                                    decoration: const InputDecoration(
                                      labelText: 'Título',
                                    ),
                                    validator:
                                        (value) =>
                                            value == null ||
                                                    value.trim().length < 3
                                                ? 'Informe o título'
                                                : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _bodyController,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      labelText: 'Texto',
                                    ),
                                    validator:
                                        (value) =>
                                            value == null ||
                                                    value.trim().length < 5
                                                ? 'Informe o texto'
                                                : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _imageController,
                                    decoration: const InputDecoration(
                                      labelText: 'URL da imagem',
                                    ),
                                    validator:
                                        (value) =>
                                            value == null ||
                                                    value.trim().length < 5
                                                ? 'Informe a imagem'
                                                : null,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _orderController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Ordem',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: SwitchListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('Ativo'),
                                          value: _isActive,
                                          onChanged:
                                              (value) => setState(
                                                () => _isActive = value,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _saving ? null : _save,
                                          icon: const Icon(Icons.save_outlined),
                                          label: Text(
                                            _saving ? 'Salvando...' : 'Salvar',
                                          ),
                                        ),
                                      ),
                                      if (_editingId != null) ...[
                                        const SizedBox(width: 12),
                                        OutlinedButton(
                                          onPressed: _clearForm,
                                          child: const Text('Cancelar'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._cards.map(
                          (card) => Card(
                            child: ListTile(
                              leading: SizedBox(
                                width: 72,
                                height: 48,
                                child: Image.network(
                                  card['image_url'] as String? ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) =>
                                          const Icon(Icons.image_not_supported),
                                ),
                              ),
                              title: Text(card['title'] as String? ?? ''),
                              subtitle: Text(
                                '${_secretarias[card['scope']] ?? card['scope']} - ${card['is_active'] == true ? 'Ativo' : 'Inativo'}',
                              ),
                              trailing: IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _edit(card),
                              ),
                            ),
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
