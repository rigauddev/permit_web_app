import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/orla_api_service.dart';
import '../../core/permit_api_service.dart';
import '../../core/session_expiration.dart';
import '../../shared/widgets/app_scaffold.dart';

const _vehicleColors = [
  'Branco',
  'Preto',
  'Prata',
  'Cinza',
  'Vermelho',
  'Azul',
  'Verde',
  'Amarelo',
  'Marrom',
  'Bege',
  'Dourado',
  'Laranja',
  'Vinho',
];

const _vehicleModelsByBrand = <String, List<String>>{
  'Chevrolet': ['Onix', 'Prisma', 'Cobalt', 'Spin', 'Tracker', 'S10'],
  'Fiat': ['Uno', 'Mobi', 'Argo', 'Cronos', 'Strada', 'Toro', 'Palio'],
  'Ford': ['Ka', 'Fiesta', 'EcoSport', 'Ranger'],
  'Honda': ['Fit', 'City', 'Civic', 'HR-V', 'WR-V'],
  'Hyundai': ['HB20', 'HB20S', 'Creta', 'Tucson'],
  'Jeep': ['Renegade', 'Compass', 'Commander'],
  'Nissan': ['March', 'Versa', 'Kicks', 'Frontier'],
  'Peugeot': ['208', '2008', 'Partner'],
  'Renault': ['Kwid', 'Sandero', 'Logan', 'Duster', 'Oroch'],
  'Toyota': ['Corolla', 'Etios', 'Yaris', 'Hilux', 'SW4', 'Corolla Cross'],
  'Volkswagen': [
    'Gol',
    'Voyage',
    'Fox',
    'Polo',
    'Virtus',
    'T-Cross',
    'Saveiro',
  ],
  'Outra': ['Outro'],
};

enum OrlaSection { access, vehicles, dashboard, inspection, guests, banners }

class OrlaPage extends StatefulWidget {
  const OrlaPage({
    super.key,
    this.api,
    this.establishmentsOnly = false,
    this.section = OrlaSection.access,
  });
  final OrlaApiService? api;
  final bool establishmentsOnly;
  final OrlaSection section;
  @override
  State<OrlaPage> createState() => _OrlaPageState();
}

