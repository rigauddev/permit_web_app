import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_service.dart';
import '../../core/permit_api_service.dart';
import '../../core/session_expiration.dart';
import '../../core/session_store.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/user_provider.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/custom_appbar.dart';
import 'change_password_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, required this.userType});

  final String userType;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  PlatformFile? _selectedPhoto;
  bool _saving = false;
  bool _loading = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _hydrate(UserModel? user) {
    if (_loaded || user == null) return;
    _nameController.text = user.name;
    _lastNameController.text = user.lastName;
    _phoneController.text = user.phone;
    _addressController.text = user.address;
    _loaded = true;
  }

  Future<void> _loadProfile() async {
    final token = await SessionExpiration.readAccessToken();
    if (token == null || token.isEmpty) {
      if (mounted) await SessionExpiration.logout(context);
      return;
    }
    try {
      final user = await _authService.currentUser(accessToken: token);
      if (!mounted) return;
      ref.read(userProvider.notifier).setUser(user);
      _loaded = false;
      _hydrate(user);
    } on AuthException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final token = await SessionExpiration.readAccessToken();
    if (token == null || token.isEmpty) {
      if (mounted) await SessionExpiration.logout(context);
      return;
    }
    setState(() => _saving = true);
    try {
      String? uploadedPhotoName;
      String? uploadedPhotoUrl;
      if (_selectedPhoto != null) {
        if (_selectedPhoto!.bytes == null) {
          _showError('Não foi possível ler a foto selecionada.');
          return;
        }
        final upload = await _authService.uploadFileBytes(
          kind: 'usuarios/fotos',
          fileName: _selectedPhoto!.name,
          bytes: _selectedPhoto!.bytes!,
        );
        uploadedPhotoName = upload['file_name']?.toString();
        uploadedPhotoUrl = upload['file_url']?.toString();
      }
      final updated = await _authService.updateCurrentUser(
        accessToken: token,
        nome: _nameController.text.trim(),
        sobrenome: _lastNameController.text.trim(),
        telefone: _phoneController.text.trim(),
        endereco: _addressController.text.trim(),
        userPhotoName: uploadedPhotoName,
        userPhotoUrl: uploadedPhotoUrl,
      );
      await const SessionStore().updateUserJson(jsonEncode(updated.toJson()));
      ref.read(userProvider.notifier).setUser(updated);
      if (!mounted) return;
      setState(() => _selectedPhoto = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
    } on AuthException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickProfilePhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _selectedPhoto = result.files.single);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    _hydrate(user);
    final photoUrl =
        user?.photoUrl.isNotEmpty == true
            ? PermitApiService().resolveFileUrl(user!.photoUrl)
            : '';
    final isCitizen =
        (user?.userType ?? widget.userType) == 'user' ||
        (user?.userType ?? widget.userType) == 'cidadao';

    return AppScaffold(
      userType: widget.userType,
      appBar: CustomAppBar(title: 'Perfil', actions: []),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 42,
                                      backgroundImage:
                                          photoUrl.isNotEmpty
                                              ? NetworkImage(photoUrl)
                                              : null,
                                      child:
                                          user?.photoUrl.isNotEmpty == true
                                              ? null
                                              : const Icon(
                                                Icons.person_outline,
                                                size: 42,
                                              ),
                                    ),
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                      onPressed:
                                          _saving ? null : _pickProfilePhoto,
                                      icon: const Icon(
                                        Icons.photo_camera_outlined,
                                      ),
                                      label: Text(
                                        _selectedPhoto == null
                                            ? 'Trocar foto'
                                            : _selectedPhoto!.name,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Dados do usuário',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nome',
                                ),
                                validator:
                                    (value) =>
                                        value == null || value.trim().length < 2
                                            ? 'Informe o nome'
                                            : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _lastNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Sobrenome',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Contato / telefone',
                                ),
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  _PhoneInputFormatter(),
                                ],
                                validator: (value) {
                                  final digits = _onlyDigits(value ?? '');
                                  if (digits.isEmpty) return null;
                                  return digits.length < 10
                                      ? 'Informe um telefone válido'
                                      : null;
                                },
                              ),
                              if (isCitizen) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _addressController,
                                  decoration: const InputDecoration(
                                    labelText: 'Endereço',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              if ((user?.email ?? '').isNotEmpty)
                                _lockedField('E-mail', user?.email ?? ''),
                              _lockedField('CPF/CNPJ', user?.cpfCnpj ?? ''),
                              if (!isCitizen) ...[
                                _lockedField('Perfil', user?.role ?? ''),
                                _lockedField(
                                  'Secretaria',
                                  user?.secretaria ?? 'Não se aplica',
                                ),
                              ],
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(
                                  _saving ? 'Salvando...' : 'Salvar perfil',
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => const ChangePasswordPage(
                                              firstAccess: false,
                                            ),
                                      ),
                                    ),
                                icon: const Icon(Icons.lock_reset_outlined),
                                label: const Text('Alterar senha'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
          ),
        ),
      ),
    );
  }

  Widget _lockedField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _onlyDigits(newValue.text);
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final formatted = _formatPhone(limited);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatPhone(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if ((value.length <= 10 && i == 6) || (value.length > 10 && i == 7)) {
        buffer.write('-');
      }
      buffer.write(value[i]);
    }
    return buffer.toString();
  }
}
