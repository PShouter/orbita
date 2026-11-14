import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

class ShiftType {
  final String id;
  final String name;
  final String shortName;
  final int color;
  final bool isWork;
  final String startTime;
  final String endTime;

  const ShiftType({
    required this.id,
    required this.name,
    required this.shortName,
    required this.color,
    required this.isWork,
    this.startTime = '08:00',
    this.endTime = '20:00',
  });

  ShiftType copyWith({
    String? id,
    String? name,
    String? shortName,
    int? color,
    bool? isWork,
    String? startTime,
    String? endTime,
  }) {
    return ShiftType(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      color: color ?? this.color,
      isWork: isWork ?? this.isWork,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'shortName': shortName,
        'color': color,
        'isWork': isWork ? 1 : 0,
        'startTime': startTime,
        'endTime': endTime,
      };

  factory ShiftType.fromMap(Map<String, dynamic> map) => ShiftType(
        id: map['id'] as String,
        name: map['name'] as String,
        shortName: map['shortName'] as String,
        color: map['color'] as int,
        isWork: (map['isWork'] as int) == 1,
        startTime: map['startTime'] as String? ?? '08:00',
        endTime: map['endTime'] as String? ?? '20:00',
      );

  bool get isNightShift {
    if (!isWork || !startTime.contains(':') || !endTime.contains(':')) {
      return false;
    }
    try {
      final s = startTime.split(':').map(int.parse).toList();
      final e = endTime.split(':').map(int.parse).toList();
      final startMin = s[0] * 60 + s[1];
      final endMin = e[0] * 60 + e[1];
      return endMin <= startMin; // смена переходит через полночь
    } catch (_) {
      return false;
    }
  }

  double get durationHours {
    if (!isWork) return 0.0;
    try {
      final s = startTime.split(':').map(int.parse).toList();
      final e = endTime.split(':').map(int.parse).toList();
      var diffMinutes = (e[0] * 60 + e[1]) - (s[0] * 60 + s[1]);
      if (diffMinutes <= 0) diffMinutes += 24 * 60;
      return diffMinutes / 60.0;
    } catch (_) {
      return 8.0;
    }
  }
}

final defaultWorkShift = ShiftType(
  id: '00000000-0000-4000-8000-000000000010',
  name: 'Работа',
  shortName: 'Р',
  color: Colors.redAccent.toARGB32(),
  isWork: true,
  startTime: '08:00',
  endTime: '20:00',
);

final defaultRestShift = ShiftType(
  id: '00000000-0000-4000-8000-000000000020',
  name: 'Выходной',
  shortName: 'В',
  color: Colors.green.toARGB32(),
  isWork: false,
  startTime: '',
  endTime: '',
);

class ShiftOverride {
  final String shiftId;
  final String? customStartTime;
  final String? customEndTime;

  ShiftOverride({
    required this.shiftId,
    this.customStartTime,
    this.customEndTime,
  });

  Map<String, dynamic> toMap() => {
        'shiftId': shiftId,
        'customStartTime': customStartTime,
        'customEndTime': customEndTime,
      };

  factory ShiftOverride.fromDynamic(dynamic val) {
    if (val is String) {
      return ShiftOverride(shiftId: val);
    }
    if (val is Map) {
      return ShiftOverride(
        shiftId: val['shiftId'] as String? ?? 'empty',
        customStartTime: val['customStartTime'] as String?,
        customEndTime: val['customEndTime'] as String?,
      );
    }
    return ShiftOverride(shiftId: 'empty');
  }
}

class ShiftScheduleState {
  final String id;
  final String name;
  final DateTime startDate;
  final List<String> cycleShiftIds;
  final Map<String, ShiftOverride> overrides;
  final List<ShiftType> customShiftTypes;

  ShiftScheduleState({
    required this.id,
    required this.name,
    required this.startDate,
    required this.cycleShiftIds,
    required this.overrides,
    required this.customShiftTypes,
  });

