import 'package:flutter/material.dart';

import '../../core/permit_api_service.dart';
import '../../core/session_expiration.dart';
import '../../shared/widgets/app_scaffold.dart';

class ContentManagementPage extends StatefulWidget {
  const ContentManagementPage({super.key, required this.userType});

  final String userType;

  @override
  State<ContentManagementPage> createState() => _ContentManagementPageState();
}

class _ContentManagementPageState extends State<ContentManagementPage> {
  final _api = PermitApiService();
  final _eventTitle = TextEditingController();
  final _eventDescription = TextEditingController();
  final _pointTitle = TextEditingController();
  final _pointDetail = TextEditingController();
  final _pointPlace = TextEditingController();
  final _pointCategory = TextEditingController(text: 'Atrativos');
  final _pointLatitude = TextEditingController();
  final _pointLongitude = TextEditingController();
  final _pointX = TextEditingController(text: '0.50');
  final _pointY = TextEditingController(text: '0.50');
  final _pointOrder = TextEditingController(text: '0');

  static const _secretarias = {
    'semop': 'SEMOP',
    'desenvolvimento_economico': 'Desenvolvimento Econômico',
    'meio_ambiente': 'Meio Ambiente',
    'infraestrutura': 'Infraestrutura',
    'dmtran': 'DMTRAN',
    'vigilancia_sanitaria': 'Vigilância Sanitária',
    'guarda_civil': 'Guarda Civil Municipal',
    'receita_municipal': 'Receita Municipal',
  };

  Map<String, dynamic>? _settings;
  List<Map<String, dynamic>> _points = [];
  final Set<String> _editors = {};
  int? _editingPointId;
  bool _pointActive = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isAdmin => widget.userType == 'admin';
  bool get _canEditEventMap => _settings?['can_edit_event_map'] == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _eventTitle,
      _eventDescription,
      _pointTitle,
      _pointDetail,
      _pointPlace,
      _pointCategory,
      _pointLatitude,
      _pointLongitude,
      _pointX,
      _pointY,
      _pointOrder,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await SessionExpiration.readAccessToken();
      if (token == null) throw PermitApiException('Sessão expirada.');
      final settings = await _api.getContentSettings(accessToken: token);
      final points = await _api.listTourismPoints(accessToken: token);
      if (!mounted) return;
      _eventTitle.text = settings['event_map_title']?.toString() ?? '';
      _eventDescription.text =
          settings['event_map_description']?.toString() ?? '';
      _editors
        ..clear()
        ..addAll(
          (settings['event_map_editor_secretarias'] as List? ?? const []).map(
            (e) => e.toString(),
          ),
        );
      setState(() {
        _settings = settings;
        _points = points;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_eventTitle.text.trim().length < 3 ||
        _eventDescription.text.trim().length < 5) {
      _message(
        'Informe o título e a descrição do mapa de eventos.',
        error: true,
      );
      return;
    }
    await _execute(() async {
      final token = await SessionExpiration.readAccessToken();
      if (token == null) throw PermitApiException('Sessão expirada.');
      final settings = await _api.updateContentSettings(
        accessToken: token,
        eventMapTitle: _eventTitle.text.trim(),
        eventMapDescription: _eventDescription.text.trim(),
        editorSecretarias: _editors.toList(),
      );
      if (mounted) setState(() => _settings = settings);
      _message('Configuração do mapa de eventos salva.');
    });
  }

  Future<void> _savePoint() async {
    if (_pointTitle.text.trim().length < 2 ||
        _pointPlace.text.trim().length < 2 ||
        _pointDetail.text.trim().length < 2) {
      _message(
        'Informe nome, descrição e local do ponto turístico.',
        error: true,
      );
      return;
    }
    await _execute(() async {
      final token = await SessionExpiration.readAccessToken();
      if (token == null) throw PermitApiException('Sessão expirada.');
      await _api.saveTourismPoint(
        accessToken: token,
        pointId: _editingPointId,
        payload: {
          'title': _pointTitle.text.trim(),
          'detail': _pointDetail.text.trim(),
          'place': _pointPlace.text.trim(),
          'category':
              _pointCategory.text.trim().isEmpty
                  ? 'Atrativos'
                  : _pointCategory.text.trim(),
          'latitude': double.tryParse(_pointLatitude.text.replaceAll(',', '.')),
          'longitude': double.tryParse(
            _pointLongitude.text.replaceAll(',', '.'),
          ),
          'marker_x': double.tryParse(_pointX.text.replaceAll(',', '.')) ?? .5,
          'marker_y': double.tryParse(_pointY.text.replaceAll(',', '.')) ?? .5,
          'display_order': int.tryParse(_pointOrder.text) ?? 0,
          'is_active': _pointActive,
        },
      );
      _clearPoint();
      await _load();
      _message('Ponto turístico salvo.');
    });
  }

  Future<void> _deletePoint(int id) async {
    await _execute(() async {
      final token = await SessionExpiration.readAccessToken();
      if (token == null) throw PermitApiException('Sessão expirada.');
      await _api.deleteTourismPoint(accessToken: token, pointId: id);
      await _load();
      _message('Ponto turístico removido.');
    });
  }

