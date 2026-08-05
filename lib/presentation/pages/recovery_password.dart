import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RecoveryPassword extends HookConsumerWidget {
  const RecoveryPassword({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();

    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);

    Future<void> requestRecovery() async {
      final email = emailController.text;
      if (!email.contains('@')) {
        errorMessage.value = 'Informe um e-mail válido';
        return;
      }
      isLoading.value = true;
      await Future.delayed(const Duration(milliseconds: 500));
      isLoading.value = false;
      errorMessage.value = null;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se o e-mail estiver cadastrado, enviaremos as instruções.',
            ),
          ),
        );
        Navigator.pop(context);
      }
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Recuperar Senha',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextField(
                              controller: emailController,
                              decoration: const InputDecoration(
                                labelText: 'Digite seu email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Center(
                              child:
                                  isLoading.value
                                      ? const CircularProgressIndicator()
                                      : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .center, // <<< CENTRALIZA OS BOTÕES
                                        children: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF006B3F,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 32,
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed: requestRecovery,
                                            child: const Text(
                                              'Enviar',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color.fromARGB(
                                                    255,
                                                    0,
                                                    2,
                                                    107,
                                                  ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 32,
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed:
                                                () => Navigator.pop(context),
                                            child: const Text(
                                              'Voltar',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                            ),

                            const SizedBox(height: 15),
                            if (errorMessage.value != null)
                              Text(
                                errorMessage.value!,
                                style: const TextStyle(color: Colors.red),
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
        ],
      ),
    );
  }
}
