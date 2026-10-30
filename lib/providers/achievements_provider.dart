import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'gamification_provider.dart';

enum AchievementCategory { all, habits, tasks, diary, budget, station }

class AchievementItem {
  final String key;
  final String title;
  final String description;
  final AchievementCategory category;
  final IconData icon;
  final Color color;
  final int expReward;
  final int targetValue;
  final int currentValue;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const AchievementItem({
    required this.key,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
    required this.expReward,
    required this.targetValue,
    this.currentValue = 0,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  double get progress =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  AchievementItem copyWith({
    int? currentValue,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return AchievementItem(
      key: key,
      title: title,
      description: description,
      category: category,
      icon: icon,
      color: color,
      expReward: expReward,
      targetValue: targetValue,
      currentValue: currentValue ?? this.currentValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

// Статический каталог космических наград
final List<AchievementItem> initialAchievementsList = [
  // 1. Привычки
  const AchievementItem(
    key: 'habit_first',
    title: 'Первая орбита',
    description: 'Закрыть любую привычку впервые',
    category: AchievementCategory.habits,
    icon: Icons.check_circle_outline,
    color: Color(0xFF10B981),
    expReward: 50,
    targetValue: 1,
  ),
  const AchievementItem(
    key: 'habit_streak_7',
    title: 'Гравитационный захват',
    description: 'Удерживать стрик привычки 7 дней',
    category: AchievementCategory.habits,
    icon: Icons.local_fire_department,
    color: Color(0xFFF59E0B),
    expReward: 150,
    targetValue: 7,
  ),
  const AchievementItem(
    key: 'habit_streak_21',
    title: 'Орбитальный автоматизм',
    description: 'Удерживать стрик привычки 21 день',
    category: AchievementCategory.habits,
    icon: Icons.flash_on,
    color: Color(0xFF8B5CF6),
    expReward: 350,
    targetValue: 21,
  ),

  // 2. Задачи
  const AchievementItem(
    key: 'task_first',
    title: 'Первый манёвр',
    description: 'Выполнить свою первую задачу',
    category: AchievementCategory.tasks,
    icon: Icons.task_alt,
    color: Color(0xFF38BDF8),
    expReward: 50,
    targetValue: 1,
  ),
  const AchievementItem(
    key: 'tasks_10',
    title: 'Командный мостик',
    description: 'Закрыть 10 задач в списке',
    category: AchievementCategory.tasks,
    icon: Icons.assignment_turned_in,
    color: Color(0xFF3B82F6),
    expReward: 100,
    targetValue: 10,
  ),
  const AchievementItem(
    key: 'tasks_50',
    title: 'Трудоголик космофлота',
    description: 'Выполнить 50 задач за все время',
    category: AchievementCategory.tasks,
    icon: Icons.military_tech,
    color: Color(0xFFEC4899),
    expReward: 300,
    targetValue: 50,
  ),

  // 3. Дневник
  const AchievementItem(
    key: 'diary_first',
    title: 'Бортовой журнал',
    description: 'Сделать первую запись в дневнике',
    category: AchievementCategory.diary,
    icon: Icons.auto_stories,
    color: Color(0xFF8B5CF6),
    expReward: 50,
    targetValue: 1,
  ),
  const AchievementItem(
    key: 'diary_7',
    title: 'Летописец экспедиции',
    description: 'Написать 7 записей в дневник',
    category: AchievementCategory.diary,
    icon: Icons.history_edu,
    color: Color(0xFFA855F7),
    expReward: 200,
    targetValue: 7,
  ),

  // 4. Бюджет
  const AchievementItem(
    key: 'budget_first',
    title: 'Учёт топлива',
    description: 'Внести первую финансовую операцию',
    category: AchievementCategory.budget,
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF10B981),
    expReward: 50,
    targetValue: 1,
  ),
  const AchievementItem(
    key: 'budget_20',
    title: 'Бортовой бухгалтер',
    description: 'Зафиксировать 20 транзакций бюджета',
    category: AchievementCategory.budget,
    icon: Icons.savings_outlined,
    color: Color(0xFFF59E0B),
    expReward: 150,
    targetValue: 20,
  ),

  // 5. Станция
  const AchievementItem(
    key: 'station_lvl_3',
    title: 'Офицер станции',
    description: 'Достичь 3 ранга на Орбитальной станции',
    category: AchievementCategory.station,
    icon: Icons.shield_outlined,
    color: Color(0xFF38BDF8),
    expReward: 200,
    targetValue: 3,
  ),
  const AchievementItem(
    key: 'station_lvl_5',
    title: 'Командор Орбиты',
    description: 'Достичь 5 ранга на Орбитальной станции',
    category: AchievementCategory.station,
    icon: Icons.workspace_premium,
    color: Colors.amber,
    expReward: 500,
    targetValue: 5,
  ),
];

class AchievementsNotifier extends Notifier<List<AchievementItem>> {
  static const _uuid = Uuid();

  @override
  List<AchievementItem> build() {
    // Подключаем мгновенное обновление UI при облачном синке
    SyncService.instance.onAchievementsPulled = () => loadAchievements();
    loadAchievements();
    return initialAchievementsList;
  }

  Future<void> loadAchievements() async {
    final db = await DatabaseService.instance.database;

    final rows = await db.query('user_achievements');
    final dbMap = {for (final r in rows) r['achievement_key'] as String: r};

    final list = initialAchievementsList.map((item) {
      if (dbMap.containsKey(item.key)) {
        final r = dbMap[item.key]!;
        return item.copyWith(
          currentValue: r['current_value'] as int? ?? 0,
          isUnlocked: (r['is_unlocked'] as int? ?? 0) == 1,
          unlockedAt: r['unlocked_at'] != null
              ? DateTime.tryParse(r['unlocked_at'] as String)
              : null,
        );
      }
      return item;
    }).toList();

    state = list;
    checkAllProgress();
  }

  /// Проверяет прогресс по всем разделам и разблокирует ачивки
  Future<void> checkAllProgress() async {
    final db = await DatabaseService.instance.database;
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'local_user';

    // 1. Привычки: макс. стрик и кол-во закрытых
    final logCountRes = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM habit_logs WHERE completed = 1',
    );
    final habitLogsCount = Sqflite.firstIntValue(logCountRes) ?? 0;

    final streakRes = await db.rawQuery(
      'SELECT MAX(streak) as max_streak FROM habits',
    );
    final maxStreak = Sqflite.firstIntValue(streakRes) ?? 0;

    // 2. Задачи: выполненные
    final tasksDoneRes = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM tasks WHERE done = 1',
    );
    final completedTasksCount = Sqflite.firstIntValue(tasksDoneRes) ?? 0;

    // 3. Дневник: число нечерновых записей
    final diaryRes = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM diaries WHERE is_draft = 0',
    );
    final diaryCount = Sqflite.firstIntValue(diaryRes) ?? 0;

    // 4. Бюджет: число транзакций
    final budgetRes = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM budget_transactions',
    );
    final txCount = Sqflite.firstIntValue(budgetRes) ?? 0;

    // 5. Станция: уровень
    final gamification = ref.read(gamificationProvider);
    final userLevel = gamification.rank.level;

    final updated = <AchievementItem>[];
    bool hasNewUnlocks = false;

    for (final item in state) {
      int curVal = item.currentValue;

      switch (item.key) {
        case 'habit_first':
          curVal = habitLogsCount;
          break;
        case 'habit_streak_7':
        case 'habit_streak_21':
          curVal = maxStreak;
          break;
        case 'task_first':
        case 'tasks_10':
        case 'tasks_50':
          curVal = completedTasksCount;
          break;
        case 'diary_first':
        case 'diary_7':
          curVal = diaryCount;
          break;
        case 'budget_first':
        case 'budget_20':
          curVal = txCount;
          break;
        case 'station_lvl_3':
        case 'station_lvl_5':
          curVal = userLevel;
          break;
      }

      final shouldUnlock = !item.isUnlocked && (curVal >= item.targetValue);
      final isNowUnlocked = item.isUnlocked || shouldUnlock;
      final unlockedDate = shouldUnlock ? DateTime.now() : item.unlockedAt;

      if (curVal != item.currentValue || shouldUnlock) {
        final nowIso = DateTime.now().toIso8601String();

        // Проверяем существующий ID, чтобы не плодить новые записи при обновлении
        final existingRow = await db.query(
          'user_achievements',
          where: 'achievement_key = ?',
          whereArgs: [item.key],
        );
        final recordId = existingRow.isNotEmpty
            ? existingRow.first['id'] as String
            : _uuid.v4();

        await db.insert('user_achievements', {
          'id': recordId,
          'user_id': userId,
          'achievement_key': item.key,
          'current_value': curVal,
          'target_value': item.targetValue,
          'is_unlocked': isNowUnlocked ? 1 : 0,
          'unlocked_at': unlockedDate?.toIso8601String(),
          'is_synced': 0,
          'updated_at': nowIso,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        if (shouldUnlock) {
          hasNewUnlocks = true;
          // Начисляем разовый бонус EXP в геймификацию
          ref
              .read(gamificationProvider.notifier)
              .addExp(ExpSource.task, item.expReward);
        }
      }

      updated.add(
        item.copyWith(
          currentValue: curVal,
          isUnlocked: isNowUnlocked,
          unlockedAt: unlockedDate,
        ),
      );
    }

    state = updated;

    if (hasNewUnlocks) {
      SyncService.instance.syncAll();
    }
  }
}

final achievementsProvider =
    NotifierProvider<AchievementsNotifier, List<AchievementItem>>(
      AchievementsNotifier.new,
    );