class _OrlaPageState extends State<OrlaPage> {
  late final OrlaApiService _api;
  final _search = TextEditingController();
  final _reportStart = TextEditingController();
  final _reportEnd = TextEditingController();
  final _bannerTitle = TextEditingController();
  final _bannerBody = TextEditingController();
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _reports;
  List<dynamic> _users = [];
  List<dynamic> _guestPasses = [];
  List<Map<String, dynamic>> _businessBanners = [];
  PlatformFile? _bannerFile;
  String? _bannerImageUrl;
  String? _bannerImageDimensions;
  int? _editingBannerId;
  bool _busy = false;
  String? _error;
  int _offset = 0;
  bool get _staff => _me?['is_staff'] == true;
  bool get _manager => _me?['can_manage'] == true;
  bool get _canRegisterGuests => _me?['can_register_guests'] == true;
  bool get _isTourismBusiness => const {
    'pousada_hotel',
    'restaurante',
    'quiosque',
  }.contains(_me?['business_category']);
  String get _userType {
    switch (_me?['role']) {
      case 'admin':
        return 'admin';
      case 'gestor_secretaria':
        return 'gestor';
      case 'operador_secretaria':
        return 'operador';
      default:
        return 'user';
    }
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? OrlaApiService();
    _run(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    _reportStart.dispose();
    _reportEnd.dispose();
    _bannerTitle.dispose();
    _bannerBody.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (e) {
      if (!mounted) return;
      if (e is PermitApiException && e.statusCode == 401) {
        await SessionExpiration.logout(context);
      } else {
        setState(() => _error = e.toString());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    final me = Map<String, dynamic>.from(await _api.request('/me'));
    final users =
        me['is_staff'] == true
            ? await _api.request(
              '/users?q=${Uri.encodeQueryComponent(_search.text)}&offset=$_offset',
            )
            : <dynamic>[];
    Map<String, dynamic>? reports;
    if (me['is_staff'] == true) {
      try {
        final params = <String>[];
        if (_reportStart.text.trim().isNotEmpty) {
          params.add(
            'start=${Uri.encodeQueryComponent(_reportStart.text.trim())}',
          );
        }
        if (_reportEnd.text.trim().isNotEmpty) {
          params.add('end=${Uri.encodeQueryComponent(_reportEnd.text.trim())}');
        }
        reports = Map<String, dynamic>.from(
          await _api.request(
            '/reports${params.isEmpty ? '' : '?${params.join('&')}'}',
          ),
        );
      } catch (_) {
        reports = null;
      }
    }
    final guestPasses =
        me['can_register_guests'] == true
            ? await _api.request('/guest-passes')
            : <dynamic>[];
    var businessBanners = <Map<String, dynamic>>[];
    final isTourismBusiness = const {
      'pousada_hotel',
      'restaurante',
      'quiosque',
    }.contains(me['business_category']);
    if (widget.establishmentsOnly && isTourismBusiness) {
      final token = await SessionExpiration.readAccessToken();
      if (token != null && token.isNotEmpty) {
        businessBanners = await PermitApiService().listHomeContent(
          token,
          mine: true,
        );
      }
    }
    if (mounted) {
      setState(() {
        _me = me;
        _users = users;
        _reports = reports;
        _guestPasses = guestPasses;
        _businessBanners = businessBanners;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = (_me?['vehicles'] as List?) ?? [];
    final responsible = ((_me?['responsible_secretarias'] as List?) ?? const [])
        .map((item) => item.toString())
        .join(' e ');
    return AppScaffold(
      userType: _userType,
      appBar: AppBar(
        leading: BackButton(onPressed: () => _goBack(context)),
        title: Text(
          widget.section == OrlaSection.vehicles
              ? 'Meus veículos'
              : widget.section == OrlaSection.dashboard
              ? 'Dashboard da Orla'
              : widget.section == OrlaSection.inspection
              ? 'Fiscalização da Orla'
              : widget.section == OrlaSection.guests
              ? 'Hóspedes'
              : widget.section == OrlaSection.banners
              ? 'Banners'
              : 'Acesso à Orla',
        ),
        actions: [
          IconButton(
            onPressed: _busy ? null : () => _run(_load),
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.section == OrlaSection.access ? 1440 : 1180,
          ),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.section == OrlaSection.access && !_staff)
                _orlaServiceBanner(context)
              else ...[
                Text(
                  widget.section == OrlaSection.vehicles
                      ? 'Meus veículos'
                      : 'Orla da praia de Guaibim',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.section == OrlaSection.vehicles
                      ? 'Consulte os veículos cadastrados para acesso à Orla.'
                      : 'Cadastro de veículos e validação de entrada na orla.',
                ),
                if (responsible.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Fiscalização: $responsible.'),
                  ),
              ],
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_me != null && !_staff) ...[
                const SizedBox(height: 16),
                if (widget.establishmentsOnly) ...[
                  _establishmentsIntro(),
                  const SizedBox(height: 16),
                  if (_isTourismBusiness) ...[
                    if (widget.section == OrlaSection.banners)
                      _businessBannerSection()
                    else if (widget.section == OrlaSection.guests &&
                        _canRegisterGuests)
                      _guestManagementSection()
                    else
                      _establishmentsUnavailable(),
                  ] else
                    _establishmentsUnavailable(),
                ] else ...[
                  Text(
                    '${vehicles.length} de ${_me!['vehicle_limit']} veículos cadastrados',
                  ),
                  const Text(
                    'Confira os dados antes de cadastrar. Veículos não podem ser editados nem excluídos.',
                  ),
                  const SizedBox(height: 12),
                  if (widget.section == OrlaSection.access)
                    FilledButton.icon(
                      onPressed:
                          _busy ||
                                  vehicles.length >=
                                      (_me!['vehicle_limit'] as int)
                              ? null
                              : _register,
                      icon: const Icon(Icons.add),
                      label: const Text('Cadastrar veículo'),
                    ),
                  if (widget.section == OrlaSection.access)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed:
                            () => Navigator.pushReplacementNamed(
                              context,
                              '/orla/veiculos',
                            ),
                        icon: const Icon(Icons.directions_car),
                        label: const Text('Ver meus veículos'),
                      ),
                    ),
                  if (vehicles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Você ainda não cadastrou veículos.'),
                    ),
                  ...vehicles.map(
                    (v) => _vehicle(Map<String, dynamic>.from(v), own: true),
                  ),
                ],
              ],
              if (_staff && widget.section == OrlaSection.dashboard) ...[
                const SizedBox(height: 16),
                _reportFilters(),
                const SizedBox(height: 12),
                if (_reports != null)
                  _OrlaDashboard(
                    data: _reports!,
                    onValidateInn:
                        (innId, beachfront) => _run(() async {
                          await _api.request(
                            '/inns/$innId/approval',
                            method: 'PUT',
                            body: {
                              'approval_status':
                                  beachfront ? 'approved' : 'pending',
                              'beachfront': beachfront,
                            },
                          );
                          await _load();
                        }),
                  )
                else
                  const _OrlaDashboardEmpty(),
              ],
              if (_staff && widget.section != OrlaSection.dashboard) ...[
                const SizedBox(height: 16),
                _inspectionHeader(context),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _scan,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Escanear QR Code'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _plate(),
                      icon: const Icon(Icons.directions_car),
                      label: const Text('Consultar placa'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _photo,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Ler placa pela câmera'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: 'Buscar usuário ou placa',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed:
                          _busy
                              ? null
                              : () {
                                _offset = 0;
                                _run(_load);
                              },
                    ),
                  ),
                  onSubmitted: (_) {
                    _offset = 0;
                    _run(_load);
                  },
                ),
                if (_users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nenhum usuário encontrado.'),
                  ),
                ..._users.map(
                  (u) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u['name'],
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Limite de cadastro: ${u['vehicle_limit']} veículos',
                          ),
                          if (_manager)
                            TextButton(
                              onPressed: _busy ? null : () => _limit(u),
                              child: const Text('Alterar limite'),
                            ),
                          ...(u['vehicles'] as List).map(
                            (v) => _vehicle(Map<String, dynamic>.from(v)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed:
                          _busy || _offset == 0
                              ? null
                              : () {
                                _offset -= 50;
                                _run(_load);
                              },
                      child: const Text('Anterior'),
                    ),
                    TextButton(
                      onPressed:
                          _busy || _users.length < 50
                              ? null
                              : () {
                                _offset += 50;
                                _run(_load);
                              },
                      child: const Text('Próxima'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _orlaServiceBanner(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1400&q=80',
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF3DB6D3), Color(0xFF0E5F2F)],
                          ),
                        ),
                      ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .10),
                        Colors.black.withValues(alpha: .62),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acesso à Orla de Guaibim',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cadastre seus veículos, gere QR Code e acompanhe os registros de entrada autorizada na área da orla.',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed:
                      _busy ||
                              ((_me?['vehicles'] as List?) ?? const [])
                                      .length >=
                                  ((_me?['vehicle_limit'] as int?) ?? 0)
                          ? null
                          : _register,
                  icon: const Icon(Icons.add),
                  label: const Text('Cadastrar veículo'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      () => Navigator.pushReplacementNamed(
                        context,
                        '/orla/veiculos',
                      ),
                  icon: const Icon(Icons.directions_car),
                  label: const Text('Meus veículos'),
                ),
                const Text(
                  'Banner, título e descrição poderão ser substituídos na gestão do sistema.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _vehicle(Map<String, dynamic> v, {bool own = false}) {
    final owner =
        (v['owner_name'] ?? v['user_name'] ?? v['guest_name'] ?? '')
            .toString()
            .trim();
    final establishment =
        (v['inn_name'] ?? v['establishment_name'] ?? '').toString().trim();
    final stayStart = v['stay_start']?.toString() ?? '';
    final stayEnd = v['stay_end']?.toString() ?? '';
    final hasStay = stayStart.isNotEmpty || stayEnd.isNotEmpty;
    final authorized = v['authorized'] == true || v['access_status'] == 'ativo';
    final expired = v['access_status'] == 'expirado';
    final statusColor =
        authorized
            ? const Color(0xFF0E5F2F)
            : expired
            ? const Color(0xFFB3261E)
            : const Color(0xFF8A5A00);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showVehicleDetails(v, own: own),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.directions_car, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              v['plate']?.toString() ?? 'Sem placa',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .8,
                              ),
                            ),
                            _AccessStatusChip.fromData(v),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${v['brand'] ?? 'Marca não informada'} ${v['model'] ?? ''} • ${v['color'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (owner.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _InfoPill(
                            icon: Icons.person_outline,
                            label: owner,
                            strong: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (establishment.isNotEmpty)
                    _InfoPill(icon: Icons.hotel_outlined, label: establishment),
                  if (hasStay)
                    _InfoPill(
                      icon: Icons.event_available_outlined,
                      label:
                          'Estadia: ${stayStart.isEmpty ? '-' : stayStart} a ${stayEnd.isEmpty ? '-' : stayEnd}',
                    ),
                  if (v['is_excursion'] == true)
                    _InfoPill(
                      icon: Icons.directions_bus_outlined,
                      label:
                          'Excursão • ${v['passengers_count'] ?? v['guest_count'] ?? 0} pessoas',
                    ),
                ],
              ),
              if ((v['authorization_message']?.toString() ?? '')
                  .isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  v['authorization_message'].toString(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(() => _history(v)),
                    icon: const Icon(Icons.history),
                    label: const Text('Entradas'),
                  ),
                  if (own)
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : () => _credential(v),
                      icon: const Icon(Icons.qr_code),
                      label: const Text('QR Code'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVehicleDetails(Map<String, dynamic> v, {required bool own}) {
    final details = <Widget>[
      _DetailLine('Placa', v['plate']),
      _DetailLine(
        'Veículo',
        '${v['brand'] ?? '-'} ${v['model'] ?? ''} • ${v['color'] ?? '-'}',
      ),
      _DetailLine(
        'Usuário/Hóspede',
        v['owner_name'] ?? v['user_name'] ?? v['guest_name'],
      ),
      _DetailLine(
        'Pousada/Estabelecimento',
        v['inn_name'] ?? v['establishment_name'],
      ),
      _DetailLine(
        'Período de estadia',
        '${v['stay_start'] ?? '-'} até ${v['stay_end'] ?? '-'}',
      ),
      _DetailLine(
        'Status',
        v['access_status_label'] ??
            v['authorization_message'] ??
            (v['authorized'] == true ? 'Ativo' : 'Não autorizado'),
      ),
      if (v['is_excursion'] == true) ...[
        _DetailLine(
          'Excursão',
          '${v['passengers_count'] ?? v['guest_count'] ?? '-'} pessoas',
        ),
        _DetailLine(
          'Motorista/Responsável',
          v['driver_name'] ?? v['excursion_responsible_name'],
        ),
        _DetailLine(
          'Telefone',
          v['driver_phone'] ?? v['excursion_responsible_phone'],
        ),
      ],
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Detalhes do acesso • ${v['plate'] ?? ''}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      _AccessStatusChip.fromData(v),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...details,
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _run(() => _history(v));
                        },
                        icon: const Icon(Icons.history),
                        label: const Text('Histórico de entradas'),
                      ),
                      if (own)
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _credential(v);
                          },
                          icon: const Icon(Icons.qr_code),
                          label: const Text('QR Code / imprimir'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _establishmentsIntro() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Área da pousada, hotel, restaurante ou quiosque',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Pousadas e hotéis podem cadastrar hóspedes e veículos para liberar QR Code da Orla. Pousadas, hotéis, restaurantes e quiosques também podem publicar banners de eventos e informações na página inicial.',
          ),
        ],
      ),
    ),
  );

  Widget _establishmentsUnavailable() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Área disponível para estabelecimentos turísticos',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Este menu aparece para contas cadastradas como pousada/hotel, restaurante ou quiosque. Se você é cidadão/turista, use Acesso à Orla ou Meus serviços.',
          ),
        ],
      ),
    ),
  );

  Future<void> _pickBannerImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw PermitApiException('Não foi possível ler a imagem selecionada.');
    }
    String? dimensions;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      dimensions = '${frame.image.width} x ${frame.image.height} px';
      frame.image.dispose();
      codec.dispose();
    } catch (_) {
      dimensions = null;
    }
    setState(() {
      _bannerFile = file;
      _bannerImageUrl = null;
      _bannerImageDimensions = dimensions;
    });
  }

  void _editBusinessBanner(Map<String, dynamic> card) {
    setState(() {
      _editingBannerId = card['id'] as int?;
      _bannerTitle.text = card['title']?.toString() ?? '';
      _bannerBody.text = card['body']?.toString() ?? '';
      _bannerImageUrl = card['image_url']?.toString();
      _bannerFile = null;
      _bannerImageDimensions = null;
    });
  }

  void _clearBusinessBannerForm() {
    setState(() {
      _editingBannerId = null;
      _bannerTitle.clear();
      _bannerBody.clear();
      _bannerFile = null;
      _bannerImageUrl = null;
      _bannerImageDimensions = null;
    });
  }

  Future<void> _deleteBusinessBanner(Map<String, dynamic> card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Excluir banner?'),
            content: Text(
              'O banner “${card['title'] ?? ''}” será removido da sua lista e da página inicial.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) {
        throw PermitApiException('Sessão expirada. Faça login novamente.');
      }
      await PermitApiService().deleteHomeContent(
        accessToken: token,
        cardId: card['id'] as int,
      );
      final cards = await PermitApiService().listHomeContent(token, mine: true);
      if (!mounted) return;
      setState(() => _businessBanners = cards);
      if (_editingBannerId == card['id']) _clearBusinessBannerForm();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Banner excluído.')));
    });
  }

  Future<void> _saveBusinessBanner() async {
    final title = _bannerTitle.text.trim();
    final body = _bannerBody.text.trim();
    if (title.length < 3 ||
        body.length < 5 ||
        (_bannerFile == null && (_bannerImageUrl ?? '').isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe título, texto e faça upload da imagem do banner.',
          ),
        ),
      );
      return;
    }
    await _run(() async {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) {
        throw PermitApiException('Sessão expirada. Faça login novamente.');
      }
      var imageUrl = _bannerImageUrl;
      final file = _bannerFile;
      if (file != null) {
        if (file.bytes == null) {
          throw PermitApiException(
            'Não foi possível ler a imagem selecionada.',
          );
        }
        final upload = await PermitApiService().uploadFile(
          accessToken: token,
          kind: 'estabelecimentos/banners',
          file: file,
        );
        imageUrl = upload['file_url']?.toString();
      }
      if (imageUrl == null || imageUrl.isEmpty) {
        throw PermitApiException('Faça upload da imagem do banner.');
      }
      final editingId = _editingBannerId;
      if (editingId == null) {
        await PermitApiService().createHomeContent(
          accessToken: token,
          scope: 'establishment',
          title: title,
          body: body,
          imageUrl: imageUrl,
          displayOrder: _businessBanners.length,
          isActive: false,
        );
      } else {
        await PermitApiService().updateHomeContent(
          accessToken: token,
          cardId: editingId,
          scope: 'establishment',
          title: title,
          body: body,
          imageUrl: imageUrl,
          displayOrder: _businessBanners.indexWhere(
            (card) => card['id'] == editingId,
          ),
          isActive: false,
        );
      }
      final cards = await PermitApiService().listHomeContent(token, mine: true);
      if (mounted) {
        setState(() {
          _businessBanners = cards;
          _editingBannerId = null;
          _bannerTitle.clear();
          _bannerBody.clear();
          _bannerFile = null;
          _bannerImageUrl = null;
          _bannerImageDimensions = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editingId == null
                  ? 'Banner enviado para aprovação. Ele aparecerá na página inicial após a liberação do administrador.'
                  : 'Banner atualizado e enviado novamente para aprovação.',
            ),
          ),
        );
      }
    });
  }

  Widget _businessBannerSection() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Banners do estabelecimento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Envie eventos, promoções e avisos para aprovação. O banner só aparece na página inicial depois de liberado pelo administrador.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 720;
              final titleField = TextField(
                controller: _bannerTitle,
                decoration: const InputDecoration(
                  labelText: 'Título do banner',
                ),
              );
              final uploadCard = OutlinedButton.icon(
                onPressed: _busy ? null : _pickBannerImage,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(
                  _bannerFile == null
                      ? 'Upload da imagem do banner'
                      : _bannerFile!.name,
                  overflow: TextOverflow.ellipsis,
                ),
              );
              final row =
                  narrow
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          titleField,
                          const SizedBox(height: 12),
                          uploadCard,
                        ],
                      )
                      : Row(
                        children: [
                          Expanded(child: titleField),
                          const SizedBox(width: 12),
                          Expanded(child: uploadCard),
                        ],
                      );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tamanhos recomendados para divulgação: web 1200 x 675 px (16:9) e mobile 1080 x 1080 px (quadrado). JPG ou PNG. Mantenha textos e logos no centro da imagem para evitar cortes.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  row,
                  if (_bannerImageDimensions != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Imagem selecionada: $_bannerImageDimensions. O envio não será bloqueado por tamanho.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bannerBody,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Texto do banner',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_editingBannerId != null) ...[
                        TextButton(
                          onPressed: _busy ? null : _clearBusinessBannerForm,
                          child: const Text('Cancelar edição'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      FilledButton.icon(
                        onPressed: _busy ? null : _saveBusinessBanner,
                        icon: Icon(
                          _editingBannerId == null
                              ? Icons.add_photo_alternate_outlined
                              : Icons.save_outlined,
                        ),
                        label: Text(
                          _editingBannerId == null
                              ? 'Enviar para aprovação'
                              : 'Salvar e reenviar',
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (_businessBanners.isEmpty)
            const Text('Nenhum banner publicado por este estabelecimento.')
          else
            ..._businessBanners.map(
              (card) => Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  leading: SizedBox(
                    width: 72,
                    height: 48,
                    child: Image.network(
                      PermitApiService().resolveFileUrl(
                        card['image_url']?.toString() ?? '',
                      ),
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) =>
                              const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                  title: Text(card['title']?.toString() ?? ''),
                  subtitle: Text(
                    '${card['body']?.toString() ?? ''}\n${card['approval_status'] == 'aprovado' ? 'Aprovado e visível na página inicial' : 'Aguardando aprovação'}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Editar banner',
                        onPressed:
                            _busy ? null : () => _editBusinessBanner(card),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Excluir banner',
                        onPressed:
                            _busy ? null : () => _deleteBusinessBanner(card),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _guestManagementSection() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hóspedes da pousada/hotel',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'Cadastre hóspedes, veículos e excursões. O sistema gera QR Code para acesso à Orla.',
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed:
                        _busy
                            ? null
                            : () => _createGuestPass(isExcursion: false),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Cadastrar hóspede'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _busy
                            ? null
                            : () => _createGuestPass(isExcursion: true),
                    icon: const Icon(Icons.directions_bus_outlined),
                    label: const Text('Cadastrar excursão'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_guestPasses.isEmpty)
            const Text('Nenhum hóspede cadastrado pela pousada/hotel.')
          else
            ..._guestPasses.map(
              (item) => _guestPassCard(Map<String, dynamic>.from(item)),
            ),
        ],
      ),
    ),
  );

  Widget _inspectionHeader(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE5F4EA),
            child: Icon(
              Icons.verified_user_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fiscalização de acesso',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Valide QR Code ou placa, confira os dados do titular e registre a entrada do veículo.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _reportFilters() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: 180,
            child: TextField(
              controller: _reportStart,
              decoration: const InputDecoration(
                labelText: 'Início do período',
                hintText: '2026-01-01',
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _reportEnd,
              decoration: const InputDecoration(
                labelText: 'Fim do período',
                hintText: '2026-12-31',
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(_load),
            icon: const Icon(Icons.filter_alt_outlined),
            label: const Text('Filtrar relatórios'),
          ),
        ],
      ),
    ),
  );

  Widget _guestPassCard(Map<String, dynamic> pass) {
    final authorized = pass['authorized'] == true;
    final expired = pass['access_status'] == 'expirado';
    final color =
        authorized
            ? const Color(0xFF0E5F2F)
            : expired
            ? const Color(0xFFB3261E)
            : const Color(0xFF8A5A00);
    final isExcursion = pass['is_excursion'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showGuestPassDetails(pass),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .12),
                    child: Icon(
                      isExcursion ? Icons.directions_bus : Icons.person,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              pass['guest_name']?.toString() ?? 'Hóspede',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            _AccessStatusChip.fromData(pass),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pass['vehicle_plate']} • ${pass['vehicle_brand']} ${pass['vehicle_model']} • ${pass['vehicle_color']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if ((pass['inn_name']?.toString() ?? '').isNotEmpty)
                    _InfoPill(
                      icon: Icons.hotel_outlined,
                      label: pass['inn_name'].toString(),
                    ),
                  _InfoPill(
                    icon: Icons.event_available_outlined,
                    label:
                        'Estadia: ${pass['stay_start']} a ${pass['stay_end']}',
                  ),
                  if (isExcursion)
                    _InfoPill(
                      icon: Icons.groups_2_outlined,
                      label:
                          'Excursão com ${pass['guest_count'] ?? 0} hóspedes',
                    ),
                ],
              ),
              if ((pass['authorization_message']?.toString() ?? '')
                  .isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  pass['authorization_message'].toString(),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed:
                        pass['status'] == 'authorized'
                            ? () => _guestCredential(pass)
                            : null,
                    icon: const Icon(Icons.qr_code),
                    label: const Text('QR Code'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        pass['status'] == 'authorized'
                            ? () => _sendGuestWhatsApp(pass)
                            : null,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuestPassDetails(Map<String, dynamic> pass) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Detalhes do hóspede',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      _AccessStatusChip.fromData(pass),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DetailLine('Nome', pass['guest_name']),
                  _DetailLine('Documento', pass['guest_document']),
                  _DetailLine('Telefone', pass['guest_phone']),
                  _DetailLine('Pousada/Hotel', pass['inn_name']),
                  _DetailLine(
                    'Período',
                    '${pass['stay_start']} até ${pass['stay_end']}',
                  ),
                  _DetailLine(
                    'Veículo',
                    '${pass['vehicle_plate']} • ${pass['vehicle_brand']} ${pass['vehicle_model']} • ${pass['vehicle_color']}',
                  ),
                  if (pass['is_excursion'] == true) ...[
                    _DetailLine(
                      'Excursão',
                      '${pass['guest_count'] ?? '-'} hóspedes',
                    ),
                    _DetailLine(
                      'Responsável/motorista',
                      pass['excursion_responsible_name'],
                    ),
                    _DetailLine(
                      'Telefone do responsável',
                      pass['excursion_responsible_phone'],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            pass['status'] == 'authorized'
                                ? () {
                                  Navigator.pop(context);
                                  _guestCredential(pass);
                                }
                                : null,
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Ver QR Code'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            pass['status'] == 'authorized'
                                ? () {
                                  Navigator.pop(context);
                                  _sendGuestWhatsApp(pass);
                                }
                                : null,
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('Enviar WhatsApp'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _createGuestPass({required bool isExcursion}) async {
    final form = GlobalKey<FormState>();
    final guestName = TextEditingController();
    final guestDocument = TextEditingController();
    final guestPhone = TextEditingController();
    final stayStart = TextEditingController();
    final stayEnd = TextEditingController();
    final plate = TextEditingController();
    final responsibleName = TextEditingController();
    final responsibleDocument = TextEditingController();
    final responsiblePhone = TextEditingController();
    final guestCount = TextEditingController();
    String? selectedBrand;
    String? selectedModel;
    String? selectedColor;
    DateTimeRange? stayRange;
    var releaseOrlaAccess = false;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              final models =
                  selectedBrand == null
                      ? const <String>[]
                      : _vehicleModelsByBrand[selectedBrand] ?? const [];
              Future<void> pickStayRange() async {
                final now = DateUtils.dateOnly(DateTime.now());
                final selected = await showDateRangePicker(
                  context: ctx,
                  initialDateRange: stayRange,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 730)),
                  helpText:
                      isExcursion
                          ? 'Selecione o período da excursão'
                          : 'Selecione o período da estadia',
                  cancelText: 'Cancelar',
                  confirmText: 'Confirmar',
                  saveText: 'Aplicar',
                  builder:
                      (context, child) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 560,
                            maxHeight: 620,
                          ),
                          child: Material(
                            borderRadius: BorderRadius.circular(24),
                            clipBehavior: Clip.antiAlias,
                            child: child,
                          ),
                        ),
                      ),
                );
                if (selected == null) return;
                setDialogState(() {
                  stayRange = DateTimeRange(
                    start: DateUtils.dateOnly(selected.start),
                    end: DateUtils.dateOnly(selected.end),
                  );
                  stayStart.text = _dateToIso(stayRange!.start);
                  stayEnd.text = _dateToIso(stayRange!.end);
                });
              }

              return AlertDialog(
                title: Text(
                  isExcursion ? 'Cadastrar excursão' : 'Cadastrar hóspede',
                ),
                content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                    child: Form(
                      key: form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FormSectionTitle(
                            icon: Icons.person_outline,
                            title:
                                isExcursion
                                    ? 'Organizador da excursão'
                                    : 'Dados do hóspede',
                          ),
                          TextFormField(
                            controller: guestName,
                            decoration: InputDecoration(
                              labelText:
                                  isExcursion
                                      ? 'Nome do organizador'
                                      : 'Nome do hóspede',
                            ),
                            validator:
                                (v) =>
                                    (v ?? '').trim().length < 2
                                        ? isExcursion
                                            ? 'Informe o organizador'
                                            : 'Informe o hóspede'
                                        : null,
                          ),
                          TextFormField(
                            controller: guestDocument,
                            decoration: InputDecoration(
                              labelText:
                                  isExcursion
                                      ? 'CPF/CNPJ do organizador'
                                      : 'CPF/CNPJ do hóspede',
                              helperText:
                                  isExcursion
                                      ? 'Usado para identificar a excursão no sistema.'
                                      : 'O hóspede poderá entrar no sistema com este documento. A senha inicial será o próprio CPF/CNPJ.',
                            ),
                            keyboardType: TextInputType.number,
                            validator:
                                (value) =>
                                    _onlyDigits(value ?? '').length < 11
                                        ? isExcursion
                                            ? 'Informe CPF/CNPJ do organizador'
                                            : 'Informe CPF/CNPJ do hóspede'
                                        : null,
                          ),
                          TextFormField(
                            controller: guestPhone,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText:
                                  isExcursion
                                      ? 'WhatsApp do organizador'
                                      : 'WhatsApp do hóspede',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _FormSectionTitle(
                            icon: Icons.calendar_month_outlined,
                            title: 'Período da estadia',
                          ),
                          OutlinedButton.icon(
                            onPressed: pickStayRange,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(
                              stayRange == null
                                  ? isExcursion
                                      ? 'Selecionar período da excursão'
                                      : 'Selecionar período da estadia'
                                  : '${stayStart.text} até ${stayEnd.text}',
                            ),
                          ),
                          FormField<DateTimeRange>(
                            validator:
                                (_) =>
                                    stayRange == null
                                        ? 'Selecione o período'
                                        : null,
                            builder:
                                (field) =>
                                    field.hasError
                                        ? Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
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
                          _FormSectionTitle(
                            icon: Icons.directions_car_outlined,
                            title:
                                isExcursion
                                    ? 'Veículo da excursão'
                                    : 'Veículo do hóspede',
                          ),
                          if (isExcursion) ...[
                            _FormSectionTitle(
                              icon: Icons.person_pin_circle_outlined,
                              title: 'Motorista e lotação',
                            ),
                            TextFormField(
                              controller: responsibleName,
                              decoration: const InputDecoration(
                                labelText: 'Nome do motorista',
                              ),
                              validator:
                                  (v) =>
                                      (v ?? '').trim().length < 2
                                          ? 'Informe o motorista'
                                          : null,
                            ),
                            TextFormField(
                              controller: responsibleDocument,
                              decoration: const InputDecoration(
                                labelText: 'Documento do motorista',
                              ),
                            ),
                            TextFormField(
                              controller: responsiblePhone,
                              decoration: const InputDecoration(
                                labelText: 'Telefone do motorista',
                              ),
                            ),
                            TextFormField(
                              controller: guestCount,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantidade de hóspedes da excursão',
                              ),
                              validator:
                                  (v) =>
                                      (int.tryParse(v ?? '') ?? 0) <= 0
                                          ? 'Informe a quantidade'
                                          : null,
                            ),
                            const Divider(height: 28),
                          ],
                          TextFormField(
                            controller: plate,
                            maxLength: 8,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Placa do veículo',
                            ),
                            validator:
                                (v) =>
                                    RegExp(
                                          r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$',
                                        ).hasMatch(
                                          (v ?? '')
                                              .replaceAll(RegExp(r'[\s-]'), '')
                                              .toUpperCase(),
                                        )
                                        ? null
                                        : 'Placa inválida',
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: selectedBrand,
                            decoration: InputDecoration(labelText: 'Marca'),
                            items:
                                _vehicleModelsByBrand.keys
                                    .map(
                                      (brand) => DropdownMenuItem(
                                        value: brand,
                                        child: Text(brand),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) => setDialogState(() {
                                  selectedBrand = value;
                                  selectedModel = null;
                                }),
                            validator:
                                (value) =>
                                    value == null ? 'Informe a marca' : null,
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: selectedModel,
                            decoration: InputDecoration(labelText: 'Modelo'),
                            items:
                                models
                                    .map(
                                      (model) => DropdownMenuItem(
                                        value: model,
                                        child: Text(model),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                models.isEmpty
                                    ? null
                                    : (value) => setDialogState(
                                      () => selectedModel = value,
                                    ),
                            validator:
                                (value) =>
                                    value == null ? 'Informe o modelo' : null,
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: selectedColor,
                            decoration: const InputDecoration(labelText: 'Cor'),
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
                                (value) =>
                                    setDialogState(() => selectedColor = value),
                            validator:
                                (value) =>
                                    value == null ? 'Informe a cor' : null,
                          ),
                          const Divider(height: 28),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: releaseOrlaAccess,
                            onChanged:
                                (value) => setDialogState(
                                  () => releaseOrlaAccess = value ?? false,
                                ),
                            title: Text(
                              isExcursion
                                  ? 'Liberar acesso da excursão à Orla'
                                  : 'Liberar acesso à Orla',
                            ),
                            subtitle: const Text(
                              'Ao marcar, o sistema gera QR Code autorizado e cria acesso para o hóspede entrar com CPF/CNPJ e senha inicial igual ao documento.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (!form.currentState!.validate()) return;
                      Navigator.pop(ctx, {
                        'guest_name': guestName.text.trim(),
                        'guest_document': guestDocument.text.trim(),
                        'guest_phone': guestPhone.text.trim(),
                        'whatsapp_phone': guestPhone.text.trim(),
                        'stay_start': stayStart.text.trim(),
                        'stay_end': stayEnd.text.trim(),
                        'vehicle_plate': plate.text.trim(),
                        'vehicle_brand': selectedBrand,
                        'vehicle_model': selectedModel,
                        'vehicle_color': selectedColor,
                        'is_excursion': isExcursion,
                        'excursion_responsible_name':
                            responsibleName.text.trim(),
                        'excursion_responsible_document':
                            responsibleDocument.text.trim(),
                        'excursion_responsible_phone':
                            responsiblePhone.text.trim(),
                        'guest_count': int.tryParse(guestCount.text.trim()),
                        'orla_access_requested': releaseOrlaAccess,
                      });
                    },
                    child: Text(
                      isExcursion ? 'Salvar excursão' : 'Salvar hóspede',
                    ),
                  ),
                ],
              );
            },
          ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final controller in [
      guestName,
      guestDocument,
      guestPhone,
      stayStart,
      stayEnd,
      plate,
      responsibleName,
      responsibleDocument,
      responsiblePhone,
      guestCount,
    ]) {
      controller.dispose();
    }
    if (data == null || !mounted) return;
    await _run(() async {
      final pass = await _api.request(
        '/guest-passes',
        method: 'POST',
        body: data,
      );
      await _load();
      if (!mounted) return;
      final created = Map<String, dynamic>.from(pass);
      if (created['status'] == 'authorized') {
        _guestCredential(created);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hóspede cadastrado sem liberação de acesso à Orla.'),
          ),
        );
      }
    });
  }

  Future<void> _register() async {
    final plate = TextEditingController();
    final establishment = TextEditingController();
    final driverName = TextEditingController();
    final driverDocument = TextEditingController();
    final driverPhone = TextEditingController();
    final passengersCount = TextEditingController();
    final form = GlobalKey<FormState>();
    String? selectedBrand;
    String? selectedModel;
    String? selectedColor;
    var isExcursion = false;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              final models =
                  selectedBrand == null
                      ? const <String>[]
                      : _vehicleModelsByBrand[selectedBrand] ?? const [];
              return AlertDialog(
                title: const Text('Cadastrar veículo'),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Form(
                      key: form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'O cadastro é permanente. Confira placa, marca, modelo e cor.',
                          ),
                          TextFormField(
                            controller: plate,
                            maxLength: 8,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(labelText: 'Placa'),
                            validator:
                                (v) =>
                                    RegExp(
                                          r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$',
                                        ).hasMatch(
                                          (v ?? '')
                                              .replaceAll(RegExp(r'[\s-]'), '')
                                              .toUpperCase(),
                                        )
                                        ? null
                                        : 'Placa inválida',
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: selectedBrand,
                            decoration: InputDecoration(labelText: 'Marca'),
                            items:
                                _vehicleModelsByBrand.keys
                                    .map(
                                      (brand) => DropdownMenuItem(
                                        value: brand,
                                        child: Text(brand),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) => setDialogState(() {
                                  selectedBrand = value;
                                  selectedModel = null;
                                }),
                            validator:
                                (value) =>
                                    value == null ? 'Informe a marca' : null,
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: selectedModel,
                            decoration: InputDecoration(labelText: 'Modelo'),
                            items:
                                models
                                    .map(
                                      (model) => DropdownMenuItem(
                                        value: model,
                                        child: Text(model),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                models.isEmpty
                                    ? null
                                    : (value) => setDialogState(
                                      () => selectedModel = value,
                                    ),
                            validator:
                                (value) =>
                                    value == null ? 'Informe o modelo' : null,
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: selectedColor,
                            decoration: const InputDecoration(labelText: 'Cor'),
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
                                (value) =>
                                    setDialogState(() => selectedColor = value),
                            validator:
                                (value) =>
                                    value == null ? 'Informe a cor' : null,
                          ),
                          TextFormField(
                            controller: establishment,
                            maxLength: 150,
                            decoration: InputDecoration(
                              labelText: 'Nome do estabelecimento (opcional)',
                            ),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: isExcursion,
                            onChanged:
                                (value) => setDialogState(
                                  () => isExcursion = value ?? false,
                                ),
                            title: const Text('Veículo de excursão'),
                          ),
                          if (isExcursion) ...[
                            TextFormField(
                              controller: driverName,
                              decoration: const InputDecoration(
                                labelText: 'Nome do motorista',
                              ),
                              validator:
                                  (v) =>
                                      isExcursion && (v ?? '').trim().length < 2
                                          ? 'Informe o motorista'
                                          : null,
                            ),
                            TextFormField(
                              controller: driverDocument,
                              decoration: const InputDecoration(
                                labelText: 'Documento do motorista',
                              ),
                            ),
                            TextFormField(
                              controller: driverPhone,
                              decoration: const InputDecoration(
                                labelText: 'Telefone do motorista',
                              ),
                            ),
                            TextFormField(
                              controller: passengersCount,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantidade de passageiros',
                              ),
                              validator:
                                  (v) =>
                                      isExcursion &&
                                              (int.tryParse(v ?? '') ?? 0) <= 0
                                          ? 'Informe a quantidade'
                                          : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(ctx, {
                          'plate': plate.text,
                          'brand': selectedBrand,
                          'model': selectedModel,
                          'color': selectedColor,
                          'establishment_name':
                              establishment.text.trim().isEmpty
                                  ? null
                                  : establishment.text.trim(),
                          'is_excursion': isExcursion,
                          'driver_name': driverName.text.trim(),
                          'driver_document': driverDocument.text.trim(),
                          'driver_phone': driverPhone.text.trim(),
                          'passengers_count': int.tryParse(
                            passengersCount.text.trim(),
                          ),
                        });
                      }
                    },
                    child: const Text('Confirmar cadastro permanente'),
                  ),
                ],
              );
            },
          ),
    );
    // Dialog route finishes animating before disposing its controllers.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    plate.dispose();
    establishment.dispose();
    driverName.dispose();
    driverDocument.dispose();
    driverPhone.dispose();
    passengersCount.dispose();
    if (data != null && mounted) {
      await _run(() async {
        await _api.request('/vehicles', method: 'POST', body: data);
        await _load();
      });
    }
  }

  Future<String?> _input(String title, String label, String initial) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: label),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Confirmar'),
              ),
            ],
          ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    return value;
  }

  Future<void> _limit(dynamic user) async {
    final text = await _input(
      'Limite de ${user['name']}',
      'Quantidade (0 suspende novas entradas)',
      '${user['vehicle_limit']}',
    );
    if (text == null || !mounted) return;
    await _run(() async {
      final value = int.tryParse(text);
      if (value == null || value < 0 || value > 1000) {
        throw PermitApiException('Informe um número de 0 a 1000.');
      }
      await _api.request(
        '/users/${user['id']}/limit',
        method: 'PUT',
        body: {'vehicle_limit': value},
      );
      await _load();
    });
  }

  Future<void> _plate([String initial = '']) async {
    final value = await _input(
      'Consultar placa',
      'Confira a placa do veículo',
      initial,
    );
    if (value != null && value.isNotEmpty && mounted) {
      await _run(() => _validate(value, 'plate'));
    }
  }

  Future<void> _photo() async {
    String? detected;
    await _run(() async {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (photo == null) return;
      final result = await _api.recognize(photo);
      final candidates = result['candidates'] as List;
      if (candidates.isEmpty) {
        throw PermitApiException(
          'Placa não identificada. Tente outra foto ou digite a placa.',
        );
      }
      if (!mounted) return;
      detected = await showDialog<String>(
        context: context,
        builder:
            (ctx) => SimpleDialog(
              title: const Text('Confira a placa identificada'),
              children:
                  candidates
                      .map(
                        (c) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, c['plate']),
                          child: Text(c['plate']),
                        ),
                      )
                      .toList(),
            ),
      );
    });
    if (detected != null && mounted && await _checkPlateSecurity(detected!)) {
      await _plate(detected!);
    }
  }

  Future<bool> _checkPlateSecurity(String plate) async {
    final result = await _api.request(
      '/plate-security',
      method: 'POST',
      body: {'method': 'plate', 'value': plate},
    );
    if (!mounted) return false;
    final message = result['message']?.toString() ?? '';
    if (result['stolen'] == true) {
      await showDialog<void>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Alerta de furto/roubo'),
              content: Text(
                message.isEmpty
                    ? 'A consulta retornou restrição para esta placa.'
                    : message,
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendi'),
                ),
              ],
            ),
      );
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['configured'] == false
              ? (message.isEmpty
                  ? 'Consulta de furto/roubo não configurada. Validando no cadastro interno.'
                  : '$message Validando no cadastro interno.')
              : (message.isEmpty
                  ? 'Sem restrição de furto/roubo. Validando no cadastro interno.'
                  : '$message Validando no cadastro interno.'),
        ),
      ),
    );
    return true;
  }

  Future<void> _scan() async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _OrlaScanner()),
    );
    if (value != null && mounted) await _run(() => _validate(value, 'qr'));
  }

  Future<void> _validate(String value, String method) async {
    final body = {'value': value, 'method': method};
    var loadingOpen = false;
    if (mounted) {
      loadingOpen = true;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder:
              (_) => const _ValidationLoadingDialog(
                message: 'Validando informações da credencial...',
              ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    late final dynamic v;
    try {
      v = await _api.request('/lookup', method: 'POST', body: body);
    } finally {
      if (loadingOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            icon: Icon(
              v['authorized'] == true
                  ? Icons.verified_user_outlined
                  : Icons.gpp_bad_outlined,
              color:
                  v['authorized'] == true
                      ? const Color(0xFF0E5F2F)
                      : const Color(0xFFB3261E),
              size: 42,
            ),
            title: Text(
              _validationTitle(v),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            content: SingleChildScrollView(child: _validationContent(v)),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar'),
              ),
              if (v['authorized'] == true)
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'entry'),
                  icon: const Icon(Icons.login_outlined),
                  label: const Text('Registrar entrada'),
                ),
            ],
          ),
    );
    if (action == null) return;
    final result = await _api.request(
      '/accesses',
      method: 'POST',
      body: {...body, 'action': action},
    );
    await _load();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF0E5F2F),
              size: 46,
            ),
            title: const Text(
              'Entrada registrada',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: SingleChildScrollView(
              child: _validationContent(
                Map<String, dynamic>.from(result),
                registered: true,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Concluir'),
              ),
            ],
          ),
    );
  }

  String _validationTitle(Map<String, dynamic> data) {
    if (data['authorized'] == true) return 'Acesso autorizado';
    return 'Entrada não autorizada';
  }

  Widget _validationContent(
    Map<String, dynamic> data, {
    bool registered = false,
  }) {
    final authorized = data['authorized'] == true;
    final isGuest = data['access_type'] == 'guest_pass';
    final message =
        data['authorization_message']?.toString().trim().isNotEmpty == true
            ? data['authorization_message'].toString()
            : authorized
            ? 'Autorizado para acessar a Orla de Guaibim.'
            : 'Esta credencial não está autorizada para acessar a Orla de Guaibim.';
    final establishment =
        (data['inn_name'] ?? data['establishment_name'])?.toString() ?? '';
    final stayType = data['stay_type']?.toString();
    final stayLabel =
        stayType == 'casa_aluguel'
            ? 'Casa de aluguel'
            : stayType == 'pousada'
            ? 'Pousada/Hotel'
            : isGuest
            ? 'Pousada/Hotel'
            : null;
    final details = <_ValidationDetail>[
      _ValidationDetail(
        isGuest ? 'Hóspede' : 'Responsável',
        (data['guest_name'] ?? data['owner_name'])?.toString() ?? '-',
      ),
      _ValidationDetail(
        'Veículo',
        '${data['plate']} • ${data['brand'] ?? 'Marca não informada'} ${data['model'] ?? ''} • ${data['color'] ?? ''}',
      ),
      if (stayLabel != null) _ValidationDetail('Tipo de estadia', stayLabel),
      if (establishment.trim().isNotEmpty)
        _ValidationDetail(
          stayType == 'casa_aluguel' ? 'Casa de aluguel' : 'Pousada/Hotel',
          establishment,
        ),
      if ((data['stay_address']?.toString() ?? '').trim().isNotEmpty)
        _ValidationDetail('Endereço da estadia', data['stay_address']),
      if ((data['stay_start']?.toString() ?? '').trim().isNotEmpty ||
          (data['stay_end']?.toString() ?? '').trim().isNotEmpty)
        _ValidationDetail(
          'Período',
          '${data['stay_start'] ?? '-'} até ${data['stay_end'] ?? '-'}',
        ),
      if (data['is_excursion'] == true)
        _ValidationDetail(
          'Excursão',
          'Responsável: ${data['driver_name'] ?? data['excursion_responsible_name'] ?? '-'} • Hóspedes: ${data['passengers_count'] ?? data['guest_count'] ?? '-'}',
        ),
    ];

    return SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  authorized
                      ? const Color(0xFFE5F4EA)
                      : const Color(0xFFFFE8E5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    authorized
                        ? const Color(0xFF6CB77D)
                        : const Color(0xFFE57373),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  authorized ? Icons.verified : Icons.block,
                  color:
                      authorized
                          ? const Color(0xFF0E5F2F)
                          : const Color(0xFFB3261E),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    registered
                        ? 'Acesso validado e entrada registrada para a Orla de Guaibim.'
                        : message,
                    style: TextStyle(
                      color:
                          authorized
                              ? const Color(0xFF0E5F2F)
                              : const Color(0xFFB3261E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...details.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: '${item.label}: ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: item.value.toString()),
                  ],
                ),
              ),
            ),
          ),
          if (!registered)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Confira os dados com o veículo presente.'),
            ),
        ],
      ),
    );
  }

  Future<void> _history(Map<String, dynamic> v) async {
    final rows = <dynamic>[];
    var offset = 0;
    while (true) {
      final page =
          await _api.request('/vehicles/${v['id']}/accesses?offset=$offset')
              as List;
      rows.addAll(page);
      if (page.length < 100) break;
      offset += 100;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Histórico • ${v['plate']}'),
            content: SizedBox(
              width: 480,
              height: 380,
              child:
                  rows.isEmpty
                      ? const Text('Nenhuma entrada registrada.')
                      : ListView(
                        children:
                            rows.map((r) {
                              final date =
                                  DateTime.tryParse(
                                    '${r['created_at']}Z',
                                  )?.toLocal();
                              return ListTile(
                                title: const Text('Entrada'),
                                subtitle: Text(
                                  '${date ?? r['created_at']} • ${r['method'] == 'qr' ? 'QR Code' : 'Placa'}',
                                ),
                              );
                            }).toList(),
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar'),
              ),
            ],
          ),
    );
  }

  void _credential(Map<String, dynamic> v) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Credencial • ${v['plate']}'),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: v['qr_code'],
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                  Text(
                    '${v['brand'] ?? 'Marca não informada'} • ${v['model']} • ${v['color']}',
                  ),
                  if ((v['establishment_name']?.toString() ?? '').isNotEmpty)
                    Text('Estabelecimento: ${v['establishment_name']}'),
                  Text('Responsável: ${v['owner_name']}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _run(() => _print(v));
                },
                icon: const Icon(Icons.print),
                label: const Text('Imprimir'),
              ),
            ],
          ),
    );
  }

  void _guestCredential(Map<String, dynamic> pass) {
    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('QR Code • ${pass['guest_name']}'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: pass['qr_code']?.toString() ?? '',
                    size: 220,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${pass['vehicle_plate']} • ${pass['vehicle_brand']} ${pass['vehicle_model']}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Informe ao hóspede que o acesso à área da Orla só poderá ser feito com este QR Code.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Login no sistema: ${pass['guest_document'] ?? 'CPF/CNPJ'} • senha inicial: o próprio CPF/CNPJ.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showGuestQrImage(pass),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Gerar imagem'),
              ),
              FilledButton.icon(
                onPressed: () => _sendGuestWhatsApp(pass),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Enviar WhatsApp'),
              ),
            ],
          ),
    );
  }

  Future<Uint8List> _buildGuestQrPng(Map<String, dynamic> pass) async {
    final painter = QrPainter(
      data: pass['qr_code']?.toString() ?? '',
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
    final byteData = await painter.toImageData(
      900,
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw PermitApiException('Não foi possível gerar a imagem do QR Code.');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _showGuestQrImage(Map<String, dynamic> pass) async {
    try {
      final bytes = await _buildGuestQrPng(pass);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Imagem do QR Code'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.memory(bytes, width: 280, height: 280),
                    const SizedBox(height: 12),
                    Text(
                      '${pass['guest_name']} • ${pass['vehicle_plate']}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'URL do sistema: ${_systemUrl()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use esta imagem para salvar, imprimir ou anexar na conversa do WhatsApp.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      () => Clipboard.setData(
                        ClipboardData(text: pass['qr_code']?.toString() ?? ''),
                      ),
                  child: const Text('Copiar código'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fechar'),
                ),
                FilledButton.icon(
                  onPressed: () => _sendGuestWhatsApp(pass),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
              ],
            ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _systemUrl() {
    final origin = Uri.base.origin;
    if (origin == 'null' || origin.isEmpty) return 'http://localhost:8081';
    return origin;
  }

  Future<void> _sendGuestWhatsApp(Map<String, dynamic> pass) async {
    final phone = (pass['whatsapp_phone'] ?? pass['guest_phone'] ?? '')
        .toString()
        .replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o WhatsApp do hóspede.')),
      );
      return;
    }
    final systemUrl = _systemUrl();
    final message = Uri.encodeComponent(
      'Olá, ${pass['guest_name']}. Sua autorização de acesso à Orla de Guaibim foi gerada. '
      'Apresente a imagem do QR Code enviada pela pousada/hotel na entrada. '
      'Código do QR: ${pass['qr_code']}. '
      'Acesse o sistema: $systemUrl. '
      'Login: CPF/CNPJ (${pass['guest_document']}). Senha inicial: o próprio CPF/CNPJ.',
    );
    final uri = Uri.parse('https://wa.me/55$phone?text=$message');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _print(Map<String, dynamic> v) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build:
            (_) => pw.Center(
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    'Acesso à Orla de Guaibim',
                    style: pw.TextStyle(fontSize: 22),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Text(
                    v['plate'],
                    style: pw.TextStyle(
                      fontSize: 36,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: v['qr_code'],
                    width: 250,
                    height: 250,
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    '${v['brand'] ?? 'Marca não informada'} - ${v['model']} - ${v['color']}',
                  ),
                  pw.Text('Responsável: ${v['owner_name']}'),
                  if ((v['establishment_name']?.toString() ?? '').isNotEmpty)
                    pw.Text('Estabelecimento: ${v['establishment_name']}'),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Apresente ao fiscal. Validade sujeita à consulta no sistema.',
                  ),
                ],
              ),
            ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'orla-${v['plate']}.pdf',
    );
  }

  void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, '/services');
  }
}

