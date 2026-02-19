import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:doorbot_fyp/services/door_control_service.dart';
import 'package:doorbot_fyp/config/app_config.dart';

class HomeViewModel extends ChangeNotifier {
  bool microphoneOn = false;
  bool speakerOn = false;
  bool notificationsOn = true;
  bool unlockPressed = false;

  final DoorControlService _doorControl = DoorControlService();
  StreamSubscription? _statusSubscription;
  Map<dynamic, dynamic>? _doorStatus;
  Map<dynamic, dynamic>? get doorStatus => _doorStatus;

  // Live stream state
  Uint8List? _currentFrame;
  Uint8List? get currentFrame => _currentFrame;
  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;
  Timer? _frameTimer;

  // Relay server URL
  static const String _latestFrameUrl = '${AppConfig.relayStreamUrl}/latest';

  HomeViewModel() {
    _statusSubscription = _doorControl.getDoorStatusStream().listen((data) {
      if (_areMapsEqual(_doorStatus, data)) return;
      _doorStatus = data;
      notifyListeners();
    });

    // Start polling for frames
    _startPolling();
  }

  void _startPolling() {
    // Poll every 300ms (~3 FPS display)
    _frameTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _fetchLatestFrame();
    });
  }

  Future<void> _fetchLatestFrame() async {
    try {
      final response = await http
          .get(Uri.parse(_latestFrameUrl))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        _currentFrame = response.bodyBytes;
        if (!_isStreaming) {
          _isStreaming = true;
        }
        notifyListeners();
      }
    } catch (_) {
      // Silently ignore — next poll will retry
    }
  }

  bool _areMapsEqual(Map? m1, Map? m2) {
    if (m1 == m2) return true;
    if (m1 == null || m2 == null) return false;
    if (m1['unlocked'] != m2['unlocked']) return false;
    return true;
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _frameTimer?.cancel();
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

    Future.delayed(const Duration(seconds: 2), () {
      _canUnlock = true;
      unlockPressed = false;
      notifyListeners();
    });
  }

  void onUnlockReleased() {
    unlockPressed = false;
    notifyListeners();
  }

  Future<void> _sendUnlockCommand() async {
    try {
      await _doorControl.sendUnlockCommand();
      debugPrint('✅ Unlock command sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending unlock command: $e');
    }
  }
}
