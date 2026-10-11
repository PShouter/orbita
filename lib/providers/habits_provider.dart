import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';

enum HabitSortType { manual, name, color, score, status }

// Модель лога выполнения привычки за дату
class HabitLog {
  final String id;
  final String habitId;
  final String date; // YYYY-MM-DD
  final double value;
  final bool completed;

  HabitLog({
    required this.id,
    required this.habitId,
    required this.date,
    required this.value,
    required this.completed,
  });

  factory HabitLog.fromMap(Map<String, dynamic> map) {
    return HabitLog(
      id: map['id'] as String,
      habitId: map['habitId'] ?? map['habit_id'] as String,
      date: map['date'] as String,
      value: (map['value'] as num?)?.toDouble() ?? 1.0,
      completed: (map['completed'] as int? ?? 1) == 1,
    );
  }
}

// Модель привычки
class HabitItem {
  final String id;
  final String title;
  final String? question;
  final String? description;
  final Color color;
  final String type; // 'boolean' | 'numerical'
  final double targetValue;
  final String? unit;
  final String frequencyType; // 'daily' | 'x_per_week' | 'specific_days'
  final List<int> frequencyDays;
  final int frequencyCount;
  final String? reminderTime;
  final int position;
  final int streak;
  final bool isArchived;
  final Map<String, HabitLog> logs; // date -> HabitLog

  HabitItem({
    required this.id,
    required this.title,
    this.question,
    this.description,
    required this.color,
    this.type = 'boolean',
    this.targetValue = 1.0,
    this.unit,
    this.frequencyType = 'daily',
    this.frequencyDays = const [],
    this.frequencyCount = 1,
    this.reminderTime,
    this.position = 0,
    this.streak = 0,
    this.isArchived = false,
    this.logs = const {},
  });

  /// Выполнена ли привычка в указанную дату (YYYY-MM-DD)
  bool isCompletedOn(String dateStr) {
    final log = logs[dateStr];
    return log != null && log.completed;
  }

  /// Получить значение за дату для числовой привычки
  double valueOn(String dateStr) {
    final log = logs[dateStr];
    return log?.value ?? 0.0;
  }

  /// Вычисление процента выполнения за последние 30 дней
  double get score30Days {
    final now = DateTime.now();
    int completedCount = 0;
    for (int i = 0; i < 30; i++) {
      final day = now.subtract(Duration(days: i));
      final dateStr =
          "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
      if (isCompletedOn(dateStr)) {
        completedCount++;
      }
    }
    return completedCount / 30.0;
  }

  HabitItem copyWith({
    String? id,
    String? title,
    String? question,
    String? description,
    Color? color,
    String? type,
    double? targetValue,
    String? unit,
    String? frequencyType,
    List<int>? frequencyDays,
    int? frequencyCount,
    String? reminderTime,
    int? position,
    int? streak,
    bool? isArchived,
    Map<String, HabitLog>? logs,
  }) {
    return HabitItem(
      id: id ?? this.id,
      title: title ?? this.title,
      question: question ?? this.question,
      description: description ?? this.description,
      color: color ?? this.color,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      frequencyType: frequencyType ?? this.frequencyType,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      frequencyCount: frequencyCount ?? this.frequencyCount,
      reminderTime: reminderTime ?? this.reminderTime,
      position: position ?? this.position,
      streak: streak ?? this.streak,
      isArchived: isArchived ?? this.isArchived,
      logs: logs ?? this.logs,
    );
  }
}