  Future<void> _execute(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
    } catch (error) {
      _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _editPoint(Map<String, dynamic> point) {
    setState(() {
      _editingPointId = point['id'] as int?;
      _pointTitle.text = point['title']?.toString() ?? '';
      _pointDetail.text = point['detail']?.toString() ?? '';
      _pointPlace.text = point['place']?.toString() ?? '';
      _pointCategory.text = point['category']?.toString() ?? 'Atrativos';
      _pointLatitude.text = point['latitude']?.toString() ?? '';
      _pointLongitude.text = point['longitude']?.toString() ?? '';
      _pointX.text = point['marker_x']?.toString() ?? '0.5';
      _pointY.text = point['marker_y']?.toString() ?? '0.5';
      _pointOrder.text = point['display_order']?.toString() ?? '0';
      _pointActive = point['is_active'] != false;
    });
  }

  void _clearPoint() {
    setState(() {
      _editingPointId = null;
      _pointTitle.clear();
      _pointDetail.clear();
      _pointPlace.clear();
      _pointCategory.text = 'Atrativos';
      _pointLatitude.clear();
      _pointLongitude.clear();
      _pointX.text = '0.50';
      _pointY.text = '0.50';
      _pointOrder.text = '0';
      _pointActive = true;
    });
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    userType: widget.userType,
    appBar: AppBar(title: const Text('Mapas e conteúdo turístico')),
    body:
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(_error!),
              ),
            )
            : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1050),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _eventMapCard(),
                        const SizedBox(height: 16),
                        _tourismImageGuide(),
                        if (_isAdmin) ...[
                          const SizedBox(height: 16),
                          _tourismForm(),
                          const SizedBox(height: 16),
                        ],
                        _tourismList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
  );

  Widget _eventMapCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Card do mapa de eventos',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _canEditEventMap
                ? 'Edite o texto exibido e defina as secretarias responsáveis.'
                : 'A edição está restrita ao administrador e às secretarias responsáveis.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _eventTitle,
            enabled: _canEditEventMap,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _eventDescription,
            enabled: _canEditEventMap,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 14),
            const Text(
              'Secretarias que podem editar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _secretarias.entries
                      .map(
                        (entry) => FilterChip(
                          label: Text(entry.value),
                          selected: _editors.contains(entry.key),
                          onSelected:
                              (selected) => setState(
                                () =>
                                    selected
                                        ? _editors.add(entry.key)
                                        : _editors.remove(entry.key),
                              ),
                        ),
                      )
                      .toList(),
            ),
          ],
          if (_canEditEventMap) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveSettings,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar configuração'),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _tourismImageGuide() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.map_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arte do mapa turístico',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 5),
                Text(
                  'Tamanhos recomendados: 1920 x 1080 px para web e 1080 x 1350 px para mobile. A arte deve deixar espaço livre para os marcadores e manter a faixa costeira e os pontos principais dentro da área central. O tamanho é apenas uma orientação.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tourismForm() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editingPointId == null
                ? 'Novo ponto turístico'
                : 'Editar ponto turístico',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'As coordenadas alimentam o botão de rota. A posição X/Y define o marcador na arte, usando valores entre 0 e 1.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _field(_pointTitle, 'Nome', 310),
              _field(_pointCategory, 'Categoria', 220),
              _field(_pointPlace, 'Local', 430),
              _field(_pointDetail, 'Descrição curta', 500),
              _field(_pointLatitude, 'Latitude', 180),
              _field(_pointLongitude, 'Longitude', 180),
              _field(_pointX, 'Posição X (0 a 1)', 170),
              _field(_pointY, 'Posição Y (0 a 1)', 170),
              _field(_pointOrder, 'Ordem', 120),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ponto ativo'),
            value: _pointActive,
            onChanged: (value) => setState(() => _pointActive = value),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_editingPointId != null)
                TextButton(
                  onPressed: _clearPoint,
                  child: const Text('Cancelar'),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _savePoint,
                icon: const Icon(Icons.place_outlined),
                label: const Text('Salvar ponto'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _field(TextEditingController controller, String label, double width) =>
      SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget _tourismList() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pontos do mapa turístico',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_points.isEmpty)
            const Text(
              'Nenhum ponto cadastrado. A home usa os pontos ilustrativos padrão.',
            )
          else
            ..._points.map(
              (point) => ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    point['is_active'] == false
                        ? Icons.location_off_outlined
                        : Icons.place_outlined,
                  ),
                ),
                title: Text(point['title']?.toString() ?? ''),
                subtitle: Text('${point['category']} • ${point['place']}'),
                trailing:
                    _isAdmin
                        ? Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Editar',
                              onPressed: () => _editPoint(point),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Excluir',
                              onPressed: () => _deletePoint(point['id'] as int),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        )
                        : null,
              ),
            ),
        ],
      ),
    ),
  );
}