String _onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

String _dateToIso(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _OrlaDashboardEmpty extends StatelessWidget {
  const _OrlaDashboardEmpty();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(18),
      child: Text('Não foi possível carregar os dados do dashboard agora.'),
    ),
  );
}

const _dashboardPalette = [
  Color(0xFF0E5F2F),
  Color(0xFF00A63C),
  Color(0xFF1565C0),
  Color(0xFFFF8F00),
  Color(0xFF8E24AA),
  Color(0xFFD81B60),
  Color(0xFF00838F),
  Color(0xFF6D4C41),
];

Color _dashboardColor(int index) =>
    _dashboardPalette[index % _dashboardPalette.length];

class _OrlaDashboard extends StatelessWidget {
  const _OrlaDashboard({required this.data, this.onValidateInn});

  final Map<String, dynamic> data;
  final Future<void> Function(int innId, bool beachfront)? onValidateInn;

  @override
  Widget build(BuildContext context) {
    final summary = Map<String, dynamic>.from(data['summary'] as Map? ?? {});
    final userType = _mapNumbers(data['user_type']);
    final innsStatus = _mapNumbers(data['inns_status']);
    final touristsByMonth = _mapNumbers(data['tourists_by_month']);
    final touristsByInn = _mapNumbers(data['tourists_by_inn']);
    final innOccupancy = _listMaps(data['inn_occupancy']);
    final overCapacity = _listMaps(data['inns_over_capacity']);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard da Orla',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('Usuários', summary['users']),
                _metric('Turistas', summary['tourists']),
                _metric('Pousadas', summary['inns']),
                _metric(
                  'Acima do estacionamento',
                  summary['inns_over_capacity'],
                ),
                _metric('Excursões', summary['excursions']),
                _metric('Veículos', summary['vehicles']),
                _metric(
                  'Mês pico',
                  summary['busiest_month_total'],
                  subtitle: summary['busiest_month']?.toString(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final charts = [
                  _chartCard(
                    context,
                    'Tipo de usuário',
                    _PieChart(values: userType),
                    userType,
                  ),
                  _chartCard(
                    context,
                    'Turistas por mês',
                    _LineChart(values: touristsByMonth),
                    touristsByMonth,
                  ),
                  _chartCard(
                    context,
                    'Pousadas por status',
                    _PieChart(values: innsStatus),
                    innsStatus,
                  ),
                  _chartCard(
                    context,
                    'Turistas por pousada',
                    _BarList(values: touristsByInn),
                    touristsByInn,
                  ),
                ];
                if (compact) {
                  return Column(
                    children:
                        charts
                            .map(
                              (chart) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: chart,
                              ),
                            )
                            .toList(),
                  );
                }
                return Wrap(spacing: 12, runSpacing: 12, children: charts);
              },
            ),
            const SizedBox(height: 18),
            _innOccupancyCard(context, innOccupancy, overCapacity),
          ],
        ),
      ),
    );
  }

  static Map<String, double> _mapNumbers(dynamic value) {
    if (value is! Map) return const {};
    return value.map(
      (key, item) => MapEntry(
        key.toString(),
        item is num ? item.toDouble() : double.tryParse('$item') ?? 0,
      ),
    );
  }

  static List<Map<String, dynamic>> _listMaps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Widget _metric(String label, dynamic value, {String? subtitle}) => SizedBox(
    width: 145,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E8D6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              '${value ?? 0}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              Text(subtitle, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );

  Widget _innOccupancyCard(
    BuildContext context,
    List<Map<String, dynamic>> occupancy,
    List<Map<String, dynamic>> overCapacity,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE1E7E1)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Estacionamento das pousadas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (overCapacity.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                  label: Text('${overCapacity.length} acima das vagas'),
                  backgroundColor: const Color(0xFFFFF3E0),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (occupancy.isEmpty)
            const Text('Nenhuma pousada cadastrada para análise de vagas.')
          else
            Column(
              children:
                  occupancy.take(8).map((inn) {
                    final exceeded = inn['exceeded'] == true;
                    final capacity = inn['parking_capacity'] ?? inn['capacity'];
                    final occupied =
                        inn['parking_occupied'] ?? inn['occupied'] ?? 0;
                    final guestCapacity = inn['guest_capacity'];
                    final guestOccupied = inn['guest_occupied'] ?? 0;
                    final exceededBy = inn['exceeded_by'] ?? 0;
                    final guestsExceeded = inn['guest_exceeded'] == true;
                    final guestsExceededBy = inn['guest_exceeded_by'] ?? 0;
                    final beachfront = inn['beachfront'] == true;
                    final approvalStatus =
                        inn['approval_status']?.toString() ?? 'pending';
                    final innId = int.tryParse(inn['id']?.toString() ?? '');
                    final guestText =
                        guestCapacity == null
                            ? ''
                            : ' • hóspedes: $guestOccupied de $guestCapacity${guestsExceeded ? ' • excedeu $guestsExceededBy' : ''}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            exceeded
                                ? const Color(0xFFFFE0B2)
                                : const Color(0xFFE8F5E9),
                        child: Icon(
                          exceeded
                              ? Icons.warning_amber_rounded
                              : Icons.hotel_outlined,
                          color:
                              exceeded
                                  ? const Color(0xFFE65100)
                                  : const Color(0xFF2E7D32),
                        ),
                      ),
                      title: Text(inn['name']?.toString() ?? 'Pousada'),
                      subtitle: Text(
                        capacity == null
                            ? 'Veículos: $occupied • vagas de estacionamento não informadas$guestText'
                            : 'Veículos: $occupied de $capacity vagas${exceeded ? ' • excedeu $exceededBy' : ''}$guestText',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              beachfront
                                  ? approvalStatus == 'approved'
                                      ? 'Orla validada'
                                      : 'Orla pendente'
                                  : 'Fora da orla',
                            ),
                            backgroundColor:
                                beachfront
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFF5F5F5),
                          ),
                          if (exceeded || guestsExceeded)
                            const Text(
                              'Excedeu',
                              style: TextStyle(
                                color: Color(0xFFE65100),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          if (onValidateInn != null && innId != null)
                            TextButton.icon(
                              onPressed:
                                  () => onValidateInn!(innId, !beachfront),
                              icon: Icon(
                                beachfront
                                    ? Icons.location_off_outlined
                                    : Icons.add_location_alt_outlined,
                              ),
                              label: Text(
                                beachfront ? 'Remover orla' : 'Validar na orla',
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    ),
  );

  Widget _chartCard(
    BuildContext context,
    String title,
    Widget chart,
    Map<String, double> legend,
  ) => SizedBox(
    width: 455,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E7E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SizedBox(height: 190, child: chart),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children:
                  legend.entries.toList().asMap().entries.map((entry) {
                    final item = entry.value;
                    return _LegendChip(
                      color: _dashboardColor(entry.key),
                      label: item.key,
                      value: item.value,
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PieChart extends StatelessWidget {
  const _PieChart({required this.values});
  final Map<String, double> values;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PiePainter(values.values.toList()),
    child: const SizedBox.expand(),
  );
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: radius,
    );
    var start = -math.pi / 2;
    if (total <= 0) {
      canvas.drawCircle(
        rect.center,
        radius,
        Paint()..color = Colors.grey.shade300,
      );
      canvas.drawCircle(
        rect.center,
        radius * .58,
        Paint()..color = Colors.white,
      );
      return;
    }
    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = _dashboardColor(i),
      );
      start += sweep;
    }
    canvas.drawCircle(rect.center, radius * .54, Paint()..color = Colors.white);
    final textPainter = TextPainter(
      text: TextSpan(
        text: total.toInt().toString(),
        style: const TextStyle(
          color: Color(0xFF172019),
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      rect.center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) =>
      oldDelegate.values != values;
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: .28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ${value.toInt()}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.values});
  final Map<String, double> values;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LinePainter(values.values.toList()),
    child: const SizedBox.expand(),
  );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final axis =
        Paint()
          ..color = Colors.grey.shade400
          ..strokeWidth = 1;
    final line =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF0E5F2F), Color(0xFF1565C0)],
          ).createShader(Offset.zero & size)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
    final pad = 20.0;
    canvas.drawLine(
      Offset(pad, size.height - pad),
      Offset(size.width - pad, size.height - pad),
      axis,
    );
    canvas.drawLine(Offset(pad, pad), Offset(pad, size.height - pad), axis);
    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max).clamp(1, double.infinity);
    final step =
        values.length == 1 ? 0 : (size.width - pad * 2) / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = pad + step * i;
      final y =
          size.height -
          pad -
          ((values[i] / maxValue) * (size.height - pad * 2));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = _dashboardColor(i));
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.values != values;
}