// --- ПРОВАЙДЕР НАСТРОЙКИ "ОТМЕЧАТЬ КОРОТКИМ НАЖАТИЕМ" ---
class HabitShortTapNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false; // По умолчанию долгое нажатие (как в Loop)
  }

  Future<void> _load() async {
    final db = await DatabaseService.instance.database;
    final res = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['habit_short_tap'],
    );
    if (res.isNotEmpty) {
      state = (res.first['value'] as String) == 'true';
    }
  }

  Future<void> toggle(bool val) async {
    state = val;
    final db = await DatabaseService.instance.database;
    await db.insert('app_settings', {
      'key': 'habit_short_tap',
      'value': val.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

final habitShortTapProvider = NotifierProvider<HabitShortTapNotifier, bool>(
  HabitShortTapNotifier.new,
);

// --- ПРОВАЙДЕР СОРТИРОВКИ ---
class HabitSortNotifier extends Notifier<HabitSortType> {
  @override
  HabitSortType build() {
    _load();
    return HabitSortType.manual;
  }

  Future<void> _load() async {
    final db = await DatabaseService.instance.database;
    final res = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['habit_sort_type'],
    );
    if (res.isNotEmpty) {
      final name = res.first['value'] as String;
      state = HabitSortType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => HabitSortType.manual,
      );
    }
  }

  Future<void> setSort(HabitSortType type) async {
    state = type;
    final db = await DatabaseService.instance.database;
    await db.insert('app_settings', {
      'key': 'habit_sort_type',
      'value': type.name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

final habitSortProvider = NotifierProvider<HabitSortNotifier, HabitSortType>(
  HabitSortNotifier.new,
);

// --- ОСНОВНОЙ ПРОВАЙДЕР ПРИВЫЧЕК ---
class HabitsNotifier extends Notifier<List<HabitItem>> {
  @override
  List<HabitItem> build() {
    loadHabits();
    return [];
  }

  Future<void> loadHabits() async {
    final db = await DatabaseService.instance.database;
    final habitRows = await db.query(
      'habits',
      where: 'is_archived = 0',
      orderBy: 'position ASC, created_at DESC',
    );

    // Загружаем логи за последние 90 дней
    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
    final cutoffStr =
        "${cutoffDate.year}-${cutoffDate.month.toString().padLeft(2, '0')}-${cutoffDate.day.toString().padLeft(2, '0')}";

    final logRows = await db.query(
      'habit_logs',
      where: 'date >= ?',
      whereArgs: [cutoffStr],
    );

    final Map<String, Map<String, HabitLog>> logsByHabit = {};
    for (final row in logRows) {
      final log = HabitLog.fromMap(row);
      logsByHabit.putIfAbsent(log.habitId, () => {})[log.date] = log;
    }

    final items = habitRows.map((r) {
      List<int> freqDays = [];
      if (r['frequency_days'] != null &&
          (r['frequency_days'] as String).isNotEmpty) {
        try {
          freqDays = List<int>.from(jsonDecode(r['frequency_days'] as String));
        } catch (_) {}
      }

      final hid = r['id'] as String;
      return HabitItem(
        id: hid,
        title: r['title'] as String,
        question: r['question'] as String?,
        description: r['description'] as String?,
        color: Color(r['color'] as int),
        type: r['type'] as String? ?? 'boolean',
        targetValue: (r['target_value'] as num?)?.toDouble() ?? 1.0,
        unit: r['unit'] as String?,
        frequencyType: r['frequency_type'] as String? ?? 'daily',
        frequencyDays: freqDays,
        frequencyCount: r['frequency_count'] as int? ?? 1,
        reminderTime: r['reminder_time'] as String?,
        position: r['position'] as int? ?? 0,
        streak: r['streak'] as int? ?? 0,
        isArchived: (r['is_archived'] as int? ?? 0) == 1,
        logs: logsByHabit[hid] ?? {},
      );
    }).toList();

    state = items;
  }

  /// Создание или обновление привычки
  Future<void> saveHabit({
    String? id,
    required String title,
    String? question,
    String? description,
    required Color color,
    String type = 'boolean',
    double targetValue = 1.0,
    String? unit,
    String frequencyType = 'daily',
    List<int> frequencyDays = const [],
    int frequencyCount = 1,
    String? reminderTime,
  }) async {
    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    final habitId = id ?? 'habit_${DateTime.now().millisecondsSinceEpoch}';

    int position = 0;
    if (id == null) {
      final maxPos = Sqflite.firstIntValue(
        await db.rawQuery('SELECT MAX(position) FROM habits'),
      );
      position = (maxPos ?? -1) + 1;
    } else {
      final cur = state.where((h) => h.id == id).firstOrNull;
      position = cur?.position ?? 0;
    }

    final row = {
      'id': habitId,
      'title': title,
      'question': question,
      'description': description,
      'color': color.toARGB32(),
      'type': type,
      'target_value': targetValue,
      'unit': unit,
      'frequency_type': frequencyType,
      'frequency_days': jsonEncode(frequencyDays),
      'frequency_count': frequencyCount,
      'reminder_time': reminderTime,
      'position': position,
      'is_archived': 0,
      'is_synced': 0,
      'created_at': nowIso,
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

  /// Быстрое переключение выполнения для привычки 'boolean'
  Future<void> toggleHabitDay(String habitId, String dateStr) async {
    final db = await DatabaseService.instance.database;
    final habit = state.firstWhere((h) => h.id == habitId);
    final isAlreadyDone = habit.isCompletedOn(dateStr);
    final newCompleted = !isAlreadyDone;

    final nowIso = DateTime.now().toIso8601String();
    final logId = 'log_${habitId}_$dateStr';

    if (newCompleted) {
      await db.insert('habit_logs', {
        'id': logId,
        'habit_id': habitId,
        'date': dateStr,
        'value': 1.0,
        'completed': 1,
        'is_synced': 0,
        'updated_at': nowIso,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.delete(
        'habit_logs',
        where: 'habit_id = ? AND date = ?',
        whereArgs: [habitId, dateStr],
      );
    }

    // Локальное мгновенное обновление стейта
    final updatedLogs = Map<String, HabitLog>.from(habit.logs);
    if (newCompleted) {
      updatedLogs[dateStr] = HabitLog(
        id: logId,
        habitId: habitId,
        date: dateStr,
        value: 1.0,
        completed: true,
      );
    } else {
      updatedLogs.remove(dateStr);
    }

    state = state
        .map((h) => h.id == habitId ? h.copyWith(logs: updatedLogs) : h)
        .toList();

    SyncService.instance.syncAll();
  }

  /// Переключение отметки за сегодняшний день (для главного экрана)
  Future<void> toggleHabitToday(String habitId) async {
    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    await toggleHabitDay(habitId, todayStr);
  }

  /// Алиас для toggleHabitToday (чтобы работало при вызове toggleHabit)
  Future<void> toggleHabit(String habitId) async {
    await toggleHabitToday(habitId);
  }

  /// Запись значения для измеримой привычки
  Future<void> setNumericalValue(
    String habitId,
    String dateStr,
    double val,
  ) async {
    final db = await DatabaseService.instance.database;
    final habit = state.firstWhere((h) => h.id == habitId);
    final nowIso = DateTime.now().toIso8601String();
    final logId = 'log_${habitId}_$dateStr';
    final completed = val >= habit.targetValue;

    if (val > 0) {
      await db.insert('habit_logs', {
        'id': logId,
        'habit_id': habitId,
        'date': dateStr,
        'value': val,
        'completed': completed ? 1 : 0,
        'is_synced': 0,
        'updated_at': nowIso,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.delete(
        'habit_logs',
        where: 'habit_id = ? AND date = ?',
        whereArgs: [habitId, dateStr],
      );
    }

    final updatedLogs = Map<String, HabitLog>.from(habit.logs);
    if (val > 0) {
      updatedLogs[dateStr] = HabitLog(
        id: logId,
        habitId: habitId,
        date: dateStr,
        value: val,
        completed: completed,
      );
    } else {
      updatedLogs.remove(dateStr);
    }

    state = state
        .map((h) => h.id == habitId ? h.copyWith(logs: updatedLogs) : h)
        .toList();

    SyncService.instance.syncAll();
  }

  /// Изменение порядка вручную (Drag & Drop)
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final items = List<HabitItem>.from(state);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    state = items;

    final db = await DatabaseService.instance.database;
    final batch = db.batch();
    for (int i = 0; i < items.length; i++) {
      batch.update(
        'habits',
        {'position': i},
        where: 'id = ?',
        whereArgs: [items[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Удаление привычки
  Future<void> deleteHabit(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('habits', where: 'id = ?', whereArgs: [id]);
    await db.delete('habit_logs', where: 'habit_id = ?', whereArgs: [id]);
    await db.insert('delete_queue', {
      'table_name': 'habits',
      'record_id': id,
      'created_at': DateTime.now().toIso8601String(),
    });

    state = state.where((h) => h.id != id).toList();
    SyncService.instance.syncAll();
  }
}

final habitsProvider = NotifierProvider<HabitsNotifier, List<HabitItem>>(
  HabitsNotifier.new,
);

/// Селектор отсортированного списка привычек
final sortedHabitsProvider = Provider<List<HabitItem>>((ref) {
  final habits = ref.watch(habitsProvider);
  final sortType = ref.watch(habitSortProvider);

  final today = DateTime.now();
  final todayStr =
      "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

  final list = List<HabitItem>.from(habits);

  switch (sortType) {
    case HabitSortType.manual:
      list.sort((a, b) => a.position.compareTo(b.position));
      break;
    case HabitSortType.name:
      list.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      break;
    case HabitSortType.color:
      list.sort((a, b) => a.color.toARGB32().compareTo(b.color.toARGB32()));
      break;
    case HabitSortType.score:
      list.sort((a, b) => b.score30Days.compareTo(a.score30Days));
      break;
    case HabitSortType.status:
      list.sort((a, b) {
        final aDone = a.isCompletedOn(todayStr) ? 1 : 0;
        final bDone = b.isCompletedOn(todayStr) ? 1 : 0;
        return aDone.compareTo(bDone); // Сначала невыполненные
      });
      break;
  }
  return list;
});
