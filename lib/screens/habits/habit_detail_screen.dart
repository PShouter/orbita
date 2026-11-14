import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/habits_provider.dart';
import '../../theme/app_theme.dart';
import 'habit_edit_screen.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  final String habitId;

  const HabitDetailScreen({super.key, required this.habitId});

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final habits = ref.watch(habitsProvider);
    final habit = habits.where((h) => h.id == widget.habitId).firstOrNull;

    if (habit == null) {
      return Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(
          backgroundColor: colors.bg,
          iconTheme: IconThemeData(color: colors.text),
        ),
        body: Center(
          child: Text(
            'Привычка не найдена',
            style: TextStyle(
              fontFamily: 'Onest',
              color: colors.text.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final streaks = _calculateStreaks(habit);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          habit.title,
          style: TextStyle(
            fontFamily: 'Unbounded',
            color: colors.text,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: colors.text),
        actions: [
          IconButton(
            icon: Icon(
              Icons.archive_outlined,
              color: colors.text.withValues(alpha: 0.6),
            ),
            tooltip: 'В архив',
            onPressed: () {
              ref.read(habitsProvider.notifier).archiveHabit(habit.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Привычка "${habit.title}" перенесена в архив',
                    style: const TextStyle(fontFamily: 'Onest'),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: colors.text.withValues(alpha: 0.6),
            ),
            tooltip: 'Редактировать',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      HabitEditScreen(type: habit.type, initialHabit: habit),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.error),
            tooltip: 'Удалить',
            onPressed: () => _showDeleteConfirm(context, habit, colors),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (habit.question != null && habit.question!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.nested),
              ),
              child: Row(
                children: [
                  Icon(Icons.help_outline, color: habit.color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      habit.question!,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Текущий стрик',
                  value: '${streaks.current} дн.',
                  icon: Icons.local_fire_department,
                  iconColor: colors.warning,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: 'Рекорд стрика',
                  value: '${streaks.best} дн.',
                  icon: Icons.emoji_events_outlined,
                  iconColor: Colors.amber,
                  colors: colors,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: 'Сила (30 дн)',
                  value: '${(habit.score30Days * 100).round()}%',
                  icon: Icons.trending_up,
                  iconColor: habit.color,
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMonthCalendar(habit, colors),
          const SizedBox(height: 16),
          _buildInfoSection(habit, colors),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required AppColorsExtension colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.nested),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Unbounded',
              color: colors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Onest',
              color: colors.text.withValues(alpha: 0.5),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar(HabitItem habit, AppColorsExtension colors) {
    final monthFormat = DateFormat('LLLL yyyy', 'ru');
    final titleMonth = monthFormat.format(_currentMonth);

    final daysInMonth = DateUtils.getDaysInMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
    final firstWeekday = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    ).weekday;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.nested),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: colors.text),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month - 1,
                      1,
                    );
                  });
                },
              ),
              Text(
                titleMonth[0].toUpperCase() + titleMonth.substring(1),
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  color: colors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: colors.text),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month + 1,
                      1,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                .map(
                  (d) => Text(
                    d,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - (firstWeekday - 1) + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox();
              }

              final cellDate = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                dayNumber,
              );
              final dateStr =
                  "${cellDate.year}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}";
              final isDone = habit.isCompletedOn(dateStr);
              final isToday = DateUtils.isSameDay(cellDate, DateTime.now());

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (habit.type == 'numerical') {
                    final newVal = isDone ? 0.0 : habit.targetValue;
                    ref
                        .read(habitsProvider.notifier)
                        .setNumericalValue(habit.id, dateStr, newVal);
                  } else {
                    ref
                        .read(habitsProvider.notifier)
                        .toggleHabitDay(habit.id, dateStr);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDone
                        ? habit.color
                        : colors.nested.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: isToday
                        ? Border.all(color: colors.accent, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: isDone
                          ? (ThemeData.estimateBrightnessForColor(
                                      habit.color) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black)
                          : colors.text.withValues(alpha: 0.8),
                      fontWeight: isDone || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(HabitItem habit, AppColorsExtension colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.nested),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Информация',
            style: TextStyle(
              fontFamily: 'Unbounded',
              color: colors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _infoRow(
            'Тип',
            habit.type == 'numerical'
                ? 'Измеримая (${habit.targetValue} ${habit.unit ?? ""})'
                : 'Да / Нет',
            colors,
          ),
          _infoRow('Частота', _formatFrequency(habit), colors),
          if (habit.reminderTime != null)
            _infoRow('Напоминание', habit.reminderTime!, colors),
          if (habit.description != null && habit.description!.isNotEmpty)
            _infoRow('Заметки', habit.description!, colors),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, AppColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Onest',
                color: colors.text.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Onest',
                color: colors.text,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFrequency(HabitItem habit) {
    if (habit.frequencyType == 'daily') return 'Каждый день';
    if (habit.frequencyType == 'x_per_week' ||
        habit.frequencyType == 'z_per_week') {
      return '${habit.frequencyCount} раз в неделю';
    }
    if (habit.frequencyType == 'z_per_month') {
      return '${habit.frequencyCount} раз в месяц';
    }
    if (habit.frequencyType == 'every_n_days') {
      return 'Каждые ${habit.frequencyCount} дн.';
    }
    if (habit.frequencyType == 'z_in_n_days') {
      final n = habit.frequencyDays.isNotEmpty ? habit.frequencyDays.first : 7;
      return '${habit.frequencyCount} раз в $n дн.';
    }
    if (habit.frequencyType == 'specific_days') {
      const names = {
        1: 'Пн',
        2: 'Вт',
        3: 'Ср',
        4: 'Чт',
        5: 'Пт',
        6: 'Сб',
        7: 'Вс',
      };
      return habit.frequencyDays.map((d) => names[d] ?? '').join(', ');
    }
    return 'По расписанию';
  }

  ({int current, int best}) _calculateStreaks(HabitItem habit) {
    final now = DateTime.now();
    int current = 0;
    int best = 0;
    int running = 0;

    DateTime cursor = now;
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    if (!habit.isCompletedOn(todayStr)) {
      cursor = now.subtract(const Duration(days: 1));
    }

    while (true) {
      final dStr =
          "${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}";
      if (habit.isCompletedOn(dStr)) {
        current++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    for (int i = 180; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dStr =
          "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
      if (habit.isCompletedOn(dStr)) {
        running++;
        if (running > best) best = running;
      } else {
        running = 0;
      }
    }

    return (current: current, best: best > current ? best : current);
  }

  void _showDeleteConfirm(
    BuildContext context,
    HabitItem habit,
    AppColorsExtension colors,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Удалить привычку?',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: Text(
          'Привычка "${habit.title}" и вся история ее выполнения будут удалены.',
          style: TextStyle(
            fontFamily: 'Onest',
            color: colors.text.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(
                fontFamily: 'Onest',
                color: colors.text.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              ref.read(habitsProvider.notifier).deleteHabit(habit.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text(
              'Удалить',
              style: TextStyle(
                fontFamily: 'Onest',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
