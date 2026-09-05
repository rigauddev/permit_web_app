import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _acceptedResponsibilityTerm = false;
  bool _mfaEmailEnabled = false;
  String _personType = 'PF';
  String _residenceProofType = 'luz';
  XFile? _userPhoto;
  PlatformFile? _residenceProof;

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cpfCnpjController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userPhoto == null) {
      _showError('Inclua uma foto do usuário para concluir o cadastro.');
      return;
    }
    if (_residenceProof == null) {
      _showError('Inclua um comprovante de residência de água ou luz.');
      return;
    }
    if (_residenceProof!.bytes == null) {
      _showError('Não foi possível ler o comprovante selecionado.');
      return;
    }
    if (!_acceptedResponsibilityTerm) {
      _showError('Aceite o termo de responsabilidade para criar a conta');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final photoUpload = await _authService.uploadFileBytes(
        kind: 'usuarios/fotos',
        fileName: _userPhoto!.name,
        bytes: await _userPhoto!.readAsBytes(),
      );
      final residenceUpload = await _authService.uploadFileBytes(
        kind: 'usuarios/comprovantes',
        fileName: _residenceProof!.name,
        bytes: _residenceProof!.bytes!,
      );
      await _authService.registerCitizen(
        tipoPessoa: _personType,
        nome: _nameController.text.trim(),
        sobrenome: _surnameController.text.trim(),
        razaoSocial:
            _personType == 'PJ' ? _businessNameController.text.trim() : null,
        cpfCnpj: _onlyDigits(_cpfCnpjController.text),
        email:
            _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
        senha: _passwordController.text,
        telefone: _phoneController.text.trim(),
        endereco: _addressController.text.trim(),
        responsibilityTermAccepted: _acceptedResponsibilityTerm,
        userPhotoName: photoUpload['file_name']?.toString() ?? _userPhoto!.name,
        userPhotoUrl: photoUpload['file_url']?.toString(),
        residenceProofName:
            residenceUpload['file_name']?.toString() ?? _residenceProof!.name,
        residenceProofUrl: residenceUpload['file_url']?.toString(),
        residenceProofType: _residenceProofType,
        mfaEmailEnabled:
            _mfaEmailEnabled && _emailController.text.trim().isNotEmpty,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastro realizado. Entre com seu CPF/CNPJ e senha.'),
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

  Future<void> _pickUserPhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1400,
    );
    if (photo == null) return;
    setState(() => _userPhoto = photo);
  }

  Future<void> _pickResidenceProof() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _residenceProof = result.files.single);
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
    final emailFilled = _emailController.text.trim().isNotEmpty;
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
                            'Dados de identificação',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
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
                                      _personType == 'PJ' &&
                                              (value ?? '').trim().isEmpty
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
                                    (value ?? '').trim().isEmpty
                                        ? 'Informe o nome'
                                        : null,
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
                            validator: (value) {
                              final digits = _onlyDigits(value ?? '');
                              if (digits.isEmpty) return 'Informe o documento';
                              final valid =
                                  _personType == 'PJ'
                                      ? _isValidCnpj(digits)
                                      : _isValidCpf(digits);
                              return valid
                                  ? null
                                  : '${_personType == 'PJ' ? 'CNPJ' : 'CPF'} informado está incorreto';
                            },
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
                                    (value ?? '').trim().isEmpty
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
                                    (value ?? '').trim().isEmpty
                                        ? 'Informe o endereço'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'E-mail (opcional)',
                              helperText:
                                  'Informe e-mail somente se quiser receber notificações ou ativar MFA por e-mail.',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              final email = (value ?? '').trim();
                              if (email.isEmpty) return null;
                              return email.contains('@')
                                  ? null
                                  : 'Informe um e-mail válido';
                            },
                          ),
                          if (emailFilled)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _mfaEmailEnabled,
                              onChanged:
                                  (value) => setState(
                                    () => _mfaEmailEnabled = value ?? false,
                                  ),
                              title: const Text(
                                'Ativar MFA por e-mail nesta conta',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Foto e comprovante de residência',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Inclua uma foto tirada pela câmera do aparelho para identificação do usuário.',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _pickUserPhoto,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: Text(
                              _userPhoto == null
                                  ? 'Tirar foto'
                                  : _userPhoto!.name,
                            ),
                          ),
                          const Divider(height: 28),
                          const Text(
                            'Comprovante obrigatório em nome do usuário, pai ou mãe. Serão aceitas somente contas de água ou luz.',
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _residenceProofType,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de comprovante',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'luz',
                                child: Text('Conta de luz'),
                              ),
                              DropdownMenuItem(
                                value: 'agua',
                                child: Text('Conta de água'),
                              ),
                            ],
                            onChanged:
                                (value) => setState(
                                  () => _residenceProofType = value ?? 'luz',
                                ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _pickResidenceProof,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: Text(
                              _residenceProof == null
                                  ? 'Anexar comprovante'
                                  : _residenceProof!.name,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'A pré-validação confere o tipo informado e indícios no nome do arquivo. A leitura automática do conteúdo do comprovante será conectada na etapa de OCR.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                    (value ?? '').length < 6
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F8F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD8E0D8)),
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
                          controlAffinity: ListTileControlAffinity.leading,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Cadastrar'),
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
