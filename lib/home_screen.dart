import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'providers/budget_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/habits_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/tasks_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  final VoidCallback onOpenCreateTask;
  final VoidCallback onOpenCreateEvent;
  final VoidCallback onOpenCreateHabit;
  final VoidCallback onOpenBudget;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onOpenCreateTask,
    required this.onOpenCreateEvent,
    required this.onOpenCreateHabit,
    required this.onOpenBudget,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late String _randomQuote;

  static const List<String> _quotes = [
    'Фокусируйся на процессе сегодня, и результат не заставит себя ждать.',
    'Маленькие шаги каждый день приводят к большим целям.',
    'Порядок в мыслях начинается с порядка в планах.',
    'Дисциплина — это мост между целями и достижениями.',
    'Каждый новый день — это чистый лист на твоей Орбите.',
    'Секрет продуктивности — не делать больше, а убирать лишнее.',
  ];

  @override
  void initState() {
    super.initState();
    _randomQuote = _quotes[Random().nextInt(_quotes.length)];
  }

  Widget _buildSvgIcon(String path, {double size = 18, Color? color}) {
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color, BlendMode.srcIn)
          : null,
      placeholderBuilder: (_) => Icon(Icons.add, size: size, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    final profile = ref.watch(profileProvider);
    final allTasks = ref.watch(tasksProvider);
    final allEvents = ref.watch(calendarProvider);
    final habits = ref.watch(habitsProvider);
    final budgetState = ref.watch(budgetProvider);

    final todayTasks = allTasks.where((t) {
      if (t['isNoDate'] == true || t['date'] == null) return false;
      final d = t['date'];
      if (d is DateTime) {
        return d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      }
      return false;
    }).toList();

    final todayEvents = allEvents.where((e) {
      final d = e['date'];
      if (d is DateTime) {
        return d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      }
      return false;
    }).toList();

    final Color textPrimary = widget.isDarkMode
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final Color textSecondary = widget.isDarkMode
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final Color borderColor = widget.isDarkMode
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Приветствие и дни
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Привет, ${profile.userName}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Дней с Орбитой: ${profile.daysWithOrbita}',
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. Блок цитаты
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.format_quote,
                size: 18,
                color: Color(0xFF38BDF8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _randomQuote,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Блок "Календарь и Задачи"
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Левая колонка: Календарь
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Календарь',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          InkWell(
                            onTap: widget.onOpenCreateEvent,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: _buildSvgIcon(
                                'assets/icons/plus.svg',
                                size: 16,
                                color: const Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (todayEvents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Событий нет',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        ...todayEvents.map(
                          (ev) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ev['title'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  ev['isAllDay'] == true
                                      ? 'Весь день'
                                      : '${ev['startTime'] ?? '00:00'} - ${ev['endTime'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Разделитель
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 1,
                  color: borderColor,
                ),

                // Правая колонка: Задачи
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Задачи',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          InkWell(
                            onTap: widget.onOpenCreateTask,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: _buildSvgIcon(
                                'assets/icons/plus.svg',
                                size: 16,
                                color: const Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (todayTasks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Задач нет',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        ...todayTasks.map((t) {
                          final isDone = t['done'] == true;
                          final isAllDay = t['isAllDay'] == true;
                          final time = t['time'];

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: isDone,
                                    onChanged: (v) {
                                      ref
                                          .read(tasksProvider.notifier)
                                          .toggleTask(
                                            t['id'].toString(),
                                            v ?? false,
                                          );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t['title'] ?? '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDone
                                              ? textSecondary
                                              : textPrimary,
                                          decoration: isDone
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (!isAllDay && time != null)
                                        Text(
                                          '⏱ $time',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isDone
                                                ? textSecondary
                                                : const Color(0xFF38BDF8),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Блок "Привычки"
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Привычки',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  InkWell(
                    onTap: widget.onOpenCreateHabit,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: _buildSvgIcon(
                        'assets/icons/plus.svg',
                        size: 16,
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (habits.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Привычек пока нет. Нажмите +, чтобы добавить!',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    final now = DateTime.now();
                    final todayStr =
                        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

                    return Row(
                      children: habits.take(3).map((h) {
                        final itemColor = h.color;
                        final isDone = h.isCompletedOn(todayStr);

                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              ref
                                  .read(habitsProvider.notifier)
                                  .toggleHabit(h.id);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: itemColor.withValues(
                                  alpha: isDone ? 0.25 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDone ? itemColor : borderColor,
                                  width: isDone ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    isDone
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    size: 20,
                                    color: itemColor,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    h.title,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${h.streak} дн.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5. Блок "Финансы"
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Финансы',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: widget.onOpenBudget,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C69D1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Бюджет',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Свободный баланс: ${budgetState.balance.toStringAsFixed(0)} ₽',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: budgetState.balance >= 0
                      ? const Color(0xFF38BDF8)
                      : Colors.redAccent,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Доходы: +${budgetState.totalIncome.toStringAsFixed(0)} ₽',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Расходы: -${budgetState.totalExpense.toStringAsFixed(0)} ₽',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
