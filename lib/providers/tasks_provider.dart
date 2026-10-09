import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';

class TasksNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    loadTasks();
    return [];
  }

  Future<void> loadTasks() async {
    final db = await DatabaseService.instance.database;
    final res = await db.query('tasks', orderBy: 'updated_at DESC');

    state = res.map((row) {
      final m = Map<String, dynamic>.from(row);
      m['done'] = m['done'] == 1;
      m['isNoDate'] = m['is_no_date'] == 1;
      m['isAllDay'] = m['is_all_day'] == 1;
      if (m['date'] != null) m['date'] = DateTime.parse(m['date']);
      if (m['subtasks'] != null) m['subtasks'] = jsonDecode(m['subtasks']);
      if (m['tags'] != null) m['tags'] = jsonDecode(m['tags']);
      return m;
    }).toList();
  }

  Future<void> toggleTask(String taskId, bool isDone) async {
    final db = await DatabaseService.instance.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'tasks',
      {'done': isDone ? 1 : 0, 'updated_at': now, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [taskId],
    );

    state = [
      for (final t in state)
        if (t['id'].toString() == taskId) {...t, 'done': isDone} else t,
    ];

    SyncService.instance.syncAll();
  }

  Future<void> saveTask({
    Map<String, dynamic>? existingTask,
    required String title,
    required String desc,
    DateTime? date,
    required bool isNoDate,
    required bool isAllDay,
    String? time,
    String? location,
    String? reminder,
    String? repeat,
    required String priority,
    required List subtasks,
    required List tags,
  }) async {
    final db = await DatabaseService.instance.database;
    final now = DateTime.now().toIso8601String();
    final id =
        existingTask?['id'] ?? 'task_${DateTime.now().millisecondsSinceEpoch}';

    final row = {
      'id': id.toString(),
      'title': title,
      'description': desc,
      'date': date?.toIso8601String(),
      'time': time,
      'is_no_date': isNoDate ? 1 : 0,
      'is_all_day': isAllDay ? 1 : 0,
      'priority': priority,
      'done': existingTask?['done'] == true ? 1 : 0,
      'subtasks': jsonEncode(subtasks),
      'tags': jsonEncode(tags),
      'is_synced': 0,
      'updated_at': now,
    };

    await db.insert('tasks', row, conflictAlgorithm: ConflictAlgorithm.replace);
    await loadTasks();
    SyncService.instance.syncAll();
  }

  Future<void> deleteTask(String taskId) async {
    final db = await DatabaseService.instance.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
    await db.insert('delete_queue', {
      'table_name': 'tasks',
      'record_id': taskId,
      'created_at': DateTime.now().toIso8601String(),
    });

    state = state.where((t) => t['id'].toString() != taskId).toList();
    SyncService.instance.syncAll();
  }
}

final tasksProvider =
    NotifierProvider<TasksNotifier, List<Map<String, dynamic>>>(
      TasksNotifier.new,
    );
