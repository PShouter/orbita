import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/habits_provider.dart';
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
    final habits = ref.watch(habitsProvider);
    final habit = habits.where((h) => h.id == widget.habitId).firstOrNull;

    if (habit == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text(
            'Привычка не найдена',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final streaks = _calculateStreaks(habit);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          habit.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined, color: Colors.white70),
            tooltip: 'В архив',
            onPressed: () {
              ref.read(habitsProvider.notifier).archiveHabit(habit.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Привычка "${habit.title}" перенесена в архив'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white70),
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
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Удалить',
            onPressed: () => _showDeleteConfirm(context, habit),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (habit.question != null && habit.question!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.help_outline, color: habit.color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      habit.question!,
                      style: const TextStyle(
                        color: Colors.white70,
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
                  iconColor: Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Рекорд стрика',
                  value: '${streaks.best} дн.',
                  icon: Icons.emoji_events_outlined,
                  iconColor: Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Сила (30 дн)',
                  value: '${(habit.score30Days * 100).round()}%',
                  icon: Icons.trending_up,
                  iconColor: habit.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildMonthCalendar(habit),
          const SizedBox(height: 20),

          _buildInfoSection(habit),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar(HabitItem habit) {
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
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
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
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),

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
                borderRadius: BorderRadius.circular(8),
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
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(color: const Color(0xFF38BDF8), width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      color: isDone ? Colors.white : Colors.white70,
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

  Widget _buildInfoSection(HabitItem habit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Информация',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _infoRow(
            'Тип',
            habit.type == 'numerical'
                ? 'Измеримая (${habit.targetValue} ${habit.unit ?? ""})'
                : 'Да / Нет',
          ),
          _infoRow('Частота', _formatFrequency(habit)),
          if (habit.reminderTime != null)
            _infoRow('Напоминание', habit.reminderTime!),
          if (habit.description != null && habit.description!.isNotEmpty)
            _infoRow('Заметки', habit.description!),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
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

  void _showDeleteConfirm(BuildContext context, HabitItem habit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Удалить привычку?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Привычка "${habit.title}" и вся история ее выполнения будут удалены.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              ref.read(habitsProvider.notifier).deleteHabit(habit.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
