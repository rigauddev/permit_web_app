import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/widgets/app_scaffold.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({
    super.key,
    required this.userType,
    this.operatorMode = false,
  });

  final String userType;
  final bool operatorMode;

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  List<_HelpTopic> _topics = const [];
  bool _loaded = false;

  bool get _canEdit =>
      widget.userType == 'admin' || widget.userType == 'gestor';
  String get _storageKey =>
      widget.operatorMode ? 'help_topics_operator' : 'help_topics_user';

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    List<_HelpTopic>? saved;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        saved = decoded
            .map(
              (item) =>
                  _HelpTopic.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(growable: false);
      } catch (_) {
        saved = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _topics = saved ?? _defaultTopics(widget.operatorMode);
      _loaded = true;
    });
  }

  Future<void> _saveTopics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_topics.map((topic) => topic.toJson()).toList()),
    );
  }

  Future<void> _editTopic(int index) async {
    final topic = _topics[index];
    final title = TextEditingController(text: topic.title);
    final text = TextEditingController(text: topic.text);
    final saved = await showDialog<_HelpTopic>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Editar tópico de ajuda'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: text,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: 'Texto'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (title.text.trim().isEmpty || text.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.pop(
                    context,
                    _HelpTopic(
                      title: title.text.trim(),
                      text: text.text.trim(),
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar'),
              ),
            ],
          ),
    );
    title.dispose();
    text.dispose();
    if (saved == null) return;
    setState(() {
      final next = [..._topics];
      next[index] = saved;
      _topics = next;
    });
    await _saveTopics();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      userType: widget.userType,
      appBar: AppBar(
        leading: BackButton(onPressed: () => _goBack(context)),
        title: Text(
          widget.operatorMode ? 'Ajuda dos operadores' : 'Ajuda do usuário',
        ),
        actions: [
          if (_canEdit)
            IconButton(
              tooltip: 'Restaurar tópicos padrão',
              onPressed: () async {
                setState(() => _topics = _defaultTopics(widget.operatorMode));
                await _saveTopics();
              },
              icon: const Icon(Icons.restore_outlined),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child:
              !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _topics.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _HelpIntro(
                          operatorMode: widget.operatorMode,
                          canEdit: _canEdit,
                        );
                      }
                      final topicIndex = index - 1;
                      return _HelpCard(
                        title: _topics[topicIndex].title,
                        text: _topics[topicIndex].text,
                        canEdit: _canEdit,
                        onEdit: () => _editTopic(topicIndex),
                      );
                    },
                  ),
        ),
      ),
    );
  }

  static void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  static List<_HelpTopic> _defaultTopics(bool operatorMode) =>
      operatorMode
          ? const [
            _HelpTopic(
              title: 'Gestão de serviços',
              text:
                  'Use os grupos de serviço para acessar filas de solicitações, vistorias, validação de eventos, relatórios e dashboard.',
            ),
            _HelpTopic(
              title: 'Fiscalização da Orla',
              text:
                  'Valide QR Code ou placa, confirme os dados do veículo e registre a entrada apenas quando o acesso estiver autorizado.',
            ),
            _HelpTopic(
              title: 'Permissões',
              text:
                  'Operadores e gestores visualizam somente serviços vinculados à secretaria. Gestão do sistema é exclusiva do administrador.',
            ),
          ]
          : const [
            _HelpTopic(
              title: 'Serviços da Prefeitura',
              text:
                  'Acesse o catálogo para solicitar alvarás, favoritar serviços e acompanhar solicitações.',
            ),
            _HelpTopic(
              title: 'Acesso à Orla',
              text:
                  'Cadastre seus veículos, imprima o QR Code e acompanhe o histórico de entrada na Orla de Guaibim.',
            ),
            _HelpTopic(
              title: 'Meu perfil e solicitações',
              text:
                  'Mantenha seus dados atualizados e acompanhe suas solicitações em Meus serviços.',
            ),
          ];
}

class _HelpTopic {
  const _HelpTopic({required this.title, required this.text});
  final String title;
  final String text;

  factory _HelpTopic.fromJson(Map<String, dynamic> json) => _HelpTopic(
    title: json['title']?.toString() ?? '',
    text: json['text']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {'title': title, 'text': text};
}

class _HelpIntro extends StatelessWidget {
  const _HelpIntro({required this.operatorMode, required this.canEdit});

  final bool operatorMode;
  final bool canEdit;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFE5F4EA),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.help_outline)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              operatorMode
                  ? 'Base de ajuda para operadores e gestores do sistema.'
                  : 'Base de ajuda para cidadãos, turistas e estabelecimentos.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (canEdit)
            const Chip(
              avatar: Icon(Icons.edit_outlined, size: 18),
              label: Text('Editável'),
            ),
        ],
      ),
    ),
  );
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.title,
    required this.text,
    required this.canEdit,
    required this.onEdit,
  });

  final String title;
  final String text;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(text),
              ],
            ),
          ),
          if (canEdit)
            IconButton.filledTonal(
              tooltip: 'Editar tópico',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
    ),
  );
}
