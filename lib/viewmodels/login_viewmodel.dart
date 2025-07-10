import 'package:flutter/material.dart';

class LoginViewModel extends ChangeNotifier {
  bool isLoading = false;

  Future<void> loginWithEmail(String email, String password) async {
    isLoading = true;
    notifyListeners();

    await Future.delayed(Duration(seconds: 2)); // Simulate network

    isLoading = false;
    notifyListeners();
    // handle your login logic
  }

  Future<void> loginWithGoogle() async {
    isLoading = true;
    notifyListeners();

    await Future.delayed(Duration(seconds: 2)); // Simulate Google login

    isLoading = false;
    notifyListeners();
    // handle your Google login logic
  }
}