  ShiftScheduleState copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    List<String>? cycleShiftIds,
    Map<String, ShiftOverride>? overrides,
    List<ShiftType>? customShiftTypes,
  }) {
    return ShiftScheduleState(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      cycleShiftIds: cycleShiftIds ?? this.cycleShiftIds,
      overrides: overrides ?? this.overrides,
      customShiftTypes: customShiftTypes ?? this.customShiftTypes,
    );
  }

  ShiftType? getShiftForDate(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    final allTypes = {for (var t in customShiftTypes) t.id: t};

    if (overrides.containsKey(key)) {
      final over = overrides[key]!;
      if (over.shiftId == 'empty') return null;
      final baseType = allTypes[over.shiftId];
      if (baseType == null) return null;

      if (over.customStartTime != null || over.customEndTime != null) {
        return baseType.copyWith(
          startTime: over.customStartTime ?? baseType.startTime,
          endTime: over.customEndTime ?? baseType.endTime,
        );
      }
      return baseType;
    }

    if (cycleShiftIds.isEmpty) return null;

    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final diffDays = dateOnly.difference(startOnly).inDays;

    final cycleLen = cycleShiftIds.length;
    final cycleIndex = (diffDays % cycleLen + cycleLen) % cycleLen;
    final shiftId = cycleShiftIds[cycleIndex];

    return allTypes[shiftId];
  }

  bool isWorkDay(DateTime date) {
    final shift = getShiftForDate(date);
    return shift?.isWork ?? false;
  }
}

class ShiftState {
  final List<ShiftScheduleState> schedules;
  final String activeScheduleId;

  ShiftState({required this.schedules, required this.activeScheduleId});

  ShiftScheduleState? get activeSchedule {
    return schedules.where((s) => s.id == activeScheduleId).firstOrNull ??
        schedules.firstOrNull;
  }
}

class ShiftNotifier extends Notifier<ShiftState> {
  static const _uuid = Uuid();
  static const _activeSchedulePrefKey = 'active_shift_schedule_id';
  static const _defaultValidUuid = '00000000-0000-4000-8000-000000000001';

  @override
  ShiftState build() {
    final initial = ShiftScheduleState(
      id: _defaultValidUuid,
      name: 'Основная работа',
      startDate: DateTime.now(),
      cycleShiftIds: [],
      overrides: {},
      customShiftTypes: [defaultWorkShift, defaultRestShift],
    );

    Future.microtask(() => loadSchedules());

    return ShiftState(
      schedules: [initial],
      activeScheduleId: _defaultValidUuid,
    );
  }

