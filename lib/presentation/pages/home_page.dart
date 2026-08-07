import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permit_api_service.dart';
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
  final _storage = const FlutterSecureStorage();
  final _api = PermitApiService();
  late Future<List<Map<String, dynamic>>> _contentFuture;

  bool get _isCitizen =>
      widget.userType == 'user' || widget.userType == 'cidadao';

  @override
  void initState() {
    super.initState();
    _contentFuture = _loadContent();
  }

  Future<List<Map<String, dynamic>>> _loadContent() async {
    final token = await _storage.read(key: 'access_token');
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    return AppScaffold(
      userType: widget.userType,
      userProfile: widget.userProfile,
      appBar: AppBar(
        title: Text(_isCitizen ? 'Página inicial' : 'Painel da secretaria'),
      ),
      body:
          _isCitizen
              ? _CitizenHome(contentFuture: _contentFuture)
              : _InternalHome(user: user),
    );
  }

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
  const _CitizenHome({required this.contentFuture});

  final Future<List<Map<String, dynamic>>> contentFuture;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/logo_prefeitura_1.png',
                  height: 86,
                ),
              ),
              const SizedBox(height: 18),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: contentFuture,
                builder: (context, snapshot) {
                  final cards = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 320,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _HomeCarousel(cards: cards);
                },
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 680;
                  return GridView.count(
                    crossAxisCount: isNarrow ? 1 : 2,
                    shrinkWrap: true,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isNarrow ? 2.8 : 2.2,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _HomeActionCard(
                        icon: Icons.event_available_outlined,
                        title: 'Solicitar alvará de evento',
                        description:
                            'Preencha o formulário, envie documentos e acompanhe o protocolo.',
                        route: '/services',
                      ),
                      _HomeActionCard(
                        icon: Icons.folder_copy_outlined,
                        title: 'Minhas solicitações',
                        description:
                            'Consulte status, pendências e autorizações emitidas.',
                        route: '/services',
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
}

class _InternalHome extends StatelessWidget {
  const _InternalHome({required this.user});

  final UserModel? user;

  bool get _canManageUsers =>
      user?.userType == 'admin' || user?.userType == 'gestor';

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
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo_prefeitura_1.png',
                    height: 72,
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
                        route: '/services',
                      ),
                      const _HomeActionCard(
                        icon: Icons.fact_check_outlined,
                        title: 'Vistorias e pendências',
                        description:
                            'Acompanhe exigências técnicas, documentos e retornos do cidadão.',
                        route: '/services',
                      ),
                      if (_canManageUsers)
                        const _HomeActionCard(
                          icon: Icons.people_outline,
                          title: 'Usuários internos',
                          description:
                              'Consulte e cadastre equipes conforme o escopo da secretaria.',
                          route: '/users',
                        ),
                      if (_canManageUsers)
                        const _HomeActionCard(
                          icon: Icons.view_carousel_outlined,
                          title: 'Conteúdo da home',
                          description:
                              'Crie até 5 cards de carrossel para sua secretaria ou prefeitura.',
                          route: '/home-content',
                        ),
                      if (user?.userType == 'admin')
                        const _HomeActionCard(
                          icon: Icons.tune_outlined,
                          title: 'Perguntas e permissões',
                          description:
                              'Configure perguntas condicionais e regras por secretaria.',
                          route: '/questtions',
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
    return Column(
      children: [
        SizedBox(
          height: 340,
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
            card['image_url'] as String? ?? '',
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
