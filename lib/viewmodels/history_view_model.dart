import 'dart:async';
import 'package:flutter/material.dart';
import '../models/history_event.dart';
import '../services/history_service.dart';

class HistoryViewModel extends ChangeNotifier {
  final HistoryService _historyService = HistoryService();

  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  List<HistoryEvent> _events = [];
  List<HistoryEvent> get events => _events;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  StreamSubscription? _subscription;

  HistoryViewModel() {
    _loadEventsForDate(_selectedDate);
  }

  void changeDate(DateTime date) {
    _selectedDate = date;
    _isLoading = true;
    notifyListeners();
    _loadEventsForDate(date);
  }

  void _loadEventsForDate(DateTime date) {
    _subscription?.cancel();
    _subscription = _historyService.getHistoryForDate(date).listen((events) {
      _events = events;
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
