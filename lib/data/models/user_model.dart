class UserModel {
  final String name;
  final String email;
  final String userType;
  final String profile;

  UserModel({
    required this.name,
    required this.email,
    required this.userType,
    required this.profile,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'userType': userType,
      'profile': profile,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'],
      email: json['email'],
      userType: json['userType'],
      profile: json['profile'],
    );
  }

}
