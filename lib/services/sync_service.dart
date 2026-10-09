import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
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
    final db = await DatabaseService.instance.database;

    try {
      // 1. Очередь удаления (для отправки DELETE в облако при появлении сети)
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
          debugPrint('Ошибка синхронизации удаления из $table ($recordId): $e');
        }
      }

      // 2. Синхронизация задач (Tasks)
      final unsyncedTasks = await db.query(
        'tasks',
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      if (unsyncedTasks.isNotEmpty) {
        final payload = unsyncedTasks.map((t) {
          final m = Map<String, dynamic>.from(t);
          m.remove('is_synced');
          m['user_id'] = user.id;
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

      // 3. Синхронизация событий календаря (Calendar Events)
      final unsyncedEvents = await db.query(
        'calendar_events',
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      if (unsyncedEvents.isNotEmpty) {
        final payload = unsyncedEvents.map((e) {
          final m = Map<String, dynamic>.from(e);
          m.remove('is_synced');
          m['user_id'] = user.id;
          m['is_all_day'] = (m['is_all_day'] == 1);
          return m;
        }).toList();

        await _supabase.from('calendar_events').upsert(payload);
        await db.update('calendar_events', {
          'is_synced': 1,
        }, where: 'is_synced = 0');
      }

      // 4. Синхронизация привычек (Habits)
      final unsyncedHabits = await db.query(
        'habits',
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      if (unsyncedHabits.isNotEmpty) {
        final payload = unsyncedHabits.map((h) {
          final m = Map<String, dynamic>.from(h);
          m.remove('is_synced');
          m['user_id'] = user.id;
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

      // 5. Синхронизация заметок (Notes)
      final unsyncedNotes = await db.query(
        'notes',
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      if (unsyncedNotes.isNotEmpty) {
        final payload = unsyncedNotes.map((n) {
          final m = Map<String, dynamic>.from(n);
          m.remove('is_synced');
          m['user_id'] = user.id;
          m['is_pinned'] = (m['is_pinned'] == 1);
          return m;
        }).toList();

        await _supabase.from('notes').upsert(payload);
        await db.update('notes', {'is_synced': 1}, where: 'is_synced = 0');
      }
    } catch (e) {
      debugPrint('Фоновая синхронизация отложена: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
