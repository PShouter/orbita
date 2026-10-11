import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';

class UserCalendar {
  final String id;
  final String title;
  final Color color;
  final bool isVisible;
  final String accountType;

  UserCalendar({
    required this.id,
    required this.title,
    required this.color,
    required this.isVisible,
    this.accountType = 'local',
  });

  UserCalendar copyWith({String? title, Color? color, bool? isVisible}) {
    return UserCalendar(
      id: id,
      title: title ?? this.title,
      color: color ?? this.color,
      isVisible: isVisible ?? this.isVisible,
      accountType: accountType,
    );
  }
}

class UserCalendarsNotifier extends Notifier<List<UserCalendar>> {
  @override
  List<UserCalendar> build() {
    loadCalendars();
    return [];
  }

  Future<void> loadCalendars() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('user_calendars');

    if (rows.isEmpty) {
      final defaultCals = [
        UserCalendar(
          id: 'cal_main',
          title: 'Основной',
          color: const Color(0xFF2C69D1),
          isVisible: true,
        ),
        UserCalendar(
          id: 'cal_work',
          title: 'Работа',
          color: const Color(0xFF38BDF8),
          isVisible: true,
        ),
        UserCalendar(
          id: 'cal_personal',
          title: 'Личное',
          color: const Color(0xFF10B981),
          isVisible: true,
        ),
      ];
      for (final c in defaultCals) {
        await db.insert('user_calendars', {
          'id': c.id,
          'title': c.title,
          'color': c.color.toARGB32(),
          'is_visible': 1,
          'account_type': 'local',
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      state = defaultCals;
    } else {
      state = rows.map((r) {
        return UserCalendar(
          id: r['id'] as String,
          title: r['title'] as String,
          color: Color(r['color'] as int),
          isVisible: (r['is_visible'] as int) == 1,
          accountType: r['account_type'] as String? ?? 'local',
        );
      }).toList();
    }
  }

  Future<void> toggleVisibility(String id) async {
    final db = await DatabaseService.instance.database;
    final current = state.firstWhere((c) => c.id == id);
    final newVis = !current.isVisible;

    await db.update(
      'user_calendars',
      {'is_visible': newVis ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    state = state
        .map((c) => c.id == id ? c.copyWith(isVisible: newVis) : c)
        .toList();
  }

  Future<void> isolateCalendar(String id) async {
    final db = await DatabaseService.instance.database;
    final allExceptSelectedAreOff = state
        .where((c) => c.id != id)
        .every((c) => !c.isVisible);

    final newStates = state.map((c) {
      final vis = allExceptSelectedAreOff ? true : (c.id == id);
      return c.copyWith(isVisible: vis);
    }).toList();

    for (final c in newStates) {
      await db.update(
        'user_calendars',
        {'is_visible': c.isVisible ? 1 : 0},
        where: 'id = ?',
        whereArgs: [c.id],
      );
    }
    state = newStates;
  }

  Future<void> addCalendar(String title, Color color) async {
    final db = await DatabaseService.instance.database;
    final id = 'cal_${DateTime.now().millisecondsSinceEpoch}';
    final nowIso = DateTime.now().toIso8601String();

    await db.insert('user_calendars', {
      'id': id,
      'title': title,
      'color': color.toARGB32(),
      'is_visible': 1,
      'account_type': 'local',
      'is_synced': 0,
      'updated_at': nowIso,
    });

    state = [
      ...state,
      UserCalendar(id: id, title: title, color: color, isVisible: true),
    ];
    SyncService.instance.syncAll();
  }

  Future<void> updateCalendar(String id, String title, Color color) async {
    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'user_calendars',
      {'title': title, 'color': color.toARGB32(), 'updated_at': nowIso},
      where: 'id = ?',
      whereArgs: [id],
    );

    state = state
        .map((c) => c.id == id ? c.copyWith(title: title, color: color) : c)
        .toList();
    SyncService.instance.syncAll();
  }

  Future<void> deleteCalendar(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('user_calendars', where: 'id = ?', whereArgs: [id]);
    await db.insert('delete_queue', {
      'table_name': 'user_calendars',
      'record_id': id,
      'created_at': DateTime.now().toIso8601String(),
    });

    state = state.where((c) => c.id != id).toList();
    SyncService.instance.syncAll();
  }
}

final userCalendarsProvider =
    NotifierProvider<UserCalendarsNotifier, List<UserCalendar>>(
      UserCalendarsNotifier.new,
    );

/// Шаблоны событий
class EventTemplatesNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() => [];

  void addTemplate(Map<String, dynamic> tpl) {
    state = [...state, tpl];
  }
}

final eventTemplatesProvider =
    NotifierProvider<EventTemplatesNotifier, List<Map<String, dynamic>>>(
      EventTemplatesNotifier.new,
    );

/// Приглашения
class EventInvitesNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() => [];

  void acceptInvite(String id) {
    state = state.where((item) => item['id'] != id).toList();
  }

  void declineInvite(String id) {
    state = state.where((item) => item['id'] != id).toList();
  }
}

final eventInvitesProvider =
    NotifierProvider<EventInvitesNotifier, List<Map<String, dynamic>>>(
      EventInvitesNotifier.new,
    );

/// Основные события
class CalendarNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    loadEvents();
    return [];
  }

  Future<void> loadEvents() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('calendar_events', orderBy: 'date ASC');

    state = rows.map((r) {
      return {
        'id': r['id'],
        'title': r['title'],
        'date': DateTime.parse(r['date'] as String),
        'endDate': r['end_date'] != null
            ? DateTime.parse(r['end_date'] as String)
            : null,
        'startTime': r['start_time'],
        'endTime': r['end_time'],
        'isAllDay': (r['is_all_day'] as int) == 1,
        'calendar': r['calendar'] ?? 'Основной',
        'color': r['color'] != null
            ? Color(r['color'] as int)
            : const Color(0xFF2C69D1),
        'description': r['description'],
        'location': r['location'],
        'reminderMinutes': r['reminder_minutes'] ?? -1,
        'recurrence': r['recurrence'] ?? 'none',
      };
    }).toList();
  }

  Future<void> addEvent({
    required String title,
    required DateTime date,
    DateTime? endDate,
    String? startTime,
    String? endTime,
    bool isAllDay = false,
    required String calendar,
    required Color color,
    String? description,
    String? location,
    int reminderMinutes = -1,
    String recurrence = 'none',
  }) async {
    final db = await DatabaseService.instance.database;
    final id = 'cal_event_${DateTime.now().millisecondsSinceEpoch}';
    final nowIso = DateTime.now().toIso8601String();

    final row = {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'is_all_day': isAllDay ? 1 : 0,
      'calendar': calendar,
      'color': color.toARGB32(),
      'description': description,
      'location': location,
      'is_synced': 0,
      'updated_at': nowIso,
    };

    await db.insert(
      'calendar_events',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await loadEvents();
    SyncService.instance.syncAll();
  }

  Future<void> deleteEvent(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('calendar_events', where: 'id = ?', whereArgs: [id]);
    await db.insert('delete_queue', {
      'table_name': 'calendar_events',
      'record_id': id,
      'created_at': DateTime.now().toIso8601String(),
    });

    state = state.where((e) => e['id'].toString() != id).toList();
    SyncService.instance.syncAll();
  }
}

final calendarProvider =
    NotifierProvider<CalendarNotifier, List<Map<String, dynamic>>>(
      CalendarNotifier.new,
    );
