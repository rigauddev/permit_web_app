import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/permit_api_service.dart';
import '../../core/routes/app_routes.dart';
import '../../core/session_expiration.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/user_provider.dart';
import '../../shared/widgets/app_scaffold.dart';

class UserHomePage extends ConsumerStatefulWidget {
  const UserHomePage({super.key, required this.userType, this.userProfile});

  final String userType;
  final String? userProfile;

  @override
  ConsumerState<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends ConsumerState<UserHomePage> {
  final _api = PermitApiService();
  late Future<List<Map<String, dynamic>>> _contentFuture;
  late Future<List<Map<String, dynamic>>> _servicesFuture;
  late Future<List<Map<String, dynamic>>> _tourismPointsFuture;
  late Future<Map<String, dynamic>> _contentSettingsFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = _loadContent();
    _servicesFuture = _loadServices();
    _tourismPointsFuture = _loadTourismPoints();
    _contentSettingsFuture = _loadContentSettings();
  }

  Future<List<Map<String, dynamic>>> _loadContent() async {
    final token = await SessionExpiration.readAccessToken();
    if (token == null || token.isEmpty) return _fallbackCards;
    try {
      final cards = await _api.listHomeContent(token);
      final activeCards =
          cards.where((card) => card['is_active'] == true).toList()..sort(
            (a, b) => (a['display_order'] as int? ?? 0).compareTo(
              b['display_order'] as int? ?? 0,
            ),
          );
      return activeCards.isEmpty ? _fallbackCards : activeCards;
    } catch (_) {
      return _fallbackCards;
    }
  }

  Future<List<Map<String, dynamic>>> _loadServices() async {
    final token = await SessionExpiration.readAccessToken();
    if (token == null || token.isEmpty) return _fallbackServices;
    try {
      final services = await _api.listServiceConfigs(accessToken: token);
      final active =
          services.where((service) => service['is_active'] == true).toList();
      return active.isEmpty ? _fallbackServices : active;
    } catch (_) {
      return _fallbackServices;
    }
  }

