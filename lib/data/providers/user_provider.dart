import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

class UserNotifier extends StateNotifier<UserModel?> {
  UserNotifier() : super(null);

  void setUser(UserModel user) {
    state = user;
  }

  void logout() {
    state = null;
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserModel?>((ref) => UserNotifier());
