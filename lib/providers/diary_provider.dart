import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';

class DiaryNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    loadEntries();
    return [];
  }

  Future<void> loadEntries() async {
    final db = await DatabaseService.instance.database;
    final res = await db.query('diary_entries', orderBy: 'date DESC');

    state = res.map((row) {
      final m = Map<String, dynamic>.from(row);
      m['date'] = DateTime.parse(m['date']);
      if (m['tags'] != null && m['tags'] is String) {
        try {
          m['tags'] = List<String>.from(jsonDecode(m['tags']));
        } catch (_) {
          m['tags'] = <String>[];
        }
      } else {
        m['tags'] = <String>[];
      }
      return m;
    }).toList();
  }

  Future<void> saveEntry({
    String? existingId,
    required DateTime date,
    required String mood,
    required String content,
    List<String> tags = const [],
  }) async {
    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    final id = existingId ?? 'diary_${DateTime.now().millisecondsSinceEpoch}';

    final row = {
      'id': id,
      'date': date.toIso8601String(),
      'mood': mood,
      'content': content,
      'tags': jsonEncode(tags),
      'is_synced': 0,
      'updated_at': nowIso,
    };

    await db.insert(
      'diary_entries',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await loadEntries();
    SyncService.instance.syncAll();
  }

  Future<void> deleteEntry(String entryId) async {
    final db = await DatabaseService.instance.database;
    await db.delete('diary_entries', where: 'id = ?', whereArgs: [entryId]);
    await db.insert('delete_queue', {
      'table_name': 'diary_entries',
      'record_id': entryId,
      'created_at': DateTime.now().toIso8601String(),
    });

    state = state.where((e) => e['id'].toString() != entryId).toList();
    SyncService.instance.syncAll();
  }
}

final diaryProvider =
    NotifierProvider<DiaryNotifier, List<Map<String, dynamic>>>(
      DiaryNotifier.new,
    );
