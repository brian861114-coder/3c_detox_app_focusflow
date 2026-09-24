import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule.dart';

class ScheduleProvider with ChangeNotifier {
  List<FocusSchedule> _schedules = [];

  bool _isLoaded = false;

  List<FocusSchedule> get schedules => _schedules;
  bool get isLoaded => _isLoaded;

  ScheduleProvider() {
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final String? schedulesJson = prefs.getString('focus_schedules');
    if (schedulesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(schedulesJson);
        _schedules = decoded.map((item) => FocusSchedule.fromJson(item)).toList();
      } catch (e) {
        debugPrint('Ignoring unreadable schedules: $e');
      }
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_schedules.map((s) => s.toJson()).toList());
    await prefs.setString('focus_schedules', encoded);
  }

  void addSchedule(FocusSchedule schedule) {
    _schedules.add(schedule);
    _saveSchedules();
    notifyListeners();
  }

  void removeSchedule(String id) {
    _schedules.removeWhere((schedule) => schedule.id == id);
    _saveSchedules();
    notifyListeners();
  }

  /// Toggle the enabled/disabled state of a schedule
  void toggleScheduleEnabled(String id) {
    final index = _schedules.indexWhere((s) => s.id == id);
    if (index != -1) {
      _schedules[index] = _schedules[index].copyWith(
        isEnabled: !_schedules[index].isEnabled,
      );
      _saveSchedules();
      notifyListeners();
    }
  }

  /// Get list of schedule names that use a specific block list
  List<String> getSchedulesUsingBlockList(String blockListId) {
    final result = <String>[];
    for (var schedule in _schedules) {
      if (schedule.blockListId == blockListId) {
        final time = '${schedule.startHour.toString().padLeft(2, '0')}:${schedule.startMinute.toString().padLeft(2, '0')}';
        result.add(time);
      }
    }
    return result;
  }

  /// When a block list is deleted or modified,
  /// disable all schedules using it and mark them with blockListChanged flag
  void onBlockListChanged(String blockListId) {
    bool changed = false;
    for (int i = 0; i < _schedules.length; i++) {
      if (_schedules[i].blockListId == blockListId) {
        _schedules[i] = _schedules[i].copyWith(
          isEnabled: false,
          blockListChanged: true,
        );
        changed = true;
      }
    }
    if (changed) {
      _saveSchedules();
      notifyListeners();
    }
  }

  /// Clear the blockListChanged flag for a schedule (user acknowledges the change)
  void clearBlockListChangedFlag(String scheduleId) {
    final index = _schedules.indexWhere((s) => s.id == scheduleId);
    if (index != -1) {
      _schedules[index] = _schedules[index].copyWith(blockListChanged: false);
      _saveSchedules();
      notifyListeners();
    }
  }

  /// Returns the enabled schedule whose window contains [now] (default: current time),
  /// together with when that window ends, or null.
  ActiveScheduleWindow? activeWindow([DateTime? now]) {
    now ??= DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final schedule in _schedules) {
      if (!schedule.isEnabled) continue;
      // Check today's occurrence, then yesterday's (in case it crosses midnight)
      for (final day in [today, DateTime(today.year, today.month, today.day - 1)]) {
        if (!schedule.weekdays.contains(day.weekday)) continue;
        final start = DateTime(day.year, day.month, day.day, schedule.startHour, schedule.startMinute);
        final end = start.add(Duration(minutes: schedule.durationMinutes));
        if (!now.isBefore(start) && now.isBefore(end)) {
          return ActiveScheduleWindow(schedule, end);
        }
      }
    }
    return null;
  }
}

class ActiveScheduleWindow {
  final FocusSchedule schedule;
  final DateTime end;

  const ActiveScheduleWindow(this.schedule, this.end);
}
