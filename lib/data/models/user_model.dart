class UserModel {
  final int? id;
  final String name;
  final String lastName;
  final String birthday;
  final String email;
  final String userType;
  final String role;
  final String profile;
  final String password;
  final String city;
  final String address;
  final String zipCode;
  final String state;
  final String phone;
  final String cpfCnpj;
  final String? secretaria;
  final List<String> permissions;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.userType,
    required this.profile,
    required this.address,
    required this.birthday,
    required this.city,
    required this.cpfCnpj,
    required this.password,
    required this.phone,
    required this.role,
    required this.lastName,
    required this.state,
    required this.zipCode,
    this.secretaria,
    this.permissions = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'userType': userType,
      'profile': profile,
      'address': address,
      'birthday': birthday,
      'city': city,
      'cpf_cnpj': cpfCnpj,
      'password': password,
      'phone': phone,
      'role': role,
      'last_name': lastName,
      'state': state,
      'zipCode': zipCode,
      'secretaria': secretaria,
      'permissions': permissions,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int?,
      name: json['name'] as String? ?? json['nome'] as String? ?? '',
      email: json['email'] as String? ?? '',
      userType:
          json['userType'] as String? ??
          _mapRoleToUserType(json['role'] as String? ?? ''),
      profile: json['profile'] as String? ?? json['role'] as String? ?? '',
      address: json['address'] as String? ?? json['endereco'] as String? ?? '',
      birthday: json['birthday'] as String? ?? '',
      city: json['city'] as String? ?? '',
      cpfCnpj: json['cpf_cnpj'] as String? ?? '',
      password: json['password'] as String? ?? '',
      phone: json['phone'] as String? ?? json['telefone'] as String? ?? '',
      role: json['role'] as String? ?? '',
      lastName:
          json['last_name'] as String? ?? json['sobrenome'] as String? ?? '',
      state: json['state'] as String? ?? '',
      zipCode: json['zipCode'] as String? ?? '',
      secretaria: json['secretaria'] as String?,
      permissions: _permissionsFromJson(json['permissions']),
    );
  }

  factory UserModel.fromApiSession(Map<String, dynamic> json) {
    final role = json['role'] as String? ?? '';
    return UserModel(
      id: json['id'] as int?,
      name: json['nome'] as String? ?? '',
      lastName: '',
      birthday: '',
      email: json['email'] as String? ?? '',
      userType: _mapRoleToUserType(role),
      role: role,
      profile: role,
      password: '',
      city: '',
      address: '',
      zipCode: '',
      state: '',
      phone: '',
      cpfCnpj: '',
      secretaria: json['secretaria'] as String?,
      permissions: _permissionsFromJson(json['permissions']),
    );
  }

  factory UserModel.fromApiUser(Map<String, dynamic> json) {
    final role = json['role'] as String? ?? '';
    return UserModel(
      id: json['id'] as int?,
      name: json['nome'] as String? ?? '',
      lastName: json['sobrenome'] as String? ?? '',
      birthday: '',
      email: json['email'] as String? ?? '',
      userType: _mapRoleToUserType(role),
      role: role,
      profile: role,
      password: '',
      city: '',
      address: json['endereco'] as String? ?? '',
      zipCode: '',
      state: '',
      phone: json['telefone'] as String? ?? '',
      cpfCnpj: json['cpf_cnpj'] as String? ?? '',
      secretaria: json['secretaria'] as String?,
      permissions: _permissionsFromJson(json['permissions']),
    );
  }

  bool hasPermission(String permission) => permissions.contains(permission);

  static List<String> _permissionsFromJson(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }

  static String _mapRoleToUserType(String role) {
    switch (role) {
      case 'cidadao':
        return 'user';
      case 'operador_secretaria':
        return 'operador';
      case 'gestor_secretaria':
        return 'gestor';
      case 'admin':
        return 'admin';
      default:
        return role;
    }
  }
}