class _BarList extends StatelessWidget {
  const _BarList({required this.values});
  final Map<String, double> values;
  @override
  Widget build(BuildContext context) {
    final entries =
        values.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue =
        entries.isEmpty ? 1 : entries.first.value.clamp(1, double.infinity);
    return ListView(
      children:
          entries.take(6).map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: entry.value / maxValue,
                    color: _dashboardColor(entries.indexOf(entry)),
                    backgroundColor: const Color(0xFFE8EFE8),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}

class _AccessStatusChip extends StatelessWidget {
  const _AccessStatusChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  factory _AccessStatusChip.fromData(Map<String, dynamic> data) {
    final status = data['access_status']?.toString();
    final label =
        data['access_status_label']?.toString().trim().isNotEmpty == true
            ? data['access_status_label'].toString()
            : data['authorized'] == true
            ? 'Ativo'
            : 'Não autorizado';
    if (status == 'expirado') {
      return _AccessStatusChip(
        label: label,
        backgroundColor: const Color(0xFFFFE8E5),
        foregroundColor: const Color(0xFFB3261E),
        icon: Icons.event_busy,
      );
    }
    if (status == 'pendente') {
      return _AccessStatusChip(
        label: label,
        backgroundColor: const Color(0xFFFFF4D8),
        foregroundColor: const Color(0xFF8A5A00),
        icon: Icons.pending_actions,
      );
    }
    if (data['authorized'] == true || status == 'ativo') {
      return _AccessStatusChip(
        label: label,
        backgroundColor: const Color(0xFFE5F4EA),
        foregroundColor: const Color(0xFF0E5F2F),
        icon: Icons.verified,
      );
    }
    return _AccessStatusChip(
      label: label,
      backgroundColor: const Color(0xFFF1F3F1),
      foregroundColor: const Color(0xFF526257),
      icon: Icons.block,
    );
  }

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: foregroundColor.withValues(alpha: 0.24)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: foregroundColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: foregroundColor,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _ValidationDetail {
  const _ValidationDetail(this.label, this.value);

  final String label;
  final Object? value;
}

class _ValidationLoadingDialog extends StatelessWidget {
  const _ValidationLoadingDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F4EA),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Aguarde enquanto conferimos autorização, veículo e período de estadia.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF526257)),
          ),
        ],
      ),
    ),
  );
}

