import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/permit_api_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/session_store.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../core/session_expiration.dart';

const favoriteEventPermitServiceKey = 'alvara_evento';
const favoriteOrlaServiceKey = 'acesso_orla';
const favoriteBusinessPermitServiceKey = 'alvara_funcionamento';
const favoriteIptuServiceKey = 'iptu';
const _favoriteServicesStorageKey = 'favorite_services';

Future<String> _favoriteServicesKey() async {
  final userJson = await const SessionStore().readUserJson();
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
  List<Map<String, dynamic>> _eventTypes = [];
  Set<String> _activeServices = {
    favoriteEventPermitServiceKey,
    favoriteOrlaServiceKey,
  };

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadEventTypes();
    _loadServiceConfigs();
  }

  Future<void> _loadServiceConfigs() async {
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) return;
      final services = await PermitApiService().listServiceConfigs(
        accessToken: token,
      );
      if (!mounted) return;
      setState(() {
        _activeServices =
            services
                .where((item) => item['is_active'] == true)
                .map((item) => item['key'].toString())
                .toSet();
      });
    } catch (_) {}
  }

  Future<void> _loadEventTypes() async {
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) return;
      final eventTypes = await PermitApiService().listEventTypes(
        accessToken: token,
      );
      if (!mounted) return;
      setState(() {
        _eventTypes =
            eventTypes.isEmpty
                ? PermitApiService.eventTypesFallback
                : eventTypes;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _eventTypes = PermitApiService.eventTypesFallback;
      });
    }
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
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
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
                      ? 'Solicite alvarás de eventos e cadastre veículos para acesso à orla.'
                      : 'Acompanhe as solicitações relacionadas ao serviço de Alvará de Evento.',
                ),
                const SizedBox(height: 18),
                _ServiceCategorySection(
                  title: 'Prefeitura',
                  description:
                      'Serviços centralizados pela Prefeitura e acompanhados por mais de uma secretaria.',
                  children: [
                    if (_activeServices.contains(
                          favoriteEventPermitServiceKey,
                        ) ||
                        _activeServices.contains(
                          favoriteBusinessPermitServiceKey,
                        ))
                      _PermitGroupCard(
                        eventActive: _activeServices.contains(
                          favoriteEventPermitServiceKey,
                        ),
                        businessActive: _activeServices.contains(
                          favoriteBusinessPermitServiceKey,
                        ),
                        loading: _loading,
                        favoriteLoading: _favoriteLoading,
                        eventFavorite: _favoriteServices.contains(
                          favoriteEventPermitServiceKey,
                        ),
                        businessFavorite: _favoriteServices.contains(
                          favoriteBusinessPermitServiceKey,
                        ),
                        onOpenEvent: _openEventPermit,
                        onOpenBusiness:
                            () => _showServiceUnavailable(
                              'Alvará de Funcionamento',
                            ),
                        onToggleEvent:
                            () =>
                                _toggleFavorite(favoriteEventPermitServiceKey),
                        onToggleBusiness:
                            () => _toggleFavorite(
                              favoriteBusinessPermitServiceKey,
                            ),
                      ),
                    if (_activeServices.contains(favoriteIptuServiceKey))
                      _ServiceCard(
                        icon: Icons.home_work_outlined,
                        title: 'IPTU',
                        tag: 'Prefeitura',
                        description:
                            'Consulta e serviços relacionados ao IPTU.',
                        loading: false,
                        favoriteLoading: _favoriteLoading,
                        isFavorite: _favoriteServices.contains(
                          favoriteIptuServiceKey,
                        ),
                        onToggleFavorite:
                            () => _toggleFavorite(favoriteIptuServiceKey),
                        onTap: () => _showServiceUnavailable('IPTU'),
                      ),
                    if (_activeServices.contains(favoriteOrlaServiceKey))
                      _ServiceCard(
                        icon: Icons.beach_access,
                        title: 'Acesso à Orla',
                        tag: 'SEMOP',
                        description:
                            'Cadastre veículos, gere QR Code e solicite acesso à Orla da praia de Guaibim.',
                        loading: false,
                        favoriteLoading: _favoriteLoading,
                        isFavorite: _favoriteServices.contains(
                          favoriteOrlaServiceKey,
                        ),
                        onToggleFavorite:
                            () => _toggleFavorite(favoriteOrlaServiceKey),
                        onTap:
                            () => Navigator.pushNamed(context, AppRoutes.orla),
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

  void _showServiceUnavailable(String serviceName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$serviceName está ativo no catálogo, mas o formulário ainda será publicado.',
        ),
      ),
    );
  }

  Future<void> _openEventPermit() async {
    setState(() => _loading = true);
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        await SessionExpiration.logout(context);
        return;
      }

      final forms = await PermitApiService().listRequests(token);
      final definitions = await PermitApiService().listQuestionDefinitions(
        accessToken: token,
      );
      final eventTypes = await PermitApiService().listEventTypes(
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
          'eventTypes':
              eventTypes.isEmpty
                  ? _eventTypes.isEmpty
                      ? PermitApiService.eventTypesFallback
                      : _eventTypes
                  : eventTypes,
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
              childAspectRatio: 1.45,
              physics: const NeverScrollableScrollPhysics(),
              children: children,
            );
          },
        ),
      ],
    );
  }
}

