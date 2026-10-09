import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_service.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isSyncing = false;

  SyncService._init();

  void initListener() {
    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        syncAll();
      }
    });
  }

  Future<void> syncAll() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _isSyncing) return;

    _isSyncing = true;
    try {
      await _pushChanges(user.id);
      await pullAll();
    } catch (e) {
      debugPrint('Ошибка синхронизации: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pushChanges(String userId) async {
    final db = await DatabaseService.instance.database;

    final deleteQueue = await db.query('delete_queue');
    for (final item in deleteQueue) {
      final table = item['table_name'] as String;
      final recordId = item['record_id'] as String;
      try {
        await _supabase.from(table).delete().eq('id', recordId);
        await db.delete(
          'delete_queue',
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      } catch (e) {
        debugPrint('Ошибка удаления из облака $table: $e');
      }
    }

    // Задачи
    final unsyncedTasks = await db.query(
      'tasks',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    if (unsyncedTasks.isNotEmpty) {
      final payload = unsyncedTasks.map((t) {
        final m = Map<String, dynamic>.from(t);
        m.remove('is_synced');
        m['user_id'] = userId;
        m['done'] = (m['done'] == 1);
        m['is_no_date'] = (m['is_no_date'] == 1);
        m['is_all_day'] = (m['is_all_day'] == 1);
        if (m['subtasks'] != null && m['subtasks'] is String) {
          try {
            m['subtasks'] = jsonDecode(m['subtasks']);
          } catch (_) {}
        }
        if (m['tags'] != null && m['tags'] is String) {
          try {
            m['tags'] = jsonDecode(m['tags']);
          } catch (_) {}
        }
        return m;
      }).toList();
      await _supabase.from('tasks').upsert(payload);
      await db.update('tasks', {'is_synced': 1}, where: 'is_synced = 0');
    }

    // Календарь
    final unsyncedEvents = await db.query(
      'calendar_events',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    if (unsyncedEvents.isNotEmpty) {
      final payload = unsyncedEvents.map((e) {
        final m = Map<String, dynamic>.from(e);
        m.remove('is_synced');
        m['user_id'] = userId;
        m['is_all_day'] = (m['is_all_day'] == 1);
        return m;
      }).toList();
      await _supabase.from('calendar_events').upsert(payload);
      await db.update('calendar_events', {
        'is_synced': 1,
      }, where: 'is_synced = 0');
    }

    // Привычки
    final unsyncedHabits = await db.query(
      'habits',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    if (unsyncedHabits.isNotEmpty) {
      final payload = unsyncedHabits.map((h) {
        final m = Map<String, dynamic>.from(h);
        m.remove('is_synced');
        m['user_id'] = userId;
        if (m['history'] != null && m['history'] is String) {
          try {
            m['history'] = jsonDecode(m['history']);
          } catch (_) {}
        }
        return m;
      }).toList();
      await _supabase.from('habits').upsert(payload);
      await db.update('habits', {'is_synced': 1}, where: 'is_synced = 0');
    }

    // Заметки
    final unsyncedNotes = await db.query(
      'notes',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    if (unsyncedNotes.isNotEmpty) {
      final payload = unsyncedNotes.map((n) {
        final m = Map<String, dynamic>.from(n);
        m.remove('is_synced');
        m['user_id'] = userId;
        m['is_pinned'] = (m['is_pinned'] == 1);
        return m;
      }).toList();
      await _supabase.from('notes').upsert(payload);
      await db.update('notes', {'is_synced': 1}, where: 'is_synced = 0');
    }

    // Бюджет
    final unsyncedBudget = await db.query(
      'budget_transactions',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    if (unsyncedBudget.isNotEmpty) {
      final payload = unsyncedBudget.map((b) {
        final m = Map<String, dynamic>.from(b);
        m.remove('is_synced');
        m['user_id'] = userId;
        return m;
      }).toList();
      await _supabase.from('budget_transactions').upsert(payload);
      await db.update('budget_transactions', {
        'is_synced': 1,
      }, where: 'is_synced = 0');
    }

    // Дневник
    final unsyncedDiary = await db.query(
      'diary_entries',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    if (unsyncedDiary.isNotEmpty) {
      final payload = unsyncedDiary.map((d) {
        final m = Map<String, dynamic>.from(d);
        m.remove('is_synced');
        m['user_id'] = userId;
        if (d['tags'] != null && d['tags'] is String) {
          try {
            m['tags'] = jsonDecode(m['tags']);
          } catch (_) {}
        }
        return m;
      }).toList();
      await _supabase.from('diary_entries').upsert(payload);
      await db.update('diary_entries', {
        'is_synced': 1,
      }, where: 'is_synced = 0');
    }

    // График смен
    final unsyncedShifts = await db.query(
      'shift_schedules',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    if (unsyncedShifts.isNotEmpty) {
      final payload = unsyncedShifts.map((s) {
        final m = Map<String, dynamic>.from(s);
        m.remove('is_synced');
        m['user_id'] = userId;
        if (m['cycle_days'] != null && m['cycle_days'] is String) {
          try {
            m['cycle_days'] = jsonDecode(m['cycle_days']);
          } catch (_) {}
        }
        if (m['overrides'] != null && m['overrides'] is String) {
          try {
            m['overrides'] = jsonDecode(m['overrides']);
          } catch (_) {}
        }
        return m;
      }).toList();
      await _supabase.from('shift_schedules').upsert(payload);
      await db.update('shift_schedules', {
        'is_synced': 1,
      }, where: 'is_synced = 0');
    }
  }

  Future<void> pullAll() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final db = await DatabaseService.instance.database;

    try {
      // 1. Tasks
      final remoteTasks = await _supabase
          .from('tasks')
          .select()
          .eq('user_id', user.id);
      for (final t in remoteTasks) {
        final local = await db.query(
          'tasks',
          where: 'id = ?',
          whereArgs: [t['id']],
        );
        if (local.isEmpty || local.first['is_synced'] == 1) {
          await db.insert('tasks', {
            'id': t['id'].toString(),
            'user_id': user.id,
            'title': t['title'] ?? '',
            'description': t['description'],
            'date': t['date'],
            'time': t['time'],
            'is_no_date': t['is_no_date'] == true ? 1 : 0,
            'is_all_day': t['is_all_day'] == true ? 1 : 0,
            'priority': t['priority'] ?? 'none',
            'done': t['done'] == true ? 1 : 0,
            'subtasks': t['subtasks'] != null
                ? jsonEncode(t['subtasks'])
                : null,
            'tags': t['tags'] != null ? jsonEncode(t['tags']) : null,
            'is_synced': 1,
            'updated_at': t['updated_at'] ?? DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 2. Calendar
      final remoteEvents = await _supabase
          .from('calendar_events')
          .select()
          .eq('user_id', user.id);
      for (final e in remoteEvents) {
        final local = await db.query(
          'calendar_events',
          where: 'id = ?',
          whereArgs: [e['id']],
        );
        if (local.isEmpty || local.first['is_synced'] == 1) {
          await db.insert('calendar_events', {
            'id': e['id'].toString(),
            'user_id': user.id,
            'title': e['title'] ?? '',
            'date': e['date'],
            'end_date': e['end_date'],
            'start_time': e['start_time'],
            'end_time': e['end_time'],
            'is_all_day': e['is_all_day'] == true ? 1 : 0,
            'calendar': e['calendar'] ?? 'Основной',
            'color': e['color'],
            'description': e['description'],
            'location': e['location'],
            'is_synced': 1,
            'updated_at': e['updated_at'] ?? DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 3. Habits
      final remoteHabits = await _supabase
          .from('habits')
          .select()
          .eq('user_id', user.id);
      for (final h in remoteHabits) {
        final local = await db.query(
          'habits',
          where: 'id = ?',
          whereArgs: [h['id']],
        );
        if (local.isEmpty || local.first['is_synced'] == 1) {
          await db.insert('habits', {
            'id': h['id'].toString(),
            'user_id': user.id,
            'title': h['title'] ?? '',
            'type': h['type'] ?? 'binary',
            'target_value': (h['target_value'] is num)
                ? (h['target_value'] as num).toDouble()
                : 1.0,
            'unit': h['unit'],
            'color': h['color'],
            'reminder_time': h['reminder_time'],
            'history': h['history'] != null
                ? jsonEncode(h['history'])
                : jsonEncode({}),
            'streak': h['streak'] ?? 0,
            'is_synced': 1,
            'updated_at': h['updated_at'] ?? DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 4. Notes
      final remoteNotes = await _supabase
          .from('notes')
          .select()
          .eq('user_id', user.id);
      for (final n in remoteNotes) {
        final local = await db.query(
          'notes',
          where: 'id = ?',
          whereArgs: [n['id']],
        );
        if (local.isEmpty || local.first['is_synced'] == 1) {
          await db.insert('notes', {
            'id': n['id'].toString(),
            'user_id': user.id,
            'title': n['title'] ?? '',
            'body': n['body'],
            'image_path': n['image_path'],
            'category': n['category'] ?? 'Общее',
            'is_pinned': n['is_pinned'] == true ? 1 : 0,
            'is_synced': 1,
            'updated_at': n['updated_at'] ?? DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 5. Budget
      final remoteBudget = await _supabase
          .from('budget_transactions')
          .select()
          .eq('user_id', user.id);
      for (final b in remoteBudget) {
        final local = await db.query(
          'budget_transactions',
          where: 'id = ?',
          whereArgs: [b['id']],
        );
        if (local.isEmpty || local.first['is_synced'] == 1) {
          await db.insert('budget_transactions', {
            'id': b['id'].toString(),
            'user_id': user.id,
            'title': b['title'] ?? '',
            'amount': (b['amount'] is num)
                ? (b['amount'] as num).toDouble()
                : 0.0,
            'type': b['type'] ?? 'expense',
            'category': b['category'] ?? 'Другое',
            'date': b['date'] ?? DateTime.now().toIso8601String(),
            'is_synced': 1,
            'updated_at': b['updated_at'] ?? DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 6. Diary
      final remoteDiary = await _supabase
          .from('diary_entries')
          .select()
          .eq('user_id', user.id);
      for (final d in remoteDiary) {
        final local = await db.query(
          'diary_entries',
          where: 'id = ?',
          whereArgs: [d['id']],
        );
        if (local.isEmpty || local.first['is_synced'] == 1) {
          await db.insert('diary_entries', {
            'id': d['id'].toString(),
            'user_id': user.id,
            'date': d['date'] ?? DateTime.now().toIso8601String(),
            'mood': d['mood'] ?? 'neutral',
            'content': d['content'] ?? '',
            'tags': d['tags'] != null ? jsonEncode(d['tags']) : jsonEncode([]),
            'is_synced': 1,
            'updated_at': d['updated_at'] ?? DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 7. Shifts
      final remoteShifts = await _supabase
          .from('shift_schedules')
          .select()
          .eq('user_id', user.id);
      for (final s in remoteShifts) {
        final local = await db.query(
          'shift_schedules',
          where: 'id = ?',
          whereArgs: [s['id']],
        );
        if (local.isEmpty || local.first['is_synced'] == 1) {
          await db.insert('shift_schedules', {
            'id': s['id'].toString(),
            'user_id': user.id,
            'name': s['name'] ?? 'Основной',
            'start_date': s['start_date'] ?? DateTime.now().toIso8601String(),
            'cycle_days': s['cycle_days'] != null
                ? jsonEncode(s['cycle_days'])
                : jsonEncode([]),
            'overrides': s['overrides'] != null
                ? jsonEncode(s['overrides'])
                : jsonEncode({}),
            'is_synced': 1,
            'updated_at': s['updated_at'] ?? DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      debugPrint('Pull sync error: $e');
    }
  }
}