class _OrlaScanner extends StatefulWidget {
  const _OrlaScanner();
  @override
  State<_OrlaScanner> createState() => _OrlaScannerState();
}

class _OrlaScannerState extends State<_OrlaScanner> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _done = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        MobileScanner(
          controller: _controller,
          errorBuilder:
              (_, error, child) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Câmera indisponível. Permita o acesso à câmera ou consulte pela placa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final value = barcode.rawValue;
              if (!_done && value != null) {
                final navigator = Navigator.of(context);
                setState(() => _done = true);
                Future<void>.delayed(const Duration(milliseconds: 450), () {
                  if (mounted) navigator.pop(value);
                });
                break;
              }
            }
          },
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .35),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Leitura de QR Code da Orla',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 270,
                  height: 270,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color:
                          _done
                              ? const Color(0xFF6CB77D)
                              : Colors.white.withValues(alpha: .9),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_done ? const Color(0xFF6CB77D) : Colors.white)
                            .withValues(alpha: .26),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child:
                        _done
                            ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF6CB77D),
                              size: 72,
                            )
                            : const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.white,
                              size: 72,
                            ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .58),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_done)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF6CB77D),
                          ),
                        )
                      else
                        const Icon(
                          Icons.center_focus_strong,
                          color: Colors.white,
                          size: 20,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        _done
                            ? 'QR capturado. Preparando validação...'
                            : 'Aponte a câmera para o QR Code',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  'Use o QR Code gerado pelo sistema para o veículo ou hóspede.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F7F2),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFD8E7D8)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0E5F2F)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == '-' || text == 'null') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF617061),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
