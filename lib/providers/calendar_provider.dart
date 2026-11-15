import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/database_service.dart';
import '../services/google_calendar_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

class UserCalendar {
  final String id;
  final String title;
  final Color color;
  final bool isVisible;
  final String accountType; // 'local' или 'google'

  const UserCalendar({
    required this.id,
    required this.title,
    required this.color,
    this.isVisible = true,
    this.accountType = 'local',
  });

  UserCalendar copyWith({
    String? id,
    String? title,
    Color? color,
    bool? isVisible,
    String? accountType,
  }) {
    return UserCalendar(
      id: id ?? this.id,
      title: title ?? this.title,
      color: color ?? this.color,
      isVisible: isVisible ?? this.isVisible,
      accountType: accountType ?? this.accountType,
    );
  }
}

class UserCalendarsNotifier extends Notifier<List<UserCalendar>> {
  @override
  List<UserCalendar> build() {
    return const [
      UserCalendar(id: 'cal_main', title: 'Основной', color: Color(0xFF2C69D1)),
      UserCalendar(id: 'cal_work', title: 'Работа', color: Color(0xFFF97316)),
      UserCalendar(id: 'cal_shifts', title: 'Смены', color: Color(0xFF10B981)),
      UserCalendar(
        id: 'cal_google',
        title: 'Google',
        color: Color(0xFF4285F4),
        accountType: 'google',
      ),
    ];
  }

  Future<void> loadCalendars() async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.query('user_calendars');
      final googleCals = rows.map((r) {
        final m = Map<String, dynamic>.from(r);
        return UserCalendar(
          id: m['id'] as String,
          title: m['title'] as String,
          color: Color((m['color'] as int?) ?? 0xFF2C69D1),
          isVisible: (m['is_visible'] as int? ?? 1) == 1,
          accountType: m['account_type'] as String? ?? 'local',
        );
      }).toList();

      final defaults = const [
        UserCalendar(
          id: 'cal_main',
          title: 'Основной',
          color: Color(0xFF2C69D1),
        ),
        UserCalendar(
          id: 'cal_work',
          title: 'Работа',
          color: Color(0xFFF97316),
        ),
        UserCalendar(
          id: 'cal_shifts',
          title: 'Смены',
          color: Color(0xFF10B981),
        ),
      ];

      state = [...defaults, ...googleCals];
    } catch (e) {
      debugPrint('Ошибка загрузки списка календарей: $e');
    }
  }

  void toggleVisibility(String id) {
    state = state.map((c) {
      if (c.id == id) {
        return c.copyWith(isVisible: !c.isVisible);
      }
      return c;
    }).toList();
  }

  void isolateCalendar(String id) {
    final target = state.firstWhere((c) => c.id == id);
    final allOthersHidden = state
        .where((c) => c.id != id)
        .every((c) => !c.isVisible);

    if (allOthersHidden && target.isVisible) {
      state = state.map((c) => c.copyWith(isVisible: true)).toList();
    } else {
      state = state.map((c) => c.copyWith(isVisible: c.id == id)).toList();
    }
  }

  void addCalendar(String title, Color color) {
    final newCal = UserCalendar(
      id: 'cal_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      color: color,
    );
    state = [...state, newCal];
  }

  void updateCalendar(String id, String title, Color color) {
    state = state.map((c) {
      if (c.id == id) {
        return c.copyWith(title: title, color: color);
      }
      return c;
    }).toList();
  }

  void deleteCalendar(String id) {
    state = state.where((c) => c.id != id).toList();
  }
}

final userCalendarsProvider =
    NotifierProvider<UserCalendarsNotifier, List<UserCalendar>>(
      UserCalendarsNotifier.new,
    );

class CalendarNotifier extends Notifier<List<Map<String, dynamic>>> {
  static const _uuid = Uuid();

  @override
  List<Map<String, dynamic>> build() {
    loadEvents();
    return const [];
  }

