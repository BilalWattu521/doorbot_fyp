import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoorControlService {
  static final DoorControlService _instance = DoorControlService._internal();

  factory DoorControlService() {
    return _instance;
  }

  DoorControlService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DatabaseReference _getUserRef(String path) {
    final uid = _uid;
    if (uid == null) {
      throw Exception("User not logged in");
    }
    return _database.ref('users/$uid/$path');
  }

  /// Send unlock command to Firebase Realtime Database
  Future<void> sendUnlockCommand() async {
    try {
      final dbRef = _getUserRef('door');

      await dbRef.update({
        'unlocked': true,
        'timestamp': ServerValue.timestamp,
      });

      debugPrint('✅ Unlock command sent to Firebase for user: $_uid');

      // Auto-reset the unlock command after 2 seconds to ensure door locks again
      await Future.delayed(const Duration(seconds: 2));
      await dbRef.update({'unlocked': false});

      debugPrint('✅ Unlock command reset');
    } catch (e) {
      debugPrint('❌ Error sending unlock command: $e');
      rethrow;
    }
  }

  /// Send lock command
  Future<void> sendLockCommand() async {
    try {
      final dbRef = _getUserRef('door');

      await dbRef.update({
        'unlocked': false,
        'timestamp': ServerValue.timestamp,
      });

      debugPrint('✅ Lock command sent to Firebase for user: $_uid');
    } catch (e) {
      debugPrint('❌ Error sending lock command: $e');
      rethrow;
    }
  }

  /// Get door status stream
  Stream<Map<dynamic, dynamic>?> getDoorStatusStream() {
    final uid = _uid;
    if (uid == null) {
      // Return empty stream or handle appropriately if no user
      return Stream.value(null);
    }

    return _getUserRef('door').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return null;

      final isUnlocked = data['unlocked'] == true;
      return {'status': isUnlocked ? 'unlocked' : 'locked', ...data};
    });
  }

  /// Get current door status
  Future<Map<dynamic, dynamic>?> getDoorStatus() async {
    try {
      final uid = _uid;
      if (uid == null) return null;

      final snapshot = await _getUserRef('door').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final isUnlocked = data['unlocked'] == true;
        return {'status': isUnlocked ? 'unlocked' : 'locked', ...data};
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting door status: $e');
      return null;
    }
  }

  /// Send a custom command
  Future<void> sendCustomCommand(String command, dynamic value) async {
    try {
      await _getUserRef('door/$command').set(value);
      debugPrint('✅ Command sent: $command = $value');
    } catch (e) {
      debugPrint('❌ Error sending command: $e');
      rethrow;
    }
  }

  /// Get doorbell event stream (timestamp)
  Stream<DateTime?> getDoorbellEventStream() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(null);
    }

    // Listening to /users/$uid/doorbell/event which is a timestamp (Long)
    return _getUserRef('doorbell/event').onValue.map((event) {
      if (event.snapshot.value == null) return null;

      final timestamp = event.snapshot.value;
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    });
  }
}
