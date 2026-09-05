import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_service.dart';
import '../../core/session_expiration.dart';
import '../../core/session_store.dart';
import '../../data/providers/user_provider.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key, this.firstAccess = true});

  final bool firstAccess;

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _sessionStore = const SessionStore();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      final session = await _authService.changePassword(
        accessToken: token,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      await _sessionStore.save(
        accessToken: session.accessToken,
        userJson: jsonEncode(session.user.toJson()),
        expiresAt:
            DateTime.now()
                .add(const Duration(days: 5))
                .toUtc()
                .toIso8601String(),
      );
      ref.read(userProvider.notifier).setUser(session.user);
      if (!mounted) return;
      if (widget.firstAccess) {
        await Future<void>.delayed(Duration.zero);
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        return;
      }
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Senha atualizada'),
              content: const Text('Sua senha foi atualizada com sucesso.'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      if (mounted) Navigator.pop(context);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Não foi possível atualizar a senha.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.firstAccess ? 'Criar nova senha' : 'Alterar senha'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_reset_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.firstAccess ? 'Primeiro acesso' : 'Alterar senha',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.firstAccess
                        ? 'Crie uma senha própria para continuar usando o sistema.'
                        : 'Informe a senha atual e defina uma nova senha.',
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Material(
                      color: const Color(0xFFFFECEC),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha atual',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator:
                        (value) =>
                            value == null || value.length < 6
                                ? 'Informe a senha atual.'
                                : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nova senha',
                      prefixIcon: Icon(Icons.password_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'A nova senha deve ter pelo menos 6 caracteres.';
                      }
                      if (value == _currentPasswordController.text) {
                        return 'A nova senha deve ser diferente da senha atual.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar nova senha',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                    ),
                    validator:
                        (value) =>
                            value != _newPasswordController.text
                                ? 'As senhas devem ser iguais.'
                                : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon:
                        _loading
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.check_circle_outline),
                    label: Text(_loading ? 'Salvando...' : 'Salvar nova senha'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
