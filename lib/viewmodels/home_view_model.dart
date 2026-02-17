import 'dart:async';
import 'package:flutter/material.dart';
import 'package:doorbot_fyp/services/door_control_service.dart';

class HomeViewModel extends ChangeNotifier {
  bool microphoneOn = false;
  bool speakerOn = false;
  bool notificationsOn = true;
  bool unlockPressed = false;

  final DoorControlService _doorControl = DoorControlService();
  StreamSubscription? _statusSubscription;
  Map<dynamic, dynamic>? _doorStatus;
  Map<dynamic, dynamic>? get doorStatus => _doorStatus;

  HomeViewModel() {
    _statusSubscription = _doorControl.getDoorStatusStream().listen((data) {
      // Only notify if data actually changed to prevent UI spam/freezing
      if (_areMapsEqual(_doorStatus, data)) return;

      _doorStatus = data;
      notifyListeners();
    });
  }

  bool _areMapsEqual(Map? m1, Map? m2) {
    if (m1 == m2) return true;
    if (m1 == null || m2 == null) return false;

    // We mainly care about the 'unlocked' status for the UI
    if (m1['unlocked'] != m2['unlocked']) return false;

    // Check timestamp if strictly needed, but might be noisy.
    // If timestamp updates but status is same, do we need to rebuild?
    // Probably not for the "Status" text, but maybe for logging?
    // Let's stick to status for now to reduce noise.
    return true;
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

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

  bool _canUnlock = true;
  bool get canUnlock => _canUnlock;

  void onUnlockPressed() {
    if (!_canUnlock) return;

    unlockPressed = true;
    _canUnlock = false;
    _sendUnlockCommand();
    notifyListeners();

    // Re-enable button after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      _canUnlock = true;
      unlockPressed = false; // Also verify visual state is reset
      notifyListeners();
    });
  }

  void onUnlockReleased() {
    unlockPressed = false;
    notifyListeners();
  }

  Future<void> _sendUnlockCommand() async {
    try {
      // Send unlock command to Firebase Realtime Database (for Arduino)
      await _doorControl.sendUnlockCommand();

      debugPrint('✅ Unlock command sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending unlock command: $e');
    }
  }
}
