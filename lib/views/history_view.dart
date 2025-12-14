import 'package:doorbot_fyp/widgets/custom_curved_appbar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryView extends StatelessWidget {
  HistoryView({super.key});

  // Sample data
  final List<DoorbellEvent> events = [
    DoorbellEvent(
      time: "10:30 AM",
      status: "Doorbell rang - Door Opened",
      date: DateTime.now(),
    ),
    DoorbellEvent(
      time: "09:15 AM",
      status: "Doorbell rang - Door Not Opened",
      date: DateTime.now(),
    ),
    DoorbellEvent(
      time: "08:30 AM",
      status: "Doorbell rang - Door Opened",
      date: DateTime.now().subtract(Duration(days: 1)),
    ),
    DoorbellEvent(
      time: "08:25 AM",
      status: "Doorbell rang - Door Not Opened",
      date: DateTime.now().subtract(Duration(days: 1)),
    ),
    DoorbellEvent(
      time: "11:00 AM",
      status: "Doorbell rang - Door Opened",
      date: DateTime(2023, 10, 23),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final groupedEvents = _groupEvents(events);

    return Scaffold(
      appBar: CustomCurvedAppBar(
        title: "History",
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: groupedEvents.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  entry.key,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ...entry.value.map((event) => _buildHistoryItem(event)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Map<String, List<DoorbellEvent>> _groupEvents(List<DoorbellEvent> events) {
    final Map<String, List<DoorbellEvent>> grouped = {};

    for (var e in events) {
      String label;

      final today = DateTime.now();
      final yesterday = today.subtract(Duration(days: 1));

      if (_isSameDate(e.date, today)) {
        label = "Today";
      } else if (_isSameDate(e.date, yesterday)) {
        label = "Yesterday";
      } else {
        label = DateFormat.yMMMMd().format(e.date);
      }

      grouped.putIfAbsent(label, () => []).add(e);
    }

    return grouped;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildHistoryItem(DoorbellEvent event) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.home, color: Colors.blueAccent, size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.time,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  event.status,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DoorbellEvent {
  final String time;
  final String status;
  final DateTime date;

  DoorbellEvent({required this.time, required this.status, required this.date});
}
