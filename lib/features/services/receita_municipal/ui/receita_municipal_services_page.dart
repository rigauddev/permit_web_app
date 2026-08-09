import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/permit_api_service.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../core/session_expiration.dart';

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
            final crossAxisCount = constraints.maxWidth < 760 ? 1 : 2;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: constraints.maxWidth < 760 ? 2.9 : 2.2,
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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String tag;
  final String description;
  final bool loading;
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
                      chip,
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 4,
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
