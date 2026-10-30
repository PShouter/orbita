import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

enum NotesViewMode { grid, list }

class NoteItem {
  final String id;
  final String title;
  final String body;
  final String? imagePath;
  final List<String> attachments;
  final List<String> tags;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteItem({
    required this.id,
    required this.title,
    required this.body,
    this.imagePath,
    this.attachments = const [],
    this.tags = const [],
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String? get previewImage {
    if (imagePath != null && imagePath!.isNotEmpty) return imagePath;
    for (final att in attachments) {
      final lower = att.toLowerCase();
      if (lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.webp')) {
        return att;
      }
    }
    return null;
  }

  NoteItem copyWith({
    String? id,
    String? title,
    String? body,
    String? imagePath,
    List<String>? attachments,
    List<String>? tags,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      imagePath: imagePath ?? this.imagePath,
      attachments: attachments ?? this.attachments,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// --- ПРОВАЙДЕР РЕЖИМА ОТОБРАЖЕНИЯ (ПЛИТКИ / СПИСОК) ---
class NotesViewModeNotifier extends Notifier<NotesViewMode> {
  @override
  NotesViewMode build() {
    _load();
    return NotesViewMode.grid;
  }

  Future<void> _load() async {
    final db = await DatabaseService.instance.database;
    final res = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['notes_view_mode'],
    );
    if (res.isNotEmpty) {
      final val = res.first['value'] as String;
      state = val == 'list' ? NotesViewMode.list : NotesViewMode.grid;
    }
  }

  Future<void> setMode(NotesViewMode mode) async {
    state = mode;
    final db = await DatabaseService.instance.database;
    await db.insert('app_settings', {
      'key': 'notes_view_mode',
      'value': mode.name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

final notesViewModeProvider =
    NotifierProvider<NotesViewModeNotifier, NotesViewMode>(
      NotesViewModeNotifier.new,
    );

// --- НОТИФИКАТОРЫ ПОИСКА И ТЕГОВ ---
class NotesSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
}

final notesSearchQueryProvider =
    NotifierProvider<NotesSearchQueryNotifier, String>(
      NotesSearchQueryNotifier.new,
    );

class NotesSelectedTagNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setTag(String? t) => state = t;
}

final notesSelectedTagProvider =
    NotifierProvider<NotesSelectedTagNotifier, String?>(
      NotesSelectedTagNotifier.new,
    );

// --- ОСНОВНОЙ ПРОВАЙДЕР ЗАМЕТОК ---
class NotesNotifier extends Notifier<List<NoteItem>> {
  static const _uuid = Uuid();

  @override
  List<NoteItem> build() {
    loadNotes();
    cleanCorruptedDeleteQueue();
    return [];
  }

  Future<void> cleanCorruptedDeleteQueue() async {
    try {
      final db = await DatabaseService.instance.database;
      await db.delete(
        'delete_queue',
        where: "table_name = 'notes' AND record_id LIKE 'note_%'",
      );
    } catch (_) {}
  }

  Future<void> loadNotes() async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'notes',
      orderBy: 'is_pinned DESC, updated_at DESC',
    );

    state = rows.map((r) {
      List<String> tags = [];
      if (r['tags'] != null && (r['tags'] as String).isNotEmpty) {
        try {
          tags = List<String>.from(jsonDecode(r['tags'] as String));
        } catch (_) {}
      }

      List<String> attachments = [];
      if (r['attachments'] != null && (r['attachments'] as String).isNotEmpty) {
        try {
          attachments = List<String>.from(
            jsonDecode(r['attachments'] as String),
          );
        } catch (_) {}
      }

      DateTime created;
      try {
        created = DateTime.parse(
          r['created_at'] as String? ?? r['updated_at'] as String,
        );
      } catch (_) {
        created = DateTime.now();
      }

      DateTime updated;
      try {
        updated = DateTime.parse(r['updated_at'] as String);
      } catch (_) {
        updated = DateTime.now();
      }

      return NoteItem(
        id: r['id'] as String,
        title: r['title'] as String,
        body: r['body'] as String? ?? '',
        imagePath: r['image_path'] as String?,
        attachments: attachments,
        tags: tags,
        isPinned: (r['is_pinned'] as int? ?? 0) == 1,
        createdAt: created,
        updatedAt: updated,
      );
    }).toList();
  }

  List<String> extractTags(String text) {
    final regex = RegExp(r'#([а-яА-Яa-zA-Z0-9_\-]+)');
    final matches = regex.allMatches(text);
    return matches.map((m) => m.group(0)!).toSet().toList();
  }

  Future<void> saveNote({
    String? id,
    required String title,
    required String body,
    String? imagePath,
    List<String> attachments = const [],
  }) async {
    final db = await DatabaseService.instance.database;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    final noteId = id ?? _uuid.v4();
    final finalTags = extractTags('$title $body');
    final userId = Supabase.instance.client.auth.currentUser?.id;

    DateTime createdAt = now;
    if (id != null) {
      final existing = state.where((n) => n.id == id).firstOrNull;
      if (existing != null) {
        createdAt = existing.createdAt;
      }
    }

    final row = {
      'id': noteId,
      'user_id': userId,
      'title': title,
      'body': body,
      'category': 'Общее',
      'image_path': imagePath,
      'attachments': jsonEncode(attachments),
      'tags': jsonEncode(finalTags),
      'is_pinned': 0,
      'is_synced': 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': nowIso,
    };

    await db.insert('notes', row, conflictAlgorithm: ConflictAlgorithm.replace);
    await loadNotes();
    SyncService.instance.syncAll();
  }

  Future<void> pinNoteToNotification(NoteItem note) async {
    await NotificationService.instance.showNotification(
      id: note.id.hashCode,
      title: note.title.isNotEmpty ? note.title : 'Заметка',
      body: note.body.isNotEmpty ? note.body : 'Текст заметки',
      payload: 'screen_notes',
      channelId: 'orbita_pinned_notes',
      channelName: 'Закрепленные заметки',
    );
  }

  Future<void> unpinNoteFromNotification(String noteId) async {
    await NotificationService.instance.cancelNotification(noteId.hashCode);
  }

  Future<void> deleteNote(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);

    await NotificationService.instance.cancelNotification(id.hashCode);

    final uuidRegExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    if (uuidRegExp.hasMatch(id)) {
      await db.insert('delete_queue', {
        'table_name': 'notes',
        'record_id': id,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    state = state.where((n) => n.id != id).toList();
    SyncService.instance.syncAll();
  }
}

final notesProvider = NotifierProvider<NotesNotifier, List<NoteItem>>(
  NotesNotifier.new,
);

final filteredNotesProvider = Provider<List<NoteItem>>((ref) {
  final notes = ref.watch(notesProvider);
  final query = ref.watch(notesSearchQueryProvider).trim().toLowerCase();
  final selectedTag = ref.watch(notesSelectedTagProvider);

  return notes.where((note) {
    final matchesQuery =
        query.isEmpty ||
        note.title.toLowerCase().contains(query) ||
        note.body.toLowerCase().contains(query);

    final matchesTag = selectedTag == null || note.tags.contains(selectedTag);

    return matchesQuery && matchesTag;
  }).toList();
});

final allNotesTagsProvider = Provider<List<String>>((ref) {
  final notes = ref.watch(notesProvider);
  final Set<String> tags = {};
  for (final n in notes) {
    tags.addAll(n.tags);
  }
  return tags.toList()..sort();
});
