import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth_service.dart';
import '../../core/session_store.dart';
import '../../data/providers/user_provider.dart';

class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=br.gov.ba.valenca.alvara';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identifierController = useTextEditingController();
    final passwordController = useTextEditingController();
    final mfaController = useTextEditingController();
    final mfaFocusNode = useFocusNode();

    final challenge = useState<LoginChallenge?>(null);
    final mfaGeneration = useState<MfaGeneration?>(null);
    final selectedMfaMethod = useState<String>('email');
    final mfaResendSeconds = useState<int>(0);
    final accessProfile = useState<String>('cidadao');
    final isLoading = useState(false);
    final obscurePassword = useState(true);
    final errorMessage = useState<String?>(null);

    final authService = AuthService();
    const sessionStore = SessionStore();

    useEffect(() {
      if (mfaResendSeconds.value <= 0) return null;
      late final Timer timer;
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mfaResendSeconds.value <= 1) {
          mfaResendSeconds.value = 0;
          timer.cancel();
        } else {
          mfaResendSeconds.value = mfaResendSeconds.value - 1;
        }
      });
      return timer.cancel;
    }, [mfaGeneration.value]);

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
      mfaResendSeconds.value = 60;
      if (generation.devCode != null) {
        debugPrint('Código MFA de teste: ${generation.devCode}');
      }
      Future.delayed(const Duration(milliseconds: 200), () {
        mfaFocusNode.requestFocus();
      });
    }

    Future<void> validateLogin() async {
      isLoading.value = true;
      errorMessage.value = null;
      try {
        if (accessProfile.value == 'cidadao' &&
            !_isValidCpfOrCnpj(identifierController.text)) {
          errorMessage.value = 'CPF/CNPJ informado está incorreto.';
          return;
        }
        final loginChallenge = await authService.startLogin(
          identifierController.text,
          passwordController.text,
          accessType: accessProfile.value == 'cidadao' ? 'cidadao' : 'interno',
          clientType: kIsWeb ? 'web' : 'app',
        );
        if (!loginChallenge.mfaRequired) {
          final accessToken = loginChallenge.accessToken;
          final user = loginChallenge.user;
          if (accessToken == null || user == null) {
            errorMessage.value = 'Não foi possível iniciar a sessão';
            return;
          }
          final expiresAt =
              DateTime.now()
                  .add(const Duration(days: 5))
                  .toUtc()
                  .toIso8601String();
          await sessionStore.save(
            accessToken: accessToken,
            expiresAt: expiresAt,
            userJson: jsonEncode(user.toJson()),
          );
          ref.read(userProvider.notifier).setUser(user);
          await Future<void>.delayed(Duration.zero);
          if (context.mounted) {
            Navigator.pushReplacementNamed(
              context,
              user.mustChangePassword ? '/change-password' : '/home',
            );
          }
          return;
        }
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
          clientType: kIsWeb ? 'web' : 'app',
        );
        final expiresAt =
            DateTime.now()
                .add(const Duration(days: 5))
                .toUtc()
                .toIso8601String();
        await sessionStore.save(
          accessToken: session.accessToken,
          expiresAt: expiresAt,
          userJson: jsonEncode(session.user.toJson()),
        );
        ref.read(userProvider.notifier).setUser(session.user);
        await Future<void>.delayed(Duration.zero);
        if (context.mounted) {
          Navigator.pushReplacementNamed(
            context,
            session.user.mustChangePassword ? '/change-password' : '/home',
          );
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
      mfaResendSeconds.value = 0;
      mfaController.clear();
      errorMessage.value = null;
    }

    void clearCredentials() {
      identifierController.clear();
      passwordController.clear();
      mfaController.clear();
      challenge.value = null;
      mfaGeneration.value = null;
      selectedMfaMethod.value = 'email';
      mfaResendSeconds.value = 0;
      obscurePassword.value = true;
      errorMessage.value = null;
    }

    void selectAccessProfile(String profile) {
      clearCredentials();
      accessProfile.value = profile;
    }

    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final hasChallenge = challenge.value != null;
    final isCitizenAccess = accessProfile.value == 'cidadao';

    Future<void> openPlayStore() async {
      final opened = await launchUrl(
        Uri.parse(_playStoreUrl),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
      errorMessage.value = 'Não foi possível abrir a Play Store';
    }

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton.icon(
                  onPressed:
                      isLoading.value
                          ? null
                          : () => selectAccessProfile(
                            isCitizenAccess ? 'interno' : 'cidadao',
                          ),
                  icon: Icon(
                    isCitizenAccess
                        ? Icons.badge_outlined
                        : Icons.person_outline,
                  ),
                  label: Text(
                    isCitizenAccess ? 'Portal do Servidor' : 'Acesso cidadão',
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 72, 16, 24),
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
                                  : isCitizenAccess
                                  ? 'Acesso do cidadão'
                                  : 'Portal do servidor',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isCitizenAccess
                                  ? 'Entre para solicitar e acompanhar alvarás de evento.'
                                  : 'Acesso restrito a servidores, operadores, gestores e administradores.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            if (!hasChallenge) ...[
                              TextField(
                                controller: identifierController,
                                keyboardType:
                                    isCitizenAccess
                                        ? TextInputType.number
                                        : TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText:
                                      isCitizenAccess
                                          ? 'CPF ou CNPJ'
                                          : 'E-mail institucional',
                                  prefixIcon: Icon(
                                    isCitizenAccess
                                        ? Icons.badge_outlined
                                        : Icons.email_outlined,
                                  ),
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
                                onPressed:
                                    isLoading.value ? null : validateLogin,
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
                              if (isCitizenAccess) ...[
                                TextButton(
                                  onPressed:
                                      () => Navigator.pushNamed(
                                        context,
                                        '/registrar_usuario',
                                      ),
                                  child: const Text('Criar conta de cidadão'),
                                ),
                              ],
                            ] else ...[
                              if (challenge.value!.availableMethods.length >
                                  1) ...[
                                DropdownButtonFormField<String>(
                                  initialValue: selectedMfaMethod.value,
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
                                      isLoading.value ||
                                              mfaGeneration.value == null
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
                                  icon: const Icon(
                                    Icons.mark_email_read_outlined,
                                  ),
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
                                    child: SelectableText(
                                      'Código MFA de teste: ${mfaGeneration.value!.devCode}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.tertiary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed:
                                      isLoading.value ||
                                              mfaResendSeconds.value > 0
                                          ? null
                                          : () => generateMfa(
                                            challenge.value!,
                                            selectedMfaMethod.value,
                                          ),
                                  icon: const Icon(Icons.refresh),
                                  label: Text(
                                    mfaResendSeconds.value > 0
                                        ? 'Solicitar novo código em ${mfaResendSeconds.value}s'
                                        : 'Solicitar novo código',
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
                                    prefixIcon: Icon(
                                      Icons.verified_user_outlined,
                                    ),
                                    counterText: '',
                                  ),
                                  onSubmitted: (_) => validateMfa(),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton(
                                  onPressed:
                                      isLoading.value ? null : validateMfa,
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
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isCitizenAccess) ...[
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: size.width < 600 ? size.width * 0.92 : 420,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: isLoading.value ? null : openPlayStore,
                        icon: const _PlayStoreLogo(),
                        label: const Text('Baixar app na Play Store'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayStoreLogo extends StatelessWidget {
  const _PlayStoreLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _PlayStoreLogoPainter()),
    );
  }
}

class _PlayStoreLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path =
        Path()
          ..moveTo(size.width * 0.12, size.height * 0.08)
          ..lineTo(size.width * 0.88, size.height * 0.50)
          ..lineTo(size.width * 0.12, size.height * 0.92)
          ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF34A853));

    final top =
        Path()
          ..moveTo(size.width * 0.12, size.height * 0.08)
          ..lineTo(size.width * 0.56, size.height * 0.50)
          ..lineTo(size.width * 0.12, size.height * 0.50)
          ..close();
    canvas.drawPath(top, Paint()..color = const Color(0xFF4285F4));

    final bottom =
        Path()
          ..moveTo(size.width * 0.12, size.height * 0.50)
          ..lineTo(size.width * 0.56, size.height * 0.50)
          ..lineTo(size.width * 0.12, size.height * 0.92)
          ..close();
    canvas.drawPath(bottom, Paint()..color = const Color(0xFFFBBC04));

    final point =
        Path()
          ..moveTo(size.width * 0.56, size.height * 0.50)
          ..lineTo(size.width * 0.88, size.height * 0.50)
          ..lineTo(size.width * 0.62, size.height * 0.64)
          ..close();
    canvas.drawPath(point, Paint()..color = const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

bool _isValidCpfOrCnpj(String value) {
  final digits = _onlyDigits(value);
  return _isValidCpf(digits) || _isValidCnpj(digits);
}

String _onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

bool _isValidCpf(String value) {
  if (value.length != 11 || RegExp(r'^(\d)\1+$').hasMatch(value)) {
    return false;
  }
  final numbers = value.split('').map(int.parse).toList();
  for (final size in [9, 10]) {
    var total = 0;
    for (var index = 0; index < size; index++) {
      total += numbers[index] * (size + 1 - index);
    }
    var digit = (total * 10) % 11;
    if (digit == 10) digit = 0;
    if (digit != numbers[size]) return false;
  }
  return true;
}

bool _isValidCnpj(String value) {
  if (value.length != 14 || RegExp(r'^(\d)\1+$').hasMatch(value)) {
    return false;
  }
  final numbers = value.split('').map(int.parse).toList();
  const weights = [
    [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2],
    [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2],
  ];
  for (var step = 0; step < weights.length; step++) {
    var total = 0;
    for (var index = 0; index < weights[step].length; index++) {
      total += numbers[index] * weights[step][index];
    }
    var digit = 11 - (total % 11);
    if (digit >= 10) digit = 0;
    if (digit != numbers[12 + step]) return false;
  }
  return true;
}
