import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth_service.dart';
import '../../core/orla_api_service.dart';
import '../../core/permit_api_service.dart';

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
  final _addressNumberController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController(text: 'Valença');
  final _stateController = TextEditingController(text: 'BA');
  final _cepController = TextEditingController();
  final _cpfCnpjController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _stayAddressController = TextEditingController();
  final _stayNumberController = TextEditingController();
  final _stayNeighborhoodController = TextEditingController();
  final _stayCityController = TextEditingController(text: 'Valença');
  final _stayStateController = TextEditingController(text: 'BA');
  final _stayCepController = TextEditingController();
  final _stayStartController = TextEditingController();
  final _stayEndController = TextEditingController();
  final _newInnNameController = TextEditingController();
  final _newInnPhoneController = TextEditingController();
  final _hotelNameController = TextEditingController();
  final _hotelCapacityController = TextEditingController();
  final _hotelGuestCapacityController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();

  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _loadingMessage = 'Preparando cadastro...';
  bool _acceptedResponsibilityTerm = false;
  bool _mfaEmailEnabled = false;
  String? _businessCategory;
  String _personType = 'PF';
  String _citizenType = 'morador';
  String _stayType = 'casa_aluguel';
  String _vehicleColor = 'Branco';
  String _residenceProofType = 'luz';
  XFile? _userPhoto;
  PlatformFile? _identityDocument;
  PlatformFile? _residenceProof;
  PlatformFile? _businessPermit;
  DateTimeRange? _stayRange;
  List<Map<String, dynamic>> _inns = const [];
  int? _selectedInnId;
  bool _newInnBeachfront = false;
  bool _orlaAccessRequested = false;
  String? _addressLatitude;
  String? _addressLongitude;
  String? _stayLatitude;
  String? _stayLongitude;

  bool get _isTouristCompany =>
      _citizenType == 'turista' && _personType == 'PJ';

  bool get _isTourismBusiness =>
      {'pousada_hotel', 'restaurante', 'quiosque'}.contains(_businessCategory);

  String get _tourismBusinessLabel {
    switch (_businessCategory) {
      case 'pousada_hotel':
        return 'pousada/hotel';
      case 'restaurante':
        return 'restaurante';
      case 'quiosque':
        return 'quiosque';
      default:
        return 'estabelecimento';
    }
  }

  String get _managedEstablishmentName {
    final customName = _hotelNameController.text.trim();
    if (customName.isNotEmpty) return customName;
    final businessName = _businessNameController.text.trim();
    if (businessName.isNotEmpty) return businessName;
    return _nameController.text.trim();
  }

  static const _vehicleBrands = {
    'Chevrolet': ['Onix', 'Prisma', 'S10', 'Tracker', 'Spin'],
    'Fiat': ['Argo', 'Cronos', 'Mobi', 'Strada', 'Toro', 'Uno'],
    'Ford': ['Ka', 'Fiesta', 'EcoSport', 'Ranger'],
    'Honda': ['Civic', 'City', 'Fit', 'HR-V'],
    'Hyundai': ['HB20', 'Creta', 'Tucson'],
    'Jeep': ['Compass', 'Renegade', 'Commander'],
    'Nissan': ['Kicks', 'March', 'Versa', 'Frontier'],
    'Renault': ['Duster', 'Kwid', 'Logan', 'Sandero'],
    'Toyota': ['Corolla', 'Etios', 'Hilux', 'SW4', 'Yaris'],
    'Volkswagen': ['Gol', 'Polo', 'Saveiro', 'T-Cross', 'Voyage'],
  };
  static const _vehicleColors = [
    'Branco',
    'Preto',
    'Prata',
    'Cinza',
    'Vermelho',
    'Azul',
    'Marrom',
    'Verde',
    'Amarelo',
    'Bege',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _addressNumberController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _cepController.dispose();
    _cpfCnpjController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _stayAddressController.dispose();
    _stayNumberController.dispose();
    _stayNeighborhoodController.dispose();
    _stayCityController.dispose();
    _stayStateController.dispose();
    _stayCepController.dispose();
    _stayStartController.dispose();
    _stayEndController.dispose();
    _newInnNameController.dispose();
    _newInnPhoneController.dispose();
    _hotelNameController.dispose();
    _hotelCapacityController.dispose();
    _hotelGuestCapacityController.dispose();
    _vehiclePlateController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _vehicleBrandController.text = _vehicleBrands.keys.first;
    _vehicleModelController.text = _vehicleBrands.values.first.first;
    _loadInns();
  }

  Future<void> _loadInns() async {
    try {
      final inns = await OrlaApiService().listInns();
      if (!mounted) return;
      setState(() {
        _inns = inns;
        _selectedInnId = null;
      });
    } catch (_) {}
  }

  void _setLoadingStage(String message) {
    if (!mounted) return;
    setState(() => _loadingMessage = message);
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    final isResident = _citizenType == 'morador';
    final isCompany = _personType == 'PJ';
    final isTouristCompany = _isTouristCompany;
    if (isCompany &&
        !isTouristCompany &&
        isResident &&
        _businessPermit == null) {
      _showError('Anexe o alvará da pessoa jurídica para concluir o cadastro.');
      return;
    }
    if (_citizenType == 'turista' && _stayRange == null) {
      _showError('Selecione o período da estadia no calendário.');
      return;
    }
    if (!isCompany && isResident && _userPhoto == null) {
      _showError('Inclua uma foto do usuário para concluir o cadastro.');
      return;
    }
    if (!isCompany && isResident && _residenceProof == null) {
      _showError('Inclua um comprovante de residência de água ou luz.');
      return;
    }
    if (!isCompany && isResident && _identityDocument == null) {
      _showError('Inclua RG ou CNH do usuário.');
      return;
    }
    if (!isCompany && isResident && _residenceProof!.bytes == null) {
      _showError('Não foi possível ler o comprovante selecionado.');
      return;
    }
    if (isCompany &&
        !isTouristCompany &&
        isResident &&
        _businessPermit!.bytes == null) {
      _showError('Não foi possível ler o alvará selecionado.');
      return;
    }
    if (isCompany && isResident && _isTourismBusiness && _orlaAccessRequested) {
      if (_addressLatitude == null || _addressLongitude == null) {
        _showError(
          'Busque e selecione o endereço do estabelecimento para validar a geolocalização da Orla.',
        );
        return;
      }
    }
    if (!_acceptedResponsibilityTerm) {
      _showError('Aceite o termo de responsabilidade para criar a conta');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Organizando as informações do cadastro...';
    });
    try {
      Map<String, dynamic>? photoUpload;
      Map<String, dynamic>? identityUpload;
      Map<String, dynamic>? residenceUpload;
      Map<String, dynamic>? businessPermitUpload;
      if (_userPhoto != null) {
        _setLoadingStage('Enviando foto do usuário...');
        photoUpload = await _authService.uploadFileBytes(
          kind: 'usuarios/fotos',
          fileName: _userPhoto!.name,
          bytes: await _userPhoto!.readAsBytes(),
        );
      }
      if (_residenceProof != null && _residenceProof!.bytes != null) {
        _setLoadingStage('Anexando comprovante de residência...');
        residenceUpload = await _authService.uploadFileBytes(
          kind: 'usuarios/comprovantes',
          fileName: _residenceProof!.name,
          bytes: _residenceProof!.bytes!,
        );
      }
      if (_identityDocument != null && _identityDocument!.bytes != null) {
        _setLoadingStage('Anexando documento de identificação...');
        identityUpload = await _authService.uploadFileBytes(
          kind: 'usuarios/documentos',
          fileName: _identityDocument!.name,
          bytes: _identityDocument!.bytes!,
        );
      }
      if (_businessPermit != null && _businessPermit!.bytes != null) {
        _setLoadingStage('Anexando alvará da pessoa jurídica...');
        businessPermitUpload = await _authService.uploadFileBytes(
          kind: 'usuarios/alvaras',
          fileName: _businessPermit!.name,
          bytes: _businessPermit!.bytes!,
        );
      }
      _setLoadingStage('Validando dados e criando sua conta...');
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
        endereco: _composeAddress(
          street: _addressController.text,
          number: _addressNumberController.text,
          neighborhood: _neighborhoodController.text,
          city: _cityController.text,
          state: _stateController.text,
        ),
        cep: _cepController.text.trim(),
        enderecoLatitude: _addressLatitude,
        enderecoLongitude: _addressLongitude,
        tipoUsuario: _citizenType,
        businessCategory: _isTouristCompany ? null : _businessCategory,
        managedInnName: _isTourismBusiness ? _managedEstablishmentName : null,
        managedInnCapacity:
            _businessCategory == 'pousada_hotel'
                ? int.tryParse(_onlyDigits(_hotelCapacityController.text))
                : null,
        managedInnGuestCapacity:
            _businessCategory == 'pousada_hotel'
                ? int.tryParse(_onlyDigits(_hotelGuestCapacityController.text))
                : null,
        tipoEstadia: _citizenType == 'turista' ? _stayType : null,
        estadiaEndereco:
            _citizenType == 'turista' && _stayType == 'casa_aluguel'
                ? _composeAddress(
                  street: _stayAddressController.text,
                  number: _stayNumberController.text,
                  neighborhood: _stayNeighborhoodController.text,
                  city: _stayCityController.text,
                  state: _stayStateController.text,
                )
                : _citizenType == 'turista' &&
                    _stayType == 'pousada' &&
                    _selectedInnId == null &&
                    _newInnNameController.text.trim().isNotEmpty
                ? 'Pousada/hotel: ${_newInnNameController.text.trim()} • Telefone: ${_newInnPhoneController.text.trim()}'
                : null,
        estadiaCep:
            _citizenType == 'turista' && _stayType == 'casa_aluguel'
                ? _stayCepController.text.trim()
                : null,
        estadiaLatitude: _stayLatitude,
        estadiaLongitude: _stayLongitude,
        estadiaInicio:
            _citizenType == 'turista' && _stayRange != null
                ? _dateToIso(_stayRange!.start)
                : null,
        estadiaFim:
            _citizenType == 'turista' && _stayRange != null
                ? _dateToIso(_stayRange!.end)
                : null,
        pousadaId:
            _citizenType == 'turista' && _stayType == 'pousada'
                ? _selectedInnId
                : null,
        orlaAccessRequested:
            (isCompany &&
                isResident &&
                _isTourismBusiness &&
                _orlaAccessRequested) ||
            (_citizenType == 'turista' &&
                _stayType == 'pousada' &&
                (_orlaAccessRequested || _newInnBeachfront)),
        orlaVehicle:
            _citizenType == 'turista'
                ? {
                  'plate': _vehiclePlateController.text.trim(),
                  'brand': _vehicleBrandController.text.trim(),
                  'model': _vehicleModelController.text.trim(),
                  'color': _vehicleColor,
                  'establishment_name': _selectedInnName(),
                }
                : null,
        responsibilityTermAccepted: _acceptedResponsibilityTerm,
        userPhotoName:
            photoUpload?['file_name']?.toString() ?? _userPhoto?.name ?? '',
        userPhotoUrl: photoUpload?['file_url']?.toString(),
        identityDocumentName:
            identityUpload?['file_name']?.toString() ?? _identityDocument?.name,
        identityDocumentUrl: identityUpload?['file_url']?.toString(),
        identityDocumentType: 'rg_cnh',
        residenceProofName:
            residenceUpload?['file_name']?.toString() ??
            _residenceProof?.name ??
            '',
        residenceProofUrl: residenceUpload?['file_url']?.toString(),
        residenceProofType: _residenceProofType,
        businessPermitName:
            businessPermitUpload?['file_name']?.toString() ??
            _businessPermit?.name,
        businessPermitUrl: businessPermitUpload?['file_url']?.toString(),
        mfaEmailEnabled:
            _mfaEmailEnabled && _emailController.text.trim().isNotEmpty,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadingMessage = 'Cadastro concluído.';
      });
      await _showMessage(
        title: 'Cadastro realizado',
        message: 'Sua conta foi criada. Entre com seu CPF/CNPJ e senha.',
        icon: Icons.check_circle_outline,
        isError: false,
      );
      if (mounted) Navigator.pop(context);
    } on AuthException catch (error) {
      if (mounted) setState(() => _isLoading = false);
      _showError(error.message);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
      _showError('Não foi possível concluir o cadastro');
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
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

  Future<void> _pickIdentityDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _identityDocument = result.files.single);
  }

  Future<void> _pickBusinessPermit() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _businessPermit = result.files.single);
  }

  Future<void> _pickStayRange() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _stayRange,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      helpText: 'Selecione o período da estadia',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      saveText: 'Aplicar',
      builder:
          (context, child) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
              child: Material(
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ),
    );
    if (selected == null) return;
    setState(() {
      _stayRange = DateTimeRange(
        start: DateUtils.dateOnly(selected.start),
        end: DateUtils.dateOnly(selected.end),
      );
      _stayStartController.text = _formatDate(_stayRange!.start);
      _stayEndController.text = _formatDate(_stayRange!.end);
    });
  }

  String _composeAddress({
    required String street,
    required String number,
    required String neighborhood,
    required String city,
    required String state,
  }) {
    final first = [
      street.trim(),
      number.trim(),
    ].where((v) => v.isNotEmpty).join(', ');
    final second = [
      neighborhood.trim(),
      city.trim(),
    ].where((v) => v.isNotEmpty).join(', ');
    return [first, second, state.trim()].where((v) => v.isNotEmpty).join(' - ');
  }

  Future<void> _lookupCep({
    required TextEditingController cepController,
    required TextEditingController streetController,
    required TextEditingController neighborhoodController,
    required TextEditingController cityController,
    required TextEditingController stateController,
  }) async {
    final cep = _onlyDigits(cepController.text);
    if (cep.length != 8) {
      _showError('Informe um CEP válido com 8 números.');
      return;
    }
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Buscando endereço pelo CEP...';
    });
    try {
      final data = await PermitApiService().lookupCep(cep);
      if (!mounted) return;
      if (data == null) {
        _showError('CEP não encontrado.');
        return;
      }
      setState(() {
        streetController.text =
            data['logradouro']?.toString() ?? streetController.text;
        neighborhoodController.text =
            data['bairro']?.toString() ?? neighborhoodController.text;
        cityController.text =
            data['localidade']?.toString() ?? cityController.text;
        stateController.text = data['uf']?.toString() ?? stateController.text;
      });
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fillAddressFieldsFromSearch({
    required Map<String, dynamic> selected,
    required TextEditingController streetController,
    required TextEditingController? cepController,
    required TextEditingController? neighborhoodController,
    required TextEditingController? cityController,
    required TextEditingController? stateController,
  }) {
    final address = selected['address'];
    if (address is Map) {
      final road =
          address['road'] ??
          address['pedestrian'] ??
          address['residential'] ??
          address['path'];
      final neighborhood =
          address['suburb'] ??
          address['neighbourhood'] ??
          address['city_district'];
      final city =
          address['city'] ??
          address['town'] ??
          address['village'] ??
          address['municipality'];
      final state = address['state_code'] ?? address['state'];
      streetController.text =
          road?.toString() ??
          selected['display_name']?.toString() ??
          streetController.text;
      if (cepController != null && address['postcode'] != null) {
        cepController.text = _formatCep(
          _onlyDigits(address['postcode'].toString()),
        );
      }
      if (neighborhoodController != null && neighborhood != null) {
        neighborhoodController.text = neighborhood.toString();
      }
      if (cityController != null && city != null) {
        cityController.text = city.toString();
      }
      if (stateController != null && state != null) {
        final value = state.toString();
        stateController.text = value.length == 2 ? value.toUpperCase() : value;
      }
    } else {
      streetController.text =
          selected['display_name']?.toString() ?? streetController.text;
    }
  }

  Future<void> _searchAddress({
    required TextEditingController addressController,
    TextEditingController? cepController,
    TextEditingController? neighborhoodController,
    TextEditingController? cityController,
    TextEditingController? stateController,
    required void Function(String? lat, String? lon) onCoordinates,
  }) async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) =>
              _AddressSearchDialog(initialQuery: addressController.text.trim()),
    );
    if (selected == null) return;
    setState(() {
      _fillAddressFieldsFromSearch(
        selected: selected,
        streetController: addressController,
        cepController: cepController,
        neighborhoodController: neighborhoodController,
        cityController: cityController,
        stateController: stateController,
      );
      onCoordinates(selected['lat']?.toString(), selected['lon']?.toString());
    });
  }

  String? _selectedInnName() {
    if (_selectedInnId == null &&
        _newInnNameController.text.trim().isNotEmpty) {
      return _newInnNameController.text.trim();
    }
    for (final inn in _inns) {
      if (inn['id'] == _selectedInnId) return inn['name']?.toString();
    }
    return null;
  }

  bool _selectedInnIsBeachfront() {
    for (final inn in _inns) {
      if (inn['id'] == _selectedInnId) return inn['beachfront'] == true;
    }
    return false;
  }

  Future<void> _showMessage({
    required String title,
    required String message,
    required IconData icon,
    required bool isError,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            icon: Icon(
              icon,
              color:
                  isError
                      ? Theme.of(ctx).colorScheme.error
                      : const Color(0xFF0E5F2F),
              size: 40,
            ),
            title: Text(title, textAlign: TextAlign.center),
            content: Text(message, textAlign: TextAlign.center),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendi'),
              ),
            ],
          ),
    );
  }

  void _showError(String message) {
    _showMessage(
      title: 'Atenção',
      message: message,
      icon: Icons.info_outline,
      isError: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final emailFilled = _emailController.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta de cidadão')),
      body: Stack(
        children: [
          Center(
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
                                    value: 'morador',
                                    label: Text('Morador'),
                                    icon: Icon(Icons.home_outlined),
                                  ),
                                  ButtonSegment(
                                    value: 'turista',
                                    label: Text('Turista'),
                                    icon: Icon(Icons.beach_access_outlined),
                                  ),
                                ],
                                selected: {_citizenType},
                                onSelectionChanged:
                                    (value) => setState(() {
                                      _citizenType = value.first;
                                      if (_isTouristCompany) {
                                        _businessCategory = null;
                                      }
                                    }),
                              ),
                              const SizedBox(height: 16),
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
                                    (value) => setState(() {
                                      _personType = value.first;
                                      if (_isTouristCompany) {
                                        _businessCategory = null;
                                      }
                                    }),
                              ),
                              const SizedBox(height: 16),
                              if (_personType == 'PJ' &&
                                  !_isTouristCompany) ...[
                                TextFormField(
                                  controller: _businessNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Razão social',
                                  ),
                                  validator:
                                      (value) =>
                                          _personType == 'PJ' &&
                                                  !_isTouristCompany &&
                                                  (value ?? '').trim().isEmpty
                                              ? 'Informe a razão social'
                                              : null,
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (!_isTouristCompany)
                                DropdownButtonFormField<String?>(
                                  initialValue: _businessCategory,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Tipo de estabelecimento (opcional)',
                                    helperText:
                                        'Disponível para morador PJ. Turista PJ informa a pousada no card de estadia.',
                                  ),
                                  items: const [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text(
                                        'Não é estabelecimento turístico',
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'pousada_hotel',
                                      child: Text('Pousada / hotel'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'restaurante',
                                      child: Text('Restaurante'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'quiosque',
                                      child: Text('Quiosque'),
                                    ),
                                  ],
                                  onChanged:
                                      (value) => setState(() {
                                        _businessCategory = value;
                                        if (value == null) {
                                          _hotelNameController.clear();
                                          _hotelCapacityController.clear();
                                          _hotelGuestCapacityController.clear();
                                          _orlaAccessRequested = false;
                                        } else if (value != 'pousada_hotel') {
                                          _hotelCapacityController.clear();
                                          _hotelGuestCapacityController.clear();
                                        }
                                      }),
                                ),
                              if (_isTourismBusiness) ...[
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _hotelNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Nome do $_tourismBusinessLabel',
                                  ),
                                  validator: (value) {
                                    if (!_isTourismBusiness) return null;
                                    if ((value ?? '').trim().isEmpty &&
                                        _businessNameController.text
                                            .trim()
                                            .isEmpty) {
                                      return 'Informe o nome do $_tourismBusinessLabel';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _orlaAccessRequested,
                                  title: const Text(
                                    'Este estabelecimento fica na área da Orla',
                                  ),
                                  subtitle: const Text(
                                    'Ao marcar, busque e selecione o endereço para salvar a geolocalização e validar automaticamente.',
                                  ),
                                  onChanged:
                                      (value) => setState(
                                        () =>
                                            _orlaAccessRequested =
                                                value ?? false,
                                      ),
                                ),
                                if (_orlaAccessRequested &&
                                    (_addressLatitude == null ||
                                        _addressLongitude == null))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'Use a busca por CEP ou rua no endereço para capturar a localização.',
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (_businessCategory == 'pousada_hotel') ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _hotelCapacityController,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Vagas de estacionamento da pousada/hotel',
                                      helperText:
                                          'Informe quantos veículos o estacionamento comporta.',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (value) {
                                      if (_businessCategory !=
                                          'pousada_hotel') {
                                        return null;
                                      }
                                      final amount = int.tryParse(
                                        _onlyDigits(value ?? ''),
                                      );
                                      if (amount == null || amount <= 0) {
                                        return 'Informe a quantidade de vagas';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _hotelGuestCapacityController,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Capacidade de hóspedes (opcional)',
                                      helperText:
                                          'Use se quiser acompanhar lotação de hóspedes no dashboard.',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  ),
                                ],
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
                                        !_isTouristCompany &&
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
                                  labelText:
                                      _personType == 'PJ' ? 'CNPJ' : 'CPF',
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  _CpfCnpjInputFormatter(
                                    isCnpj: _personType == 'PJ',
                                  ),
                                ],
                                validator: (value) {
                                  final digits = _onlyDigits(value ?? '');
                                  if (digits.isEmpty) {
                                    return 'Informe o documento';
                                  }
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
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  _PhoneInputFormatter(),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Telefone',
                                ),
                                validator: (value) {
                                  final digits = _onlyDigits(value ?? '');
                                  if (_isTouristCompany && digits.isEmpty) {
                                    return null;
                                  }
                                  if (digits.isEmpty) {
                                    return 'Informe o telefone';
                                  }
                                  return digits.length < 10
                                      ? 'Informe um telefone válido'
                                      : null;
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cepController,
                                      decoration: const InputDecoration(
                                        labelText: 'CEP',
                                        hintText: '00000-000',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        _CepInputFormatter(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    onPressed:
                                        _isLoading
                                            ? null
                                            : () => _lookupCep(
                                              cepController: _cepController,
                                              streetController:
                                                  _addressController,
                                              neighborhoodController:
                                                  _neighborhoodController,
                                              cityController: _cityController,
                                              stateController: _stateController,
                                            ),
                                    icon: const Icon(Icons.travel_explore),
                                    label: const Text('Buscar CEP'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: _addressController,
                                      decoration: const InputDecoration(
                                        labelText: 'Rua / logradouro',
                                        helperText:
                                            'Pesquise pelo nome da rua ou informe manualmente.',
                                      ),
                                      validator:
                                          (value) =>
                                              !_isTouristCompany &&
                                                      (value ?? '')
                                                          .trim()
                                                          .isEmpty
                                                  ? 'Informe a rua'
                                                  : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _addressNumberController,
                                      decoration: const InputDecoration(
                                        labelText: 'Número',
                                      ),
                                      validator:
                                          (value) =>
                                              !_isTouristCompany &&
                                                      (value ?? '')
                                                          .trim()
                                                          .isEmpty
                                                  ? 'Informe o número'
                                                  : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _neighborhoodController,
                                decoration: const InputDecoration(
                                  labelText: 'Bairro',
                                ),
                                validator:
                                    (value) =>
                                        !_isTouristCompany &&
                                                (value ?? '').trim().isEmpty
                                            ? 'Informe o bairro'
                                            : null,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _cityController,
                                      decoration: const InputDecoration(
                                        labelText: 'Cidade',
                                      ),
                                      validator:
                                          (value) =>
                                              !_isTouristCompany &&
                                                      (value ?? '')
                                                          .trim()
                                                          .isEmpty
                                                  ? 'Informe a cidade'
                                                  : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _stateController,
                                      decoration: const InputDecoration(
                                        labelText: 'Estado',
                                        hintText: 'BA',
                                      ),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      validator:
                                          (value) =>
                                              !_isTouristCompany &&
                                                      (value ?? '')
                                                          .trim()
                                                          .isEmpty
                                                  ? 'Informe o estado'
                                                  : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed:
                                      () => _searchAddress(
                                        addressController: _addressController,
                                        cepController: _cepController,
                                        neighborhoodController:
                                            _neighborhoodController,
                                        cityController: _cityController,
                                        stateController: _stateController,
                                        onCoordinates: (lat, lon) {
                                          _addressLatitude = lat;
                                          _addressLongitude = lon;
                                        },
                                      ),
                                  icon: const Icon(Icons.search),
                                  label: const Text(
                                    'Pesquisar pelo nome da rua ou endereço completo',
                                  ),
                                ),
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
                                  return _isValidEmail(email)
                                      ? null
                                      : 'Informe um e-mail válido';
                                },
                              ),
                              if (emailFilled)
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
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
                      if (_citizenType == 'turista') ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Estadia do turista',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 12),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'casa_aluguel',
                                      label: Text('Casa de aluguel'),
                                      icon: Icon(Icons.house_outlined),
                                    ),
                                    ButtonSegment(
                                      value: 'pousada',
                                      label: Text('Pousada/hotel'),
                                      icon: Icon(Icons.hotel_outlined),
                                    ),
                                  ],
                                  selected: {_stayType},
                                  onSelectionChanged:
                                      (value) => setState(
                                        () => _stayType = value.first,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _pickStayRange,
                                  icon: const Icon(
                                    Icons.calendar_month_outlined,
                                  ),
                                  label: Text(
                                    _stayRange == null
                                        ? 'Selecionar início e fim da estadia'
                                        : '${_formatDate(_stayRange!.start)} até ${_formatDate(_stayRange!.end)}',
                                  ),
                                ),
                                FormField<DateTimeRange>(
                                  validator:
                                      (_) =>
                                          _citizenType == 'turista' &&
                                                  _stayRange == null
                                              ? 'Selecione o período da estadia'
                                              : null,
                                  builder:
                                      (field) =>
                                          field.hasError
                                              ? Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 6,
                                                  left: 12,
                                                ),
                                                child: Text(
                                                  field.errorText!,
                                                  style: TextStyle(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.error,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              )
                                              : const SizedBox.shrink(),
                                ),
                                const SizedBox(height: 12),
                                if (_stayType == 'casa_aluguel') ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _stayCepController,
                                          decoration: const InputDecoration(
                                            labelText: 'CEP da estadia',
                                            hintText: '00000-000',
                                          ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            _CepInputFormatter(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        onPressed:
                                            _isLoading
                                                ? null
                                                : () => _lookupCep(
                                                  cepController:
                                                      _stayCepController,
                                                  streetController:
                                                      _stayAddressController,
                                                  neighborhoodController:
                                                      _stayNeighborhoodController,
                                                  cityController:
                                                      _stayCityController,
                                                  stateController:
                                                      _stayStateController,
                                                ),
                                        icon: const Icon(Icons.travel_explore),
                                        label: const Text('Buscar CEP'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          controller: _stayAddressController,
                                          decoration: const InputDecoration(
                                            labelText: 'Rua / logradouro',
                                          ),
                                          validator:
                                              (value) =>
                                                  _citizenType == 'turista' &&
                                                          _stayType ==
                                                              'casa_aluguel' &&
                                                          (value ?? '')
                                                              .trim()
                                                              .isEmpty
                                                      ? 'Informe a rua da estadia'
                                                      : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _stayNumberController,
                                          decoration: const InputDecoration(
                                            labelText: 'Número',
                                          ),
                                          validator:
                                              (value) =>
                                                  _citizenType == 'turista' &&
                                                          _stayType ==
                                                              'casa_aluguel' &&
                                                          (value ?? '')
                                                              .trim()
                                                              .isEmpty
                                                      ? 'Informe o número'
                                                      : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _stayNeighborhoodController,
                                    decoration: const InputDecoration(
                                      labelText: 'Bairro',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: _stayCityController,
                                          decoration: const InputDecoration(
                                            labelText: 'Cidade',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _stayStateController,
                                          decoration: const InputDecoration(
                                            labelText: 'Estado',
                                          ),
                                          textCapitalization:
                                              TextCapitalization.characters,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed:
                                          () => _searchAddress(
                                            addressController:
                                                _stayAddressController,
                                            cepController: _stayCepController,
                                            neighborhoodController:
                                                _stayNeighborhoodController,
                                            cityController: _stayCityController,
                                            stateController:
                                                _stayStateController,
                                            onCoordinates: (lat, lon) {
                                              _stayLatitude = lat;
                                              _stayLongitude = lon;
                                            },
                                          ),
                                      icon: const Icon(Icons.search),
                                      label: const Text(
                                        'Buscar rua ou endereço',
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  DropdownButtonFormField<int>(
                                    initialValue: _selectedInnId,
                                    decoration: const InputDecoration(
                                      labelText: 'Pousada ou hotel',
                                    ),
                                    items: [
                                      const DropdownMenuItem<int>(
                                        value: null,
                                        child: Text('Não está na lista'),
                                      ),
                                      ..._inns.map(
                                        (inn) => DropdownMenuItem<int>(
                                          value: inn['id'] as int?,
                                          child: Text(
                                            inn['name']?.toString() ?? '',
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged:
                                        (value) => setState(
                                          () => _selectedInnId = value,
                                        ),
                                    validator:
                                        (value) =>
                                            _citizenType == 'turista' &&
                                                    _stayType == 'pousada' &&
                                                    value == null &&
                                                    _newInnNameController.text
                                                        .trim()
                                                        .isEmpty
                                                ? 'Selecione a pousada ou informe o nome'
                                                : null,
                                  ),
                                  if (_selectedInnIsBeachfront()) ...[
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed:
                                          () => setState(
                                            () => _orlaAccessRequested = true,
                                          ),
                                      icon: const Icon(
                                        Icons.assignment_turned_in_outlined,
                                      ),
                                      label: Text(
                                        _orlaAccessRequested
                                            ? 'Solicitação de acesso à Orla marcada'
                                            : 'Enviar solicitação de acesso à Orla',
                                      ),
                                    ),
                                  ],
                                  const Divider(height: 28),
                                  TextFormField(
                                    controller: _newInnNameController,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Nome da pousada/hotel se não estiver na lista',
                                    ),
                                    validator:
                                        (value) =>
                                            _citizenType == 'turista' &&
                                                    _stayType == 'pousada' &&
                                                    _selectedInnId == null &&
                                                    (value ?? '').trim().isEmpty
                                                ? 'Informe o nome da pousada/hotel'
                                                : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _newInnPhoneController,
                                    decoration: const InputDecoration(
                                      labelText: 'Telefone da pousada/hotel',
                                    ),
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      _PhoneInputFormatter(),
                                    ],
                                    validator:
                                        (value) =>
                                            _citizenType == 'turista' &&
                                                    _stayType == 'pousada' &&
                                                    _selectedInnId == null &&
                                                    _onlyDigits(
                                                          value ?? '',
                                                        ).length <
                                                        10
                                                ? 'Informe o telefone da pousada/hotel'
                                                : null,
                                  ),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: _newInnBeachfront,
                                    onChanged:
                                        (value) => setState(() {
                                          _newInnBeachfront = value ?? false;
                                          if (_newInnBeachfront) {
                                            _orlaAccessRequested = true;
                                          }
                                        }),
                                    title: const Text('Pousada/hotel na orla'),
                                    subtitle: const Text(
                                      'Ao concluir, será enviada solicitação de liberação de acesso à Orla para validação.',
                                    ),
                                  ),
                                ],
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
                                  'Veículo para acesso à Orla',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _vehiclePlateController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    labelText: 'Placa',
                                    hintText: 'ABC1D23',
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp('[a-zA-Z0-9-]'),
                                    ),
                                    LengthLimitingTextInputFormatter(8),
                                  ],
                                  validator:
                                      (value) =>
                                          _citizenType == 'turista' &&
                                                  !_isValidPlate(value ?? '')
                                              ? 'Informe uma placa válida'
                                              : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _vehicleBrandController.text,
                                  decoration: const InputDecoration(
                                    labelText: 'Marca',
                                  ),
                                  items:
                                      _vehicleBrands.keys
                                          .map(
                                            (brand) => DropdownMenuItem(
                                              value: brand,
                                              child: Text(brand),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (value) => setState(() {
                                        _vehicleBrandController.text =
                                            value ?? _vehicleBrands.keys.first;
                                        _vehicleModelController.text =
                                            _vehicleBrands[_vehicleBrandController
                                                    .text]!
                                                .first;
                                      }),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _vehicleModelController.text,
                                  decoration: const InputDecoration(
                                    labelText: 'Modelo',
                                  ),
                                  items:
                                      (_vehicleBrands[_vehicleBrandController
                                                  .text] ??
                                              const <String>[])
                                          .map(
                                            (model) => DropdownMenuItem(
                                              value: model,
                                              child: Text(model),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (value) => setState(
                                        () =>
                                            _vehicleModelController.text =
                                                value ?? '',
                                      ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _vehicleColor,
                                  decoration: const InputDecoration(
                                    labelText: 'Cor',
                                  ),
                                  items:
                                      _vehicleColors
                                          .map(
                                            (color) => DropdownMenuItem(
                                              value: color,
                                              child: Text(color),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (value) => setState(
                                        () => _vehicleColor = value ?? 'Branco',
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child:
                              _personType == 'PJ'
                                  ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Alvará da pessoa jurídica',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Para pessoa jurídica, anexe apenas o alvará de funcionamento. Foto e comprovante de residência não são exigidos.',
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed:
                                            _isLoading
                                                ? null
                                                : _pickBusinessPermit,
                                        icon: const Icon(
                                          Icons.assignment_outlined,
                                        ),
                                        label: Text(
                                          _businessPermit == null
                                              ? 'Anexar alvará'
                                              : _businessPermit!.name,
                                        ),
                                      ),
                                    ],
                                  )
                                  : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Foto e comprovante de residência',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Inclua uma foto tirada pela câmera do aparelho para identificação do usuário.',
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed:
                                            _isLoading ? null : _pickUserPhoto,
                                        icon: const Icon(
                                          Icons.photo_camera_outlined,
                                        ),
                                        label: Text(
                                          _userPhoto == null
                                              ? 'Tirar foto'
                                              : _userPhoto!.name,
                                        ),
                                      ),
                                      const Divider(height: 28),
                                      const Text(
                                        'Anexe RG ou CNH. Para moradores, este documento é obrigatório.',
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed:
                                            _isLoading
                                                ? null
                                                : _pickIdentityDocument,
                                        icon: const Icon(Icons.badge_outlined),
                                        label: Text(
                                          _identityDocument == null
                                              ? 'Anexar RG ou CNH'
                                              : _identityDocument!.name,
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
                                              () =>
                                                  _residenceProofType =
                                                      value ?? 'luz',
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed:
                                            _isLoading
                                                ? null
                                                : _pickResidenceProof,
                                        icon: const Icon(
                                          Icons.upload_file_outlined,
                                        ),
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
                                              _obscurePassword =
                                                  !_obscurePassword,
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
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _registerUser,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Concluir cadastro'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading) _RegistrationLoadingOverlay(message: _loadingMessage),
        ],
      ),
    );
  }
}

String _onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

String _formatCep(String value) {
  final limited = value.length > 8 ? value.substring(0, 8) : value;
  if (limited.length <= 5) return limited;
  return '${limited.substring(0, 5)}-${limited.substring(5)}';
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _dateToIso(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

bool _isValidPlate(String value) {
  final normalized = value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  return RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$').hasMatch(normalized);
}

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

bool _isValidEmail(String email) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
}

class _CpfCnpjInputFormatter extends TextInputFormatter {
  _CpfCnpjInputFormatter({required this.isCnpj});

  final bool isCnpj;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final maxLength = isCnpj ? 14 : 11;
    final digits = _onlyDigits(newValue.text);
    final limited =
        digits.length > maxLength ? digits.substring(0, maxLength) : digits;
    final formatted = isCnpj ? _formatCnpj(limited) : _formatCpf(limited);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatCpf(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(value[i]);
    }
    return buffer.toString();
  }

  String _formatCnpj(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('/');
      if (i == 12) buffer.write('-');
      buffer.write(value[i]);
    }
    return buffer.toString();
  }
}

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

class _CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _formatCep(_onlyDigits(newValue.text));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _RegistrationLoadingOverlay extends StatelessWidget {
  const _RegistrationLoadingOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: .42),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: .92, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder:
                (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .22),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 6,
                          color: colorScheme.primary,
                          backgroundColor: colorScheme.primary.withValues(
                            alpha: .12,
                          ),
                        ),
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                const Color(0xFF6CB77D),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in_outlined,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Criando seu cadastro',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF526257),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      color: colorScheme.primary,
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: .12,
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

class _AddressSearchDialog extends StatefulWidget {
  const _AddressSearchDialog({required this.initialQuery});

  final String initialQuery;

  @override
  State<_AddressSearchDialog> createState() => _AddressSearchDialogState();
}

class _AddressSearchDialogState extends State<_AddressSearchDialog> {
  late final TextEditingController _controller;
  List<Map<String, dynamic>> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.trim().length >= 3) {
      Future.microtask(_search);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.length < 3) {
      setState(() => _error = 'Digite pelo menos 3 caracteres.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await PermitApiService().searchEventAddresses(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível buscar o endereço.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar endereço'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Rua, bairro ou local',
                suffixIcon:
                    _loading
                        ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                        : IconButton(
                          tooltip: 'Buscar',
                          onPressed: _search,
                          icon: const Icon(Icons.search),
                        ),
              ),
              onSubmitted: (_) => _search(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child:
                  _results.isEmpty
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Busque e selecione uma opção.'),
                        ),
                      )
                      : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(
                              item['display_name']?.toString() ?? '',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