class _PermitGroupCard extends StatelessWidget {
  const _PermitGroupCard({
    required this.eventActive,
    required this.businessActive,
    required this.loading,
    required this.favoriteLoading,
    required this.eventFavorite,
    required this.businessFavorite,
    required this.onOpenEvent,
    required this.onOpenBusiness,
    required this.onToggleEvent,
    required this.onToggleBusiness,
  });

  final bool eventActive;
  final bool businessActive;
  final bool loading;
  final bool favoriteLoading;
  final bool eventFavorite;
  final bool businessFavorite;
  final VoidCallback onOpenEvent;
  final VoidCallback onOpenBusiness;
  final VoidCallback onToggleEvent;
  final VoidCallback onToggleBusiness;

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
                CircleAvatar(
                  backgroundColor: const Color(0xFFE5F4EA),
                  child: Icon(
                    Icons.assignment_turned_in_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alvarás',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('Escolha o tipo de alvará que deseja solicitar.'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (eventActive)
              _PermitSubServiceTile(
                icon: Icons.event_available_outlined,
                title: 'Alvará de Evento',
                description: 'Festas, eventos e autorizações temporárias.',
                loading: loading,
                favoriteLoading: favoriteLoading,
                isFavorite: eventFavorite,
                onTap: onOpenEvent,
                onToggleFavorite: onToggleEvent,
              ),
            if (businessActive)
              _PermitSubServiceTile(
                icon: Icons.store_mall_directory_outlined,
                title: 'Alvará de Funcionamento',
                description: 'Funcionamento de estabelecimentos e atividades.',
                loading: false,
                favoriteLoading: favoriteLoading,
                isFavorite: businessFavorite,
                onTap: onOpenBusiness,
                onToggleFavorite: onToggleBusiness,
              ),
          ],
        ),
      ),
    );
  }
}

class _PermitSubServiceTile extends StatelessWidget {
  const _PermitSubServiceTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.loading,
    required this.favoriteLoading,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool loading;
  final bool favoriteLoading;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBF7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD8E0D8)),
        ),
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(description),
          onTap: loading ? null : onTap,
          trailing: IconButton(
            tooltip:
                isFavorite
                    ? 'Remover dos favoritos'
                    : 'Adicionar aos favoritos',
            onPressed: favoriteLoading ? null : onToggleFavorite,
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          ),
        ),
      ),
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
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
          icon: const Icon(Icons.arrow_back),
        ),
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
      final token = await SessionExpiration.readAccessToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        await SessionExpiration.logout(context);
        return;
      }
      final forms = await PermitApiService().listRequests(token);
      final definitions = await PermitApiService().listQuestionDefinitions(
        accessToken: token,
      );
      final eventTypes = await PermitApiService().listEventTypes(
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
          'eventTypes':
              eventTypes.isEmpty
                  ? PermitApiService.eventTypesFallback
                  : eventTypes,
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
