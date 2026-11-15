import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../providers/budget_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/habits_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../data/motivation_quotes.dart';
import '../../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _randomQuote = kMotivationQuotes[Random().nextInt(kMotivationQuotes.length)];
  }

  Widget _buildSvgIcon(String path, {double size = 18, Color? color}) {
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter:
          color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
      placeholderBuilder: (_) => Icon(Icons.add, size: size, color: color),
    );
  }

  static const List<String> _weekdays = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  static const List<String> _months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  String _formatToday() {
    final now = DateTime.now();
    final weekday =
        _weekdays[now.weekday - DateTime.monday]; // weekday: 1..7
    final month = _months[now.month - 1];
    return '$weekday, ${now.day} $month';
  }

  Widget _buildShiftBadge(ShiftType? todayShift, AppColorsExtension colors) {
    if (todayShift == null) return const SizedBox.shrink();

    final shiftColor = Color(todayShift.color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: shiftColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: shiftColor.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            todayShift.isWork
                ? (todayShift.isNightShift
                    ? Icons.nights_stay
                    : Icons.work_outline)
                : Icons.beach_access,
            size: 14,
            color: shiftColor,
          ),
          const SizedBox(width: 6),
          Text(
            todayShift.isWork && todayShift.startTime.isNotEmpty
                ? '${todayShift.name} (${todayShift.startTime}-${todayShift.endTime})'
                : todayShift.name,
            style: TextStyle(
              fontFamily: 'Onest',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: shiftColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyFocusCard({
    required List focusTasks,
    required ShiftType? todayShift,
    required AppColorsExtension colors,
  }) {
    if (focusTasks.isEmpty) return const SizedBox.shrink();

    final Map<String, dynamic> mainTask = Map<String, dynamic>.from(
      focusTasks.first as Map,
    );
    final isDone = mainTask['done'] == true;
    final priority =
        (mainTask['priority'] as String? ?? 'normal').toLowerCase();
    final time = mainTask['time'] as String?;
    final isShiftOverlap = todayShift != null && todayShift.isWork && !isDone;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(21),
                topRight: Radius.circular(21),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.gps_fixed, size: 16, color: colors.accent),
                const SizedBox(width: 8),
                Text(
                  'ФОКУС ДНЯ',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: colors.accent,
                  ),
                ),
                const Spacer(),
                if (priority == 'high')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      'Высокий приоритет',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isDone,
                        activeColor: colors.accent,
                        checkColor: colors.isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        side: BorderSide(
                          color: colors.text.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        onChanged: (v) {
                          HapticFeedback.lightImpact();
                          ref.read(tasksProvider.notifier).toggleTask(
                                mainTask['id'].toString(),
                                v ?? false,
                              );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mainTask['title'] ?? '',
                            style: TextStyle(
                              fontFamily: 'Onest',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDone
                                  ? colors.text.withValues(alpha: 0.45)
                                  : colors.text,
                              decoration:
                                  isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (mainTask['description'] != null &&
                              (mainTask['description'] as String)
                                  .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              mainTask['description'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Onest',
                                fontSize: 13,
                                color: colors.text.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                          if (time != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 13,
                                  color: colors.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontFamily: 'Onest',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (isShiftOverlap) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: colors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: colors.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Сегодня смена: ${todayShift.name} (${todayShift.startTime}-${todayShift.endTime})',
                            style: TextStyle(
                              fontFamily: 'Onest',
                              fontSize: 11,
                              color: colors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final colors = context.colors;

    final userName = ref.watch(profileProvider.select((p) => p.userName));
    final daysWithOrbita = ref.watch(
      profileProvider.select((p) => p.daysWithOrbita),
    );
    final allTasks = ref.watch(tasksProvider);
    final allEvents = ref.watch(calendarProvider);
    final habits = ref.watch(habitsProvider);
    final freeMoney = ref.watch(budgetProvider.select((b) => b.freeMoney));
    final dailySafeLimit = ref.watch(
      budgetProvider.select((b) => b.dailySafeLimit),
    );
    final totalAccountsBalance = ref.watch(
      budgetProvider.select((b) => b.totalAccountsBalance),
    );

    final activeSchedule = ref.watch(
      shiftProvider.select((s) => s.activeSchedule),
    );
    final todayShift = activeSchedule?.getShiftForDate(today);

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

    final activeTodayTasks =
        todayTasks.where((t) => t['done'] != true).toList();
    activeTodayTasks.sort((a, b) {
      final aHigh = (a['priority'] == 'high') ? 1 : 0;
      final bHigh = (b['priority'] == 'high') ? 1 : 0;
      if (aHigh != bHigh) return bHigh.compareTo(aHigh);

      final aTime = a['time'] as String? ?? '99:99';
      final bTime = b['time'] as String? ?? '99:99';
      return aTime.compareTo(bTime);
    });

    final todayEvents = allEvents.where((e) {
      final d = e['date'];
      if (d is DateTime) {
        return d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      }
      return false;
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Привет, ${userName}',
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatToday(),
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.text.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Дней с Орбитой: ${daysWithOrbita}',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 13,
                      color: colors.text.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildShiftBadge(todayShift, colors),
          ],
        ),
        const SizedBox(height: 16),

        // Карточка цитаты
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.nested),
          ),
          child: Row(
            children: [
              Icon(
                Icons.format_quote,
                size: 20,
                color: colors.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _randomQuote,
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: colors.text.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Фокус дня
        _buildDailyFocusCard(
          focusTasks: activeTodayTasks,
          todayShift: todayShift,
          colors: colors,
        ),

        // Сдвоенная карточка: Календарь и Задачи
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.nested),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Колонка Календарь
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
                              fontFamily: 'Onest',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                          InkWell(
                            onTap: widget.onOpenCreateEvent,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: _buildSvgIcon(
                                'assets/icons/plus.svg',
                                size: 16,
                                color: colors.accent,
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
                              fontFamily: 'Onest',
                              color: colors.text.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        ...todayEvents.map(
                          (ev) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ev['title'] ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Onest',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ev['isAllDay'] == true
                                      ? 'Весь день'
                                      : '${ev['startTime'] ?? '00:00'} - ${ev['endTime'] ?? ''}',
                                  style: TextStyle(
                                    fontFamily: 'Onest',
                                    fontSize: 11,
                                    color: colors.text.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 1,
                  color: colors.nested,
                ),

                // Колонка Задачи
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
                              fontFamily: 'Onest',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                          InkWell(
                            onTap: widget.onOpenCreateTask,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: _buildSvgIcon(
                                'assets/icons/plus.svg',
                                size: 16,
                                color: colors.accent,
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
                              fontFamily: 'Onest',
                              color: colors.text.withValues(alpha: 0.5),
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
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: isDone,
                                    activeColor: colors.accent,
                                    checkColor: colors.isDark
                                        ? Colors.black
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    side: BorderSide(
                                      color: colors.text.withValues(alpha: 0.4),
                                    ),
                                    onChanged: (v) {
                                      HapticFeedback.lightImpact();
                                      ref
                                          .read(tasksProvider.notifier)
                                          .toggleTask(
                                            t['id'].toString(),
                                            v ?? false,
                                          );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t['title'] ?? '',
                                        style: TextStyle(
                                          fontFamily: 'Onest',
                                          fontSize: 13,
                                          color: isDone
                                              ? colors.text
                                                  .withValues(alpha: 0.45)
                                              : colors.text,
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
                                            fontFamily: 'Onest',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDone
                                                ? colors.text
                                                    .withValues(alpha: 0.45)
                                                : colors.accent,
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

        // Блок Привычки
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.nested),
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
                      fontFamily: 'Onest',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  InkWell(
                    onTap: widget.onOpenCreateHabit,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildSvgIcon(
                        'assets/icons/plus.svg',
                        size: 16,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (habits.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Привычек пока нет. Нажмите +, чтобы добавить!',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
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
                                vertical: 12,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: itemColor.withValues(
                                  alpha: isDone ? 0.25 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDone ? itemColor : colors.nested,
                                  width: isDone ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    isDone
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    size: 22,
                                    color: itemColor,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    h.title,
                                    style: TextStyle(
                                      fontFamily: 'Onest',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.text,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${h.streak} дн.',
                                    style: TextStyle(
                                      fontFamily: 'Onest',
                                      fontSize: 11,
                                      color: colors.text.withValues(alpha: 0.6),
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

        // Блок Финансы
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.nested),
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
                      fontFamily: 'Onest',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  FilledButton(
                    onPressed: widget.onOpenBudget,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor:
                          colors.isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      minimumSize: const Size(44, 36),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Бюджет',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Свободно: ${freeMoney.toStringAsFixed(0)} ₽',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color:
                      freeMoney >= 0 ? colors.accent : colors.error,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'На счетах: ${totalAccountsBalance.toStringAsFixed(0)} ₽',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 12,
                      color: colors.text.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'В день: ~${dailySafeLimit.toStringAsFixed(0)} ₽',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 12,
                      color: colors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
