import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models/user_model.dart';

class LoginChallenge {
  final String challengeToken;
  final List<String> availableMethods;
  final String defaultMethod;

  LoginChallenge({
    required this.challengeToken,
    required this.availableMethods,
    required this.defaultMethod,
  });

  factory LoginChallenge.fromJson(Map<String, dynamic> json) {
    return LoginChallenge(
      challengeToken: json['challenge_token'] as String,
      availableMethods: List<String>.from(
        json['available_methods'] as List<dynamic>,
      ),
      defaultMethod: json['default_method'] as String? ?? 'email',
    );
  }
}

class MfaGeneration {
  final String method;
  final String delivery;
  final String? devCode;

  MfaGeneration({required this.method, required this.delivery, this.devCode});

  factory MfaGeneration.fromJson(Map<String, dynamic> json) {
    return MfaGeneration(
      method: json['method'] as String,
      delivery: json['delivery'] as String,
      devCode: json['dev_code'] as String?,
    );
  }
}

class AuthSession {
  final String accessToken;
  final UserModel user;

  AuthSession({required this.accessToken, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      user: UserModel.fromApiSession(json['user'] as Map<String, dynamic>),
    );
  }
}

class EmailVerificationStart {
  final String delivery;
  final String? devCode;

  EmailVerificationStart({required this.delivery, this.devCode});

  factory EmailVerificationStart.fromJson(Map<String, dynamic> json) {
    return EmailVerificationStart(
      delivery: json['delivery'] as String,
      devCode: json['dev_code'] as String?,
    );
  }
}

class EmailVerificationConfirm {
  final String verificationToken;

  EmailVerificationConfirm({required this.verificationToken});

  factory EmailVerificationConfirm.fromJson(Map<String, dynamic> json) {
    return EmailVerificationConfirm(
      verificationToken: json['verification_token'] as String,
    );
  }
}

class AuthService {
  AuthService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://127.0.0.1:8000',
          );

  final http.Client _client;
  final String _baseUrl;

  Future<LoginChallenge> startLogin(
    String email,
    String password, {
    required String accessType,
  }) async {
    final response = await _post('/auth/login', {
      'email': email.trim(),
      'senha': password,
      'access_type': accessType,
    });
    return LoginChallenge.fromJson(response);
  }

  Future<MfaGeneration> generateMfa(
    String challengeToken,
    String method,
  ) async {
    final response = await _post('/auth/mfa/generate', {
      'challenge_token': challengeToken,
      'method': method,
    });
    return MfaGeneration.fromJson(response);
  }

  Future<AuthSession> verifyMfa(
    String challengeToken,
    String method,
    String code, {
    required String clientType,
  }) async {
    final response = await _post('/auth/mfa/verify', {
      'challenge_token': challengeToken,
      'method': method,
      'code': code.trim(),
      'client_type': clientType,
    });
    return AuthSession.fromJson(response);
  }

  Future<UserModel> registerCitizen({
    required String tipoPessoa,
    required String nome,
    String? sobrenome,
    String? razaoSocial,
    required String cpfCnpj,
    required String email,
    required String senha,
    String? telefone,
    String? endereco,
    required String emailVerificationToken,
    required bool responsibilityTermAccepted,
  }) async {
    final response = await _post('/auth/register', {
      'tipo_pessoa': tipoPessoa,
      'nome': nome,
      'sobrenome': sobrenome,
      'razao_social': razaoSocial,
      'cpf_cnpj': cpfCnpj,
      'email': email,
      'senha': senha,
      'telefone': telefone,
      'endereco': endereco,
      'role': 'cidadao',
      'email_verification_token': emailVerificationToken,
      'termo_responsabilidade_aceito': responsibilityTermAccepted,
    });
    return UserModel.fromApiUser(response);
  }

  Future<EmailVerificationStart> startRegistrationEmailVerification(
    String email,
  ) async {
    final response = await _post('/auth/email-verifications', {
      'email': email.trim(),
      'purpose': 'register',
    });
    return EmailVerificationStart.fromJson(response);
  }

  Future<EmailVerificationConfirm> confirmRegistrationEmailVerification(
    String email,
    String code,
  ) async {
    final response = await _post('/auth/email-verifications/confirm', {
      'email': email.trim(),
      'code': code.trim(),
      'purpose': 'register',
    });
    return EmailVerificationConfirm.fromJson(response);
  }

  Future<UserModel> createCompanyUser({
    required String accessToken,
    required String nome,
    String? sobrenome,
    required String cpfCnpj,
    required String email,
    required String senha,
    required String role,
    String? secretaria,
    String? telefone,
  }) async {
    final response = await _post('/auth/company-users', {
      'tipo_pessoa': 'PF',
      'nome': nome,
      'sobrenome': sobrenome,
      'cpf_cnpj': cpfCnpj,
      'email': email,
      'senha': senha,
      'telefone': telefone,
      'role': role,
      'secretaria': secretaria,
    }, accessToken: accessToken);
    return UserModel.fromApiUser(response);
  }

  Future<UserModel> currentUser({required String accessToken}) async {
    final response = await _get('/auth/me', accessToken: accessToken);
    return UserModel.fromApiUser(response);
  }

  Future<List<UserModel>> listUsers({required String accessToken}) async {
    final response = await _getList('/auth/users', accessToken: accessToken);
    return response
        .map((item) => UserModel.fromApiUser(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded =
        response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(utf8.decode(response.bodyBytes))
                as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final detail = decoded['detail'];
    throw AuthException(
      detail is String ? detail : 'Não foi possível concluir a autenticação',
      statusCode: response.statusCode,
    );
  }

  Future<List<dynamic>> _getList(String path, {String? accessToken}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );
    final decoded =
        response.body.isEmpty
            ? <dynamic>[]
            : jsonDecode(utf8.decode(response.bodyBytes)) as dynamic;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded as List<dynamic>;
    }
    final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
    throw AuthException(
      detail is String ? detail : 'Não foi possível carregar os dados',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> _get(String path, {String? accessToken}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );
    return _decodeResponse(response);
  }
}

class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
