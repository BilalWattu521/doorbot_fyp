// lib/viewmodels/home_view_model.dart
import 'package:flutter/material.dart';

class HomeViewModel extends ChangeNotifier {
  bool microphoneOn = false;
  bool speakerOn = false;

  void toggleMicrophone() {
    microphoneOn = !microphoneOn;
    notifyListeners();
  }

  void toggleSpeaker() {
    speakerOn = !speakerOn;
    notifyListeners();
  }
}
