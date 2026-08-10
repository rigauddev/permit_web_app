import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/permit_api_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../core/session_expiration.dart';

const favoriteEventPermitServiceKey = 'alvara_evento';
const _favoriteServicesStorageKey = 'favorite_services';

Future<String> _favoriteServicesKey() async {
  const storage = FlutterSecureStorage();
  final userJson = await storage.read(key: 'user');
  if (userJson == null || userJson.isEmpty) {
    return _favoriteServicesStorageKey;
  }
  try {
    final user = jsonDecode(userJson) as Map<String, dynamic>;
    final id = user['id']?.toString();
    final email = user['email']?.toString();
    final suffix =
        id != null && id.isNotEmpty
            ? id
            : email != null && email.isNotEmpty
            ? email
            : null;
    return suffix == null
        ? _favoriteServicesStorageKey
        : '${_favoriteServicesStorageKey}_$suffix';
  } catch (_) {
    return _favoriteServicesStorageKey;
  }
}

class ReceitaMunicipalServicesPage extends StatefulWidget {
  final String userType;
  final String? userProfile;
  final String? userName;

  const ReceitaMunicipalServicesPage({
    super.key,
    required this.userType,
    this.userProfile,
    this.userName,
  });

  @override
  State<ReceitaMunicipalServicesPage> createState() =>
      _ReceitaMunicipalServicesPageState();
}

class _ReceitaMunicipalServicesPageState
    extends State<ReceitaMunicipalServicesPage> {
  bool _loading = false;
  bool _favoriteLoading = true;
  Set<String> _favoriteServices = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _favoriteServicesKey();
    final items = prefs.getStringList(storageKey) ?? const [];
    if (!mounted) return;
    setState(() {
      _favoriteServices = items.toSet();
      _favoriteLoading = false;
    });
  }

  Future<void> _toggleFavorite(String serviceKey) async {
    final updated = Set<String>.from(_favoriteServices);
    if (updated.contains(serviceKey)) {
      updated.remove(serviceKey);
    } else {
      updated.add(serviceKey);
    }
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _favoriteServicesKey();
    await prefs.setStringList(storageKey, updated.toList());
    if (!mounted) return;
    setState(() => _favoriteServices = updated);
  }

  @override
  Widget build(BuildContext context) {
    final isCitizen = widget.userType == 'user' || widget.userType == 'cidadao';
    return AppScaffold(
      userType: widget.userType,
      userProfile: widget.userProfile,
      appBar: AppBar(
        title: Text(isCitizen ? 'Serviços municipais' : 'Serviços da área'),
        actions: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => _goBack(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Catálogo de serviços',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  isCitizen
                      ? 'Os serviços estão organizados por categoria. Nesta primeira entrega, o serviço ativo é o Alvará de Evento.'
                      : 'Acompanhe as solicitações relacionadas ao serviço de Alvará de Evento.',
                ),
                const SizedBox(height: 18),
                _ServiceCategorySection(
                  title: 'Prefeitura',
                  description:
                      'Serviços centralizados pela Prefeitura e acompanhados por mais de uma secretaria.',
                  children: [
                    _ServiceCard(
                      icon: Icons.event_available_outlined,
                      title: 'Alvará de Evento',
                      tag: 'MVP ativo',
                      description:
                          'Solicitação de autorização para festas e eventos, com análise das secretarias responsáveis.',
                      loading: _loading,
                      favoriteLoading: _favoriteLoading,
                      isFavorite: _favoriteServices.contains(
                        favoriteEventPermitServiceKey,
                      ),
                      onToggleFavorite:
                          () => _toggleFavorite(favoriteEventPermitServiceKey),
                      onTap: _openEventPermit,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _ServiceCategorySection(
                  title: 'Secretarias',
                  description:
                      'Na v2, cada secretaria terá seus próprios serviços neste catálogo.',
                  children: [
                    _FutureServiceCard(
                      title: 'Meio Ambiente',
                      description:
                          'Serviços ambientais serão adicionados em versões futuras.',
                    ),
                    _FutureServiceCard(
                      title: 'Infraestrutura',
                      description:
                          'Vistorias e serviços técnicos serão organizados aqui.',
                    ),
                    _FutureServiceCard(
                      title: 'DMTRAN',
                      description:
                          'Serviços de mobilidade e trânsito serão incluídos na v2.',
                    ),
                    _FutureServiceCard(
                      title: 'Vigilância Sanitária',
                      description:
                          'Serviços sanitários ficarão separados por secretaria.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEventPermit() async {
    setState(() => _loading = true);
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        await SessionExpiration.logout(context);
        return;
      }

      final forms = await PermitApiService().listRequests(token);
      final definitions = await PermitApiService().listQuestionDefinitions(
        accessToken: token,
      );
      final eventQuestions =
          definitions
              .where((question) => question['tipo'] == 'Alvará de Eventos')
              .toList();
      final questions =
          eventQuestions.isEmpty
              ? PermitApiService.eventPermitQuestions
              : eventQuestions;
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/permit-dashboard',
        arguments: {
          'userType': widget.userType,
          'userProfile': widget.userProfile ?? '',
          'permitType': 'Alvará de Evento',
          'userName': widget.userName ?? '',
          'questions': questions,
          'forms': forms,
        },
      );
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}

class _ServiceCategorySection extends StatelessWidget {
  const _ServiceCategorySection({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(description),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) {
              return Column(
                children:
                    children
                        .map(
                          (child) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: child,
                          ),
                        )
                        .toList(),
              );
            }
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              physics: const NeverScrollableScrollPhysics(),
              children: children,
            );
          },
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.tag,
    required this.description,
    required this.loading,
    required this.favoriteLoading,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String tag;
  final String description;
  final bool loading;
  final bool favoriteLoading;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;
              final chip = Chip(label: Text(tag));
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNarrow)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  isFavorite
                                      ? 'Remover dos favoritos'
                                      : 'Adicionar aos favoritos',
                              onPressed:
                                  favoriteLoading ? null : onToggleFavorite,
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                              ),
                            ),
                          ],
                        ),
                        chip,
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip:
                              isFavorite
                                  ? 'Remover dos favoritos'
                                  : 'Adicionar aos favoritos',
                          onPressed: favoriteLoading ? null : onToggleFavorite,
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                          ),
                        ),
                        chip,
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: isNarrow ? 3 : 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (loading) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          icon,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: content),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Icon(
                    icon,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FutureServiceCard extends StatelessWidget {
  const _FutureServiceCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.lock_clock_outlined,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
    );
  }
}

