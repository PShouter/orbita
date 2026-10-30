import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import 'gamification_provider.dart';

// ----------------------------------------------------
// Модель привычки
// ----------------------------------------------------
class HabitItem {
  final String id;
  final String title;
  final String? question;
  final String? description;
  final Color color;
  final String type; // 'boolean' | 'numerical'
  final double targetValue;
  final String? unit;
  final String frequencyType;
  final List<int> frequencyDays;
  final int frequencyCount;
  final String? reminderTime;
  final Map<String, double> history; // "YYYY-MM-DD": value
  final int streak;
  final double score30Days;
  final int position;
  final bool isArchived;
  final String updatedAt;

  const HabitItem({
    required this.id,
    required this.title,
    this.question,
    this.description,
    required this.color,
    required this.type,
    required this.targetValue,
    this.unit,
    required this.frequencyType,
    required this.frequencyDays,
    required this.frequencyCount,
    this.reminderTime,
    required this.history,
    this.streak = 0,
    this.score30Days = 0.0,
    this.position = 0,
    this.isArchived = false,
    required this.updatedAt,
  });

  bool isCompletedOn(String dateStr) {
    final val = history[dateStr] ?? 0.0;
    if (type == 'numerical') {
      return val >= targetValue;
    }
    return val > 0.0;
  }

