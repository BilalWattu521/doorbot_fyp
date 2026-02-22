import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/history_event.dart';

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DatabaseReference get _historyRef {
    final uid = _uid;
    if (uid == null) throw Exception("User not logged in");
    return _db.ref('users/$uid/history');
  }

  /// Save a new event to history
  Future<void> saveEvent(String type) async {
    try {
      await _historyRef.push().set({
        'type': type,
        'timestamp': ServerValue.timestamp,
      });
      debugPrint('✅ History saved: $type');
    } catch (e) {
      debugPrint('❌ Error saving history: $e');
    }
  }

  /// Get history events for a specific date (filtered client-side for reliability)
  Stream<List<HistoryEvent>> getHistoryForDate(DateTime date) {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Listen to all history, filter client-side (avoids .indexOn requirement)
    return _historyRef.orderByChild('timestamp').onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        debugPrint('📋 History: no data found');
        return <HistoryEvent>[];
      }

      debugPrint('📋 History: found ${data.length} total events');

      final events = <HistoryEvent>[];
      for (final entry in data.entries) {
        final val = entry.value;
        if (val is Map<dynamic, dynamic>) {
          final ev = HistoryEvent.fromMap(entry.key as String, val);

          // Filter by selected date
          if (ev.timestamp.isAfter(startOfDay) &&
              ev.timestamp.isBefore(endOfDay)) {
            events.add(ev);
          }
        }
      }

      // Sort by timestamp descending (latest first)
      events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      debugPrint(
        '📋 History: ${events.length} events for ${date.toString().split(' ')[0]}',
      );
      return events;
    });
  }
}
