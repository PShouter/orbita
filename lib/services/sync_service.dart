import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_service.dart';

typedef JsonMap = Map<String, dynamic>;

class SyncService {
  static final SyncService instance = SyncService._init();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isSyncing = false;
  Timer? _periodicTimer;

  VoidCallback? onGamificationPulled;
  VoidCallback? onAchievementsPulled;

  SyncService._init();

  void initListener() {
    Connectivity().onConnectivityChanged.listen((results) async {
      if (!results.contains(ConnectivityResult.none)) {
        await Future.delayed(const Duration(seconds: 2));
        syncAll();
      }
    });

    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      syncAll();
    });
  }

  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<T?> _retryOperation<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    String opName = 'Операция',
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        return await operation();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isNetwork = errStr.contains('socketexception') ||
            errStr.contains('connection timed out') ||
            errStr.contains('clientexception') ||
            errStr.contains('timeoutexception') ||
            e is SocketException ||
            e is TimeoutException;

        if (!isNetwork || attempt >= maxAttempts) {
          debugPrint(
              'SyncService: $opName завершилась ошибкой (попытка $attempt/$maxAttempts): $e');
          return null;
        }

        debugPrint(
            'SyncService: $opName сетевой сбой. Повтор $attempt/$maxAttempts через ${delay.inSeconds}с...');
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    return null;
  }

  Future<void> syncAll() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _isSyncing) return;

    _isSyncing = true;
    try {
      await _cleanStaleDeleteQueue();
      await _pushChanges(user.id);
      await pullAllFromCloud();
    } catch (e) {
      debugPrint('Ошибка синхронизации: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _cleanStaleDeleteQueue() async {
    try {
      final db = await DatabaseService.instance.database;
      final sevenDaysAgo =
          DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      await db.delete('delete_queue',
          where: "created_at < ?", whereArgs: [sevenDaysAgo]);
    } catch (e) {
      debugPrint('SyncService: Ошибка очистки старой delete_queue: $e');
    }
  }

  int _parsePriorityToInt(dynamic priority) {
    if (priority is int) return priority;
    switch (priority?.toString()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  String _parseIntToPriority(dynamic priority) {
    if (priority == 3) return 'high';
    if (priority == 2) return 'medium';
    if (priority == 1) return 'low';
    return 'none';
  }

  Future<void> _pushChanges(String userId) async {
    final db = await DatabaseService.instance.database;
    final uuidRegExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    // 0. Очередь удалений с изолированным таймаутом для каждой записи
    try {
      final deleteQueue = await db.query('delete_queue');
      for (final item in deleteQueue) {
        final table = item['table_name'] as String;
        final recordId = item['record_id'] as String;

        if (table == 'vault_documents') {
          await db.delete(
            'delete_queue',
            where: 'id = ?',
            whereArgs: [item['id']],
          );
          continue;
        }

        final targetTable = (table == 'diaries') ? 'diary_entries' : table;

        final success = await _retryOperation(
          () => _supabase
              .from(targetTable)
              .delete()
              .eq('id', recordId)
              .timeout(const Duration(seconds: 4)),
          opName: 'Удаление из $targetTable ($recordId)',
        );

        if (success != null) {
          await db.delete(
            'delete_queue',
            where: 'id = ?',
            whereArgs: [item['id']],
          );
        } else {
          // Если запись некорректна для базы Supabase, удаляем из очереди
          await db.delete(
            'delete_queue',
            where: 'id = ?',
            whereArgs: [item['id']],
          );
        }
      }
    } catch (e) {
      debugPrint('SyncService: Ошибка очереди удалений: $e');
    }

    // 1. Задачи (public.tasks)
    try {
      final unsyncedTasks = await db.query(
        'tasks',
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      if (unsyncedTasks.isNotEmpty) {
        final List<JsonMap> payload = [];
        for (final t in unsyncedTasks) {
          final idStr = t['id'].toString();

          if (!uuidRegExp.hasMatch(idStr)) {
            await db.update(
              'tasks',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [idStr],
            );
            continue;
          }

          dynamic subtasksData = t['subtasks'];
          if (subtasksData is! String && subtasksData != null) {
            subtasksData = jsonEncode(subtasksData);
          }

          dynamic tagsData = t['tags'];
          if (tagsData is! String && tagsData != null) {
            tagsData = jsonEncode(tagsData);
          }

          dynamic attachData = t['attachments'];
          if (attachData is! String && attachData != null) {
            attachData = jsonEncode(attachData);
          }

          String? dueDate;
          if (t['date'] != null && t['date'].toString().isNotEmpty) {
            dueDate = t['date'].toString().split('T')[0];
          }

          payload.add({
            'id': idStr,
            'user_id': userId,
            'title': t['title'] ?? '',
            'description': t['description'] ?? '',
            'due_date': dueDate != null ? '${dueDate}T00:00:00Z' : null,
            'is_completed': (t['done'] == 1),
            'priority': _parsePriorityToInt(t['priority']),
            'attachments': attachData,
            'subtasks': subtasksData,
            'tags': tagsData,
            'created_at': t['updated_at'] ?? DateTime.now().toIso8601String(),
          });
        }

        if (payload.isNotEmpty) {
          final res = await _retryOperation(
            () => _supabase
                .from('tasks')
                .upsert(payload)
                .timeout(const Duration(seconds: 8)),
            opName: 'Выгрузка задач',
          );
          if (res != null) {
            await db.update('tasks', {'is_synced': 1}, where: 'is_synced = 0');
          }
        }
      }
    } catch (e) {
      debugPrint('SyncService: Ошибка выгрузки задач в Supabase: $e');
    }

    // 2. Календарь (public.calendar_events)
    try {
      await db.rawUpdate('''
        UPDATE calendar_events 
        SET is_synced = 1 
        WHERE is_synced = 0 AND id LIKE 'shift_ev_%'
      ''');

      await db.rawUpdate(
        '''
        UPDATE calendar_events 
        SET user_id = ? 
        WHERE user_id IS NULL OR user_id = ''
      ''',
        [userId],
      );

      final unsyncedEvents = await db.query(
        'calendar_events',
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      if (unsyncedEvents.isNotEmpty) {
        final List<JsonMap> validEvents = [];
        final List<String> invalidIds = [];

        for (final e in unsyncedEvents) {
          final idStr = e['id'].toString();

          if (!uuidRegExp.hasMatch(idStr)) {
            invalidIds.add(idStr);
            continue;
          }

          final int isAllDayInt =
              (e['is_all_day'] == 1 || e['is_all_day'] == true) ? 1 : 0;
          final int? colorVal = e['color'] is int ? e['color'] as int : null;

          validEvents.add({
            'id': idStr,
            'user_id': userId,
            'title': e['title'] ?? 'Без названия',
            'date': e['date'] ?? DateTime.now().toIso8601String().split('T')[0],
            'end_date': e['end_date'] ?? e['date'],
            'start_time': e['start_time'],
            'end_time': e['end_time'],
            'is_all_day': isAllDayInt,
            'calendar': e['calendar'] ?? 'Основной',
            'color': colorVal,
            'description': e['description'],
            'location': e['location'],
            'reminder_minutes': e['reminder_minutes'] ?? -1,
            'recurrence': e['recurrence'] ?? 'none',
            'is_synced': 1,
            'updated_at': e['updated_at'] ?? DateTime.now().toIso8601String(),
          });
        }

        if (invalidIds.isNotEmpty) {
          for (final invId in invalidIds) {
            await db.update(
              'calendar_events',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [invId],
            );
          }
        }

        if (validEvents.isNotEmpty) {
          const batchSize = 25;
          bool allBatchesSuccess = true;

          for (int i = 0; i < validEvents.length; i += batchSize) {
            final chunk = validEvents.sublist(
              i,
              i + batchSize > validEvents.length
                  ? validEvents.length
                  : i + batchSize,
            );
            final batchRes = await _retryOperation(
              () => _supabase
                  .from('calendar_events')
                  .upsert(chunk)
                  .timeout(const Duration(seconds: 8)),
              opName: 'Выгрузка батча календаря',
            );
            if (batchRes == null) {
              allBatchesSuccess = false;
            }
          }

          if (allBatchesSuccess) {
            await db.update(
                'calendar_events',
                {
                  'is_synced': 1,
                },
                where: 'is_synced = 0');
            debugPrint(
              'SyncService: Календарь успешно выгружен (${validEvents.length} событий)',
            );
          }
        }
      }
    } catch (e) {
      debugPrint(
        'SyncService: Ошибка выгрузки событий календаря в Supabase: $e',
      );
    }

    // 3. Привычки (public.habits)
    try {
      await db.rawUpdate('''
        UPDATE habits 
        SET is_synced = 1 
        WHERE is_synced = 0 AND id LIKE 'habit_%'
      ''');

      final unsyncedHabits = await db.query(
        'habits',
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      if (unsyncedHabits.isNotEmpty) {
        final List<JsonMap> payload = [];
        for (final h in unsyncedHabits) {
          final idStr = h['id'].toString();
          if (!uuidRegExp.hasMatch(idStr)) {
            await db.update(
              'habits',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [idStr],
            );
            continue;
          }

          payload.add({
            'id': idStr,
            'user_id': userId,
            'title': h['title'] ?? '',
            'description': h['description'] ?? '',
            'streak': h['streak'] ?? 0,
            'color': h['color'] is int ? h['color'] : 4281373137,
            'frequency_count': h['frequency_count'] ?? 1,
            'frequency_type': h['frequency_type'] ?? 'daily',
            'frequency_days': h['frequency_days']?.toString(),
            'is_archived': h['is_archived'] ?? 0,
            'position': h['position'] ?? 0,
            'question': h['question'] ?? '',
            'reminder_time': h['reminder_time'],
            'target_value': (h['target_value'] is num)
                ? (h['target_value'] as num).toDouble()
                : 1.0,
            'unit': h['unit'],
            'type': h['type'] ?? 'boolean',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        }

        if (payload.isNotEmpty) {
          final res = await _retryOperation(
            () => _supabase
                .from('habits')
                .upsert(payload)
                .timeout(const Duration(seconds: 8)),
            opName: 'Выгрузка привычек',
          );
          if (res != null) {
            await db.update('habits', {'is_synced': 1}, where: 'is_synced = 0');
          }
        }
      }
    } catch (e) {
      debugPrint('SyncService: Ошибка выгрузки привычек в Supabase: $e');
    }

    // 4. Заметки (public.notes)
    try {
      final unsyncedNotes = await db.query(
        'notes',
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      if (unsyncedNotes.isNotEmpty) {
        final List<JsonMap> payload = [];
        for (final n in unsyncedNotes) {
          final idStr = n['id'].toString();
          if (!uuidRegExp.hasMatch(idStr)) {
            await db.update(
              'notes',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [idStr],
            );
            continue;
          }

          payload.add({
            'id': idStr,
            'user_id': userId,
            'title': n['title'] ?? 'Без названия',
            'body': n['body'] ?? '',
            'image_url': n['image_path'] ?? '',
            'tags': n['tags']?.toString(),
            'attachments': n['attachments']?.toString(),
            'created_at': n['created_at'] ?? DateTime.now().toIso8601String(),
            'updated_at': n['updated_at'] ?? DateTime.now().toIso8601String(),
          });
        }

        if (payload.isNotEmpty) {
          final res = await _retryOperation(
            () => _supabase
                .from('notes')
                .upsert(payload)
                .timeout(const Duration(seconds: 8)),
            opName: 'Выгрузка заметок',
          );
          if (res != null) {
            await db.update('notes', {'is_synced': 1}, where: 'is_synced = 0');
          }
        }
      }
    } catch (e) {
      debugPrint('SyncService: Ошибка выгрузки заметок в Supabase: $e');
    }

    // 5. Дневник (public.diary_entries)
    try {
      List<JsonMap> unsyncedDiary = [];
      String localTable = 'diaries';

      try {
        final rows = await db.query(
          'diaries',
          where: 'is_synced = ?',
          whereArgs: [0],
        );
        unsyncedDiary = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      } catch (_) {
        localTable = 'diary_entries';
        try {
          final rows = await db.query(
            'diary_entries',
            where: 'is_synced = ?',
            whereArgs: [0],
          );
          unsyncedDiary =
              rows.map((r) => Map<String, dynamic>.from(r)).toList();
        } catch (_) {}
      }

      if (unsyncedDiary.isNotEmpty) {
        final List<JsonMap> payload = [];
        for (final d in unsyncedDiary) {
          final idStr = d['id'].toString();
          if (!uuidRegExp.hasMatch(idStr)) {
            await db.update(
              localTable,
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [idStr],
            );
            continue;
          }

          String entryDate = DateTime.now().toIso8601String().split('T')[0];
          if (d['date'] != null && d['date'].toString().isNotEmpty) {
            entryDate = d['date'].toString().split('T')[0];
          }

          String imageUrl = '';
          if (d['images'] != null && d['images'].toString().isNotEmpty) {
            try {
              final decodedImgs = jsonDecode(d['images'].toString());
              if (decodedImgs is List && decodedImgs.isNotEmpty) {
                imageUrl = decodedImgs.first.toString();
              }
            } catch (_) {
              imageUrl = d['images'].toString();
            }
          }

          final titlePart =
              (d['title'] != null && d['title'].toString().isNotEmpty)
                  ? '${d['title']}\n\n'
                  : '';
          final contentPart = d['content'] ?? d['text'] ?? '';

          payload.add({
            'id': idStr,
            'user_id': userId,
            'entry_date': entryDate,
            'mood': d['mood'] ?? '😊',
            'text': '$titlePart$contentPart'.trim(),
            'image_url': imageUrl,
            'created_at': d['created_at'] ?? DateTime.now().toIso8601String(),
          });
        }

        if (payload.isNotEmpty) {
          final res = await _retryOperation(
            () => _supabase
                .from('diary_entries')
                .upsert(payload)
                .timeout(const Duration(seconds: 8)),
            opName: 'Выгрузка дневника',
          );
          if (res != null) {
            await db.update(localTable, {'is_synced': 1},
                where: 'is_synced = 0');
          }
        }
      }
    } catch (e) {
      debugPrint('SyncService: Ошибка выгрузки дневника в Supabase: $e');
    }

    // 6. График смен (public.shift_schedules)
    try {
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
          return m;
        }).toList();

        final res = await _retryOperation(
          () => _supabase
              .from('shift_schedules')
              .upsert(payload)
              .timeout(const Duration(seconds: 8)),
          opName: 'Выгрузка смен',
        );
        if (res != null) {
          await db.update(
              'shift_schedules',
              {
                'is_synced': 1,
              },
              where: 'is_synced = 0');
        }
      }
    } catch (e) {
      debugPrint('SyncService: Ошибка выгрузки смен в Supabase: $e');
    }

    // 7. Геймификация (public.user_gamification)
    try {
      final unsyncedGamification = await db.query(
        'user_gamification',
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      if (unsyncedGamification.isNotEmpty) {
        final g = Map<String, dynamic>.from(unsyncedGamification.first);
        g.remove('is_synced');
        g['user_id'] = userId;
        final res = await _retryOperation(
          () => _supabase
              .from('user_gamification')
              .upsert(g)
              .timeout(const Duration(seconds: 6)),
          opName: 'Выгрузка геймификации',
        );
        if (res != null) {
          await db.update(
              'user_gamification',
              {
                'is_synced': 1,
              },
              where: 'is_synced = 0');
        }
      }
    } catch (e) {
      debugPrint('SyncService: Ошибка выгрузки геймификации в Supabase: $e');
    }

    // 8. Достижения (public.user_achievements)
    try {
      final unsyncedAchievements = await db.query(
        'user_achievements',
        where: 'is_synced = ?',
        whereArgs: [0],
      );
      if (unsyncedAchievements.isNotEmpty) {
        final payload = unsyncedAchievements.map((a) {
          final isUnlockedVal =
              (a['is_unlocked'] == 1 || a['is_unlocked'] == true) ? 1 : 0;
          return {
            'id': a['id'].toString(),
            'user_id': userId,
            'achievement_key': a['achievement_key'],
            'current_value': a['current_value'] ?? 0,
            'target_value': a['target_value'] ?? 1,
            'is_unlocked': isUnlockedVal,
            'unlocked_at': a['unlocked_at'],
            'updated_at': a['updated_at'] ?? DateTime.now().toIso8601String(),
          };
        }).toList();

        final res = await _retryOperation(
          () => _supabase
              .from('user_achievements')
              .upsert(payload, onConflict: 'user_id, achievement_key')
              .timeout(const Duration(seconds: 8)),
          opName: 'Выгрузка достижений',
        );
        if (res != null) {
          await db.update(
              'user_achievements',
              {
                'is_synced': 1,
              },
              where: 'is_synced = 0');
        }
      }
    } catch (e) {
      debugPrint('SyncService: Ошибка выгрузки достижений в Supabase: $e');
    }
  }

  Future<void> pullAllFromCloud({bool forceReplace = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final db = await DatabaseService.instance.database;

    try {
      final results = await Future.wait<dynamic>([
        _retryOperation(
          () => _supabase
              .from('tasks')
              .select()
              .eq('user_id', user.id)
              .timeout(const Duration(seconds: 10)),
          opName: 'Pull Tasks',
        ),
        _retryOperation(
          () => _supabase
              .from('calendar_events')
              .select()
              .eq('user_id', user.id)
              .timeout(const Duration(seconds: 10)),
          opName: 'Pull Events',
        ),
        _retryOperation(
          () => _supabase
              .from('habits')
              .select()
              .eq('user_id', user.id)
              .timeout(const Duration(seconds: 10)),
          opName: 'Pull Habits',
        ),
        _retryOperation(
          () => _supabase
              .from('notes')
              .select()
              .eq('user_id', user.id)
              .timeout(const Duration(seconds: 10)),
          opName: 'Pull Notes',
        ),
        _retryOperation(
          () => _supabase
              .from('diary_entries')
              .select()
              .eq('user_id', user.id)
              .timeout(const Duration(seconds: 10)),
          opName: 'Pull Diary',
        ),
        _retryOperation(
          () => _supabase
              .from('shift_schedules')
              .select()
              .eq('user_id', user.id)
              .timeout(const Duration(seconds: 10)),
          opName: 'Pull Shifts',
        ),
        _retryOperation(
          () => _supabase
              .from('user_gamification')
              .select()
              .eq('user_id', user.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 10)),
          opName: 'Pull Gamification',
        ),
        _retryOperation(
          () => _supabase
              .from('user_achievements')
              .select()
              .eq('user_id', user.id)
              .timeout(const Duration(seconds: 10)),
          opName: 'Pull Achievements',
        ),
      ]);

      final remoteTasks = results[0] as List<dynamic>? ?? [];
      final remoteEvents = results[1] as List<dynamic>? ?? [];
      final remoteHabits = results[2] as List<dynamic>? ?? [];
      final remoteNotes = results[3] as List<dynamic>? ?? [];
      final remoteDiary = results[4] as List<dynamic>? ?? [];
      final remoteShifts = results[5] as List<dynamic>? ?? [];
      final remoteGamification = results[6] as Map<String, dynamic>?;
      final remoteAchievements = results[7] as List<dynamic>? ?? [];

      await db.transaction((txn) async {
        final batch = txn.batch();

        for (final t in remoteTasks) {
          batch.insert(
              'tasks',
              {
                'id': t['id'].toString(),
                'user_id': user.id,
                'title': t['title'] ?? '',
                'description': t['description'] ?? '',
                'date': t['due_date'],
                'time': null,
                'is_no_date': (t['due_date'] == null) ? 1 : 0,
                'is_all_day': 1,
                'priority': _parseIntToPriority(t['priority']),
                'done': (t['is_completed'] == true) ? 1 : 0,
                'subtasks': t['subtasks'] != null
                    ? (t['subtasks'] is String
                        ? t['subtasks']
                        : jsonEncode(t['subtasks']))
                    : null,
                'tags': t['tags'] != null
                    ? (t['tags'] is String ? t['tags'] : jsonEncode(t['tags']))
                    : null,
                'attachments': t['attachments'] != null
                    ? (t['attachments'] is String
                        ? t['attachments']
                        : jsonEncode(t['attachments']))
                    : null,
                'is_synced': 1,
                'updated_at':
                    t['created_at'] ?? DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        for (final e in remoteEvents) {
          final isAllDayInt =
              (e['is_all_day'] == 1 || e['is_all_day'] == true) ? 1 : 0;
          batch.insert(
              'calendar_events',
              {
                'id': e['id'].toString(),
                'user_id': user.id,
                'title': e['title'] ?? '',
                'date': e['date'],
                'end_date': e['end_date'],
                'start_time': e['start_time'],
                'end_time': e['end_time'],
                'is_all_day': isAllDayInt,
                'calendar': e['calendar'] ?? 'Основной',
                'color': e['color'],
                'description': e['description'],
                'location': e['location'],
                'reminder_minutes': e['reminder_minutes'] ?? -1,
                'recurrence': e['recurrence'] ?? 'none',
                'is_synced': 1,
                'updated_at':
                    e['updated_at'] ?? DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        for (final h in remoteHabits) {
          List<int> fDays = [];
          if (h['frequency_days'] != null) {
            try {
              final decoded = jsonDecode(h['frequency_days'].toString());
              if (decoded is List) fDays = decoded.cast<int>();
            } catch (_) {}
          }

          final createdAtStr = h['created_at'] ??
              h['updated_at'] ??
              DateTime.now().toIso8601String();

          batch.insert(
              'habits',
              {
                'id': h['id'].toString(),
                'user_id': user.id,
                'title': h['title'] ?? '',
                'question': h['question'] ?? '',
                'description': h['description'] ?? '',
                'color': h['color'] is int ? h['color'] : 4281373137,
                'type': h['type'] ?? 'boolean',
                'target_value': (h['target_value'] is num)
                    ? (h['target_value'] as num).toDouble()
                    : 1.0,
                'unit': h['unit'],
                'frequency_type': h['frequency_type'] ?? 'daily',
                'frequency_days': jsonEncode(fDays),
                'frequency_count': h['frequency_count'] ?? 1,
                'reminder_time': h['reminder_time'],
                'position': h['position'] ?? 0,
                'streak': h['streak'] ?? 0,
                'is_archived': h['is_archived'] ?? 0,
                'history': jsonEncode({}),
                'is_synced': 1,
                'created_at': createdAtStr,
                'updated_at':
                    h['updated_at'] ?? DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        for (final n in remoteNotes) {
          batch.insert(
              'notes',
              {
                'id': n['id'].toString(),
                'user_id': user.id,
                'title': n['title'] ?? 'Без названия',
                'body': n['body'] ?? '',
                'image_path': n['image_url'],
                'tags': n['tags'],
                'attachments': n['attachments'],
                'category': 'Общее',
                'is_pinned': 0,
                'is_synced': 1,
                'created_at':
                    n['created_at'] ?? DateTime.now().toIso8601String(),
                'updated_at':
                    n['updated_at'] ?? DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        for (final d in remoteDiary) {
          final text = (d['text'] as String?) ?? '';
          final lines = text.split('\n\n');
          final title = lines.isNotEmpty ? lines.first : '';
          final content =
              lines.length > 1 ? lines.sublist(1).join('\n\n') : text;

          final imgs =
              (d['image_url'] != null && d['image_url'].toString().isNotEmpty)
                  ? jsonEncode([d['image_url']])
                  : jsonEncode([]);

          batch.insert(
              'diaries',
              {
                'id': d['id'].toString(),
                'user_id': user.id,
                'title': title,
                'content': content,
                'date': d['entry_date'] ?? DateTime.now().toIso8601String(),
                'mood': d['mood'] ?? '😊',
                'images': imgs,
                'is_draft': 0,
                'is_synced': 1,
                'created_at':
                    d['created_at'] ?? DateTime.now().toIso8601String(),
                'updated_at':
                    d['created_at'] ?? DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace);

          batch.insert(
              'diary_entries',
              {
                'id': d['id'].toString(),
                'user_id': user.id,
                'date': d['entry_date'] ?? DateTime.now().toIso8601String(),
                'mood': d['mood'] ?? '😊',
                'content': text,
                'tags': jsonEncode([]),
                'is_synced': 1,
                'updated_at':
                    d['created_at'] ?? DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        for (final s in remoteShifts) {
          batch.insert(
              'shift_schedules',
              {
                'id': s['id'].toString(),
                'user_id': user.id,
                'name': s['name'] ?? 'Основной',
                'start_date':
                    s['start_date'] ?? DateTime.now().toIso8601String(),
                'cycle_days': s['cycle_days']?.toString() ?? jsonEncode([]),
                'overrides': s['overrides']?.toString() ?? jsonEncode({}),
                'custom_types': s['custom_types']?.toString(),
                'is_synced': 1,
                'updated_at':
                    s['updated_at'] ?? DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        if (remoteGamification != null) {
          batch.insert(
              'user_gamification',
              {
                'user_id': user.id,
                'total_exp': remoteGamification['total_exp'] ?? 0,
                'weekly_exp': remoteGamification['weekly_exp'] ?? 0,
                'last_week_reset': remoteGamification['last_week_reset'] ??
                    DateTime.now().toIso8601String(),
                'habits_exp': remoteGamification['habits_exp'] ?? 0,
                'diary_exp': remoteGamification['diary_exp'] ?? 0,
                'budget_exp': remoteGamification['budget_exp'] ?? 0,
                'tasks_exp': remoteGamification['tasks_exp'] ?? 0,
                'is_synced': 1,
                'updated_at': remoteGamification['updated_at'] ??
                    DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        for (final a in remoteAchievements) {
          batch.insert(
              'user_achievements',
              {
                'id': a['id'].toString(),
                'user_id': user.id,
                'achievement_key': a['achievement_key'],
                'current_value': a['current_value'] ?? 0,
                'target_value': a['target_value'] ?? 1,
                'is_unlocked':
                    (a['is_unlocked'] == true || a['is_unlocked'] == 1) ? 1 : 0,
                'unlocked_at': a['unlocked_at'],
                'is_synced': 1,
                'updated_at':
                    a['updated_at'] ?? DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        await batch.commit(noResult: true);
      });

      if (remoteGamification != null) onGamificationPulled?.call();
      if (remoteAchievements.isNotEmpty) onAchievementsPulled?.call();

      debugPrint('SyncService: pullAllFromCloud успешно завершен');
    } catch (e) {
      debugPrint('Ошибка выгрузки данных из облака: $e');
    }
  }

  Future<void> pullAll() => pullAllFromCloud();
}