  Future<void> loadEvents() async {
    try {
      final db = await DatabaseService.instance.database;

      await db.execute('''
        CREATE TABLE IF NOT EXISTS calendar_events (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          title TEXT NOT NULL,
          date TEXT NOT NULL,
          end_date TEXT,
          start_time TEXT,
          end_time TEXT,
          is_all_day INTEGER DEFAULT 0,
          calendar TEXT DEFAULT 'Основной',
          color INTEGER,
          location TEXT,
          description TEXT,
          reminder_minutes INTEGER DEFAULT -1,
          recurrence TEXT DEFAULT 'none',
          is_synced INTEGER DEFAULT 0,
          updated_at TEXT NOT NULL
        )
      ''');

      final rows = await db.query('calendar_events', orderBy: 'date ASC');
      final events = rows.map((r) {
        final m = Map<String, dynamic>.from(r);
        m['date'] =
            DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now();
        if (m['end_date'] != null) {
          m['endDate'] = DateTime.tryParse(m['end_date'] as String);
        }
        m['startTime'] = m['start_time'];
        m['endTime'] = m['end_time'];
        m['isAllDay'] = m['is_all_day'] == 1;
        if (m['color'] != null) {
          m['color'] = Color(m['color'] as int);
        }
        return m;
      }).toList();

      state = events;
    } catch (e) {
      debugPrint('Ошибка загрузки событий: $e');
    }
  }

