import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';

class CalendarNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    loadEvents();
    return [];
  }

  Future<void> loadEvents() async {
    final db = await DatabaseService.instance.database;
    final res = await db.query('calendar_events', orderBy: 'date ASC');

    state = res.map((row) {
      final m = Map<String, dynamic>.from(row);
      m['date'] = DateTime.parse(m['date']);
      if (m['end_date'] != null) m['endDate'] = DateTime.parse(m['end_date']);
      m['startTime'] = m['start_time'];
      m['endTime'] = m['end_time'];
      m['isAllDay'] = m['is_all_day'] == 1;
      if (m['color'] != null) m['color'] = Color(m['color'] as int);
      return m;
    }).toList();
  }

  Future<void> addEvent(Map<String, dynamic> event) async {
    final db = await DatabaseService.instance.database;
    final now = DateTime.now().toIso8601String();
    final id = event['id'] ?? 'event_${DateTime.now().millisecondsSinceEpoch}';

    final row = {
      'id': id.toString(),
      'title': event['title'] ?? 'Событие',
      'date': (event['date'] as DateTime).toIso8601String(),
      'end_date': event['endDate'] is DateTime
          ? (event['endDate'] as DateTime).toIso8601String()
          : null,
      'start_time': event['startTime'],
      'end_time': event['endTime'],
      'is_all_day': event['isAllDay'] == true ? 1 : 0,
      'calendar': event['calendar'] ?? 'Основной',
      'color': event['color'] is Color
          ? (event['color'] as Color).toARGB32()
          : null,
      'description': event['desc'],
      'location': event['location'],
      'is_synced': 0,
      'updated_at': now,
    };

    await db.insert(
      'calendar_events',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await loadEvents();
    SyncService.instance.syncAll();
  }

  Future<void> deleteEvent(String eventId) async {
    final db = await DatabaseService.instance.database;
    await db.delete('calendar_events', where: 'id = ?', whereArgs: [eventId]);
    await db.insert('delete_queue', {
      'table_name': 'calendar_events',
      'record_id': eventId,
      'created_at': DateTime.now().toIso8601String(),
    });

    state = state.where((e) => e['id'].toString() != eventId).toList();
    SyncService.instance.syncAll();
  }
}

final calendarProvider =
    NotifierProvider<CalendarNotifier, List<Map<String, dynamic>>>(
      CalendarNotifier.new,
    );
