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
      'key': 'tem_palco',
      'pergunta': 'O evento terá palco ou estrutura montada?',
      'secretaria': 'Infraestrutura',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencia': 'Vistoria de palco/estrutura',
    },
    {
      'id': 3,
      'key': 'tem_gerador',
      'pergunta': 'O evento terá gerador?',
      'secretaria': 'Infraestrutura',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencia': 'Vistoria de gerador',
    },
    {
      'id': 4,
      'key': 'tem_trio_eletrico',
      'pergunta': 'O evento terá trio elétrico?',
      'secretaria': 'DMTRAN',
      'tipos_resposta': ['Sim/Não', 'Texto', 'Anexar Documento'],
      'exigencia': 'Vistoria do veículo, CNH do motorista e mapa do circuito',
    },
    {
      'id': 5,
      'key': 'bloqueia_via',
      'pergunta': 'O evento usará ou bloqueará vias/ruas municipais?',
      'secretaria': 'DMTRAN',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencia': 'Autorização para uso ou bloqueio de via pública',
    },
    {
      'id': 6,
      'key': 'tem_alimentacao',
      'pergunta':
          'O evento terá venda, preparo ou distribuição de alimentação?',
      'secretaria': 'Vigilância Sanitária',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencia': 'Vistoria de equipamentos e instalações de alimentação',
    },
    {
      'id': 7,
      'key': 'precisa_guarda',
      'pergunta': 'Será necessária a presença da Guarda Civil Municipal?',
      'secretaria': 'Guarda Civil Municipal',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencia': 'Ofício solicitando presença da Guarda Civil Municipal',
    },
    {
      'id': 8,
      'key': 'precisa_brigadista',
      'pergunta': 'O evento exigirá brigadista contratado?',
      'secretaria': 'Responsável pelo evento',
      'tipos_resposta': ['Sim/Não', 'Texto'],
      'exigencia': 'Contratação de brigadista pelo responsável',
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
        requirements.add({
          'secretaria': question['secretaria'] as String,
          'exigencia': question['exigencia'] as String,
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
    );
  }

  static Map<String, dynamic> _toDashboardForm(Map<String, dynamic> item) {
    final evento = item['dados_evento'] as Map<String, dynamic>? ?? {};
    final requirements = item['requirements'] as List<dynamic>? ?? [];
    return {
      'formId': item['id'],
      'protocolo': item['protocolo'],
      'nome_do_evento': evento['nome_evento'] ?? 'Evento',
      'permitType': 'Alvará de Evento',
      'local_evento': evento['endereco_evento'] ?? '',
      'data_do_evento': evento['data_evento'] ?? '',
      'status': item['status'] ?? 'enviada',
      'dam_status': item['dam_status'] ?? '',
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

  PermitApiException(this.message);

  @override
  String toString() => message;
}
