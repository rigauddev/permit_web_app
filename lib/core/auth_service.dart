import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models/user_model.dart';

class LoginChallenge {
  final bool mfaRequired;
  final String challengeToken;
  final List<String> availableMethods;
  final String defaultMethod;
  final String? accessToken;
  final UserModel? user;

  LoginChallenge({
    required this.mfaRequired,
    required this.challengeToken,
    required this.availableMethods,
    required this.defaultMethod,
    this.accessToken,
    this.user,
  });

  factory LoginChallenge.fromJson(Map<String, dynamic> json) {
    return LoginChallenge(
      mfaRequired: json['mfa_required'] as bool? ?? true,
      challengeToken: json['challenge_token'] as String? ?? '',
      availableMethods: List<String>.from(
        json['available_methods'] as List<dynamic>? ?? const [],
      ),
      defaultMethod: json['default_method'] as String? ?? 'email',
      accessToken: json['access_token'] as String?,
      user:
          json['user'] is Map<String, dynamic>
              ? UserModel.fromApiSession(json['user'] as Map<String, dynamic>)
              : null,
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
    String identifier,
    String password, {
    required String accessType,
    required String clientType,
  }) async {
    final response = await _post('/auth/login', {
      'identifier': identifier.trim(),
      'senha': password,
      'access_type': accessType,
      'client_type': clientType,
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
    String? email,
    required String senha,
    String? telefone,
    String? endereco,
    String? emailVerificationToken,
    required bool responsibilityTermAccepted,
    required String userPhotoName,
    required String residenceProofName,
    required String residenceProofType,
    String? userPhotoUrl,
    String? residenceProofUrl,
    bool mfaEmailEnabled = false,
  }) async {
    final response = await _post('/auth/register', {
      'tipo_pessoa': tipoPessoa,
      'nome': nome,
      'sobrenome': sobrenome,
      'razao_social': razaoSocial,
      'cpf_cnpj': cpfCnpj,
      'email': email?.trim().isEmpty == true ? null : email?.trim(),
      'senha': senha,
      'telefone': telefone,
      'endereco': endereco,
      'role': 'cidadao',
      'email_verification_token': emailVerificationToken,
      'termo_responsabilidade_aceito': responsibilityTermAccepted,
      'foto_usuario_nome': userPhotoName,
      'foto_usuario_url': userPhotoUrl,
      'comprovante_residencia_nome': residenceProofName,
      'comprovante_residencia_url': residenceProofUrl,
      'comprovante_residencia_tipo': residenceProofType,
      'mfa_email_enabled': mfaEmailEnabled,
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
    String? cpfCnpj,
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
      'cpf_cnpj': cpfCnpj?.trim().isEmpty == true ? null : cpfCnpj,
      'email': email.trim(),
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

  Future<AuthSession> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _post('/auth/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    }, accessToken: accessToken);
    return AuthSession.fromJson(response);
  }

  Future<UserModel> updateCurrentUser({
    required String accessToken,
    required String nome,
    String? sobrenome,
    String? telefone,
    String? endereco,
  }) async {
    final response = await _patch('/auth/me', {
      'nome': nome,
      'sobrenome': sobrenome,
      'telefone': telefone,
      'endereco': endereco,
    }, accessToken: accessToken);
    return UserModel.fromApiUser(response);
  }

  Future<List<UserModel>> listUsers({required String accessToken}) async {
    final response = await _getList('/auth/users', accessToken: accessToken);
    return response
        .map((item) => UserModel.fromApiUser(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserModel> updateUser({
    required String accessToken,
    required int userId,
    required String nome,
    String? sobrenome,
    String? email,
    String? telefone,
    String? endereco,
    String? role,
    String? secretaria,
    bool? isActive,
  }) async {
    final response = await _patch('/auth/users/$userId', {
      'nome': nome,
      'sobrenome': sobrenome,
      'email': email,
      'telefone': telefone,
      'endereco': endereco,
      'role': role,
      'secretaria': secretaria,
      'is_active': isActive,
    }, accessToken: accessToken);
    return UserModel.fromApiUser(response);
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

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _client.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
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
