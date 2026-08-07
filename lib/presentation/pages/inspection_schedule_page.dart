import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/permit_api_service.dart';
import '../../core/routes/app_routes.dart';
import '../../core/session_expiration.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/user_provider.dart';
import '../../shared/widgets/custom_drawer.dart';

class InspectionSchedulePage extends ConsumerStatefulWidget {
  const InspectionSchedulePage({super.key, required this.userType});

  final String userType;

  @override
  ConsumerState<InspectionSchedulePage> createState() =>
      _InspectionSchedulePageState();
}

class _InspectionSchedulePageState
    extends ConsumerState<InspectionSchedulePage> {
  final _api = PermitApiService();
  final _storage = const FlutterSecureStorage();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null || token.isEmpty) {
        if (mounted) await SessionExpiration.logout(context);
        return;
      }
      final requests = await _api.listRequests(token);
      if (!mounted) return;
      setState(() => _requests = requests);
    } on PermitApiException catch (error) {
      if (error.statusCode == 401 && mounted) {
        await SessionExpiration.logout(context);
        return;
      }
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar as vistorias.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final inspections = _buildInspections(_requests, user);
    final today = DateUtils.dateOnly(DateTime.now());
    final performed =
        inspections
            .where((item) => item.date != null && item.date!.isBefore(today))
            .toList();
    final todayItems =
        inspections
            .where((item) => DateUtils.isSameDay(item.date, today))
            .toList();
    final future =
        inspections
            .where((item) => item.date == null || item.date!.isAfter(today))
            .toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed:
              () => Navigator.pushReplacementNamed(context, AppRoutes.home),
        ),
        title: const Text('Vistorias e pendências'),
      ),
      drawer: CustomDrawer(userType: widget.userType),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child:
                    _loading
                        ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                        : _error != null
                        ? _MessageState(
                          icon: Icons.error_outline,
                          title: _error!,
                          onRefresh: _loadRequests,
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Header(total: inspections.length),
                            const SizedBox(height: 16),
                            _Calendar(inspections: inspections),
                            const SizedBox(height: 16),
                            _InspectionSection(
                              title: 'Vistorias de hoje',
                              icon: Icons.today_outlined,
                              items: todayItems,
                            ),
                            _InspectionSection(
                              title: 'Vistorias futuras',
                              icon: Icons.event_available_outlined,
                              items: future,
                            ),
                            _InspectionSection(
                              title: 'Vistorias realizadas',
                              icon: Icons.fact_check_outlined,
                              items: performed,
                            ),
                          ],
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<_InspectionItem> _buildInspections(
    List<Map<String, dynamic>> requests,
    UserModel? user,
  ) {
    final items = <_InspectionItem>[];
    for (final request in requests) {
      final requirements =
          (request['perguntas'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>();
      for (final requirement in requirements) {
        if (!_isVisibleToUser(requirement, user)) continue;
        if (!_requiresInspection(requirement['pergunta']?.toString() ?? '')) {
          continue;
        }
        items.add(
          _InspectionItem(
            eventName: request['nome_do_evento']?.toString() ?? 'Evento',
            protocol: request['protocolo']?.toString() ?? '-',
            secretaria: requirement['secretaria']?.toString() ?? '',
            requirement: requirement['pergunta']?.toString() ?? '',
            status: requirement['status']?.toString() ?? 'aguardando_analise',
            date: _parseDate(request['data_do_evento']?.toString()),
          ),
        );
      }
    }
    items.sort((a, b) {
      final aDate = a.date ?? DateTime(9999);
      final bDate = b.date ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return items;
  }

  static bool _isVisibleToUser(
    Map<String, dynamic> requirement,
    UserModel? user,
  ) {
    if (user?.userType == 'admin') return true;
    return requirement['secretaria_slug'] == user?.secretaria;
  }

  static bool _requiresInspection(String text) {
    final value = text.toLowerCase();
    return value.contains('vistoria') ||
        value.contains('avcb') ||
        value.contains('palco') ||
        value.contains('gerador') ||
        value.contains('trio') ||
        value.contains('alimentação') ||
        value.contains('alimentacao');
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/images/logo_prefeitura_1.png', height: 64),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Agenda técnica',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text('$total exigência(s) técnicas encontradas.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.inspections});

  final List<_InspectionItem> inspections;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final monthDays = DateUtils.getDaysInMonth(now.year, now.month);
    final leading = firstDay.weekday % 7;
    final counts = <int, int>{};
    for (final item in inspections) {
      final date = item.date;
      if (date == null || date.month != now.month || date.year != now.year) {
        continue;
      }
      counts[date.day] = (counts[date.day] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calendário do mês',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              itemCount: leading + monthDays,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.5,
              ),
              itemBuilder: (context, index) {
                if (index < leading) return const SizedBox.shrink();
                final day = index - leading + 1;
                final count = counts[day] ?? 0;
                final selected = count > 0;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                    ),
                    color:
                        selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                  ),
                  child: Center(
                    child: Text(
                      count > 0 ? '$day\n$count vist.' : '$day',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectionSection extends StatelessWidget {
  const _InspectionSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<_InspectionItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: title == 'Vistorias de hoje',
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${items.length} registro(s)'),
        children:
            items.isEmpty
                ? const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum registro nesta categoria.'),
                  ),
                ]
                : items.map((item) => _InspectionTile(item: item)).toList(),
      ),
    );
  }
}

class _InspectionTile extends StatelessWidget {
  const _InspectionTile({required this.item});

  final _InspectionItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.requirement),
      subtitle: Text(
        '${item.eventName} | Protocolo ${item.protocol} | ${item.secretaria}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(item.dateLabel),
          Text(item.status, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.onRefresh,
  });

  final IconData icon;
  final String title;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }
}

class _InspectionItem {
  const _InspectionItem({
    required this.eventName,
    required this.protocol,
    required this.secretaria,
    required this.requirement,
    required this.status,
    required this.date,
  });

  final String eventName;
  final String protocol;
  final String secretaria;
  final String requirement;
  final String status;
  final DateTime? date;

  String get dateLabel {
    final value = date;
    if (value == null) return 'Sem data';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}
