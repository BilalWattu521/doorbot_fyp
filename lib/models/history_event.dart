class HistoryEvent {
  final String id;
  final String type; // "doorbell" or "unlock"
  final DateTime timestamp;

  HistoryEvent({required this.id, required this.type, required this.timestamp});

  factory HistoryEvent.fromMap(String id, Map<dynamic, dynamic> data) {
    return HistoryEvent(
      id: id,
      type: data['type'] as String? ?? 'unknown',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (data['timestamp'] as int?) ?? 0,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {'type': type, 'timestamp': ServerTimestampPlaceholder.value};
  }

  String get displayTime {
    final h = timestamp.hour;
    final m = timestamp.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $period';
  }

  String get displayStatus {
    switch (type) {
      case 'doorbell':
        return 'Doorbell Rang';
      case 'unlock':
        return 'Door Unlocked';
      default:
        return 'Unknown Event';
    }
  }
}

/// Placeholder for ServerValue.timestamp (used in toMap)
class ServerTimestampPlaceholder {
  static const Map<String, String> value = {'.sv': 'timestamp'};
}