  double valueOn(String dateStr) {
    return history[dateStr] ?? 0.0;
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
    Map<String, double>? history,
    int? streak,
    double? score30Days,
    int? position,
    bool? isArchived,
    String? updatedAt,
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
      history: history ?? this.history,
      streak: streak ?? this.streak,
      score30Days: score30Days ?? this.score30Days,
      position: position ?? this.position,
      isArchived: isArchived ?? this.isArchived,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ----------------------------------------------------
// Провайдер привычек
// ----------------------------------------------------
class HabitsNotifier extends Notifier<List<HabitItem>> {
  static const _uuid = Uuid();

  @override
  List<HabitItem> build() {
    loadHabits();
    return [];
  }

  Future<void> loadHabits() async {
    final db = await DatabaseService.instance.database;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS habits (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        question TEXT,
        description TEXT,
        color INTEGER,
        type TEXT DEFAULT 'boolean',
        target_value REAL DEFAULT 1.0,
        unit TEXT,
        frequency_type TEXT DEFAULT 'daily',
        frequency_days TEXT,
        frequency_count INTEGER DEFAULT 1,
        reminder_time TEXT,
        history TEXT,
        position INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    final rows = await db.query('habits', orderBy: 'position ASC');

    state = rows.map((r) {
      Map<String, double> hist = {};
      if (r['history'] != null && (r['history'] as String).isNotEmpty) {
        try {
          final decoded =
              jsonDecode(r['history'] as String) as Map<String, dynamic>;
          hist = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
        } catch (_) {}
      }

      List<int> fDays = [];
      if (r['frequency_days'] != null &&
          (r['frequency_days'] as String).isNotEmpty) {
        try {
          fDays = (jsonDecode(r['frequency_days'] as String) as List)
              .cast<int>();
        } catch (_) {}
      }

      final colorInt = r['color'] as int?;
      final color = colorInt != null
          ? Color(colorInt)
          : const Color(0xFF38BDF8);

      final habit = HabitItem(
        id: r['id'] as String,
        title: r['title'] as String,
        question: r['question'] as String?,
        description: r['description'] as String?,
        color: color,
        type: r['type'] as String? ?? 'boolean',
        targetValue: (r['target_value'] as num?)?.toDouble() ?? 1.0,
        unit: r['unit'] as String?,
        frequencyType: r['frequency_type'] as String? ?? 'daily',
        frequencyDays: fDays,
        frequencyCount: r['frequency_count'] as int? ?? 1,
        reminderTime: r['reminder_time'] as String?,
        history: hist,
        position: r['position'] as int? ?? 0,
        isArchived: (r['is_archived'] as int? ?? 0) == 1,
        updatedAt: r['updated_at'] as String,
      );

      return habit.copyWith(
        streak: _calcStreak(habit),
        score30Days: _calcScore30(habit),
      );
    }).toList();
  }

  int _calcStreak(HabitItem habit) {
    int s = 0;
    final now = DateTime.now();
    DateTime cur = now;

    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    if (!habit.isCompletedOn(todayStr)) {
      cur = now.subtract(const Duration(days: 1));
    }

    while (true) {
      final dStr =
          "${cur.year}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}";
      if (habit.isCompletedOn(dStr)) {
        s++;
        cur = cur.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return s;
  }

  double _calcScore30(HabitItem habit) {
    final now = DateTime.now();
    int completedDays = 0;
    for (int i = 0; i < 30; i++) {
      final d = now.subtract(Duration(days: i));
      final dStr =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      if (habit.isCompletedOn(dStr)) completedDays++;
    }
    return (completedDays / 30.0).clamp(0.0, 1.0);
  }

  Future<void> saveHabit({
    String? id,
    required String title,
    String? question,
    String? description,
    required Color color,
    required String type,
    required double targetValue,
    String? unit,
    required String frequencyType,
    required List<int> frequencyDays,
    required int frequencyCount,
    String? reminderTime,
  }) async {
    final db = await DatabaseService.instance.database;
    final hId = id ?? _uuid.v4();
    final nowIso = DateTime.now().toIso8601String();

    HabitItem? existing = state.where((h) => h.id == hId).firstOrNull;
    final historyMap = existing?.history ?? {};
    final pos = existing?.position ?? state.length;
    final isArch = existing?.isArchived ?? false;

    final row = {
      'id': hId,
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
      'history': jsonEncode(historyMap),
      'position': pos,
      'is_archived': isArch ? 1 : 0,
      'is_synced': 0,
      'updated_at': nowIso,
    };

    await db.insert(
      'habits',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (reminderTime != null && reminderTime.contains(':')) {
      try {
        final parts = reminderTime.split(':');
        final now = DateTime.now();
        var remindDate = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        if (remindDate.isBefore(now)) {
          remindDate = remindDate.add(const Duration(days: 1));
        }

        await NotificationService.instance.scheduleNotification(
          id: hId.hashCode,
          title: 'Привычка: $title',
          body: question ?? 'Пора выполнить привычку!',
          scheduledDate: remindDate,
          payload: 'screen_habits',
        );
      } catch (e) {
        debugPrint('Ошибка напоминания привычки: $e');
      }
    } else {
      await NotificationService.instance.cancelNotification(hId.hashCode);
    }

    await loadHabits();
    SyncService.instance.syncAll();
  }

  Future<void> toggleHabitDay(String habitId, String dateStr) async {
    final idx = state.indexWhere((h) => h.id == habitId);
    if (idx == -1) return;

    final habit = state[idx];
    final isDone = habit.isCompletedOn(dateStr);

    final double newVal = isDone
        ? 0.0
        : (habit.type == 'numerical' ? habit.targetValue : 1.0);

    await setNumericalValue(habitId, dateStr, newVal);

    if (!isDone) {
      ref.read(gamificationProvider.notifier).addExp(ExpSource.habit, 10);
    }
    await loadHabits();
  }

  Future<void> toggleHabit(String habitId) async {
    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    await toggleHabitDay(habitId, todayStr);
  }

  Future<void> setNumericalValue(
    String habitId,
    String dateStr,
    double value,
  ) async {
    final idx = state.indexWhere((h) => h.id == habitId);
    if (idx == -1) return;

    final habit = state[idx];
    final newHistory = Map<String, double>.from(habit.history);

    if (value <= 0.0) {
      newHistory.remove(dateStr);
    } else {
      newHistory[dateStr] = value;
    }

    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'habits',
      {'history': jsonEncode(newHistory), 'is_synced': 0, 'updated_at': nowIso},
      where: 'id = ?',
      whereArgs: [habitId],
    );

    final updated = habit.copyWith(history: newHistory, updatedAt: nowIso);

    final withStats = updated.copyWith(
      streak: _calcStreak(updated),
      score30Days: _calcScore30(updated),
    );

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == idx) withStats else state[i],
    ];

    SyncService.instance.syncAll();
  }

  Future<void> archiveHabit(String id) async {
    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'habits',
      {'is_archived': 1, 'is_synced': 0, 'updated_at': nowIso},
      where: 'id = ?',
      whereArgs: [id],
    );

    await NotificationService.instance.cancelNotification(id.hashCode);
    await loadHabits();
    SyncService.instance.syncAll();
  }

  Future<void> unarchiveHabit(String id) async {
    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'habits',
      {'is_archived': 0, 'is_synced': 0, 'updated_at': nowIso},
      where: 'id = ?',
      whereArgs: [id],
    );

    await loadHabits();
    SyncService.instance.syncAll();
  }

  Future<void> deleteHabit(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('habits', where: 'id = ?', whereArgs: [id]);
    await db.insert('delete_queue', {
      'table_name': 'habits',
      'record_id': id,
      'created_at': DateTime.now().toIso8601String(),
    });

    await NotificationService.instance.cancelNotification(id.hashCode);
    state = state.where((h) => h.id != id).toList();
    SyncService.instance.syncAll();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final active = state.where((h) => !h.isArchived).toList();
    if (newIndex > oldIndex) newIndex -= 1;
    final item = active.removeAt(oldIndex);
    active.insert(newIndex, item);

    final db = await DatabaseService.instance.database;
    final batch = db.batch();
    final nowIso = DateTime.now().toIso8601String();

    for (int i = 0; i < active.length; i++) {
      batch.update(
        'habits',
        {'position': i, 'updated_at': nowIso},
        where: 'id = ?',
        whereArgs: [active[i].id],
      );
    }
    await batch.commit(noResult: true);
    await loadHabits();
  }
}

final habitsProvider = NotifierProvider<HabitsNotifier, List<HabitItem>>(
  HabitsNotifier.new,
);

final archivedHabitsProvider = Provider<List<HabitItem>>((ref) {
  final all = ref.watch(habitsProvider);
  return all.where((h) => h.isArchived).toList();
});

// ----------------------------------------------------
// Сортировка привычек
// ----------------------------------------------------
enum HabitSortType { manual, name, color, score, status }

class HabitSortNotifier extends Notifier<HabitSortType> {
  @override
  HabitSortType build() => HabitSortType.manual;

