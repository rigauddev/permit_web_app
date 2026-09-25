import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'session_expiration.dart';
import 'permit_api_service.dart';

class OrlaApiService {
  static const _base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://127.0.0.1:8000',
    ),
  );
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final token = await SessionExpiration.readAccessToken();
    if (token == null) {
      throw PermitApiException('Sessão expirada.', statusCode: 401);
    }
    final request = http.Request(method, Uri.parse('$_base/orla$path'));
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });
    if (body != null) request.body = jsonEncode(body);
    return _decode(
      await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 30)),
      ).timeout(const Duration(seconds: 30)),
    );
  }

  Future<dynamic> recognize(XFile file) async {
    final token = await SessionExpiration.readAccessToken();
    if (token == null) {
      throw PermitApiException('Sessão expirada.', statusCode: 401);
    }
    if (await file.length() > 5 * 1024 * 1024) {
      throw PermitApiException('Envie uma foto de até 5 MB.');
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/orla/recognize-plate'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    // MultipartFile infers no image MIME; set it through the HTTP parser.
    final mime =
        file.mimeType ??
        (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await file.readAsBytes(),
        filename: file.name,
        contentType: MediaType.parse(mime),
      ),
    );
    return _decode(
      await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 30)),
      ).timeout(const Duration(seconds: 30)),
    );
  }

  Future<List<Map<String, dynamic>>> listInns() async {
    final response = await http
        .get(Uri.parse('$_base/orla/inns/public'))
        .timeout(const Duration(seconds: 30));
    final decoded = _decode(response);
    if (decoded is! List) return const [];
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createInn({
    required String name,
    String? address,
    String? cep,
    String? latitude,
    String? longitude,
    int? capacity,
    int? guestCapacity,
    required bool beachfront,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/orla/inns'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'address': address,
            'cep': cep,
            'latitude': latitude,
            'longitude': longitude,
            'parking_capacity': capacity,
            'guest_capacity': guestCapacity,
            'beachfront': beachfront,
          }),
        )
        .timeout(const Duration(seconds: 30));
    return (_decode(response) as Map).cast<String, dynamic>();
  }

  dynamic _decode(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw PermitApiException(
        'Servidor indisponível. Tente novamente.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode >= 400) {
      throw PermitApiException(
        data is Map && data['detail'] is String
            ? data['detail']
            : 'Confira os dados informados.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }
}