  Future<List<Map<String, dynamic>>> _loadTourismPoints() async {
    final token = await SessionExpiration.readAccessToken();
    if (token == null || token.isEmpty) return const [];
    try {
      return await _api.listTourismPoints(accessToken: token);
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> _loadContentSettings() async {
    final token = await SessionExpiration.readAccessToken();
    if (token == null || token.isEmpty) return const {};
    try {
      return await _api.getContentSettings(accessToken: token);
    } catch (_) {
      return const {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final effectiveUserType = user?.userType ?? widget.userType;
    final isCitizen =
        user?.role == 'cidadao' ||
        effectiveUserType == 'user' ||
        effectiveUserType == 'cidadao';
    return AppScaffold(
      userType: effectiveUserType,
      userProfile: widget.userProfile,
      appBar: AppBar(
        title: Text(isCitizen ? 'Página inicial' : 'Painel da secretaria'),
      ),
      body:
          isCitizen
              ? _CitizenHome(
                contentFuture: _contentFuture,
                servicesFuture: _servicesFuture,
                tourismPointsFuture: _tourismPointsFuture,
              )
              : _InternalHome(
                user: user,
                contentSettingsFuture: _contentSettingsFuture,
              ),
    );
  }

  static const _fallbackServices = [
    {
      'key': 'alvara_evento',
      'title': 'Alvará de Evento',
      'description': 'Autorização para festas e eventos.',
      'is_active': true,
    },
    {
      'key': 'acesso_orla',
      'title': 'Acesso à Orla',
      'description': 'Cadastro de veículos para a Orla de Guaibim.',
      'is_active': true,
    },
  ];

  static const _fallbackCards = [
    {
      'scope': 'prefeitura',
      'title': 'Prefeitura de Valença',
      'body':
          'Acompanhe serviços municipais digitais com mais praticidade e segurança.',
      'image_url':
          'https://images.unsplash.com/photo-1494526585095-c41746248156?auto=format&fit=crop&w=1200&q=80',
      'display_order': 0,
      'is_active': true,
    },
    {
      'scope': 'prefeitura',
      'title': 'Central de Eventos',
      'body':
          'Solicite alvará de evento e acompanhe as etapas em um único sistema.',
      'image_url':
          'https://images.unsplash.com/photo-1517457373958-b7bdd4587205?auto=format&fit=crop&w=1200&q=80',
      'display_order': 1,
      'is_active': true,
    },
  ];
}

class _CitizenHome extends StatelessWidget {
  const _CitizenHome({
    required this.contentFuture,
    required this.servicesFuture,
    required this.tourismPointsFuture,
  });

  final Future<List<Map<String, dynamic>>> contentFuture;
  final Future<List<Map<String, dynamic>>> servicesFuture;
  final Future<List<Map<String, dynamic>>> tourismPointsFuture;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _MunicipalBrandHeader(),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: contentFuture,
                      builder: (context, snapshot) {
                        final cards =
                            snapshot.data ?? const <Map<String, dynamic>>[];
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            height: 320,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final mainCards =
                            cards
                                .where(
                                  (card) =>
                                      !(card['scope']?.toString().startsWith(
                                            'establishment:',
                                          ) ??
                                          false),
                                )
                                .toList();
                        return _HomeCarousel(
                          cards:
                              mainCards.isEmpty
                                  ? _UserHomePageState._fallbackCards
                                  : mainCards,
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: tourismPointsFuture,
                      builder:
                          (context, snapshot) => _GuaibimEventsMapCard(
                            points:
                                (snapshot.data ?? const [])
                                    .where((item) => item['is_active'] != false)
                                    .map(_TourismPoint.fromMap)
                                    .toList(),
                          ),
                    ),
                    const SizedBox(height: 18),
                    _HomeServicesCard(servicesFuture: servicesFuture),
                    const SizedBox(height: 18),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: contentFuture,
                      builder: (context, snapshot) {
                        final establishmentCards =
                            (snapshot.data ?? const <Map<String, dynamic>>[])
                                .where(
                                  (card) =>
                                      card['scope']?.toString().startsWith(
                                        'establishment:',
                                      ) ??
                                      false,
                                )
                                .toList();
                        if (establishmentCards.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          children: [
                            _EstablishmentHighlightsCarousel(
                              cards: establishmentCards,
                            ),
                            const SizedBox(height: 18),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeServicesCard extends StatelessWidget {
  const _HomeServicesCard({required this.servicesFuture});

  final Future<List<Map<String, dynamic>>> servicesFuture;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Serviços',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      () => Navigator.pushNamed(context, AppRoutes.services),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Ver mais'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Acesse rapidamente os principais serviços municipais.'),
            const SizedBox(height: 14),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: servicesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final services =
                    (snapshot.data ?? const <Map<String, dynamic>>[])
                        .take(6)
                        .toList();
                if (services.isEmpty) {
                  return const Text('Nenhum serviço ativo no momento.');
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth =
                        constraints.maxWidth < 700
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 24) / 3;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children:
                          services
                              .map(
                                (service) => SizedBox(
                                  width: itemWidth,
                                  child: _MiniServiceCard(
                                    title:
                                        service['title']?.toString() ??
                                        'Serviço',
                                    description:
                                        service['description']?.toString() ??
                                        '',
                                    serviceKey:
                                        service['key']?.toString() ?? '',
                                  ),
                                ),
                              )
                              .toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MunicipalBrandHeader extends StatelessWidget {
  const _MunicipalBrandHeader();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 620;
      final logo = Image.asset(
        'assets/images/logo_prefeitura_1.png',
        width: compact ? 150 : 220,
        height: compact ? 105 : 145,
        fit: BoxFit.contain,
      );
      final text = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            'Prefeitura de Valença',
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF174F32),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Serviços municipais, turismo e informações em um só lugar.',
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF315A48),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 34,
          vertical: compact ? 18 : 22,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF7F0), Color(0xFFFFF7D6), Color(0xFFE7F4FA)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFC9E2D3)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF174F32).withValues(alpha: .08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child:
            compact
                ? Column(children: [logo, const SizedBox(height: 8), text])
                : Row(
                  children: [
                    logo,
                    const SizedBox(width: 30),
                    Expanded(child: text),
                  ],
                ),
      );
    },
  );
}

class _MiniServiceCard extends StatelessWidget {
  const _MiniServiceCard({
    required this.title,
    required this.description,
    required this.serviceKey,
  });

  final String title;
  final String description;
  final String serviceKey;

  @override
  Widget build(BuildContext context) {
    final icon = switch (serviceKey) {
      'acesso_orla' => Icons.beach_access,
      'alvara_evento' => Icons.event_available_outlined,
      'alvara_funcionamento' => Icons.store_mall_directory_outlined,
      'iptu' => Icons.home_work_outlined,
      _ => Icons.design_services_outlined,
    };
    final route =
        serviceKey == 'acesso_orla' ? AppRoutes.orla : AppRoutes.services;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.pushNamed(context, route),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBF7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD8E0D8)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE5F4EA),
                child: Icon(icon, color: const Color(0xFF0E5F2F)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InternalHome extends StatelessWidget {
  const _InternalHome({
    required this.user,
    required this.contentSettingsFuture,
  });

  final UserModel? user;
  final Future<Map<String, dynamic>> contentSettingsFuture;

  bool get _canManageUsers =>
      user?.userType == 'admin' || user?.userType == 'gestor_secretaria';

  bool get _canAccessOrla =>
      user?.userType == 'admin' ||
      user?.secretaria == 'dmtran' ||
      user?.secretaria == 'guarda_civil';

  @override
  Widget build(BuildContext context) {
    final secretaria = _formatSecretaria(user?.secretaria);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEAF7F0), Color(0xFFFFF7D6)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFC9E2D3)),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/logo_prefeitura_1.png',
                      height:
                          MediaQuery.sizeOf(context).width >= 900 ? 118 : 82,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.userType == 'admin'
                                ? 'Dashboard administrativo'
                                : 'Dashboard da secretaria',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            user?.userType == 'admin'
                                ? 'Acompanhe serviços, usuários e conteúdos de todas as secretarias.'
                                : 'Área de trabalho: $secretaria',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _InternalOperationsPreview(
                contentSettingsFuture: contentSettingsFuture,
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount =
                      constraints.maxWidth < 680
                          ? 1
                          : constraints.maxWidth < 980
                          ? 2
                          : 3;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: constraints.maxWidth < 680 ? 2.7 : 1.55,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      const _HomeActionCard(
                        icon: Icons.assignment_turned_in_outlined,
                        title: 'Solicitações da secretaria',
                        description:
                            'Analise aprovações, recusas e pedidos de correção pertinentes ao seu órgão.',
                        route: '/secretaria-requests',
                      ),
                      const _HomeActionCard(
                        icon: Icons.fact_check_outlined,
                        title: 'Vistorias e pendências',
                        description:
                            'Acompanhe exigências técnicas, documentos e retornos do cidadão.',
                        route: '/inspections',
                      ),
                      const _HomeActionCard(
                        icon: Icons.qr_code_scanner_outlined,
                        title: 'Verificar evento',
                        description:
                            'Leia o QR Code do alvará e registre a fiscalização do evento autorizado.',
                        route: '/verificar-evento',
                      ),
                      if (_canAccessOrla)
                        const _HomeActionCard(
                          icon: Icons.beach_access,
                          title: 'Acesso à Orla',
                          description:
                              'Valide veículos cadastrados por QR Code ou placa e registre entradas.',
                          route: '/orla',
                        ),
                      const _HomeActionCard(
                        icon: Icons.analytics_outlined,
                        title: 'Relatórios',
                        description:
                            'Analise eventos por período, ano, tipo, secretaria e frequência mensal.',
                        route: '/reports',
                      ),
                      if (_canManageUsers)
                        const _HomeActionCard(
                          icon: Icons.people_outline,
                          title: 'Usuários',
                          description:
                              'Consulte e cadastre usuários conforme o escopo da secretaria.',
                          route: '/users',
                        ),
                      if (user?.userType == 'admin')
                        const _HomeActionCard(
                          icon: Icons.security_outlined,
                          title: 'Tipos de usuário e permissões',
                          description:
                              'Controle permissões por perfil e categoria do sistema.',
                          route: '/permissions',
                        ),
                      if (_canManageUsers)
                        const _HomeActionCard(
                          icon: Icons.view_carousel_outlined,
                          title: 'Conteúdo da página inicial',
                          description:
                              'Crie até 5 cards de carrossel para sua secretaria ou prefeitura.',
                          route: '/home-content',
                        ),
                      if (user?.role == 'admin' ||
                          user?.role == 'gestor_secretaria')
                        const _HomeActionCard(
                          icon: Icons.add_location_alt_outlined,
                          title: 'Mapas e conteúdo turístico',
                          description:
                              'Edite pontos turísticos, rotas e responsáveis pelo mapa de eventos.',
                          route: AppRoutes.contentManagement,
                        ),
                      if (_canManageUsers)
                        const _HomeActionCard(
                          icon: Icons.account_balance_outlined,
                          title: 'Secretarias',
                          description:
                              'Configure e-mail, logo e textos usados em notificações e documentos.',
                          route: '/secretarias',
                        ),
                      if (user?.userType == 'admin' ||
                          user?.userType == 'gestor_secretaria')
                        const _HomeActionCard(
                          icon: Icons.design_services_outlined,
                          title: 'Gestão de Serviços',
                          description:
                              'Configure perguntas, tipos de resposta, documentos modelo e regras por secretaria.',
                          route: '/questions',
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatSecretaria(String? slug) {
    switch (slug) {
      case 'desenvolvimento_economico':
        return 'Desenvolvimento Econômico';
      case 'meio_ambiente':
        return 'Meio Ambiente';
      case 'infraestrutura':
        return 'Infraestrutura';
      case 'dmtran':
        return 'DMTRAN';
      case 'vigilancia_sanitaria':
        return 'Vigilância Sanitária';
      case 'guarda_civil':
        return 'Guarda Civil Municipal';
      case 'receita_municipal':
        return 'Receita Municipal';
      default:
        return slug ?? 'Sem secretaria vinculada';
    }
  }
}

class _InternalOperationsPreview extends StatelessWidget {
  const _InternalOperationsPreview({required this.contentSettingsFuture});

  final Future<Map<String, dynamic>> contentSettingsFuture;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 760;
        final mapCard = FutureBuilder<Map<String, dynamic>>(
          future: contentSettingsFuture,
          builder: (context, snapshot) {
            final settings = snapshot.data ?? const <String, dynamic>{};
            return _HomeActionCard(
              icon: Icons.map_outlined,
              title:
                  settings['event_map_title']?.toString() ??
                  'Mapa de eventos autorizados',
              description:
                  settings['event_map_description']?.toString() ??
                  'Consulte os eventos autorizados por data e abra a rota de cada local.',
              route: AppRoutes.eventMap,
            );
          },
        );
        if (isNarrow) {
          return Column(
            children: [
              const _CityDatesPanel(),
              const SizedBox(height: 12),
              mapCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(child: _CityDatesPanel()),
            const SizedBox(width: 16),
            Expanded(child: mapCard),
          ],
        );
      },
    );
  }
}

class _CityDatesPanel extends StatelessWidget {
  const _CityDatesPanel();

  static const _dates = [
    ('02/02', 'Yemanjá'),
    ('19/03', 'Dia do Artesão'),
    ('24/06', 'São João'),
    ('29/06', 'São Pedro'),
    ('12/10', 'Dia das Crianças'),
    ('10/11', 'Aniversário da Cidade'),
    ('08/11', 'Lavagem do Amparo'),
    ('25/11', 'Dia das Baianas de Acarajé'),
    ('25/12', 'Natal'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_note_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Calendário comemorativo da cidade',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._dates.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        item.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(child: Text(item.$2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuaibimEventsMapCard extends StatefulWidget {
  const _GuaibimEventsMapCard({
    this.fullscreen = false,
    this.points = const [],
  });

  final bool fullscreen;
  final List<_TourismPoint> points;

  @override
  State<_GuaibimEventsMapCard> createState() => _GuaibimEventsMapCardState();
}

class _GuaibimEventsMapCardState extends State<_GuaibimEventsMapCard> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'Todos';

  static const _fallbackPoints = [
    _TourismPoint(
      title: 'Ponta do Curral',
      detail: 'Ponto natural • encontro com o mar',
      place: 'Extremo da faixa turística',
      x: .83,
      y: .21,
      color: Color(0xFF00695C),
      category: 'Atrativos',
      icon: Icons.explore,
    ),
    _TourismPoint(
      title: 'Guaibimzinho',
      detail: 'Praia tranquila • banho e caminhada',
      place: 'Lado sul de Guaibim',
      x: .23,
      y: .70,
      color: Color(0xFF0277BD),
      category: 'Praia',
      icon: Icons.beach_access,
    ),
    _TourismPoint(
      title: 'Igreja de Guaibim',
      detail: 'Referência local',
      place: 'Centro do povoado',
      x: .47,
      y: .55,
      color: Color(0xFF6D4C41),
      category: 'Religioso',
      icon: Icons.account_balance,
    ),
    _TourismPoint(
      title: 'Pousadas da Orla',
      detail: 'Hospedagens próximas à praia',
      place: 'Av. Beira Mar',
      x: .58,
      y: .43,
      color: Color(0xFF7B1FA2),
      category: 'Pousadas',
      icon: Icons.hotel,
    ),
    _TourismPoint(
      title: 'Pousadas centrais',
      detail: 'Hospedagens e comércio local',
      place: 'Área central',
      x: .39,
      y: .62,
      color: Color(0xFF8E24AA),
      category: 'Pousadas',
      icon: Icons.apartment,
    ),
    _TourismPoint(
      title: 'Praça da Orla',
      detail: 'Eventos • feira • apresentações',
      place: 'Orla principal',
      x: .51,
      y: .37,
      color: Color(0xFFFF8F00),
      category: 'Eventos',
      icon: Icons.event,
    ),
    _TourismPoint(
      title: 'Barracas e gastronomia',
      detail: 'Comida local e apoio ao turista',
      place: 'Faixa de praia',
      x: .66,
      y: .34,
      color: Color(0xFFD84315),
      category: 'Gastronomia',
      icon: Icons.restaurant,
    ),
  ];

  List<_TourismPoint> get _points =>
      widget.points.isEmpty ? _fallbackPoints : widget.points;

  List<String> get _categories => [
    'Todos',
    ...{for (final point in _points) point.category},
  ];

  List<_TourismPoint> get _filteredPoints {
    final term = _searchController.text.trim().toLowerCase();
    return _points.where((point) {
      final byCategory =
          _selectedCategory == 'Todos' || point.category == _selectedCategory;
      final byTerm =
          term.isEmpty ||
          point.title.toLowerCase().contains(term) ||
          point.detail.toLowerCase().contains(term) ||
          point.place.toLowerCase().contains(term) ||
          point.category.toLowerCase().contains(term);
      return byCategory && byTerm;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final map = RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: const _GuaibimMapPainter(pulse: .45),
            child: const SizedBox.expand(),
          ),
          ..._filteredPoints.map(
            (point) => _TourismMarker(
              point: point,
              pulse: .45,
              compact: !widget.fullscreen,
            ),
          ),
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(widget.fullscreen ? 20 : 16),
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
                        'Mapa turístico de Guaibim',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'Guia ilustrado com pontos turísticos e estabelecimentos. Use o botão de rota para abrir a navegação.',
                      ),
                    ],
                  ),
                ),
                if (!widget.fullscreen)
                  IconButton.filledTonal(
                    tooltip: 'Ver mapa em tela cheia',
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => _GuaibimMapFullscreen(points: _points),
                          ),
                        ),
                    icon: const Icon(Icons.fullscreen),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar pousada, praia, igreja, evento ou atrativo',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    _categories
                        .map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: _selectedCategory == category,
                              onSelected:
                                  (_) => setState(
                                    () => _selectedCategory = category,
                                  ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 760;
                final mapBox = ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: SizedBox(
                      height: widget.fullscreen ? 560 : 330,
                      child: map,
                    ),
                  ),
                );
                final list = SizedBox(
                  height: widget.fullscreen ? 560 : 330,
                  child: _TourismPointList(points: _filteredPoints),
                );
                if (narrow) {
                  return Column(
                    children: [mapBox, const SizedBox(height: 12), list],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: mapBox),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: list),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GuaibimMapFullscreen extends StatelessWidget {
  const _GuaibimMapFullscreen({this.points = const []});

  final List<_TourismPoint> points;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mapa turístico de Guaibim')),
    body: _GuaibimEventsMapCard(fullscreen: true, points: points),
  );
}

