import 'package:flutter/material.dart';

class HomeViewModel extends ChangeNotifier {
  bool microphoneOn = false;
  bool speakerOn = false;
  bool notificationsOn = true;

  void toggleMicrophone() {
    microphoneOn = !microphoneOn;
    notifyListeners();
  }

  void toggleSpeaker() {
    speakerOn = !speakerOn;
    notifyListeners();
  }

  void toggleNotifications() {
    notificationsOn = !notificationsOn;
    notifyListeners();
  }
}
