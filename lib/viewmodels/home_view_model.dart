import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
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

  // Authenticated URL
  static final String _latestFrameUrl = '${AppConfig.relayBaseUrl}/latest';

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
    debugPrint('🚀 Frame polling started (every 300ms)');
    _frameTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _fetchLatestFrame();
    });
  }

  bool _isFetching = false;
  int _pollCount = 0;
  int _successCount = 0;
  int _errorCount = 0;

  Future<void> _fetchLatestFrame() async {
    // Prevent concurrent requests from piling up when server responds slowly
    if (_isFetching) return;
    _isFetching = true;
    _pollCount++;

    // Heartbeat every 30 polls (~9 seconds)
    if (_pollCount % 30 == 0) {
      debugPrint(
        '💓 Stream heartbeat: polls=$_pollCount ok=$_successCount err=$_errorCount streaming=$_isStreaming',
      );
    }

    try {
      // Get current user UID for authentication
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _isFetching = false;
        return;
      }

      // Cache-busting: append timestamp to prevent Android HTTP caching
      final url = '$_latestFrameUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'x-api-key': AppConfig.doorbotApiKey,
              'x-user-uid': uid,
              'Cache-Control': 'no-cache, no-store',
              'Pragma': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        _currentFrame = response.bodyBytes;
        if (!_isStreaming) {
          _isStreaming = true;
          debugPrint('🎥 Stream started — receiving frames');
        }
        _successCount++;
        notifyListeners();
      } else if (response.statusCode == 204) {
        // No frame or stale frame — show "Waiting for camera..."
        if (_isStreaming) {
          _isStreaming = false;
          _currentFrame = null;
          debugPrint('📷 Camera offline — no fresh frames from ESP32');
          notifyListeners();
        }
      } else {
        debugPrint('⚠️ Relay returned status: ${response.statusCode}');
      }
    } catch (e) {
      _errorCount++;
      debugPrint('⚠️ Frame fetch error (#$_errorCount): $e');
    } finally {
      _isFetching = false;
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
