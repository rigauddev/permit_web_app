import 'package:flutter/material.dart';

class BackNavigationButton extends StatelessWidget {
  final String route;
  final String label;
  final EdgeInsetsGeometry? padding;

  const BackNavigationButton({
    super.key,
    required this.route,
    this.label = 'Voltar',
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(top: 12, left: 12, right: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            Navigator.pushReplacementNamed(context, route);
          },
          icon: Icon(Icons.arrow_back),
          label: Text(label),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
