import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';

class NotesNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    loadNotes();
    return [];
  }

  Future<void> loadNotes() async {
    final db = await DatabaseService.instance.database;
    // Закрепленные заметки всегда сверху, затем свежие по updated_at
    final res = await db.query(
      'notes',
      orderBy: 'is_pinned DESC, updated_at DESC',
    );

    state = res.map((row) {
      final m = Map<String, dynamic>.from(row);
      m['is_pinned'] = m['is_pinned'] == 1;
      m['image'] = m['image_path'];
      return m;
    }).toList();
  }

  Future<void> saveNote({
    String? existingId,
    required String title,
    required String body,
    String? imagePath,
    String category = 'Общее',
    bool isPinned = false,
  }) async {
    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();
    final id = existingId ?? 'note_${DateTime.now().millisecondsSinceEpoch}';

    final row = {
      'id': id,
      'title': title,
      'body': body,
      'image_path': imagePath,
      'category': category,
      'is_pinned': isPinned ? 1 : 0,
      'is_synced': 0,
      'updated_at': nowIso,
    };

    await db.insert('notes', row, conflictAlgorithm: ConflictAlgorithm.replace);
    await loadNotes();
    SyncService.instance.syncAll();
  }

  Future<void> togglePin(String noteId, bool currentPinState) async {
    final db = await DatabaseService.instance.database;
    final nowIso = DateTime.now().toIso8601String();

    await db.update(
      'notes',
      {
        'is_pinned': currentPinState ? 0 : 1,
        'updated_at': nowIso,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );

    await loadNotes();
    SyncService.instance.syncAll();
  }

  Future<void> deleteNote(String noteId) async {
    final db = await DatabaseService.instance.database;
    await db.delete('notes', where: 'id = ?', whereArgs: [noteId]);
    await db.insert('delete_queue', {
      'table_name': 'notes',
      'record_id': noteId,
      'created_at': DateTime.now().toIso8601String(),
    });

    state = state.where((n) => n['id'].toString() != noteId).toList();
    SyncService.instance.syncAll();
  }
}

final notesProvider =
    NotifierProvider<NotesNotifier, List<Map<String, dynamic>>>(
      NotesNotifier.new,
    );
