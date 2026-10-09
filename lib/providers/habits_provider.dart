import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';

class HabitsNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    loadHabits();
    return [];
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> loadHabits() async {
    final db = await DatabaseService.instance.database;
    final res = await db.query('habits', orderBy: 'updated_at DESC');
    final today = _todayKey();

    state = res.map((row) {
      final m = Map<String, dynamic>.from(row);
      if (m['color'] != null) m['color'] = Color(m['color'] as int);

      Map<String, dynamic> history = {};
      if (m['history'] != null) {
        try {
          history = Map<String, dynamic>.from(jsonDecode(m['history']));
        } catch (_) {}
      }
      m['history'] = history;

      // Вычисляем статус выполнения на сегодня
      final todayVal = history[today];
      if (m['type'] == 'measurable') {
        final current = (todayVal is num) ? todayVal.toDouble() : 0.0;
        final target = (m['target_value'] is num)
            ? (m['target_value'] as num).toDouble()
            : 1.0;
        m['done'] = current >= target;
        m['current_value'] = current;
      } else {
        m['done'] = todayVal == true || todayVal == 1;
      }

      return m;
    }).toList();
  }

  Future<void> toggleHabit(String habitId) async {
    final db = await DatabaseService.instance.database;
    final today = _todayKey();
    final nowIso = DateTime.now().toIso8601String();

    state = [
      for (final h in state)
        if (h['id'].toString() == habitId) _applyToggle(h, today) else h,
    ];

    final updated = state.firstWhere((h) => h['id'].toString() == habitId);

    await db.update(
      'habits',
      {
        'history': jsonEncode(updated['history']),
        'streak': updated['streak'] ?? 0,
        'updated_at': nowIso,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [habitId],
    );

    SyncService.instance.syncAll();
  }

  Map<String, dynamic> _applyToggle(Map<String, dynamic> habit, String today) {
    final m = Map<String, dynamic>.from(habit);
    final history = Map<String, dynamic>.from(m['history'] ?? {});
    final isDone = m['done'] == true;

    if (m['type'] == 'measurable') {
      final target = (m['target_value'] is num)
          ? (m['target_value'] as num).toDouble()
          : 1.0;
      if (isDone) {
        history[today] = 0.0;
        m['done'] = false;
        m['current_value'] = 0.0;
      } else {
        history[today] = target;
        m['done'] = true;
        m['current_value'] = target;
      }
    } else {
      if (isDone) {
        history.remove(today);
        m['done'] = false;
      } else {
        history[today] = true;
        m['done'] = true;
      }
    }

    m['history'] = history;
    m['streak'] = _calculateStreak(history);
    return m;
  }

  int _calculateStreak(Map<String, dynamic> history) {
    int streak = 0;
    DateTime checkDate = DateTime.now();

    // Если сегодня еще не отмечено, проверяем со вчера
    final todayKey =
        '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
    if (history[todayKey] == null ||
        history[todayKey] == false ||
        history[todayKey] == 0) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while (true) {
      final key =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      final val = history[key];
      if (val != null && val != false && val != 0) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  Future<void> saveHabit({
    String? existingId,
    required String title,
    required String type,
    double targetValue = 1.0,
    String? unit,
    required Color color,
    String? reminderTime,
  }) async {
    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    final id = existingId ?? 'habit_${DateTime.now().millisecondsSinceEpoch}';

    final row = {
      'id': id,
      'title': title,
      'type': type,
      'target_value': targetValue,
      'unit': unit,
      'color': color.toARGB32(),
      'reminder_time': reminderTime,
      'history': jsonEncode({}),
      'streak': 0,
      'is_synced': 0,
      'updated_at': nowIso,
    };

    await db.insert(
      'habits',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await loadHabits();
    SyncService.instance.syncAll();
  }

  Future<void> deleteHabit(String habitId) async {
    final db = await DatabaseService.instance.database;
    await db.delete('habits', where: 'id = ?', whereArgs: [habitId]);
    await db.insert('delete_queue', {
      'table_name': 'habits',
      'record_id': habitId,
      'created_at': DateTime.now().toIso8601String(),
    });

    state = state.where((h) => h['id'].toString() != habitId).toList();
    SyncService.instance.syncAll();
  }
}

final habitsProvider =
    NotifierProvider<HabitsNotifier, List<Map<String, dynamic>>>(
      HabitsNotifier.new,
    );