class _TourismPointList extends StatelessWidget {
  const _TourismPointList({required this.points});

  final List<_TourismPoint> points;

  Future<void> _openRoute(_TourismPoint point) async {
    final query =
        point.latitude != null && point.longitude != null
            ? '${point.latitude},${point.longitude}'
            : '${point.title}, ${point.place}, Guaibim, Valença, BA';
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nenhum ponto encontrado para o filtro informado.'),
        ),
      );
    }
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: points.length,
        itemBuilder: (context, index) {
          final point = points[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8, right: 8),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: point.color,
                child: Icon(point.icon, color: Colors.white, size: 20),
              ),
              title: Text(point.title),
              subtitle: Text(
                '${point.category} • ${point.detail}\n${point.place}',
              ),
              isThreeLine: true,
              trailing: IconButton.filledTonal(
                tooltip: 'Abrir rota',
                onPressed: () => _openRoute(point),
                icon: const Icon(Icons.directions_outlined),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TourismMarker extends StatelessWidget {
  const _TourismMarker({
    required this.point,
    required this.pulse,
    required this.compact,
  });

  final _TourismPoint point;
  final double pulse;
  final bool compact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final left = constraints.maxWidth * point.x;
      final top = constraints.maxHeight * point.y;
      final labelVisible = !compact || constraints.maxWidth > 560;
      return Positioned(
        left: (left - 22).clamp(8, constraints.maxWidth - 180),
        top: (top - 20).clamp(8, constraints.maxHeight - 76),
        child: Tooltip(
          message: '${point.title}\n${point.detail}',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40 + pulse * 16,
                    height: 40 + pulse * 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: point.color.withValues(alpha: .18),
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: point.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(point.icon, color: Colors.white, size: 18),
                  ),
                ],
              ),
              if (labelVisible) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(maxWidth: 136),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    point.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _TourismPoint {
  const _TourismPoint({
    required this.title,
    required this.detail,
    required this.place,
    required this.x,
    required this.y,
    required this.color,
    required this.category,
    required this.icon,
    this.latitude,
    this.longitude,
  });

  factory _TourismPoint.fromMap(Map<String, dynamic> data) {
    final category = data['category']?.toString() ?? 'Atrativos';
    final color = switch (category.toLowerCase()) {
      'praia' => const Color(0xFF0277BD),
      'pousadas' || 'hospedagem' => const Color(0xFF7B1FA2),
      'eventos' => const Color(0xFFFF8F00),
      'gastronomia' => const Color(0xFFD84315),
      'religioso' => const Color(0xFF6D4C41),
      _ => const Color(0xFF00695C),
    };
    final icon = switch (category.toLowerCase()) {
      'praia' => Icons.beach_access,
      'pousadas' || 'hospedagem' => Icons.hotel,
      'eventos' => Icons.event,
      'gastronomia' => Icons.restaurant,
      'religioso' => Icons.account_balance,
      _ => Icons.explore,
    };
    return _TourismPoint(
      title: data['title']?.toString() ?? '',
      detail: data['detail']?.toString() ?? '',
      place: data['place']?.toString() ?? '',
      x: (data['marker_x'] as num?)?.toDouble() ?? .5,
      y: (data['marker_y'] as num?)?.toDouble() ?? .5,
      color: color,
      category: category,
      icon: icon,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  final String title;
  final String detail;
  final String place;
  final double x;
  final double y;
  final Color color;
  final String category;
  final IconData icon;
  final double? latitude;
  final double? longitude;
}

class _GuaibimMapPainter extends CustomPainter {
  const _GuaibimMapPainter({required this.pulse});

  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final seaGradient =
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF69D2E7), Color(0xFF0089B7)],
          ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, seaGradient);

    _drawWaves(canvas, size);
    _drawCoast(canvas, size);
    _drawTown(canvas, size);
    _drawAerialTexture(canvas, size);
    _drawRoads(canvas, size);
    _drawIllustrations(canvas, size);
    _drawMapLabels(canvas, size);
    _drawCompass(canvas, size);
  }

  void _drawCoast(Canvas canvas, Size size) {
    final sand = Paint()..color = const Color(0xFFF7DFA1);
    final wetSand =
        Paint()..color = const Color(0xFFFFF1C1).withValues(alpha: .82);
    final beach =
        Path()
          ..moveTo(0, size.height * .46)
          ..cubicTo(
            size.width * .18,
            size.height * .36,
            size.width * .32,
            size.height * .62,
            size.width * .52,
            size.height * .46,
          )
          ..cubicTo(
            size.width * .68,
            size.height * .33,
            size.width * .82,
            size.height * .31,
            size.width,
            size.height * .23,
          )
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
    canvas.drawPath(beach, sand);

    final foam =
        Path()
          ..moveTo(0, size.height * .43)
          ..cubicTo(
            size.width * .18,
            size.height * .33,
            size.width * .32,
            size.height * .59,
            size.width * .51,
            size.height * .43,
          )
          ..cubicTo(
            size.width * .67,
            size.height * .30,
            size.width * .82,
            size.height * .27,
            size.width,
            size.height * .20,
          );
    canvas.drawPath(
      foam,
      Paint()
        ..color = Colors.white.withValues(alpha: .82)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      foam.shift(Offset(0, size.height * .03)),
      wetSand
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawTown(Canvas canvas, Size size) {
    final green = Paint()..color = const Color(0xFF8BCB75);
    final park =
        Path()
          ..moveTo(0, size.height * .71)
          ..cubicTo(
            size.width * .20,
            size.height * .62,
            size.width * .34,
            size.height * .78,
            size.width * .52,
            size.height * .63,
          )
          ..cubicTo(
            size.width * .70,
            size.height * .48,
            size.width * .86,
            size.height * .49,
            size.width,
            size.height * .40,
          )
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
    canvas.drawPath(park, green);

    final blocks = Paint()..color = Colors.white.withValues(alpha: .38);
    final random = math.Random(8);
    for (var i = 0; i < 28; i++) {
      final dx = size.width * (.08 + random.nextDouble() * .78);
      final dy = size.height * (.58 + random.nextDouble() * .30);
      final w = 12 + random.nextDouble() * 18;
      final h = 8 + random.nextDouble() * 14;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(dx, dy, w, h),
          const Radius.circular(3),
        ),
        blocks,
      );
    }
  }

  void _drawAerialTexture(Canvas canvas, Size size) {
    final random = math.Random(42);
    for (var i = 0; i < 80; i++) {
      final dx = size.width * random.nextDouble();
      final dy = size.height * (.42 + random.nextDouble() * .55);
      final radius = 4 + random.nextDouble() * 18;
      final color =
          [
            const Color(0xFF3F8E4D).withValues(alpha: .16),
            const Color(0xFF6DA65D).withValues(alpha: .14),
            const Color(0xFFC7B07A).withValues(alpha: .12),
            Colors.white.withValues(alpha: .10),
          ][random.nextInt(4)];
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(dx, dy),
          width: radius * (1.8 + random.nextDouble()),
          height: radius,
        ),
        Paint()..color = color,
      );
    }
    final gridPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: .08)
          ..strokeWidth = 1;
    for (var i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(
        Offset(x, size.height * .46),
        Offset(x + size.width * .08, size.height),
        gridPaint,
      );
    }
    for (var i = 1; i < 7; i++) {
      final y = size.height * (.48 + i * .07);
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 24), gridPaint);
    }
  }

  void _drawRoads(Canvas canvas, Size size) {
    final roadPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: .84)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
    final roadBorder =
        Paint()
          ..color = const Color(0xFFD29D48).withValues(alpha: .55)
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
    final coastRoad =
        Path()
          ..moveTo(size.width * .08, size.height * .73)
          ..cubicTo(
            size.width * .28,
            size.height * .62,
            size.width * .40,
            size.height * .68,
            size.width * .56,
            size.height * .54,
          )
          ..cubicTo(
            size.width * .72,
            size.height * .40,
            size.width * .86,
            size.height * .42,
            size.width * .95,
            size.height * .31,
          );
    canvas.drawPath(coastRoad, roadBorder);
    canvas.drawPath(coastRoad, roadPaint);

    final accessRoad =
        Path()
          ..moveTo(size.width * .42, size.height * .95)
          ..lineTo(size.width * .47, size.height * .71)
          ..lineTo(size.width * .48, size.height * .55);
    canvas.drawPath(accessRoad, roadBorder);
    canvas.drawPath(accessRoad, roadPaint);
  }

  void _drawWaves(Canvas canvas, Size size) {
    final wavePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: .32 + pulse * .08)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
    for (var row = 0; row < 6; row++) {
      final y = size.height * (.08 + row * .07);
      for (var col = 0; col < 8; col++) {
        final x = size.width * (.04 + col * .13 + (row.isEven ? .02 : .07));
        final wave =
            Path()
              ..moveTo(x, y)
              ..quadraticBezierTo(x + 10, y - 7, x + 20, y)
              ..quadraticBezierTo(x + 30, y + 7, x + 40, y);
        canvas.drawPath(wave, wavePaint);
      }
    }
  }

  void _drawIllustrations(Canvas canvas, Size size) {
    final palmPaint = Paint()..color = const Color(0xFF2E7D32);
    final trunk =
        Paint()
          ..color = const Color(0xFF8D6E63)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    for (final p in [
      Offset(size.width * .30, size.height * .54),
      Offset(size.width * .61, size.height * .39),
      Offset(size.width * .75, size.height * .34),
    ]) {
      canvas.drawLine(p, p.translate(0, 22), trunk);
      for (var i = 0; i < 5; i++) {
        final angle = -math.pi + i * math.pi / 4;
        canvas.drawLine(
          p,
          p.translate(math.cos(angle) * 18, math.sin(angle) * 12),
          palmPaint..strokeWidth = 4,
        );
      }
    }

    final boat = Paint()..color = const Color(0xFFFF7043);
    final boatPath =
        Path()
          ..moveTo(size.width * .16, size.height * .24)
          ..lineTo(size.width * .25, size.height * .24)
          ..quadraticBezierTo(
            size.width * .22,
            size.height * .29,
            size.width * .18,
            size.height * .29,
          )
          ..close();
    canvas.drawPath(boatPath, boat);
    canvas.drawLine(
      Offset(size.width * .205, size.height * .24),
      Offset(size.width * .205, size.height * .16),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2,
    );
    final sail =
        Path()
          ..moveTo(size.width * .21, size.height * .16)
          ..lineTo(size.width * .25, size.height * .23)
          ..lineTo(size.width * .21, size.height * .23)
          ..close();
    canvas.drawPath(sail, Paint()..color = Colors.white.withValues(alpha: .92));
  }

  void _drawMapLabels(Canvas canvas, Size size) {
    _drawLabel(
      canvas,
      'MAR DE GUAIBIM',
      Offset(size.width * .08, size.height * .10),
      Colors.white,
    );
    _drawLabel(
      canvas,
      'ORLA / PRAIA',
      Offset(size.width * .56, size.height * .25),
      const Color(0xFF7B4F00),
    );
    _drawLabel(
      canvas,
      'CENTRO',
      Offset(size.width * .43, size.height * .82),
      const Color(0xFF245A2A),
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: .82),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawCompass(Canvas canvas, Size size) {
    final center = Offset(size.width - 42, 38);
    canvas.drawCircle(
      center,
      22,
      Paint()..color = Colors.white.withValues(alpha: .78),
    );
    canvas.drawLine(
      center.translate(0, 13),
      center.translate(0, -13),
      Paint()
        ..color = const Color(0xFF00695C)
        ..strokeWidth = 2,
    );
    final north =
        Path()
          ..moveTo(center.dx, center.dy - 18)
          ..lineTo(center.dx - 5, center.dy - 6)
          ..lineTo(center.dx + 5, center.dy - 6)
          ..close();
    canvas.drawPath(north, Paint()..color = const Color(0xFF00695C));
    _drawLabel(canvas, 'N', center.translate(-4, -8), const Color(0xFF00695C));
  }

  @override
  bool shouldRepaint(covariant _GuaibimMapPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}

class _EstablishmentHighlightsCarousel extends StatefulWidget {
  const _EstablishmentHighlightsCarousel({required this.cards});

  final List<Map<String, dynamic>> cards;

  @override
  State<_EstablishmentHighlightsCarousel> createState() =>
      _EstablishmentHighlightsCarouselState();
}

class _EstablishmentHighlightsCarouselState
    extends State<_EstablishmentHighlightsCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    final compact = MediaQuery.sizeOf(context).width < 680;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Eventos e avisos dos estabelecimentos',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pousadas, hotéis, restaurantes e quiosques podem divulgar novidades para moradores e turistas.',
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: compact ? 390 : 300,
              child: PageView.builder(
                controller: _controller,
                itemCount: cards.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder:
                    (context, index) =>
                        _EstablishmentBannerCard(card: cards[index]),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                cards.length,
                (index) => Container(
                  width: _index == index ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color:
                        _index == index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstablishmentBannerCard extends StatelessWidget {
  const _EstablishmentBannerCard({required this.card});

  final Map<String, dynamic> card;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 680;
      final image = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          PermitApiService().resolveFileUrl(card['image_url'] as String? ?? ''),
          fit: BoxFit.cover,
          height: narrow ? 130 : double.infinity,
          width: double.infinity,
          errorBuilder:
              (_, __, ___) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Icon(Icons.storefront_outlined, size: 42),
                ),
              ),
        ),
      );
      final text = Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card['title'] as String? ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              card['body'] as String? ?? '',
              maxLines: narrow ? 3 : 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
      if (narrow) {
        return Column(children: [image, Expanded(child: text)]);
      }
      return Row(
        children: [
          Expanded(flex: 5, child: image),
          Expanded(flex: 4, child: text),
        ],
      );
    },
  );
}

class _HomeCarousel extends StatefulWidget {
  const _HomeCarousel({required this.cards});

  final List<Map<String, dynamic>> cards;

  @override
  State<_HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<_HomeCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    if (cards.isEmpty) return const SizedBox.shrink();
    final compact = MediaQuery.sizeOf(context).width < 620;
    return Column(
      children: [
        SizedBox(
          height: compact ? 420 : 360,
          child: PageView.builder(
            controller: _controller,
            itemCount: cards.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) => _CarouselCard(card: cards[index]),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            cards.length,
            (index) => Container(
              width: _index == index ? 22 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color:
                    _index == index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({required this.card});

  final Map<String, dynamic> card;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            PermitApiService().resolveFileUrl(
              card['image_url'] as String? ?? '',
            ),
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                  ),
                ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.68),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card['title'] as String? ?? '',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Text(
                    card['body'] as String? ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String description;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                icon,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
