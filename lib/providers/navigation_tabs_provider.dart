import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../services/database_service.dart';

enum AppTabKey {
  calendar,
  tasks,
  habits,
  notes,
  diary,
  shifts,
  vault,
  budget,
  station,
}

class AppTabMeta {
  final AppTabKey key;
  final String title;
  final String assetIcon;
  final String fallbackIconName;

  const AppTabMeta({
    required this.key,
    required this.title,
    required this.assetIcon,
    required this.fallbackIconName,
  });
}

// Доступные для настройки разделы
const List<AppTabMeta> kAllAvailableTabs = [
  AppTabMeta(
    key: AppTabKey.calendar,
    title: 'Календарь',
    assetIcon: 'assets/icons/norm/calendar.svg',
    fallbackIconName: 'calendar_today',
  ),
  AppTabMeta(
    key: AppTabKey.tasks,
    title: 'Задачи',
    assetIcon: 'assets/icons/norm/tasks.svg',
    fallbackIconName: 'check_circle',
  ),
  AppTabMeta(
    key: AppTabKey.habits,
    title: 'Привычки',
    assetIcon: 'assets/icons/norm/habbits.svg',
    fallbackIconName: 'repeat',
  ),
  AppTabMeta(
    key: AppTabKey.notes,
    title: 'Заметки',
    assetIcon: 'assets/icons/norm/notes.svg',
    fallbackIconName: 'description',
  ),
  AppTabMeta(
    key: AppTabKey.diary,
    title: 'Дневник',
    assetIcon: 'assets/icons/norm/Diary.svg',
    fallbackIconName: 'book',
  ),
  AppTabMeta(
    key: AppTabKey.shifts,
    title: 'График смен',
    assetIcon: 'assets/icons/norm/bag.svg',
    fallbackIconName: 'work',
  ),
  AppTabMeta(
    key: AppTabKey.vault,
    title: 'Сейф',
    assetIcon: 'assets/icons/norm/vault.svg',
    fallbackIconName: 'shield',
  ),
  AppTabMeta(
    key: AppTabKey.budget,
    title: 'Бюджет',
    assetIcon: 'assets/icons/norm/buget.svg',
    fallbackIconName: 'account_balance_wallet',
  ),
  AppTabMeta(
    key: AppTabKey.station,
    title: 'Орбитальная станция',
    assetIcon: 'assets/icons/norm/orbital.svg',
    fallbackIconName: 'radar',
  ),
];

// Закрепленный строгий порядок для рабочих экранов в боковом меню
const List<AppTabKey> kDrawerOrderList = [
  AppTabKey.calendar,
  AppTabKey.tasks,
  AppTabKey.habits,
  AppTabKey.notes,
  AppTabKey.diary,
  AppTabKey.shifts,
  AppTabKey.vault,
  AppTabKey.budget,
];

class NavigationTabsNotifier extends Notifier<List<AppTabKey>> {
  static const _prefKey = 'bottom_navigation_tabs_custom_v2';

  static const List<AppTabKey> defaultTabs = [
    AppTabKey.calendar,
    AppTabKey.tasks,
    AppTabKey.habits,
    AppTabKey.notes,
  ];

  @override
  List<AppTabKey> build() {
    _loadFromDb();
    return defaultTabs;
  }

  Future<void> _loadFromDb() async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [_prefKey],
      );

      if (rows.isNotEmpty) {
        final rawJson = rows.first['value'] as String?;
        if (rawJson != null && rawJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(rawJson);
          final loaded = decoded
              .map(
                (str) =>
                    AppTabKey.values.where((k) => k.name == str).firstOrNull,
              )
              .whereType<AppTabKey>()
              .toList();

          if (loaded.isNotEmpty) {
            state = loaded;
          }
        }
      }
    } catch (_) {}
  }

  Future<bool> toggleTab(AppTabKey key) async {
    final current = List<AppTabKey>.from(state);
    if (current.contains(key)) {
      if (current.length <= 1) {
        return false;
      }
      current.remove(key);
    } else {
      if (current.length >= 4) {
        return false;
      }
      current.add(key);
    }

    state = current;
    await _saveToDb(current);
    return true;
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final current = List<AppTabKey>.from(state);
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);

    state = current;
    await _saveToDb(current);
  }

  Future<void> resetToDefaults() async {
    state = defaultTabs;
    await _saveToDb(defaultTabs);
  }

  Future<void> _saveToDb(List<AppTabKey> keys) async {
    final db = await DatabaseService.instance.database;
    final jsonStr = jsonEncode(keys.map((k) => k.name).toList());
    await db.insert('app_settings', {
      'key': _prefKey,
      'value': jsonStr,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

final navigationTabsProvider =
    NotifierProvider<NavigationTabsNotifier, List<AppTabKey>>(
      NavigationTabsNotifier.new,
    );

// Селектор: берет строгий порядок kDrawerOrderList и исключает те вкладки,
// которые в данный момент уже отображаются в нижнем меню
final drawerTabsProvider = Provider<List<AppTabMeta>>((ref) {
  final activeBottomTabs = ref.watch(navigationTabsProvider);

  return kDrawerOrderList
      .where((key) => !activeBottomTabs.contains(key))
      .map((key) => kAllAvailableTabs.firstWhere((meta) => meta.key == key))
      .toList();
});
