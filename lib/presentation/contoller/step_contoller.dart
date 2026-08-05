import 'package:flutter/material.dart';

class StepController extends ChangeNotifier {
  int _currentStep = 0;
  int get currentStep => _currentStep;

  final List<GlobalKey<FormState>> formKeys;

  StepController({required this.formKeys});

  bool nextStep() {
    final currentForm = formKeys[_currentStep].currentState;
    if (currentForm == null) return false;

    if (currentForm.validate()) {
      if (_currentStep < formKeys.length - 1) {
        _currentStep++;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  bool previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
      return true;
    }
    return false;
  }

  void reset() {
    _currentStep = 0;
    notifyListeners();
  }
}
