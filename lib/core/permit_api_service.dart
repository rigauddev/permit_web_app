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

  Future<Map<String, dynamic>> createRequest({
    required String accessToken,
    required Map<String, String> responsibleData,
    required Map<String, String> eventData,
    required Map<String, bool> answers,
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
        'respostas': answers,
      }),
    );
    return _decodeResponse(response) as Map<String, dynamic>;
  }

  static List<Map<String, String>> previewRequirements(
    Map<String, bool> answers,
    Map<String, String> eventData,
  ) {
    final requirements = <Map<String, String>>[];
    for (final question in eventPermitQuestions) {
      final key = question['key'] as String;
      if (answers[key] == true) {
        final exigencias = List<String>.from(
          question['exigencias'] ?? [question['exigencia']],
        );
        for (final exigencia in exigencias) {
          requirements.add({
            'secretaria': question['secretaria'] as String,
            'exigencia': exigencia,
          });
        }
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
    return {
      'formId': item['id'],
      'protocolo': item['protocolo'],
      'nome_do_evento': evento['nome_evento'] ?? 'Evento',
      'responsavel': responsavel['nome'] ?? '',
      'permitType': 'Alvará de Evento',
      'local_evento': evento['endereco_evento'] ?? '',
      'data_do_evento': evento['data_evento'] ?? '',
      'horario_inicio': evento['horario_inicio'] ?? '',
      'horario_termino': evento['horario_termino'] ?? '',
      'status': item['status'] ?? 'enviada',
      'dam_status': item['dam_status'] ?? '',
      'credentials': item['credentials'] ?? const <dynamic>[],
      'perguntas':
          requirements.map((requirement) {
            final data = requirement as Map<String, dynamic>;
            return {
              'id': data['id'],
              'pergunta': data['tipo_exigencia'],
              'secretaria': _formatSecretaria(data['secretaria'] as String?),
              'status': data['status'] ?? 'aguardando_analise',
              'observacoes':
                  data['observacoes'] == null ? [] : [data['observacoes']],
              'anexos': const <String>[],
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
