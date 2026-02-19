import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Service to receive live camera frames from ESP32 via Firebase RTDB.
/// ESP32 writes Base64 JPEG frames to `users/$uid/doorbell/frame`.
/// This service listens and emits the raw base64 strings.
class LiveStreamService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Returns a stream of Base64-encoded JPEG frames from the ESP32 camera.
  /// Returns null if user is not authenticated.
  Stream<String?> getFrameStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ LiveStreamService: No authenticated user');
      return Stream.value(null);
    }

    final ref = _db.ref('users/${user.uid}/doorbell/frame');

    return ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return data.toString();
    });
  }
}
