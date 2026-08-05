import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/auth_service.dart';
import '../../data/providers/user_provider.dart';

class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final mfaController = useTextEditingController();
    final mfaFocusNode = useFocusNode();

    final challenge = useState<LoginChallenge?>(null);
    final mfaGeneration = useState<MfaGeneration?>(null);
    final selectedMfaMethod = useState<String>('email');
    final isLoading = useState(false);
    final obscurePassword = useState(true);
    final errorMessage = useState<String?>(null);

    final authService = AuthService();
    final secureStorage = const FlutterSecureStorage();

    Future<void> generateMfa(
      LoginChallenge loginChallenge,
      String method,
    ) async {
      final generation = await authService.generateMfa(
        loginChallenge.challengeToken,
        method,
      );
      mfaGeneration.value = generation;
      selectedMfaMethod.value = method;
      Future.delayed(const Duration(milliseconds: 200), () {
        mfaFocusNode.requestFocus();
      });
    }

    Future<void> validateLogin() async {
      isLoading.value = true;
      errorMessage.value = null;
      try {
        final loginChallenge = await authService.startLogin(
          emailController.text,
          passwordController.text,
        );
        challenge.value = loginChallenge;
        selectedMfaMethod.value = loginChallenge.defaultMethod;
        mfaController.clear();
        if (loginChallenge.availableMethods.length == 1) {
          await generateMfa(loginChallenge, loginChallenge.defaultMethod);
        }
      } on AuthException catch (error) {
        errorMessage.value = error.message;
      } catch (_) {
        errorMessage.value =
            'Não foi possível conectar ao serviço de autenticação';
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> validateMfa() async {
      final loginChallenge = challenge.value;
      if (loginChallenge == null) return;

      isLoading.value = true;
      errorMessage.value = null;
      try {
        final session = await authService.verifyMfa(
          loginChallenge.challengeToken,
          selectedMfaMethod.value,
          mfaController.text,
        );
        await secureStorage.write(
          key: 'access_token',
          value: session.accessToken,
        );
        await secureStorage.write(
          key: 'user',
          value: jsonEncode(session.user.toJson()),
        );
        ref.read(userProvider.notifier).setUser(session.user);
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } on AuthException catch (error) {
        errorMessage.value = error.message;
      } catch (_) {
        errorMessage.value = 'Não foi possível validar o MFA';
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> changeMfaMethod(String method) async {
      final loginChallenge = challenge.value;
      if (loginChallenge == null) return;

      isLoading.value = true;
      errorMessage.value = null;
      try {
        mfaController.clear();
        await generateMfa(loginChallenge, method);
      } on AuthException catch (error) {
        errorMessage.value = error.message;
      } finally {
        isLoading.value = false;
      }
    }

    void resetLogin() {
      challenge.value = null;
      mfaGeneration.value = null;
      selectedMfaMethod.value = 'email';
      mfaController.clear();
      errorMessage.value = null;
    }

    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final hasChallenge = challenge.value != null;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo_prefeitura_1.png',
                width: size.width < 600 ? size.width * 0.62 : 280,
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width < 600 ? size.width * 0.92 : 420,
                ),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          hasChallenge
                              ? 'Validação de segurança'
                              : 'Acesso ao sistema',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        if (!hasChallenge) ...[
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword.value,
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword.value
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed:
                                    () =>
                                        obscurePassword.value =
                                            !obscurePassword.value,
                              ),
                            ),
                            onSubmitted: (_) => validateLogin(),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  () => Navigator.pushNamed(
                                    context,
                                    '/recovery-password',
                                  ),
                              child: const Text('Esqueci minha senha'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: isLoading.value ? null : validateLogin,
                            child:
                                isLoading.value
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text('Entrar'),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed:
                                () => Navigator.pushNamed(
                                  context,
                                  '/registrar_usuario',
                                ),
                            child: const Text('Criar conta de cidadão'),
                          ),
                        ] else ...[
                          if (challenge.value!.availableMethods.length > 1) ...[
                            DropdownButtonFormField<String>(
                              value: selectedMfaMethod.value,
                              decoration: const InputDecoration(
                                labelText: 'Método de MFA',
                              ),
                              items:
                                  challenge.value!.availableMethods
                                      .map(
                                        (method) => DropdownMenuItem(
                                          value: method,
                                          child: Text(
                                            method == 'email'
                                                ? 'E-mail'
                                                : method.toUpperCase(),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  isLoading.value || mfaGeneration.value == null
                                      ? null
                                      : (value) {
                                        if (value != null) {
                                          changeMfaMethod(value);
                                        }
                                      },
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (mfaGeneration.value == null)
                            ElevatedButton.icon(
                              onPressed:
                                  isLoading.value
                                      ? null
                                      : () => generateMfa(
                                        challenge.value!,
                                        selectedMfaMethod.value,
                                      ),
                              icon: const Icon(Icons.mark_email_read_outlined),
                              label: const Text('Enviar código'),
                            )
                          else ...[
                            Text(
                              'Código enviado para ${mfaGeneration.value!.delivery}',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            if (mfaGeneration.value!.devCode != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Código de teste: ${mfaGeneration.value!.devCode}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: mfaController,
                              focusNode: mfaFocusNode,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(
                                labelText: 'Código MFA',
                                prefixIcon: Icon(Icons.verified_user_outlined),
                                counterText: '',
                              ),
                              onSubmitted: (_) => validateMfa(),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: isLoading.value ? null : validateMfa,
                              child:
                                  isLoading.value
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('Validar e entrar'),
                            ),
                          ],
                          TextButton(
                            onPressed: isLoading.value ? null : resetLogin,
                            child: const Text('Voltar'),
                          ),
                        ],
                        if (errorMessage.value != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              errorMessage.value!,
                              style: TextStyle(color: theme.colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
