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

    final showMfaField = useState(false);
    final isLoading = useState(false);
    final obscurePassword = useState(true);
    final errorMessage = useState<String?>(null);

    final authService = AuthService();
    final secureStorage = const FlutterSecureStorage();

    Future<void> validateLogin() async {
      final email = emailController.text;
      final password = passwordController.text;

      if (await authService.validateLogin(email, password)) {
        showMfaField.value = true;
        errorMessage.value = null;
        Future.delayed(const Duration(milliseconds: 300), () {
          mfaFocusNode.requestFocus();
        });
      } else {
        errorMessage.value = 'Email ou senha inválidos';
      }
    }

    Future<void> validateMfa() async {
      isLoading.value = true;

      final email = emailController.text;
      final password = passwordController.text;
      final mfaCode = mfaController.text;

      final mfaValid = await authService.validateMfaWithCredentials(email, password, mfaCode);

      if (mfaValid) {
        final user = authService.getUser(email);
        await secureStorage.write(key: 'user', value: jsonEncode(user?.toJson()));
        ref.read(userProvider.notifier).setUser(user!);
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        errorMessage.value = 'Código MFA inválido';
      }

      isLoading.value = false;
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo_prefeitura_1.png',
                    width: size.width < 600 ? size.width * 0.6 : 250,
                  ),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: size.width < 600 ? size.width * 0.9 : 400,
                    ),
                    child: Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!showMfaField.value) ...[
                              TextField(
                                controller: emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.email),
                                ),
                              ),
                              const SizedBox(height: 15),
                              TextField(
                                controller: passwordController,
                                obscureText: obscurePassword.value,
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(obscurePassword.value ? Icons.visibility : Icons.visibility_off),
                                    onPressed: () => obscurePassword.value = !obscurePassword.value,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pushNamed(context, '/esqueci_senha'),
                                child: const Text('Esqueci minha senha'),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF006B3F),
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: validateLogin,
                                child: const Text('Entrar', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                            if (showMfaField.value) ...[
                              const SizedBox(height: 20),
                              Text(
                                'Insira o código MFA',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: mfaController,
                                focusNode: mfaFocusNode,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Código MFA',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.shield),
                                ),
                              ),
                              const SizedBox(height: 10),
                              isLoading.value
                                  ? const CircularProgressIndicator()
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF002776),
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: validateMfa,
                                      child: const Text('Enviar', style: TextStyle(color: Colors.white)),
                                    ),
                                    const SizedBox(height: 10),
                                    TextButton(
                                      onPressed: () => Navigator.pushNamed(context, '/'),
                                      child: const Text('Cancelar', style: TextStyle(color: Colors.redAccent)),
                                    ),
                            ],
                            if (errorMessage.value != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  errorMessage.value!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!showMfaField.value) ...[
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/registrar_usuario'),
                      child: const Text('Não tem uma conta? Cadastre-se'),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
