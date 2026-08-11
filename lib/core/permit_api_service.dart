import 'dart:convert';

import 'package:http/http.dart' as http;

class PermitApiService {
  PermitApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://127.0.0.1:8000',
          );

  final http.Client _client;
  final String _baseUrl;

  String resolveFileUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    final base = Uri.parse(_baseUrl);
    if (value.startsWith('/')) {
      return base.replace(path: value, query: null, fragment: null).toString();
    }
    return base.resolve(value).toString();
  }

  static const List<Map<String, dynamic>> eventPermitQuestions = [
    {
      'id': 1,
      'key': 'tem_som',
      'pergunta': 'O evento terá som?',
      'secretaria': 'Meio Ambiente',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencia': 'Termo de Responsabilidade Ambiental',
    },
    {
      'id': 2,
      'key': 'local_fixo_sem_alvara',
      'pergunta':
          'O evento será em local fixo sem alvará de funcionamento válido?',
      'secretaria': 'Desenvolvimento Econômico',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencias': ['Regularização do alvará de funcionamento do local fixo'],
    },
    {
      'id': 3,
      'key': 'precisa_avcb',
      'pergunta': 'O evento exige Auto de Vistoria do Corpo de Bombeiros?',
      'secretaria': 'Infraestrutura',
      'tipos_resposta': ['Sim/Não', 'Anexar Documento', 'Texto'],
      'exigencias': ['Auto de Vistoria do Corpo de Bombeiros (AVCB)'],
    },
    {
      'id': 4,
      'key': 'tem_palco',
      'pergunta': 'O evento terá palco ou estrutura montada?',
      'secretaria': 'Infraestrutura',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencias': [
        'Vistoria de palco/estrutura',
        'Anotação de Responsabilidade Técnica (ART) da estrutura',
      ],
    },
    {
      'id': 5,
      'key': 'tem_gerador',
      'pergunta': 'O evento terá gerador?',
      'secretaria': 'Infraestrutura',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencias': [
        'Vistoria de gerador',
        'Anotação de Responsabilidade Técnica (ART) do gerador',
      ],
    },
    {
      'id': 6,
      'key': 'precisa_planta_baixa',
      'pergunta':
          'Evento particular de médio/grande porte em local fixo exigirá planta baixa?',
      'secretaria': 'Infraestrutura',
      'tipos_resposta': ['Sim/Não', 'Anexar Documento', 'Texto'],
      'exigencias': [
        'Planta baixa para evento particular de médio ou grande porte em local fixo',
      ],
    },
    {
      'id': 7,
      'key': 'tem_trio_eletrico',
      'pergunta': 'O evento terá trio elétrico?',
      'secretaria': 'DMTRAN',
      'tipos_resposta': ['Sim/Não', 'Texto', 'Anexar Documento'],
      'exigencias': [
        'Vistoria do veículo, CNH do motorista e mapa do circuito',
      ],
    },
    {
      'id': 8,
      'key': 'bloqueia_via',
      'pergunta': 'O evento usará ou bloqueará vias/ruas municipais?',
      'secretaria': 'DMTRAN',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencias': [
        'Autorização para uso ou bloqueio de via pública',
        'Croqui/mapa do circuito ou desvio de trânsito',
      ],
    },
    {
      'id': 9,
      'key': 'tem_alimentacao',
      'pergunta':
          'O evento terá venda, preparo ou distribuição de alimentação?',
      'secretaria': 'Vigilância Sanitária',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencias': ['Vistoria de equipamentos e instalações de alimentação'],
    },
    {
      'id': 10,
      'key': 'precisa_ambulancia',
      'pergunta': 'O evento precisará de ambulância no local?',
      'secretaria': 'Secretaria de Saúde',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencias': ['Ofício solicitando ambulância no local do evento'],
    },
    {
      'id': 11,
      'key': 'precisa_guarda',
      'pergunta': 'Será necessária a presença da Guarda Civil Municipal?',
      'secretaria': 'Guarda Civil Municipal',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencias': ['Ofício solicitando presença da Guarda Civil Municipal'],
    },
    {
      'id': 12,
      'key': 'precisa_brigadista',
      'pergunta': 'O evento exigirá brigadista contratado?',
      'secretaria': 'Responsável pelo evento',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencias': ['Contratação de brigadista pelo responsável'],
    },
  ];

  Future<List<Map<String, dynamic>>> listRequests(String accessToken) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/permit-requests'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final decoded = _decodeResponse(response);
    final requests = decoded as List<dynamic>;
    return requests
        .map((item) => _toDashboardForm(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> updateRequirementStatus({
    required String accessToken,
    required int requirementId,
    required String status,
    String? observacoes,
  }) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/permit-requests/requirements/$requirementId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'status': status, 'observacoes': observacoes}),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> scheduleInspection({
    required String accessToken,
    required int requirementId,
    required String scheduledFor,
  }) async {
    final response = await _client.patch(
      Uri.parse(
        '$_baseUrl/permit-requests/requirements/$requirementId/inspection-schedule',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'scheduled_for': scheduledFor}),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeInspection({
    required String accessToken,
    required int requirementId,
    required bool approved,
    required Map<String, bool> checklist,
    String? observacoes,
    List<String> fotos = const [],
    String? novaData,
  }) async {
    final response = await _client.patch(
      Uri.parse(
        '$_baseUrl/permit-requests/requirements/$requirementId/inspection-complete',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'approved': approved,
        'checklist': checklist,
        'observacoes': observacoes,
        'fotos': fotos,
        'nova_data': novaData,
      }),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listHomeContent(String accessToken) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/home-content'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final decoded = _decodeResponse(response) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createHomeContent({
    required String accessToken,
    required String scope,
    required String title,
    required String body,
    required String imageUrl,
    required int displayOrder,
    required bool isActive,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/home-content'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'scope': scope,
        'title': title,
        'body': body,
        'image_url': imageUrl,
        'display_order': displayOrder,
        'is_active': isActive,
      }),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateHomeContent({
    required String accessToken,
    required int cardId,
    required String scope,
    required String title,
    required String body,
    required String imageUrl,
    required int displayOrder,
    required bool isActive,
  }) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/home-content/$cardId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'scope': scope,
        'title': title,
        'body': body,
        'image_url': imageUrl,
        'display_order': displayOrder,
        'is_active': isActive,
      }),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listSecretarias({
    required String accessToken,
  }) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/secretarias'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final decoded = _decodeResponse(response) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createSecretaria({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/secretarias'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSecretaria({
    required String accessToken,
    required int secretariaId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/secretarias/$secretariaId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<void> deleteSecretaria({
    required String accessToken,
    required int secretariaId,
  }) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/secretarias/$secretariaId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decodeResponse(response);
    }
  }

  Future<Map<String, dynamic>> getPermissionMatrix({
    required String accessToken,
  }) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/permissions'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRolePermissions({
    required String accessToken,
    required String roleSlug,
    required List<String> permissions,
  }) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/permissions/roles/$roleSlug'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'permissions': permissions}),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createRole({
    required String accessToken,
    required String slug,
    required String nome,
    String? descricao,
    List<String> permissions = const [],
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/permissions/roles'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'slug': slug,
        'nome': nome,
        'descricao': descricao,
        'permissions': permissions,
      }),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listPublicRanges({
    required String accessToken,
  }) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/permit-requests/public-ranges'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final decoded = _decodeResponse(response) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createPublicRange({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/permit-requests/public-ranges'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePublicRange({
    required String accessToken,
    required int rangeId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/permit-requests/public-ranges/$rangeId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<void> deletePublicRange({
    required String accessToken,
    required int rangeId,
  }) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/permit-requests/public-ranges/$rangeId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decodeResponse(response);
    }
  }

  Future<Map<String, dynamic>> getAuthorization({
    required String accessToken,
    required int requestId,
  }) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/permit-requests/$requestId/authorization'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> issueAuthorization({
    required String accessToken,
    required int requestId,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/permit-requests/$requestId/issue-authorization'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> attachDam({
    required String accessToken,
    required int requestId,
    required String fileName,
    required String fileUrl,
    String? mimeType,
    int? sizeBytes,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/permit-requests/$requestId/dam-attachment'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'nome_arquivo': fileName,
        'arquivo_url': fileUrl,
        'mime_type': mimeType,
        'tamanho_bytes': sizeBytes,
      }),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> attachDamPaymentProof({
    required String accessToken,
    required int requestId,
    required String fileName,
    required String fileUrl,
    String? mimeType,
    int? sizeBytes,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/permit-requests/$requestId/dam-payment-proof'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'nome_arquivo': fileName,
        'arquivo_url': fileUrl,
        'mime_type': mimeType,
        'tamanho_bytes': sizeBytes,
      }),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> attachFinalPermit({
    required String accessToken,
    required int requestId,
    required String fileName,
    required String fileUrl,
    String? mimeType,
    int? sizeBytes,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/permit-requests/$requestId/final-permit-attachment'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'nome_arquivo': fileName,
        'arquivo_url': fileUrl,
        'mime_type': mimeType,
        'tamanho_bytes': sizeBytes,
      }),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> validateEventCredential({
    required String publicCode,
    required String token,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/event-credentials/$publicCode/validate',
    ).replace(queryParameters: {'t': token});
    final response = await _client.get(uri);
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAuthorizationTemplate({
    required String accessToken,
  }) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/permit-requests/authorization-template'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAuthorizationTemplate({
    required String accessToken,
    required String headerText,
    required String footerText,
  }) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/permit-requests/authorization-template'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'header_text': headerText, 'footer_text': footerText}),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listQuestionDefinitions({
    required String accessToken,
  }) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/permit-requests/question-definitions'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final decoded = _decodeResponse(response) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createQuestionDefinition({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/permit-requests/question-definitions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateQuestionDefinition({
    required String accessToken,
    required int questionId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/permit-requests/question-definitions/$questionId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<void> deleteQuestionDefinition({
    required String accessToken,
    required int questionId,
  }) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/permit-requests/question-definitions/$questionId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decodeResponse(response);
    }
  }

  Future<Map<String, dynamic>> createRequest({
    required String accessToken,
    required Map<String, String> responsibleData,
    required Map<String, String> eventData,
    required Map<String, bool> answers,
    required Map<String, dynamic> answerDetails,
    required List<String> attachmentNames,
  }) async {
    final isBeneficente = eventData['is_beneficente'] == 'true';
    final response = await _client.post(
      Uri.parse('$_baseUrl/permit-requests'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'is_beneficente': isBeneficente,
        'instituicao_beneficiada': eventData['instituicao_beneficiada'],
        'dados_responsavel': responsibleData,
        'dados_evento': {...eventData, 'anexos_informados': attachmentNames},
        'respostas': {
          for (final entry in answers.entries)
            entry.key:
                answerDetails[entry.key] is Map
                    ? {
                      ...Map<String, dynamic>.from(answerDetails[entry.key]),
                      'valor': entry.value,
                    }
                    : entry.value,
        },
      }),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelRequest({
    required String accessToken,
    required int requestId,
    String? motivo,
  }) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/permit-requests/$requestId/cancel'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'motivo': motivo}),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  static const Map<String, List<Map<String, String>>> requirementRules = {
    'tem_som': [
      {
        'secretaria': 'Meio Ambiente',
        'exigencia': 'Termo de Responsabilidade Ambiental',
      },
    ],
    'local_fixo_sem_alvara': [
      {
        'secretaria': 'Desenvolvimento Econômico',
        'exigencia': 'Regularização do alvará de funcionamento do local fixo',
      },
    ],
    'precisa_avcb': [
      {
        'secretaria': 'Infraestrutura',
        'exigencia': 'Auto de Vistoria do Corpo de Bombeiros (AVCB)',
      },
    ],
    'tem_palco': [
      {
        'secretaria': 'Infraestrutura',
        'exigencia': 'Vistoria de palco/estrutura',
      },
      {
        'secretaria': 'Infraestrutura',
        'exigencia': 'Anotação de Responsabilidade Técnica (ART) da estrutura',
      },
    ],
    'tem_gerador': [
      {'secretaria': 'Infraestrutura', 'exigencia': 'Vistoria de gerador'},
      {
        'secretaria': 'Infraestrutura',
        'exigencia': 'Anotação de Responsabilidade Técnica (ART) do gerador',
      },
    ],
    'precisa_planta_baixa': [
      {
        'secretaria': 'Infraestrutura',
        'exigencia':
            'Planta baixa para evento particular de médio ou grande porte em local fixo',
      },
    ],
    'tem_trio_eletrico': [
      {
        'secretaria': 'DMTRAN',
        'exigencia':
            'Vistoria de trio elétrico, CNH do motorista e mapa do circuito',
      },
    ],
    'bloqueia_via': [
      {
        'secretaria': 'DMTRAN',
        'exigencia': 'Autorização para uso ou bloqueio de via pública',
      },
      {
        'secretaria': 'DMTRAN',
        'exigencia': 'Croqui/mapa do circuito ou desvio de trânsito',
      },
    ],
    'tem_alimentacao': [
      {
        'secretaria': 'Vigilância Sanitária',
        'exigencia': 'Vistoria de equipamentos e instalações de alimentação',
      },
    ],
    'precisa_ambulancia': [
      {
        'secretaria': 'Vigilância Sanitária',
        'exigencia': 'Ofício solicitando ambulância no local do evento',
      },
    ],
    'precisa_guarda': [
      {
        'secretaria': 'Guarda Civil Municipal',
        'exigencia': 'Ofício solicitando presença da Guarda Civil Municipal',
      },
    ],
    'precisa_brigadista': [
      {
        'secretaria': 'Desenvolvimento Econômico',
        'exigencia': 'Contratação de brigadista pelo responsável',
      },
    ],
  };

  static List<Map<String, String>> previewRequirements(
    Map<String, bool> answers,
    Map<String, String> eventData,
    List<Map<String, dynamic>> questions,
  ) {
    final requirements = <Map<String, String>>[];
    for (final question in questions) {
      final key = question['key'] as String?;
      if (key == null || answers[key] != true) continue;
      final rules = requirementRules[key] ?? [];
      if (rules.isNotEmpty) {
        for (final rule in rules) {
          requirements.add({
            'secretaria': rule['secretaria'] ?? question['secretaria'] ?? '',
            'exigencia': rule['exigencia'] ?? '',
          });
        }
        continue;
      }
      final exigencias = List<String>.from(
        question['exigencias'] ?? [question['pergunta'] ?? 'Exigência'],
      );
      for (final exigencia in exigencias) {
        requirements.add({
          'secretaria': question['secretaria']?.toString() ?? '',
          'exigencia': exigencia,
        });
      }
    }

    if (eventData['is_beneficente'] == 'true') {
      requirements.add({
        'secretaria': 'Receita Municipal',
        'exigencia': 'Conferência de declaração de evento beneficente',
      });
    }

    return requirements;
  }

  dynamic _decodeResponse(http.Response response) {
    final decoded =
        response.body.isEmpty
            ? null
            : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
    throw PermitApiException(
      detail is String ? detail : 'Não foi possível concluir a solicitação',
      statusCode: response.statusCode,
    );
  }

  static Map<String, dynamic> _toDashboardForm(Map<String, dynamic> item) {
    final evento = item['dados_evento'] as Map<String, dynamic>? ?? {};
    final responsavel =
        item['dados_responsavel'] as Map<String, dynamic>? ?? {};
    final requirements = item['requirements'] as List<dynamic>? ?? [];
    final attachments = item['attachments'] as List<dynamic>? ?? [];
    final comments = item['comments'] as List<dynamic>? ?? [];
    return {
      'id': item['id'],
      'formId': item['id'],
      'protocolo': item['protocolo'],
      'nome_do_evento': evento['nome_evento'] ?? 'Evento',
      'responsavel': responsavel['nome'] ?? '',
      'permitType': 'Alvará de Evento',
      'local_evento': evento['endereco_evento'] ?? '',
      'data_do_evento': evento['data_evento'] ?? '',
      'publico_estimado': evento['publico_estimado']?.toString() ?? '',
      'horario_inicio': evento['horario_inicio'] ?? '',
      'horario_termino': evento['horario_termino'] ?? '',
      'status': item['status'] ?? 'enviada',
      'dam_status': item['dam_status'] ?? '',
      'attachments': attachments.cast<Map<String, dynamic>>(),
      'comments': comments.cast<Map<String, dynamic>>(),
      'credentials': item['credentials'] ?? const <dynamic>[],
      'perguntas':
          requirements.map((requirement) {
            final data = requirement as Map<String, dynamic>;
            return {
              'id': data['id'],
              'pergunta': data['tipo_exigencia'],
              'secretaria_slug': data['secretaria'] ?? '',
              'secretaria': _formatSecretaria(data['secretaria'] as String?),
              'status': data['status'] ?? 'aguardando_analise',
              'observacoes':
                  data['observacoes'] == null ? [] : [data['observacoes']],
              'anexos': const <String>[],
              'requires_inspection': data['requires_inspection'] ?? false,
              'inspection_checklist':
                  data['inspection_checklist'] ?? const <dynamic>[],
              'inspection_scheduled_for': data['inspection_scheduled_for'],
              'inspection_status': data['inspection_status'] ?? 'nao_agendada',
              'inspection_result': data['inspection_result'],
            };
          }).toList(),
    };
  }

  static String _formatSecretaria(String? slug) {
    switch (slug) {
      case 'meio_ambiente':
        return 'Meio Ambiente';
      case 'infraestrutura':
        return 'Infraestrutura';
      case 'desenvolvimento_economico':
        return 'Desenvolvimento Econômico';
      case 'dmtran':
        return 'DMTRAN';
      case 'vigilancia_sanitaria':
        return 'Vigilância Sanitária';
      case 'guarda_civil':
        return 'Guarda Civil Municipal';
      case 'receita_municipal':
        return 'Receita Municipal';
      default:
        return slug ?? '';
    }
  }
}

class PermitApiException implements Exception {
  final String message;
  final int? statusCode;

  PermitApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
