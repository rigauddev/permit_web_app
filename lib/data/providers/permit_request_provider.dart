import 'package:flutter_riverpod/flutter_riverpod.dart';

final permitRequestProvider = StateProvider<PermitRequestData?>((ref) => null);

class PermitRequestData {
  final String userType;
  final String userProfile;
  final String permitType;
  final List<Map<String, dynamic>> questions;

  PermitRequestData({
    required this.userType,
    required this.userProfile,
    required this.permitType,
    required this.questions,
  });
}
