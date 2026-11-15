import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import 'gamification_provider.dart';

class DiaryMood {
  final String id;
  final String emoji;
  final String label;

  const DiaryMood({required this.id, required this.emoji, required this.label});
}

const List<DiaryMood> defaultMoods = [
  DiaryMood(id: 'great', emoji: '😄', label: 'Отлично'),
  DiaryMood(id: 'good', emoji: '😊', label: 'Хорошо'),
  DiaryMood(id: 'neutral', emoji: '😐', label: 'Нормально'),
  DiaryMood(id: 'tired', emoji: '🥱', label: 'Устал'),
  DiaryMood(id: 'sad', emoji: '😔', label: 'Грустно'),
  DiaryMood(id: 'angry', emoji: '😡', label: 'Злость'),
  DiaryMood(id: 'love', emoji: '🥰', label: 'Влюблен'),
  DiaryMood(id: 'anxious', emoji: '😰', label: 'Тревожно'),
];

const List<DiaryMood> minimalMoods = [
  DiaryMood(id: 'great', emoji: '😀', label: 'Отлично'),
  DiaryMood(id: 'good', emoji: '🙂', label: 'Хорошо'),
  DiaryMood(id: 'neutral', emoji: '😶', label: 'Нормально'),
  DiaryMood(id: 'tired', emoji: '😴', label: 'Устал'),
  DiaryMood(id: 'sad', emoji: '😢', label: 'Грустно'),
  DiaryMood(id: 'angry', emoji: '😠', label: 'Злость'),
];

const List<DiaryMood> vividMoods = [
  DiaryMood(id: 'great', emoji: '🤩', label: 'Восторг'),
  DiaryMood(id: 'good', emoji: '😃', label: 'Отлично'),
  DiaryMood(id: 'neutral', emoji: '😌', label: 'Спокойно'),
  DiaryMood(id: 'tired', emoji: '😪', label: 'Устал'),
  DiaryMood(id: 'sad', emoji: '😭', label: 'Грустно'),
  DiaryMood(id: 'angry', emoji: '😤', label: 'Злость'),
  DiaryMood(id: 'love', emoji: '😍', label: 'Влюблен'),
  DiaryMood(id: 'anxious', emoji: '😨', label: 'Тревожно'),
];

const Map<String, List<DiaryMood>> diaryMoodStyles = {
  'classic': defaultMoods,
  'minimal': minimalMoods,
  'vivid': vividMoods,
};

List<DiaryMood> getDiaryMoodStyle(String styleId) {
  return diaryMoodStyles[styleId] ?? defaultMoods;
}

class DiaryItem {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String mood;
  final List<String> images;
  final bool isDraft;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiaryItem({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.mood,
    this.images = const [],
    this.isDraft = false,
    required this.createdAt,
    required this.updatedAt,
  });

  DiaryMood get moodObject {
    return defaultMoods.firstWhere(
      (m) => m.id == mood,
      orElse: () =>
          const DiaryMood(id: 'neutral', emoji: '😐', label: 'Нормально'),
    );
  }

  DiaryItem copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? date,
    String? mood,
    List<String>? images,
    bool? isDraft,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiaryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      mood: mood ?? this.mood,
      images: images ?? this.images,
      isDraft: isDraft ?? this.isDraft,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DiarySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
}

final diarySearchQueryProvider =
    NotifierProvider<DiarySearchQueryNotifier, String>(
      DiarySearchQueryNotifier.new,
    );

class DiaryNotifier extends Notifier<List<DiaryItem>> {
  static const _uuid = Uuid();
  static const int _diaryNotificationId = 90001;

  @override
  List<DiaryItem> build() {
    loadDiaries();
    cleanExpiredDrafts();
    return [];
  }

  Future<void> loadEntries() => loadDiaries();

  Future<void> cleanExpiredDrafts() async {
    try {
      final db = await DatabaseService.instance.database;
      final threshold = DateTime.now()
          .subtract(const Duration(hours: 48))
          .toIso8601String();
      await db.delete(
        'diaries',
        where: 'is_draft = 1 AND created_at < ?',
        whereArgs: [threshold],
      );
    } catch (e) {
      debugPrint('Ошибка автоудаления черновиков: $e');
    }
  }