  void setSort(HabitSortType type) {
    state = type;
  }
}

final habitSortProvider = NotifierProvider<HabitSortNotifier, HabitSortType>(
  HabitSortNotifier.new,
);

final sortedHabitsProvider = Provider<List<HabitItem>>((ref) {
  final all = ref.watch(habitsProvider);
  final active = all.where((h) => !h.isArchived).toList();
  final sortType = ref.watch(habitSortProvider);

  final now = DateTime.now();
  final todayStr =
      "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

  switch (sortType) {
    case HabitSortType.manual:
      return active;
    case HabitSortType.name:
      active.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      return active;
    case HabitSortType.color:
      active.sort((a, b) => a.color.toARGB32().compareTo(b.color.toARGB32()));
      return active;
    case HabitSortType.score:
      active.sort((a, b) => b.score30Days.compareTo(a.score30Days));
      return active;
    case HabitSortType.status:
      active.sort((a, b) {
        final aDone = a.isCompletedOn(todayStr);
        final bDone = b.isCompletedOn(todayStr);
        if (aDone == bDone) return a.position.compareTo(b.position);
        return aDone ? 1 : -1;
      });
      return active;
  }
});

// ----------------------------------------------------
// Настройки интерфейса привычек
// ----------------------------------------------------
class HabitShortTapNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true; // По умолчанию включено: одиночный тап сразу отмечает день
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

class HabitReverseDaysNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true; // По умолчанию включено: дни идут на уменьшение слева направо (25, 24, 23...)
  }

  Future<void> _load() async {
    final db = await DatabaseService.instance.database;
    final res = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['habit_reverse_days'],
    );
    if (res.isNotEmpty) {
      state = (res.first['value'] as String) == 'true';
    }
  }

  Future<void> toggle(bool val) async {
    state = val;
    final db = await DatabaseService.instance.database;
    await db.insert('app_settings', {
      'key': 'habit_reverse_days',
      'value': val.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

final habitReverseDaysProvider =
    NotifierProvider<HabitReverseDaysNotifier, bool>(
      HabitReverseDaysNotifier.new,
    );
