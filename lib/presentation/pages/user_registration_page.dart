import 'package:flutter/material.dart';

import '../../core/auth_service.dart';

class UserRegistrationPage extends StatefulWidget {
  const UserRegistrationPage({super.key});

  @override
  State<UserRegistrationPage> createState() => _UserRegistrationPageState();
}

class _UserRegistrationPageState extends State<UserRegistrationPage> {
  static const _responsibilityTerm = '''
Declaro que os dados pessoais, documentos e informações cadastrados são verdadeiros, completos e pertencem a mim ou à pessoa jurídica que represento.

Estou ciente de que sou responsável pela exatidão e atualização das informações, pelo sigilo da minha senha e pelas consequências administrativas, civis e penais decorrentes de informações falsas, incompletas ou uso indevido da conta.

Autorizo o tratamento dos dados informados para fins de cadastro, identificação, solicitação e acompanhamento de serviços municipais, observadas as regras da Lei Geral de Proteção de Dados.
''';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cpfCnpjController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _acceptedResponsibilityTerm = false;
  String _personType = 'PF';
  String? _emailDelivery;
  String? _emailDevCode;
  String? _emailVerificationToken;

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cpfCnpjController.dispose();
    _emailController.dispose();
    _emailCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_emailVerificationToken == null) {
      _showError('Valide seu e-mail antes de concluir o cadastro');
      return;
    }
    if (!_acceptedResponsibilityTerm) {
      _showError('Aceite o termo de responsabilidade para criar a conta');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.registerCitizen(
        tipoPessoa: _personType,
        nome: _nameController.text,
        sobrenome: _surnameController.text,
        razaoSocial: _personType == 'PJ' ? _businessNameController.text : null,
        cpfCnpj: _cpfCnpjController.text,
        email: _emailController.text,
        senha: _passwordController.text,
        telefone: _phoneController.text,
        endereco: _addressController.text,
        emailVerificationToken: _emailVerificationToken!,
        responsibilityTermAccepted: _acceptedResponsibilityTerm,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastro realizado. Entre com seu e-mail e senha.'),
        ),
      );
      Navigator.pop(context);
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Não foi possível concluir o cadastro');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendEmailCode() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showError('Informe um e-mail válido');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _authService.startRegistrationEmailVerification(
        email,
      );
      setState(() {
        _emailDelivery = result.delivery;
        _emailDevCode = result.devCode;
        _emailVerificationToken = null;
        _emailCodeController.clear();
      });
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Não foi possível enviar o código de validação');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmEmailCode() async {
    final email = _emailController.text.trim();
    if (_emailCodeController.text.length != 6) {
      _showError('Informe o código de 6 dígitos');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _authService.confirmRegistrationEmailVerification(
        email,
        _emailCodeController.text,
      );
      setState(() {
        _emailVerificationToken = result.verificationToken;
      });
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Não foi possível validar o e-mail');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta de cidadão')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Validação de e-mail',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            enabled: _emailVerificationToken == null,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator:
                                (value) =>
                                    value!.isEmpty ? 'Informe o e-mail' : null,
                          ),
                          const SizedBox(height: 12),
                          if (_emailVerificationToken == null) ...[
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _sendEmailCode,
                              icon: const Icon(Icons.mark_email_read_outlined),
                              label: const Text('Enviar código'),
                            ),
                            if (_emailDelivery != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Código enviado para $_emailDelivery',
                                textAlign: TextAlign.center,
                              ),
                              if (_emailDevCode != null)
                                Text(
                                  'Código de teste: $_emailDevCode',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _emailCodeController,
                                maxLength: 6,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Código recebido',
                                  counterText: '',
                                  prefixIcon: Icon(Icons.verified_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed:
                                    _isLoading ? null : _confirmEmailCode,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Validar e-mail'),
                              ),
                            ],
                          ] else
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(child: Text('E-mail validado')),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AbsorbPointer(
                    absorbing: _emailVerificationToken == null,
                    child: Opacity(
                      opacity: _emailVerificationToken == null ? 0.55 : 1,
                      child: Column(
                        children: [
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'PF',
                                label: Text('Pessoa física'),
                                icon: Icon(Icons.person_outline),
                              ),
                              ButtonSegment(
                                value: 'PJ',
                                label: Text('Pessoa jurídica'),
                                icon: Icon(Icons.apartment_outlined),
                              ),
                            ],
                            selected: {_personType},
                            onSelectionChanged:
                                (value) =>
                                    setState(() => _personType = value.first),
                          ),
                          const SizedBox(height: 16),
                          if (_personType == 'PJ') ...[
                            TextFormField(
                              controller: _businessNameController,
                              decoration: const InputDecoration(
                                labelText: 'Razão social',
                              ),
                              validator:
                                  (value) =>
                                      _personType == 'PJ' && value!.isEmpty
                                          ? 'Informe a razão social'
                                          : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText:
                                  _personType == 'PJ'
                                      ? 'Responsável legal'
                                      : 'Nome',
                            ),
                            validator:
                                (value) =>
                                    value!.isEmpty ? 'Informe o nome' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _surnameController,
                            decoration: const InputDecoration(
                              labelText: 'Sobrenome',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _cpfCnpjController,
                            decoration: InputDecoration(
                              labelText: _personType == 'PJ' ? 'CNPJ' : 'CPF',
                            ),
                            keyboardType: TextInputType.number,
                            validator:
                                (value) =>
                                    value!.isEmpty
                                        ? 'Informe o documento'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Telefone',
                            ),
                            validator:
                                (value) =>
                                    value!.isEmpty
                                        ? 'Informe o telefone'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Endereço',
                            ),
                            validator:
                                (value) =>
                                    value!.isEmpty
                                        ? 'Informe o endereço'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed:
                                    () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                              ),
                            ),
                            validator:
                                (value) =>
                                    value!.length < 6
                                        ? 'A senha deve ter pelo menos 6 caracteres'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirmar senha',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed:
                                    () => setState(
                                      () =>
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword,
                                    ),
                              ),
                            ),
                            validator:
                                (value) =>
                                    value != _passwordController.text
                                        ? 'As senhas devem ser iguais'
                                        : null,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F8F5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFD8E0D8),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Termo de responsabilidade do cadastro',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                const Text(_responsibilityTerm),
                                const Divider(height: 20),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  value: _acceptedResponsibilityTerm,
                                  onChanged:
                                      (value) => setState(
                                        () =>
                                            _acceptedResponsibilityTerm =
                                                value ?? false,
                                      ),
                                  title: const Text(
                                    'Li e aceito o termo de responsabilidade pelas informações cadastradas.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _registerUser,
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text('Cadastrar'),
                          ),
                        ],
                      ),
                    ),
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
