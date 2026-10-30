import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';

class NotificationSettingsState {
  final bool calendarEnabled;
  final bool tasksEnabled;
  final bool habitsEnabled;
  final bool diaryEnabled;
  final TimeOfDay diaryTime;
  final bool budgetEnabled;
  final TimeOfDay budgetMorningTime;
  final TimeOfDay budgetEveningTime;
  final bool shiftsEnabled;

  NotificationSettingsState({
    required this.calendarEnabled,
    required this.tasksEnabled,
    required this.habitsEnabled,
    required this.diaryEnabled,
    required this.diaryTime,
    required this.budgetEnabled,
    required this.budgetMorningTime,
    required this.budgetEveningTime,
    required this.shiftsEnabled,
  });

  NotificationSettingsState copyWith({
    bool? calendarEnabled,
    bool? tasksEnabled,
    bool? habitsEnabled,
    bool? diaryEnabled,
    TimeOfDay? diaryTime,
    bool? budgetEnabled,
    TimeOfDay? budgetMorningTime,
    TimeOfDay? budgetEveningTime,
    bool? shiftsEnabled,
  }) {
    return NotificationSettingsState(
      calendarEnabled: calendarEnabled ?? this.calendarEnabled,
      tasksEnabled: tasksEnabled ?? this.tasksEnabled,
      habitsEnabled: habitsEnabled ?? this.habitsEnabled,
      diaryEnabled: diaryEnabled ?? this.diaryEnabled,
      diaryTime: diaryTime ?? this.diaryTime,
      budgetEnabled: budgetEnabled ?? this.budgetEnabled,
      budgetMorningTime: budgetMorningTime ?? this.budgetMorningTime,
      budgetEveningTime: budgetEveningTime ?? this.budgetEveningTime,
      shiftsEnabled: shiftsEnabled ?? this.shiftsEnabled,
    );
  }
}

class NotificationSettingsNotifier extends Notifier<NotificationSettingsState> {
  @override
  NotificationSettingsState build() {
    loadSettings();
    return NotificationSettingsState(
      calendarEnabled: true,
      tasksEnabled: true,
      habitsEnabled: true,
      diaryEnabled: true,
      diaryTime: const TimeOfDay(hour: 21, minute: 30),
      budgetEnabled: true,
      budgetMorningTime: const TimeOfDay(hour: 9, minute: 0),
      budgetEveningTime: const TimeOfDay(hour: 21, minute: 0),
      shiftsEnabled: true,
    );
  }

  Future<void> loadSettings() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('app_settings');
    final Map<String, String> map = {
      for (var r in rows) r['key'] as String: r['value'] as String,
    };

    TimeOfDay parseTime(String? val, TimeOfDay fallback) {
      if (val == null || !val.contains(':')) return fallback;
      final parts = val.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    state = NotificationSettingsState(
      calendarEnabled: (map['notif_calendar'] ?? 'true') == 'true',
      tasksEnabled: (map['notif_tasks'] ?? 'true') == 'true',
      habitsEnabled: (map['notif_habits'] ?? 'true') == 'true',
      diaryEnabled: (map['notif_diary'] ?? 'true') == 'true',
      diaryTime: parseTime(
        map['notif_diary_time'],
        const TimeOfDay(hour: 21, minute: 30),
      ),
      budgetEnabled: (map['notif_budget'] ?? 'true') == 'true',
      budgetMorningTime: parseTime(
        map['notif_budget_morning_time'],
        const TimeOfDay(hour: 9, minute: 0),
      ),
      budgetEveningTime: parseTime(
        map['notif_budget_evening_time'],
        const TimeOfDay(hour: 21, minute: 0),
      ),
      shiftsEnabled: (map['notif_shifts'] ?? 'true') == 'true',
    );

    _rescheduleSystemReminders();
  }

  Future<void> updateSetting(String key, String value) async {
    final db = await DatabaseService.instance.database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await loadSettings();
  }

  void _rescheduleSystemReminders() {
    final s = NotificationService.instance;

    // 1. Дневник (ID = 90001)
    if (state.diaryEnabled) {
      s.scheduleDailyNotification(
        id: 90001,
        title: 'Дневник Орбиты',
        body: 'Как прошел твой день? Зафиксируй важные мысли и события.',
        hour: state.diaryTime.hour,
        minute: state.diaryTime.minute,
        payload: 'screen_diary',
      );
    } else {
      s.cancelNotification(90001);
    }

    // 2. Бюджет: Утренний план (ID = 90002)
    if (state.budgetEnabled) {
      s.scheduleDailyNotification(
        id: 90002,
        title: 'Бюджет на сегодня',
        body: 'Проверьте плановые платежи и безопасный лимит на день.',
        hour: state.budgetMorningTime.hour,
        minute: state.budgetMorningTime.minute,
        payload: 'screen_budget',
      );
      // Бюджет: Вечерняя запись расходов (ID = 90003)
      s.scheduleDailyNotification(
        id: 90003,
        title: 'Учет расходов',
        body: 'Не забудьте внести сегодняшние траты для точного баланса.',
        hour: state.budgetEveningTime.hour,
        minute: state.budgetEveningTime.minute,
        payload: 'screen_budget',
      );
    } else {
      s.cancelNotification(90002);
      s.cancelNotification(90003);
    }
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
      NotificationSettingsNotifier.new,
    );
