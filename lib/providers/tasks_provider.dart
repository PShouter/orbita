import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import 'gamification_provider.dart';

typedef TaskMap = Map<String, dynamic>;

// --- ПРОВАЙДЕР КАТЕГОРИЙ ЗАДАЧ ---
class TaskCategoriesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    loadCategories();
    return ['Личное'];
  }

  Future<void> loadCategories() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('task_categories', orderBy: 'name ASC');
    if (rows.isNotEmpty) {
      state = rows.map((r) => r['name'] as String).toList();
    } else {
      state = ['Личное'];
    }
  }

  Future<void> addCategory(String name) async {
    final clean = name.trim();
    if (clean.isEmpty || state.contains(clean)) return;

    final db = await DatabaseService.instance.database;
    await db.insert('task_categories', {
      'id': const Uuid().v4(),
      'name': clean,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });

    state = [...state, clean];
  }
}

final taskCategoriesProvider =
    NotifierProvider<TaskCategoriesNotifier, List<String>>(
  TaskCategoriesNotifier.new,
);

// --- ПРОВАЙДЕР СПИСКА ЗАДАЧ ---
class TasksNotifier extends Notifier<List<TaskMap>> {
  static const _uuid = Uuid();

  @override
  List<TaskMap> build() {
    loadTasks();
    return [];
  }

