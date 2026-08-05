import 'package:flutter/material.dart';

import '../../features/services/receita_municipal/ui/receita_municipal_services_page.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({
    super.key,
    required this.userType,
    this.userProfile,
    this.userName,
  });

  final String userType;
  final String? userProfile;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    return ReceitaMunicipalServicesPage(
      userType: userType,
      userProfile: userProfile,
      userName: userName,
    );
  }
}
