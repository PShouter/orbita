import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/database_service.dart';
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
  id: 'shift_work',
  name: 'Работа',
  shortName: 'Р',
  color: Colors.redAccent.value,
  isWork: true,
  startTime: '08:00',
  endTime: '20:00',
);

final defaultRestShift = ShiftType(
  id: 'shift_rest',
  name: 'Выходной',
  shortName: 'В',
  color: Colors.green.value,
  isWork: false,
  startTime: '',
  endTime: '',
);

// Сохраненное переопределение дня (с возможностью кастомных часов для конкретной даты)
class ShiftOverride {
  final String shiftId; // или 'empty'
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

  @override
  ShiftState build() {
    final defaultId = 'schedule_main';
    final initial = ShiftScheduleState(
      id: defaultId,
      name: 'Основная работа',
      startDate: DateTime.now(),
      cycleShiftIds: [],
      overrides: {},
      customShiftTypes: [defaultWorkShift, defaultRestShift],
    );

    Future.microtask(() => loadSchedules());

    return ShiftState(schedules: [initial], activeScheduleId: defaultId);
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
      if (rows.isEmpty) {
        final initial = ShiftScheduleState(
          id: _uuid.v4(),
          name: 'Основная работа',
          startDate: DateTime.now(),
          cycleShiftIds: [],
          overrides: {},
          customShiftTypes: [defaultWorkShift, defaultRestShift],
        );
        await _saveToDb(initial);
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

          return ShiftScheduleState(
            id: r['id'] as String,
            name: r['name'] as String? ?? 'График',
            startDate:
                DateTime.tryParse(r['start_date'] as String? ?? '') ??
                DateTime.now(),
            cycleShiftIds: cycle,
            overrides: over,
            customShiftTypes: types,
          );
        }).toList();

        final currentActive = loaded.any((s) => s.id == state.activeScheduleId)
            ? state.activeScheduleId
            : loaded.first.id;

        state = ShiftState(schedules: loaded, activeScheduleId: currentActive);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки графиков смен: $e');
    }
  }

  void switchSchedule(String id) {
    if (state.schedules.any((s) => s.id == id)) {
      state = ShiftState(schedules: state.schedules, activeScheduleId: id);
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
          color: Colors.blueAccent.value,
        ),
        defaultRestShift.copyWith(id: _uuid.v4()),
      ],
    );

    final updated = [...state.schedules, newSchedule];
    state = ShiftState(schedules: updated, activeScheduleId: newSchedule.id);
    await _saveToDb(newSchedule);
  }

  Future<void> deleteActiveSchedule() async {
    if (state.schedules.length <= 1) return; // Не удаляем последний график
    final activeId = state.activeScheduleId;

    final db = await DatabaseService.instance.database;
    await db.delete('shift_schedules', where: 'id = ?', whereArgs: [activeId]);

    final remaining = state.schedules.where((s) => s.id != activeId).toList();
    state = ShiftState(
      schedules: remaining,
      activeScheduleId: remaining.first.id,
    );
  }

  Future<void> _saveToDb(ShiftScheduleState schedule) async {
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
    for (final d in dates) {
      final key = DateFormat('yyyy-MM-dd').format(d);
      newOverrides[key] = ShiftOverride(shiftId: 'empty');
    }

    final updatedSchedule = active.copyWith(overrides: newOverrides);
    final newSchedules = state.schedules
        .map((s) => s.id == active.id ? updatedSchedule : s)
        .toList();
    state = ShiftState(schedules: newSchedules, activeScheduleId: active.id);
    await _saveToDb(updatedSchedule);
  }

  Future<void> clearEntireActiveSchedule() async {
    final active = state.activeSchedule;
    if (active == null) return;

    final updatedSchedule = active.copyWith(cycleShiftIds: [], overrides: {});

    final newSchedules = state.schedules
        .map((s) => s.id == active.id ? updatedSchedule : s)
        .toList();
    state = ShiftState(schedules: newSchedules, activeScheduleId: active.id);
    await _saveToDb(updatedSchedule);
  }

  /// Синхронизация ВСЕХ графиков пользователя в календарь
  Future<int> syncAllSchedulesToCalendar(int monthsCount) async {
    try {
      final db = await DatabaseService.instance.database;

      final now = DateTime.now();
      final startRange = DateTime(now.year, now.month, 1);
      final endRange = DateTime(now.year, now.month + monthsCount, 0);

      final startIso = DateFormat('yyyy-MM-dd').format(startRange);
      final endIso = DateFormat('yyyy-MM-dd').format(endRange);

      // Очищаем старые события со смен
      await db.delete(
        'calendar_events',
        where: "calendar = 'Смены' AND date >= ? AND date <= ?",
        whereArgs: [startIso, endIso],
      );

      var insertedCount = 0;

      for (final schedule in state.schedules) {
        var cur = startRange;
        while (!cur.isAfter(endRange)) {
          final shift = schedule.getShiftForDate(cur);

          if (shift != null && shift.isWork) {
            final dateStr = DateFormat('yyyy-MM-dd').format(cur);
            final eventId = _uuid.v4();
            final nowIso = DateTime.now().toIso8601String();

            await db.insert('calendar_events', {
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
                  'График: ${schedule.name}\nВремя: ${shift.startTime} - ${shift.endTime}',
              'is_synced': 0,
              'updated_at': nowIso,
            });
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