  Future<void> loadTasks() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'tasks',
      orderBy: 'done ASC, date ASC, id ASC',
    );

    state = rows.map((r) {
      DateTime? d;
      if (r['date'] != null && (r['date'] as String).isNotEmpty) {
        d = DateTime.tryParse(r['date'] as String);
      }

      List<TaskMap> subtasksList = [];
      if (r['subtasks'] != null && (r['subtasks'] as String).isNotEmpty) {
        try {
          final decoded = jsonDecode(r['subtasks'] as String);
          if (decoded is List) {
            subtasksList = decoded
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();
          }
        } catch (_) {}
      }

      List<String> attachmentsList = [];
      if (r['attachments'] != null && (r['attachments'] as String).isNotEmpty) {
        try {
          final decoded = jsonDecode(r['attachments'] as String);
          if (decoded is List) {
            attachmentsList = List<String>.from(decoded);
          }
        } catch (_) {}
      }

      final isDone = (r['done'] as int? ?? 0) == 1;
      final status = r['status'] as String? ?? (isDone ? 'done' : 'todo');

      return <String, dynamic>{
        'id': r['id'] as String,
        'title': r['title'] as String,
        'description': r['description'] as String?,
        'date': d,
        'time': r['time'] as String?,
        'isNoDate': (r['is_no_date'] as int? ?? 0) == 1,
        'isAllDay': (r['is_all_day'] as int? ?? 0) == 1,
        'priority': r['priority'] as String? ?? 'normal',
        'status': status,
        'done': isDone,
        'category': r['category'] as String? ?? 'Личное',
        'color': r['color'] != null
            ? Color(r['color'] as int)
            : const Color(0xFF38BDF8),
        'reminderMinutes': r['reminder_minutes'] as int? ?? -1,
        'recurrence': r['recurrence'] as String? ?? 'none',
        'attachments': attachmentsList,
        'subtasks': subtasksList,
        'updated_at': r['updated_at'] as String,
      };
    }).toList();
  }

  Future<void> saveTask({
    String? id,
    required String title,
    String? description,
    DateTime? date,
    String? time,
    bool isNoDate = false,
    bool isAllDay = false,
    String priority = 'normal',
    String status = 'todo',
    String category = 'Личное',
    Color color = const Color(0xFF38BDF8),
    int reminderMinutes = -1,
    String recurrence = 'none',
    List<String> attachments = const [],
    List<TaskMap> subtasks = const [],
  }) async {
    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    final taskId = id ?? _uuid.v4();

    final bool hasSubtasks = subtasks.isNotEmpty;
    final bool allSubtasksDone =
        hasSubtasks && subtasks.every((s) => s['done'] == true);

    final finalStatus = allSubtasksDone ? 'done' : status;
    final isDone = finalStatus == 'done';

    final row = {
      'id': taskId,
      'title': title,
      'description': description,
      'date': date?.toIso8601String(),
      'time': time,
      'is_no_date': isNoDate ? 1 : 0,
      'is_all_day': isAllDay ? 1 : 0,
      'priority': priority,
      'status': finalStatus,
      'done': isDone ? 1 : 0,
      'category': category,
      'color': color.toARGB32(),
      'reminder_minutes': reminderMinutes,
      'recurrence': recurrence,
      'attachments': jsonEncode(attachments),
      'subtasks': jsonEncode(subtasks),
      'is_synced': 0,
      'updated_at': nowIso,
    };

    await db.insert('tasks', row, conflictAlgorithm: ConflictAlgorithm.replace);

    final notifId = taskId.hashCode;
    if (!isDone && !isNoDate && date != null && reminderMinutes >= 0) {
      try {
        final timeStr = time ?? (isAllDay ? '09:00' : '10:00');
        final parts = timeStr.split(':');
        final taskDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        final remindTime = taskDateTime.subtract(
          Duration(minutes: reminderMinutes),
        );

        if (remindTime.isAfter(DateTime.now())) {
          await NotificationService.instance.scheduleNotification(
            id: notifId,
            title: 'Задача: $title',
            body: reminderMinutes == 0
                ? 'Время выполнить задачу ($timeStr)'
                : 'Срок через $reminderMinutes мин. ($timeStr)',
            scheduledDate: remindTime,
            payload: 'screen_tasks',
          );
        }
      } catch (e) {
        debugPrint('Ошибка планирования уведомления задачи: $e');
      }
    } else {
      await NotificationService.instance.cancelNotification(notifId);
    }

    await loadTasks();
    SyncService.instance.syncAll();
  }

  Future<void> toggleTask(String id, bool done) async {
    final newStatus = done ? 'done' : 'todo';
    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();

    final current = state.firstWhere((t) => t['id'] == id, orElse: () => {});

    final prefs = await SharedPreferences.getInstance();
    final autoCompleteSubs =
        prefs.getBool('task_auto_complete_subtasks_with_parent') ?? true;

    final updateData = <String, dynamic>{
      'done': done ? 1 : 0,
      'status': newStatus,
      'is_synced': 0,
      'updated_at': nowIso,
    };

    if (done &&
        autoCompleteSubs &&
        current.isNotEmpty &&
        current['subtasks'] != null) {
      final subs = List<TaskMap>.from(
        (current['subtasks'] as List).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      for (final s in subs) {
        s['done'] = true;
      }
      updateData['subtasks'] = jsonEncode(subs);
    }

    await db.update('tasks', updateData, where: 'id = ?', whereArgs: [id]);

    final notifId = id.hashCode;
    if (done) {
      await NotificationService.instance.cancelNotification(notifId);
      final isHigh = (current['priority'] == 'high');
      ref
          .read(gamificationProvider.notifier)
          .addExp(ExpSource.task, isHigh ? 20 : 10);
    }

    await loadTasks();
    SyncService.instance.syncAll();
  }

  Future<void> toggleSubtask(String taskId, int subtaskIndex, bool done) async {
    final current = state.firstWhere((t) => t['id'] == taskId);
    final subs = List<TaskMap>.from(current['subtasks'] ?? []);

    if (subtaskIndex >= 0 && subtaskIndex < subs.length) {
      subs[subtaskIndex]['done'] = done;
    }

    final bool hasSubtasks = subs.isNotEmpty;
    final bool allDone = hasSubtasks && subs.every((s) => s['done'] == true);

    final bool newParentDone = allDone
        ? true
        : (subs.any((s) => s['done'] == false && current['done'] == true)
            ? false
            : (current['done'] as bool? ?? false));

    final String newParentStatus = newParentDone
        ? 'done'
        : (current['status'] == 'done'
            ? 'todo'
            : (current['status'] as String? ?? 'todo'));

    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'tasks',
      {
        'subtasks': jsonEncode(subs),
        'done': newParentDone ? 1 : 0,
        'status': newParentStatus,
        'is_synced': 0,
        'updated_at': nowIso,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );

    if (newParentDone) {
      await NotificationService.instance.cancelNotification(taskId.hashCode);
      ref.read(gamificationProvider.notifier).addExp(ExpSource.task, 10);
    }

    await loadTasks();
    SyncService.instance.syncAll();
  }

  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final items = List<TaskMap>.from(state);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    state = items;
  }

  Future<void> deleteTask(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    await db.insert('delete_queue', {
      'table_name': 'tasks',
      'record_id': id,
      'created_at': DateTime.now().toIso8601String(),
    });

    await NotificationService.instance.cancelNotification(id.hashCode);

    state = state.where((t) => t['id'] != id).toList();
    SyncService.instance.syncAll();
  }

  Future<void> deleteMultipleTasks(Iterable<String> ids) async {
    final targetIds = Set<String>.from(ids);
    if (targetIds.isEmpty) return;

    final db = await DatabaseService.instance.database;
    final batch = db.batch();
    final nowIso = DateTime.now().toIso8601String();

    for (final id in targetIds) {
      batch.delete('tasks', where: 'id = ?', whereArgs: [id]);
      batch.insert('delete_queue', {
        'table_name': 'tasks',
        'record_id': id,
        'created_at': nowIso,
      });
      await NotificationService.instance.cancelNotification(id.hashCode);
    }

    await batch.commit(noResult: true);
    await loadTasks();
    SyncService.instance.syncAll();
  }

  Future<void> updateStatusForMultiple(
    Iterable<String> ids,
    String status,
  ) async {
    final targetIds = Set<String>.from(ids);
    if (targetIds.isEmpty) return;

    final db = await DatabaseService.instance.database;
    final isDone = status == 'done';
    final nowIso = DateTime.now().toIso8601String();

    final batch = db.batch();
    for (final id in targetIds) {
      batch.update(
        'tasks',
        {
          'status': status,
          'done': isDone ? 1 : 0,
          'is_synced': 0,
          'updated_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (isDone) {
        await NotificationService.instance.cancelNotification(id.hashCode);
      }
    }
    await batch.commit(noResult: true);
    await loadTasks();
    SyncService.instance.syncAll();
  }

  Future<void> moveCategoryForMultiple(
    Iterable<String> ids,
    String newCategory,
  ) async {
    final targetIds = Set<String>.from(ids);
    if (targetIds.isEmpty) return;

    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();

    final batch = db.batch();
    for (final id in targetIds) {
      batch.update(
        'tasks',
        {
          'category': newCategory,
          'is_synced': 0,
          'updated_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
    await loadTasks();
    SyncService.instance.syncAll();
  }
}

final tasksProvider = NotifierProvider<TasksNotifier, List<TaskMap>>(
  TasksNotifier.new,
);
