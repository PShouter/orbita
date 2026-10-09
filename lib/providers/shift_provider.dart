import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';

class ShiftSchedule {
  final String id;
  final String name;
  final DateTime startDate;
  final List<Map<String, dynamic>> cycleDays; // список дней шаблона
  final Map<String, dynamic> overrides; // ручные замены по дате YYYY-MM-DD

  ShiftSchedule({
    required this.id,
    required this.name,
    required this.startDate,
    required this.cycleDays,
    required this.overrides,
  });

  /// Получить информацию о смене на конкретный день
  Map<String, dynamic>? getShiftForDate(DateTime date) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // Если есть ручная подмена/отгул на этот день
    if (overrides.containsKey(key)) {
      return Map<String, dynamic>.from(overrides[key]);
    }

    if (cycleDays.isEmpty) return null;

    final startClean = DateTime(startDate.year, startDate.month, startDate.day);
    final targetClean = DateTime(date.year, date.month, date.day);
    final diffDays = targetClean.difference(startClean).inDays;

    final cycleLength = cycleDays.length;
    final index = (diffDays % cycleLength + cycleLength) % cycleLength;
    return Map<String, dynamic>.from(cycleDays[index]);
  }
}

class ShiftNotifier extends Notifier<ShiftSchedule?> {
  @override
  ShiftSchedule? build() {
    loadSchedule();
    return null;
  }

  Future<void> loadSchedule() async {
    final db = await DatabaseService.instance.database;
    final res = await db.query('shift_schedules', limit: 1);

    if (res.isNotEmpty) {
      final row = res.first;
      List<Map<String, dynamic>> cycle = [];
      try {
        final List d = jsonDecode(row['cycle_days'] as String);
        cycle = d.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}

      Map<String, dynamic> ovr = {};
      if (row['overrides'] != null) {
        try {
          ovr = Map<String, dynamic>.from(
            jsonDecode(row['overrides'] as String),
          );
        } catch (_) {}
      }

      state = ShiftSchedule(
        id: row['id'] as String,
        name: row['name'] as String,
        startDate: DateTime.parse(row['start_date'] as String),
        cycleDays: cycle,
        overrides: ovr,
      );
    } else {
      // Дефолтный график: 2 через 2 (2 дневных, 2 выходных)
      state = ShiftSchedule(
        id: 'default_shift',
        name: 'График 2/2',
        startDate: DateTime.now(),
        cycleDays: [
          {
            'name': 'Дневная',
            'type': 'work',
            'time': '08:00 - 20:00',
            'color': const Color(0xFF2C69D1).value,
          },
          {
            'name': 'Дневная',
            'type': 'work',
            'time': '08:00 - 20:00',
            'color': const Color(0xFF2C69D1).value,
          },
          {
            'name': 'Выходной',
            'type': 'rest',
            'time': null,
            'color': const Color(0xFF66BB6A).value,
          },
          {
            'name': 'Выходной',
            'type': 'rest',
            'time': null,
            'color': const Color(0xFF66BB6A).value,
          },
        ],
        overrides: {},
      );
      saveSchedule(state!);
    }
  }

  Future<void> saveSchedule(ShiftSchedule schedule) async {
    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();

    final row = {
      'id': schedule.id,
      'name': schedule.name,
      'start_date': schedule.startDate.toIso8601String(),
      'cycle_days': jsonEncode(schedule.cycleDays),
      'overrides': jsonEncode(schedule.overrides),
      'is_synced': 0,
      'updated_at': nowIso,
    };

    await db.insert(
      'shift_schedules',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    state = schedule;
    SyncService.instance.syncAll();
  }

  Future<void> setOverride(
    DateTime date,
    Map<String, dynamic>? overrideShift,
  ) async {
    if (state == null) return;
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final newOverrides = Map<String, dynamic>.from(state!.overrides);

    if (overrideShift == null) {
      newOverrides.remove(key);
    } else {
      newOverrides[key] = overrideShift;
    }

    final updated = ShiftSchedule(
      id: state!.id,
      name: state!.name,
      startDate: state!.startDate,
      cycleDays: state!.cycleDays,
      overrides: newOverrides,
    );

    await saveSchedule(updated);
  }
}

final shiftProvider = NotifierProvider<ShiftNotifier, ShiftSchedule?>(
  ShiftNotifier.new,
);
