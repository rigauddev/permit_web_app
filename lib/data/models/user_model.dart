class UserModel {
  final String name;
  final String email;
  final String password;
  final String tipoUsuario;

  UserModel({
    required this.name,
    required this.email,
    required this.password,
    required this.tipoUsuario,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'tipoUsuario': tipoUsuario,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'],
      email: json['email'],
      password: json['password'],
      tipoUsuario: json['tipoUsuario'],
    );
  }

  get type => null;

  get profile => null;
}
