import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rank_model.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

enum ExpSource { habit, diary, budget, task }

class GamificationState {
  final int totalExp;
  final int weeklyExp;
  final int habitsExp;
  final int diaryExp;
  final int budgetExp;
  final int tasksExp;
  final bool isLoading;

  const GamificationState({
    this.totalExp = 0,
    this.weeklyExp = 0,
    this.habitsExp = 0,
    this.diaryExp = 0,
    this.budgetExp = 0,
    this.tasksExp = 0,
    this.isLoading = true,
  });

  RankTierInfo get rank => RankCalculator.getRankByExp(totalExp);
  double get progress => RankCalculator.getProgress(totalExp);

  GamificationState copyWith({
    int? totalExp,
    int? weeklyExp,
    int? habitsExp,
    int? diaryExp,
    int? budgetExp,
    int? tasksExp,
    bool? isLoading,
  }) {
    return GamificationState(
      totalExp: totalExp ?? this.totalExp,
      weeklyExp: weeklyExp ?? this.weeklyExp,
      habitsExp: habitsExp ?? this.habitsExp,
      diaryExp: diaryExp ?? this.diaryExp,
      budgetExp: budgetExp ?? this.budgetExp,
      tasksExp: tasksExp ?? this.tasksExp,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class GamificationNotifier extends Notifier<GamificationState> {
  @override
  GamificationState build() {
    // Подключаем коллбэк для SyncService, чтобы при синке облака состояние обновлялось моментально
    SyncService.instance.onGamificationPulled = () => loadData();
    loadData();
    return const GamificationState();
  }

  Future<void> loadData() async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.query('user_gamification', limit: 1);

      if (rows.isNotEmpty) {
        final r = rows.first;
        final lastResetStr = r['last_week_reset'] as String?;
        int weekly = r['weekly_exp'] as int? ?? 0;

        // Проверка сброса недели (каждый понедельник)
        final now = DateTime.now();
        DateTime? lastReset = lastResetStr != null
            ? DateTime.tryParse(lastResetStr)
            : null;
        if (lastReset == null ||
            now.difference(lastReset).inDays >= 7 ||
            (now.weekday == DateTime.monday && lastReset.day != now.day)) {
          weekly = 0;
          await db.update('user_gamification', {
            'weekly_exp': 0,
            'last_week_reset': now.toIso8601String(),
          });
        }

        state = GamificationState(
          totalExp: r['total_exp'] as int? ?? 0,
          weeklyExp: weekly,
          habitsExp: r['habits_exp'] as int? ?? 0,
          diaryExp: r['diary_exp'] as int? ?? 0,
          budgetExp: r['budget_exp'] as int? ?? 0,
          tasksExp: r['tasks_exp'] as int? ?? 0,
          isLoading: false,
        );
      } else {
        final user = Supabase.instance.client.auth.currentUser;
        final userId = user?.id ?? 'local_user';
        final nowIso = DateTime.now().toIso8601String();

        await db.insert('user_gamification', {
          'user_id': userId,
          'total_exp': 0,
          'weekly_exp': 0,
          'last_week_reset': nowIso,
          'habits_exp': 0,
          'diary_exp': 0,
          'budget_exp': 0,
          'tasks_exp': 0,
          'is_synced': 0,
          'updated_at': nowIso,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        state = const GamificationState(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> addExp(ExpSource source, int amount) async {
    if (amount <= 0) return;

    final newTotal = state.totalExp + amount;
    final newWeekly = state.weeklyExp + amount;

    int newHabits = state.habitsExp;
    int newDiary = state.diaryExp;
    int newBudget = state.budgetExp;
    int newTasks = state.tasksExp;

    switch (source) {
      case ExpSource.habit:
        newHabits += amount;
        break;
      case ExpSource.diary:
        newDiary += amount;
        break;
      case ExpSource.budget:
        newBudget += amount;
        break;
      case ExpSource.task:
        newTasks += amount;
        break;
    }

    state = state.copyWith(
      totalExp: newTotal,
      weeklyExp: newWeekly,
      habitsExp: newHabits,
      diaryExp: newDiary,
      budgetExp: newBudget,
      tasksExp: newTasks,
    );

    await _persistExp(
      newTotal,
      newWeekly,
      newHabits,
      newDiary,
      newBudget,
      newTasks,
    );
  }

  Future<void> removeExp(ExpSource source, int amount) async {
    if (amount <= 0) return;

    final newTotal = (state.totalExp - amount).clamp(0, 9999999);
    final newWeekly = (state.weeklyExp - amount).clamp(0, 9999999);

    int newHabits = state.habitsExp;
    int newDiary = state.diaryExp;
    int newBudget = state.budgetExp;
    int newTasks = state.tasksExp;

    switch (source) {
      case ExpSource.habit:
        newHabits = (newHabits - amount).clamp(0, 9999999);
        break;
      case ExpSource.diary:
        newDiary = (newDiary - amount).clamp(0, 9999999);
        break;
      case ExpSource.budget:
        newBudget = (newBudget - amount).clamp(0, 9999999);
        break;
      case ExpSource.task:
        newTasks = (newTasks - amount).clamp(0, 9999999);
        break;
    }

    state = state.copyWith(
      totalExp: newTotal,
      weeklyExp: newWeekly,
      habitsExp: newHabits,
      diaryExp: newDiary,
      budgetExp: newBudget,
      tasksExp: newTasks,
    );

    await _persistExp(
      newTotal,
      newWeekly,
      newHabits,
      newDiary,
      newBudget,
      newTasks,
    );
  }

  Future<void> _persistExp(
    int total,
    int weekly,
    int habits,
    int diary,
    int budget,
    int tasks,
  ) async {
    try {
      final db = await DatabaseService.instance.database;
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id ?? 'local_user';
      final nowIso = DateTime.now().toIso8601String();

      await db.insert('user_gamification', {
        'user_id': userId,
        'total_exp': total,
        'weekly_exp': weekly,
        'last_week_reset': nowIso,
        'habits_exp': habits,
        'diary_exp': diary,
        'budget_exp': budget,
        'tasks_exp': tasks,
        'is_synced': 0,
        'updated_at': nowIso,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      SyncService.instance.syncAll();
    } catch (_) {}
  }
}

final gamificationProvider =
    NotifierProvider<GamificationNotifier, GamificationState>(
      GamificationNotifier.new,
    );