  Future<void> loadDiaries() async {
    try {
      final db = await DatabaseService.instance.database;

      await db.execute('''
        CREATE TABLE IF NOT EXISTS diaries (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          title TEXT,
          content TEXT,
          date TEXT NOT NULL,
          mood TEXT DEFAULT 'good',
          images TEXT,
          is_draft INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      final rows = await db.query(
        'diaries',
        orderBy: 'date DESC, created_at DESC',
      );

      final items = rows.map((r) {
        List<String> imgs = [];
        if (r['images'] != null && (r['images'] as String).isNotEmpty) {
          try {
            imgs = List<String>.from(jsonDecode(r['images'] as String));
          } catch (_) {}
        }

        return DiaryItem(
          id: r['id'] as String,
          title: r['title'] as String? ?? '',
          content: r['content'] as String? ?? '',
          date: DateTime.tryParse(r['date'] as String? ?? '') ?? DateTime.now(),
          mood: r['mood'] as String? ?? 'good',
          images: imgs,
          isDraft: (r['is_draft'] as int? ?? 0) == 1,
          createdAt:
              DateTime.tryParse(r['created_at'] as String? ?? '') ??
              DateTime.now(),
          updatedAt:
              DateTime.tryParse(r['updated_at'] as String? ?? '') ??
              DateTime.now(),
        );
      }).toList();

      state = items;
      _checkTodayDiaryNotification(items);
    } catch (e) {
      debugPrint('Ошибка загрузки дневников: $e');
    }
  }

  Future<String> saveDiary({
    String? id,
    required String title,
    required String content,
    required DateTime date,
    required String mood,
    List<String> images = const [],
    required bool isDraft,
  }) async {
    final db = await DatabaseService.instance.database;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final diaryId = id ?? _uuid.v4();

    DateTime createdAt = now;
    if (id != null) {
      final existing = state.where((d) => d.id == id).firstOrNull;
      if (existing != null) {
        createdAt = existing.createdAt;
      }
    }

    final row = {
      'id': diaryId,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
      'mood': mood,
      'images': jsonEncode(images),
      'is_draft': isDraft ? 1 : 0,
      'is_synced': 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': nowIso,
    };

    await db.insert(
      'diaries',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final newItem = DiaryItem(
      id: diaryId,
      title: title,
      content: content,
      date: date,
      mood: mood,
      images: images,
      isDraft: isDraft,
      createdAt: createdAt,
      updatedAt: now,
    );

    final existingIndex = state.indexWhere((d) => d.id == diaryId);
    List<DiaryItem> updatedList;
    if (existingIndex >= 0) {
      updatedList = List<DiaryItem>.from(state);
      updatedList[existingIndex] = newItem;
    } else {
      updatedList = [newItem, ...state];
    }
    state = updatedList;

    if (!isDraft) {
      ref.read(gamificationProvider.notifier).addExp(ExpSource.diary, 25);
    }

    if (!isDraft && _isSameDay(date, now)) {
      await NotificationService.instance.cancelNotification(
        _diaryNotificationId,
      );
    }

    try {
      SyncService.instance.syncAll();
    } catch (e) {
      debugPrint('Синхронизация дневника отложена: $e');
    }

    return diaryId;
  }

  Future<void> deleteDiary(String id) async {
    try {
      final db = await DatabaseService.instance.database;
      await db.delete('diaries', where: 'id = ?', whereArgs: [id]);

      await db.insert('delete_queue', {
        'table_name': 'diaries',
        'record_id': id,
        'created_at': DateTime.now().toIso8601String(),
      });

      final updated = state.where((d) => d.id != id).toList();
      state = updated;
      _checkTodayDiaryNotification(updated);

      SyncService.instance.syncAll();
    } catch (e) {
      debugPrint('Ошибка удаления дневника: $e');
    }
  }

  Future<void> _checkTodayDiaryNotification(List<DiaryItem> items) async {
    final now = DateTime.now();
    final hasEntryToday = items.any(
      (d) => !d.isDraft && _isSameDay(d.date, now),
    );

    if (!hasEntryToday) {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('diary_reminder_enabled') ?? true;
      if (!enabled) return;

      final timeStr = prefs.getString('diary_reminder_time') ?? '21:00';
      final parts = timeStr.split(':');
      final hour = int.tryParse(parts[0]) ?? 21;
      final minute = int.tryParse(parts[1]) ?? 0;

      await NotificationService.instance.scheduleDailyNotification(
        id: _diaryNotificationId,
        title: 'Дневник Орбиты',
        body: 'Как прошел твой день? Зафиксируй важные мысли и события.',
        hour: hour,
        minute: minute,
        payload: 'screen_diary',
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

final diaryProvider = NotifierProvider<DiaryNotifier, List<DiaryItem>>(
  DiaryNotifier.new,
);

final filteredDiariesProvider = Provider<List<DiaryItem>>((ref) {
  final diaries = ref.watch(diaryProvider);
  final query = ref.watch(diarySearchQueryProvider).trim().toLowerCase();

  if (query.isEmpty) return diaries;

  final dateFormat = DateFormat('dd.MM.yyyy', 'ru');
  final dateFullFormat = DateFormat('d MMMM yyyy', 'ru');

  return diaries.where((item) {
    final dateStr = dateFormat.format(item.date).toLowerCase();
    final dateFullStr = dateFullFormat.format(item.date).toLowerCase();
    final titleStr = item.title.toLowerCase();
    final contentStr = item.content.toLowerCase();

    return titleStr.contains(query) ||
        contentStr.contains(query) ||
        dateStr.contains(query) ||
        dateFullStr.contains(query);
  }).toList();
});