  Future<void> loadSchedules() async {
    try {
      final db = await DatabaseService.instance.database;

      await db.execute('''
        CREATE TABLE IF NOT EXISTS shift_schedules (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          name TEXT NOT NULL,
          start_date TEXT NOT NULL,
          cycle_days TEXT NOT NULL,
          overrides TEXT,
          custom_types TEXT,
          is_synced INTEGER DEFAULT 0,
          updated_at TEXT NOT NULL
        )
      ''');

      final rows = await db.query('shift_schedules', orderBy: 'updated_at ASC');
      final prefs = await SharedPreferences.getInstance();
      final savedActiveId = prefs.getString(_activeSchedulePrefKey);

      if (rows.isEmpty) {
        final initial = ShiftScheduleState(
          id: _defaultValidUuid,
          name: 'Основная работа',
          startDate: DateTime.now(),
          cycleShiftIds: [],
          overrides: {},
          customShiftTypes: [defaultWorkShift, defaultRestShift],
        );
        await _saveToDb(initial, autoSyncCalendar: false);
        state = ShiftState(schedules: [initial], activeScheduleId: initial.id);
      } else {
        final loaded = rows.map((r) {
          List<String> cycle = [];
          if (r['cycle_days'] != null) {
            try {
              cycle = List<String>.from(jsonDecode(r['cycle_days'] as String));
            } catch (_) {}
          }

          Map<String, ShiftOverride> over = {};
          if (r['overrides'] != null) {
            try {
              final rawMap = jsonDecode(r['overrides'] as String) as Map;
              rawMap.forEach((k, v) {
                over[k.toString()] = ShiftOverride.fromDynamic(v);
              });
            } catch (_) {}
          }

          List<ShiftType> types = [defaultWorkShift, defaultRestShift];
          if (r['custom_types'] != null) {
            try {
              final decoded = jsonDecode(r['custom_types'] as String) as List;
              types = decoded.map((m) => ShiftType.fromMap(m)).toList();
            } catch (_) {}
          }

          var schedId = r['id'] as String;
          if (schedId == 'schedule_main') {
            schedId = _defaultValidUuid;
          }

          return ShiftScheduleState(
            id: schedId,
            name: r['name'] as String? ?? 'График',
            startDate: DateTime.tryParse(r['start_date'] as String? ?? '') ??
                DateTime.now(),
            cycleShiftIds: cycle,
            overrides: over,
            customShiftTypes: types,
          );
        }).toList();

        String currentActive = loaded.first.id;
        if (savedActiveId != null && loaded.any((s) => s.id == savedActiveId)) {
          currentActive = savedActiveId;
        }

        state = ShiftState(schedules: loaded, activeScheduleId: currentActive);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки графиков смен: $e');
    }
  }

  Future<void> switchSchedule(String id) async {
    if (state.schedules.any((s) => s.id == id)) {
      state = ShiftState(schedules: state.schedules, activeScheduleId: id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeSchedulePrefKey, id);
    }
  }

  Future<void> addNewSchedule(String name) async {
    final newSchedule = ShiftScheduleState(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Новый график' : name.trim(),
      startDate: DateTime.now(),
      cycleShiftIds: [],
      overrides: {},
      customShiftTypes: [
        defaultWorkShift.copyWith(
          id: _uuid.v4(),
          color: Colors.blueAccent.toARGB32(),
        ),
        defaultRestShift.copyWith(id: _uuid.v4()),
      ],
    );

    final updated = [...state.schedules, newSchedule];
    state = ShiftState(schedules: updated, activeScheduleId: newSchedule.id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeSchedulePrefKey, newSchedule.id);

    await _saveToDb(newSchedule);
  }

  Future<void> deleteActiveSchedule() async {
    if (state.schedules.length <= 1) return;
    final activeId = state.activeScheduleId;

    final db = await DatabaseService.instance.database;
    await db.delete('shift_schedules', where: 'id = ?', whereArgs: [activeId]);

    final rows = await db.query(
      'calendar_events',
      where: "calendar = 'Смены' AND description LIKE ?",
      whereArgs: ['%$activeId%'],
    );
    for (final r in rows) {
      final evId = r['id'] as String;
      await NotificationService.instance.cancelNotification(
        ('eve_$evId').hashCode,
      );
      await NotificationService.instance.cancelNotification(
        ('warn_$evId').hashCode,
      );
      await db.insert('delete_queue', {
        'table_name': 'calendar_events',
        'record_id': evId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    await db.delete(
      'calendar_events',
      where: "calendar = 'Смены' AND description LIKE ?",
      whereArgs: ['%$activeId%'],
    );

    final remaining = state.schedules.where((s) => s.id != activeId).toList();
    state = ShiftState(
      schedules: remaining,
      activeScheduleId: remaining.first.id,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeSchedulePrefKey, remaining.first.id);

    await syncAllSchedulesToCalendar(3);
  }

  Future<void> _saveToDb(
    ShiftScheduleState schedule, {
    bool autoSyncCalendar = true,
  }) async {
    try {
      final db = await DatabaseService.instance.database;

      final overridesMap = schedule.overrides.map(
        (k, v) => MapEntry(k, v.toMap()),
      );

      final row = {
        'id': schedule.id,
        'name': schedule.name,
        'start_date': schedule.startDate.toIso8601String(),
        'cycle_days': jsonEncode(schedule.cycleShiftIds),
        'overrides': jsonEncode(overridesMap),
        'custom_types': jsonEncode(
          schedule.customShiftTypes.map((t) => t.toMap()).toList(),
        ),
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await db.insert(
        'shift_schedules',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      SyncService.instance.syncAll();

      if (autoSyncCalendar) {
        await syncAllSchedulesToCalendar(3);
      }
    } catch (e) {
      debugPrint('Ошибка сохранения графика в БД: $e');
    }
  }

  Future<void> updateActiveSchedule({
    required String name,
    required DateTime startDate,
    required List<String> cycleShiftIds,
    required List<ShiftType> customShiftTypes,
  }) async {
    final active = state.activeSchedule;
    if (active == null) return;

    final updatedSchedule = active.copyWith(
      name: name,
      startDate: startDate,
      cycleShiftIds: cycleShiftIds,
      customShiftTypes: customShiftTypes,
    );

    final newSchedules = state.schedules
        .map((s) => s.id == active.id ? updatedSchedule : s)
        .toList();
    state = ShiftState(schedules: newSchedules, activeScheduleId: active.id);
    await _saveToDb(updatedSchedule);
  }

  Future<void> assignShiftToDates(
    List<DateTime> dates,
    String shiftId, {
    String? customStartTime,
    String? customEndTime,
  }) async {
    final active = state.activeSchedule;
    if (active == null) return;

    final newOverrides = Map<String, ShiftOverride>.from(active.overrides);
    for (final d in dates) {
      final key = DateFormat('yyyy-MM-dd').format(d);
      newOverrides[key] = ShiftOverride(
        shiftId: shiftId,
        customStartTime: customStartTime,
        customEndTime: customEndTime,
      );
    }

    final updatedSchedule = active.copyWith(overrides: newOverrides);
    final newSchedules = state.schedules
        .map((s) => s.id == active.id ? updatedSchedule : s)
        .toList();
    state = ShiftState(schedules: newSchedules, activeScheduleId: active.id);
    await _saveToDb(updatedSchedule);
  }

  Future<void> clearShiftsForDates(List<DateTime> dates) async {
    final active = state.activeSchedule;
    if (active == null) return;

    final newOverrides = Map<String, ShiftOverride>.from(active.overrides);
    final db = await DatabaseService.instance.database;

    for (final d in dates) {
      final key = DateFormat('yyyy-MM-dd').format(d);
      newOverrides[key] = ShiftOverride(shiftId: 'empty');

      final rows = await db.query(
        'calendar_events',
        where: "calendar = 'Смены' AND date = ?",
        whereArgs: [key],
      );
      for (final r in rows) {
        final evId = r['id'] as String;
        await db.delete('calendar_events', where: 'id = ?', whereArgs: [evId]);
        await db.insert('delete_queue', {
          'table_name': 'calendar_events',
          'record_id': evId,
          'created_at': DateTime.now().toIso8601String(),
        });

        await NotificationService.instance.cancelNotification(
          ('eve_$evId').hashCode,
        );
        await NotificationService.instance.cancelNotification(
          ('warn_$evId').hashCode,
        );
      }
    }

    final updatedSchedule = active.copyWith(overrides: newOverrides);
    final newSchedules = state.schedules
        .map((s) => s.id == active.id ? updatedSchedule : s)
        .toList();
    state = ShiftState(schedules: newSchedules, activeScheduleId: active.id);
    await _saveToDb(updatedSchedule, autoSyncCalendar: false);
  }

  Future<void> clearEntireActiveSchedule() async {
    final active = state.activeSchedule;
    if (active == null) return;

    final db = await DatabaseService.instance.database;

    final rows = await db.query('calendar_events', where: "calendar = 'Смены'");
    for (final r in rows) {
      final evId = r['id'] as String;
      await NotificationService.instance.cancelNotification(
        ('eve_$evId').hashCode,
      );
      await NotificationService.instance.cancelNotification(
        ('warn_$evId').hashCode,
      );
      await db.insert('delete_queue', {
        'table_name': 'calendar_events',
        'record_id': evId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    await db.delete('calendar_events', where: "calendar = 'Смены'");

    final updatedSchedule = active.copyWith(cycleShiftIds: [], overrides: {});

    final newSchedules = state.schedules
        .map((s) => s.id == active.id ? updatedSchedule : s)
        .toList();
    state = ShiftState(schedules: newSchedules, activeScheduleId: active.id);
    await _saveToDb(updatedSchedule, autoSyncCalendar: false);
  }

  Future<int> syncAllSchedulesToCalendar(int monthsCount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSyncEnabled = prefs.getBool('shifts_sync_main_calendar') ?? true;
      final remindEve = prefs.getBool('shifts_remind_evening') ?? true;
      final eveTimeStr = prefs.getString('shifts_evening_time') ?? '20:00';
      final remindBefore = prefs.getBool('shifts_remind_before') ?? true;
      final remindBeforeMinutes =
          prefs.getInt('shifts_remind_before_minutes') ?? 90;

      final db = await DatabaseService.instance.database;

      final now = DateTime.now();
      final startRange = DateTime(now.year, now.month - 1, 1);
      final endRange = DateTime(now.year, now.month + monthsCount, 0);

      final startIso = DateFormat('yyyy-MM-dd').format(startRange);
      final endIso = DateFormat('yyyy-MM-dd').format(endRange);

      final existingRows = await db.query(
        'calendar_events',
        where: "calendar = 'Смены' AND date >= ? AND date <= ?",
        whereArgs: [startIso, endIso],
      );
      for (final r in existingRows) {
        final evId = r['id'] as String;
        await NotificationService.instance.cancelNotification(
          ('eve_$evId').hashCode,
        );
        await NotificationService.instance.cancelNotification(
          ('warn_$evId').hashCode,
        );
        await db.insert('delete_queue', {
          'table_name': 'calendar_events',
          'record_id': evId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      await db.delete(
        'calendar_events',
        where: "calendar = 'Смены' AND date >= ? AND date <= ?",
        whereArgs: [startIso, endIso],
      );

      if (!isSyncEnabled) {
        try {
          SyncService.instance.syncAll();
        } catch (_) {}
        return 0;
      }

      var insertedCount = 0;

      for (final schedule in state.schedules) {
        var cur = startRange;
        while (!cur.isAfter(endRange)) {
          final shift = schedule.getShiftForDate(cur);

          if (shift != null && shift.isWork) {
            final dateStr = DateFormat('yyyy-MM-dd').format(cur);
            final eventId = _uuid.v4();
            final nowIso = DateTime.now().toIso8601String();

            await db.insert(
                'calendar_events',
                {
                  'id': eventId,
                  'title': '${schedule.name}: ${shift.name}',
                  'date': dateStr,
                  'end_date': dateStr,
                  'start_time': shift.startTime,
                  'end_time': shift.endTime,
                  'is_all_day': 0,
                  'calendar': 'Смены',
                  'color': shift.color,
                  'description':
                      'График: ${schedule.name} [${schedule.id}]\nВремя: ${shift.startTime} - ${shift.endTime}',
                  'is_synced': 0,
                  'updated_at': nowIso,
                },
                conflictAlgorithm: ConflictAlgorithm.replace);

            if (remindEve) {
              final eveParts = eveTimeStr.split(':');
              final eveH = int.tryParse(eveParts[0]) ?? 20;
              final eveM = int.tryParse(eveParts[1]) ?? 0;

              final eveDate = cur.subtract(const Duration(days: 1));
              final scheduleEveDate = DateTime(
                eveDate.year,
                eveDate.month,
                eveDate.day,
                eveH,
                eveM,
              );

              if (scheduleEveDate.isAfter(DateTime.now())) {
                await NotificationService.instance.scheduleNotification(
                  id: ('eve_$eventId').hashCode,
                  title: 'Завтра смена: ${shift.name}',
                  body:
                      'Время: ${shift.startTime} - ${shift.endTime} (${schedule.name})',
                  scheduledDate: scheduleEveDate,
                  payload: 'screen_shifts',
                );
              }
            }

            if (remindBefore) {
              try {
                final startParts = shift.startTime.split(':');
                final shiftStartTime = DateTime(
                  cur.year,
                  cur.month,
                  cur.day,
                  int.parse(startParts[0]),
                  int.parse(startParts[1]),
                );
                final notifyTime = shiftStartTime.subtract(
                  Duration(minutes: remindBeforeMinutes),
                );
                if (notifyTime.isAfter(DateTime.now())) {
                  await NotificationService.instance.scheduleNotification(
                    id: ('warn_$eventId').hashCode,
                    title: 'Скоро смена: ${shift.name}',
                    body: 'Начало в ${shift.startTime}. Пора собираться!',
                    scheduledDate: notifyTime,
                    payload: 'screen_shifts',
                  );
                }
              } catch (_) {}
            }

            insertedCount++;
          }
          cur = cur.add(const Duration(days: 1));
        }
      }

      try {
        SyncService.instance.syncAll();
      } catch (_) {}

      return insertedCount;
    } catch (e) {
      debugPrint('Ошибка синхронизации: $e');
      return 0;
    }
  }
}

final shiftProvider = NotifierProvider<ShiftNotifier, ShiftState>(
  ShiftNotifier.new,
);