  Future<void> addEvent({
    required String title,
    required DateTime date,
    required DateTime endDate,
    String? startTime,
    String? endTime,
    bool isAllDay = false,
    String calendar = 'Основной',
    Color color = const Color(0xFF2C69D1),
    String? location,
    String? description,
    int reminderMinutes = -1,
    String recurrence = 'none',
  }) async {
    final db = await DatabaseService.instance.database;
    final id = _uuid.v4();
    final nowIso = DateTime.now().toIso8601String();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

    final row = {
      'id': id,
      'title': title,
      'date': dateStr,
      'end_date': endDateStr,
      'start_time': startTime,
      'end_time': endTime,
      'is_all_day': isAllDay ? 1 : 0,
      'calendar': calendar,
      'color': color.toARGB32(),
      'location': location,
      'description': description,
      'reminder_minutes': reminderMinutes,
      'recurrence': recurrence,
      'is_synced': 0,
      'updated_at': nowIso,
    };

    await db.insert(
      'calendar_events',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (reminderMinutes >= 0 && !isAllDay && startTime != null) {
      try {
        final parts = startTime.split(':');
        final evTime = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        final notifyTime = evTime.subtract(Duration(minutes: reminderMinutes));
        if (notifyTime.isAfter(DateTime.now())) {
          await NotificationService.instance.scheduleNotification(
            id: id.hashCode,
            title: 'Событие: $title',
            body: 'Начало в $startTime ($calendar)',
            scheduledDate: notifyTime,
            payload: 'screen_calendar',
          );
        }
      } catch (_) {}
    }

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

    await NotificationService.instance.cancelNotification(id.hashCode);
    await loadEvents();
    SyncService.instance.syncAll();
  }

  /// Сквозная синхронизация со ВСЕМИ календарями Google
  Future<int> syncWithGoogleCalendar() async {
    try {
      final isAuth = await GoogleCalendarService.instance.init();
      if (!isAuth) {
        final account = await GoogleCalendarService.instance.signIn();
        if (account == null) {
          debugPrint('Google Calendar: пользователь отменил авторизацию');
          return 0;
        }
      }

      // Запрашиваем события за широкий интервал: 3 месяца назад и 12 месяцев вперед
      final now = DateTime.now();
      final timeMin = DateTime(now.year, now.month - 3, 1);
      final timeMax = DateTime(now.year + 1, now.month + 12, 1);

      final events = await GoogleCalendarService.instance
          .fetchAllEventsFromAllCalendars(timeMin: timeMin, timeMax: timeMax);

      if (events.isEmpty) {
        debugPrint('Google Calendar: нет событий для импорта');
        return 0;
      }

      final db = await DatabaseService.instance.database;
      int importedCount = 0;

      // Карта созданных календарей приложения под каждый Google-календарь.
      final existingCalendars =
          (await db.query('user_calendars')).map((r) => Map<String, dynamic>.from(r)).toList();
      final googleCalTitles = <String,String>{};
      for (final ge in events) {
        googleCalTitles[ge.calendarId] = ge.calendarTitle;
      }
      for (final entry in googleCalTitles.entries) {
        final exists = existingCalendars.any((c) => c['title'] == entry.value && c['account_type'] == 'google');
        if (!exists) {
          await db.insert('user_calendars', {
            'id': 'gcal_${_uuid.v4()}',
            'user_id': null,
            'title': entry.value,
            'color': events.firstWhere((e) => e.calendarId == entry.key).colorArgb,
            'is_visible': 1,
            'account_type': 'google',
            'is_synced': 0,
            'updated_at': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      for (final ge in events) {
        final ev = ge.event;
        final calTitle = ge.calendarTitle;
        final calColor = ge.colorArgb;
        final title = ev.summary ?? 'Без названия';

        DateTime? startDt;
        bool isAllDay = false;
        String? startTime;
        String? endTime;

        if (ev.start?.dateTime != null) {
          startDt = ev.start!.dateTime!.toLocal();
          startTime = DateFormat('HH:mm').format(startDt);
        } else if (ev.start?.date != null) {
          startDt = ev.start!.date;
          isAllDay = true;
        }

        if (startDt == null) continue;

        DateTime endDt = startDt;
        if (ev.end?.dateTime != null) {
          final endLocal = ev.end!.dateTime!.toLocal();
          endDt = endLocal;
          endTime = DateFormat('HH:mm').format(endLocal);
        } else if (ev.end?.date != null) {
          endDt = ev.end!.date!;
        }

        final dateStr = DateFormat('yyyy-MM-dd').format(startDt);
        final endDateStr = DateFormat('yyyy-MM-dd').format(endDt);

        // Формируем детерминированный UUID на базе id события Google
        final eventId = _uuid.v5(
          Uuid.NAMESPACE_URL,
          'google_calendar_${ev.id ?? title}_$dateStr',
        );
        final nowIso = DateTime.now().toIso8601String();

        await db.insert('calendar_events', {
          'id': eventId,
          'title': title,
          'date': dateStr,
          'end_date': endDateStr,
          'start_time': startTime,
          'end_time': endTime,
          'is_all_day': isAllDay ? 1 : 0,
          'calendar': calTitle,
          'color': calColor,
          'location': ev.location,
          'description': ev.description,
          'reminder_minutes': -1,
          'recurrence': 'none',
          'is_synced': 0,
          'updated_at': nowIso,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        importedCount++;
      }

      await loadEvents();
      SyncService.instance.syncAll();
      return importedCount;
    } catch (e, stack) {
      debugPrint(
        'Ошибка синхронизации Google Calendar в провайдере: $e\n$stack',
      );
      return 0;
    }
  }
}

final calendarProvider =
    NotifierProvider<CalendarNotifier, List<Map<String, dynamic>>>(
      CalendarNotifier.new,
    );

// Шаблоны событий
class EventTemplatesNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() => [];

  void addTemplate(Map<String, dynamic> template) {
    state = [...state, template];
  }
}

final eventTemplatesProvider =
    NotifierProvider<EventTemplatesNotifier, List<Map<String, dynamic>>>(
      EventTemplatesNotifier.new,
    );

// Приглашения
class EventInvitesNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() => [];

  void acceptInvite(String id) {
    state = state.where((item) => item['id'].toString() != id).toList();
  }

  void declineInvite(String id) {
    state = state.where((item) => item['id'].toString() != id).toList();
  }
}

final eventInvitesProvider =
    NotifierProvider<EventInvitesNotifier, List<Map<String, dynamic>>>(
      EventInvitesNotifier.new,
    );