class FavoriteServicesPage extends StatefulWidget {
  const FavoriteServicesPage({
    super.key,
    required this.userType,
    this.userProfile,
    this.userName,
  });

  final String userType;
  final String? userProfile;
  final String? userName;

  @override
  State<FavoriteServicesPage> createState() => _FavoriteServicesPageState();
}

class _FavoriteServicesPageState extends State<FavoriteServicesPage> {
  bool _loading = true;
  bool _opening = false;
  Set<String> _favoriteServices = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _favoriteServicesKey();
    final items = prefs.getStringList(storageKey) ?? const [];
    if (!mounted) return;
    setState(() {
      _favoriteServices = items.toSet();
      _loading = false;
    });
  }

  Future<void> _removeFavorite(String serviceKey) async {
    final updated = Set<String>.from(_favoriteServices)..remove(serviceKey);
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _favoriteServicesKey();
    await prefs.setStringList(storageKey, updated.toList());
    if (!mounted) return;
    setState(() => _favoriteServices = updated);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      userType: widget.userType,
      userProfile: widget.userProfile,
      appBar: AppBar(
        title: const Text('Serviços favoritos'),
        actions: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            icon: const Icon(Icons.arrow_back),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child:
                        _favoriteServices.contains(
                              favoriteEventPermitServiceKey,
                            )
                            ? _FavoriteServiceTile(
                              opening: _opening,
                              onOpen: _openEventPermit,
                              onRemove:
                                  () => _removeFavorite(
                                    favoriteEventPermitServiceKey,
                                  ),
                            )
                            : const _EmptyFavorites(),
                  ),
                ),
              ),
    );
  }

  Future<void> _openEventPermit() async {
    setState(() => _opening = true);
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        await SessionExpiration.logout(context);
        return;
      }
      final forms = await PermitApiService().listRequests(token);
      final definitions = await PermitApiService().listQuestionDefinitions(
        accessToken: token,
      );
      final eventQuestions =
          definitions
              .where((question) => question['tipo'] == 'Alvará de Eventos')
              .toList();
      final questions =
          eventQuestions.isEmpty
              ? PermitApiService.eventPermitQuestions
              : eventQuestions;
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.permitDashboard,
        arguments: {
          'userType': widget.userType,
          'userProfile': widget.userProfile ?? '',
          'permitType': 'Alvará de Evento',
          'userName': widget.userName ?? '',
          'questions': questions,
          'forms': forms,
        },
      );
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }
}

class _FavoriteServiceTile extends StatelessWidget {
  const _FavoriteServiceTile({
    required this.opening,
    required this.onOpen,
    required this.onRemove,
  });

  final bool opening;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.event_available_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Alvará de Evento'),
        subtitle: const Text(
          'Solicitação de autorização para festas e eventos.',
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: 'Remover favorito',
              onPressed: onRemove,
              icon: const Icon(Icons.favorite),
            ),
            ElevatedButton.icon(
              onPressed: opening ? null : onOpen,
              icon:
                  opening
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.open_in_new),
              label: const Text('Abrir'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhum serviço favorito',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Marque serviços com o coração no catálogo para aparecerem aqui.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed:
                  () => Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.services,
                  ),
              icon: const Icon(Icons.search),
              label: const Text('Ver serviços'),
            ),
          ],
        ),
      ),
    );
  }
}
