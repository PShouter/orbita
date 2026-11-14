import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/habits_provider.dart';
import '../../theme/app_theme.dart';
import '../settings/sections/habit_settings_screen.dart';
import 'habit_archive_screen.dart';
import 'habit_detail_screen.dart';
import 'habit_edit_screen.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const HabitsScreen({super.key, this.isDarkMode = true});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  int _dayOffset = 0;
  static const int _visibleDaysCount = 5;

  double _dragDistance = 0.0;
  static const double _dragThreshold = 24.0;

  List<DateTime> _getVisibleDates(bool isReverse) {
    final today = DateTime.now();
    final List<DateTime> dates = [];
    if (isReverse) {
      for (int i = 0; i < _visibleDaysCount; i++) {
        dates.add(today.subtract(Duration(days: _dayOffset + i)));
      }
    } else {
      for (int i = _visibleDaysCount - 1; i >= 0; i--) {
        dates.add(today.subtract(Duration(days: _dayOffset + i)));
      }
    }
    return dates;
  }

  void _shiftDays(int delta) {
    final newOffset = (_dayOffset + delta).clamp(0, 365);
    if (newOffset != _dayOffset) {
      setState(() {
        _dayOffset = newOffset;
      });
      HapticFeedback.selectionClick();
    }
  }

  void _handleDragStart() {
    _dragDistance = 0.0;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragDistance += details.primaryDelta ?? 0.0;

    if (_dragDistance > _dragThreshold) {
      _shiftDays(1);
      _dragDistance = 0.0;
    } else if (_dragDistance < -_dragThreshold) {
      _shiftDays(-1);
      _dragDistance = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final habits = ref.watch(sortedHabitsProvider);
    final sortType = ref.watch(habitSortProvider);
    final isReverseDays = ref.watch(habitReverseDaysProvider);
    final visibleDates = _getVisibleDates(isReverseDays);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          'Привычки',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.archive_outlined,
                color: colors.text.withValues(alpha: 0.6)),
            tooltip: 'Архив привычек',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HabitArchiveScreen(isDarkMode: colors.isDark),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list,
                color: colors.text.withValues(alpha: 0.6)),
            tooltip: 'Фильтр',
            onPressed: () => _showFilterDialog(context, colors),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: colors.text.withValues(alpha: 0.6)),
            tooltip: 'Настройки',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HabitSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: habits.isEmpty
          ? _buildEmptyState(colors)
          : Column(
              children: [
                _buildDatesHeader(visibleDates, colors),
                Divider(height: 1, color: colors.nested),
                Expanded(
                  child: sortType == HabitSortType.manual
                      ? ReorderableListView.builder(
                          padding: const EdgeInsets.only(bottom: 84),
                          itemCount: habits.length,
                          onReorder: (oldIndex, newIndex) {
                            ref
                                .read(habitsProvider.notifier)
                                .reorder(oldIndex, newIndex);
                          },
                          itemBuilder: (context, index) {
                            final habit = habits[index];
                            return _buildHabitRow(
                              key: ValueKey('habit_${habit.id}'),
                              habit: habit,
                              visibleDates: visibleDates,
                              colors: colors,
                            );
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 84),
                          itemCount: habits.length,
                          itemBuilder: (context, index) {
                            final habit = habits[index];
                            return _buildHabitRow(
                              key: ValueKey('habit_${habit.id}'),
                              habit: habit,
                              visibleDates: visibleDates,
                              colors: colors,
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.accent,
        foregroundColor: colors.isDark ? Colors.black : Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
        onPressed: () => _showCreateTypeDialog(context, colors),
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat,
            size: 64,
            color: colors.text.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Нет привычек',
            style: TextStyle(
              fontFamily: 'Onest',
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите "+", чтобы создать первую привычку',
            style: TextStyle(
              fontFamily: 'Onest',
              color: colors.text.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesHeader(
    List<DateTime> visibleDates,
    AppColorsExtension colors,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _handleDragStart(),
      onHorizontalDragUpdate: _handleDragUpdate,
      child: Container(
        color: colors.card,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Привычка',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_dayOffset > 0) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() => _dayOffset = 0);
                        HapticFeedback.selectionClick();
                      },
                      borderRadius: BorderRadius.circular(13),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          'Сегодня',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            color: colors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: visibleDates.map((date) {
                final isToday = _isToday(date);
                final weekdayStr = DateFormat('E', 'ru').format(date);
                final dayStr = date.day.toString();

                return Container(
                  width: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          weekdayStr,
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontSize: 11,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.w500,
                            color: isToday
                                ? colors.accent
                                : colors.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          dayStr,
                          style: TextStyle(
                            fontFamily: isToday ? 'Unbounded' : 'Onest',
                            fontSize: 12,
                            fontWeight:
                                isToday ? FontWeight.w600 : FontWeight.w500,
                            color: isToday
                                ? colors.text
                                : colors.text.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitRow({
    required Key key,
    required HabitItem habit,
    required List<DateTime> visibleDates,
    required AppColorsExtension colors,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.nested, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HabitDetailScreen(habitId: habit.id),
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: habit.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: TextStyle(
                            fontFamily: 'Onest',
                            color: colors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (habit.question != null &&
                            habit.question!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            habit.question!,
                            style: TextStyle(
                              fontFamily: 'Onest',
                              color: colors.text.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: visibleDates.map((date) {
              final dateStr =
                  "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
              final isDone = habit.isCompletedOn(dateStr);
              final val = habit.valueOn(dateStr);

              return Container(
                width: 36,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                alignment: Alignment.center,
                child: _buildDayCheckCell(
                  habit: habit,
                  dateStr: dateStr,
                  isDone: isDone,
                  value: val,
                  colors: colors,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCheckCell({
    required HabitItem habit,
    required String dateStr,
    required bool isDone,
    required double value,
    required AppColorsExtension colors,
  }) {
    final isNumerical = habit.type == 'numerical';
    final isShortTap = ref.watch(habitShortTapProvider);

    final cellBody = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? habit.color : Colors.transparent,
        border: Border.all(
          color: isDone ? habit.color : colors.nested,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: isNumerical
          ? (isDone
              ? Text(
                  value >= 1000
                      ? '${(value / 1000).toStringAsFixed(1)}k'
                      : value.toStringAsFixed(
                          value.truncateToDouble() == value ? 0 : 1,
                        ),
                  style: const TextStyle(
                    fontFamily: 'Onest',
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : (value > 0
                  ? Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: habit.color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null))
          : (isDone
              ? const Icon(Icons.check, size: 18, color: Colors.white)
              : null),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        if (isNumerical) {
          _showNumericalInputDialog(habit, dateStr, value, colors);
        } else if (isShortTap) {
          HapticFeedback.selectionClick();
          await ref
              .read(habitsProvider.notifier)
              .toggleHabitDay(habit.id, dateStr);
        }
      },
      onLongPress: () async {
        if (isNumerical) {
          _showNumericalInputDialog(habit, dateStr, value, colors);
        } else {
          HapticFeedback.mediumImpact();
          await ref
              .read(habitsProvider.notifier)
              .toggleHabitDay(habit.id, dateStr);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: cellBody,
      ),
    );
  }

  void _showNumericalInputDialog(
    HabitItem habit,
    String dateStr,
    double currentValue,
    AppColorsExtension colors,
  ) {
    double tempVal = currentValue > 0 ? currentValue : habit.targetValue;
    final controller = TextEditingController(
      text: tempVal.toStringAsFixed(
        tempVal.truncateToDouble() == tempVal ? 0 : 1,
      ),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              title: Text(
                habit.title,
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  color: colors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Цель: ${habit.targetValue} ${habit.unit ?? ""}',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: colors.text,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            tempVal = (tempVal - 1).clamp(0.0, 999999.0);
                            controller.text = tempVal.toStringAsFixed(0);
                          });
                        },
                      ),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Unbounded',
                            color: colors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            suffixText: habit.unit,
                            suffixStyle: TextStyle(
                              fontFamily: 'Onest',
                              color: colors.text.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: colors.nested),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: colors.accent, width: 2),
                            ),
                          ),
                          onChanged: (v) {
                            tempVal = double.tryParse(v) ?? tempVal;
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: colors.text,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            tempVal += 1;
                            controller.text = tempVal.toStringAsFixed(0);
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    ref
                        .read(habitsProvider.notifier)
                        .setNumericalValue(habit.id, dateStr, 0);
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    'Сбросить',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: habit.color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    final entered = double.tryParse(controller.text) ?? tempVal;
                    ref
                        .read(habitsProvider.notifier)
                        .setNumericalValue(habit.id, dateStr, entered);
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Сохранить',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFilterDialog(
    BuildContext context,
    AppColorsExtension colors,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final currentSort = ref.watch(habitSortProvider);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Сортировка',
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ),
              _buildSortTile(
                title: 'Вручную',
                subtitle: 'Перетаскивание элементов вверх/вниз',
                value: HabitSortType.manual,
                groupValue: currentSort,
                colors: colors,
              ),
              _buildSortTile(
                title: 'По названию',
                subtitle: 'Алфавитный порядок (А–Я)',
                value: HabitSortType.name,
                groupValue: currentSort,
                colors: colors,
              ),
              _buildSortTile(
                title: 'По цвету',
                subtitle: 'Группировка по оттенкам',
                value: HabitSortType.color,
                groupValue: currentSort,
                colors: colors,
              ),
              _buildSortTile(
                title: 'По результатам',
                subtitle: 'По силе привычки за 30 дней',
                value: HabitSortType.score,
                groupValue: currentSort,
                colors: colors,
              ),
              _buildSortTile(
                title: 'По статусу',
                subtitle: 'Сначала невыполненные на сегодня',
                value: HabitSortType.status,
                groupValue: currentSort,
                colors: colors,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortTile({
    required String title,
    required String subtitle,
    required HabitSortType value,
    required HabitSortType groupValue,
    required AppColorsExtension colors,
  }) {
    return RadioListTile<HabitSortType>(
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Onest',
          fontWeight: FontWeight.w600,
          color: colors.text,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'Onest',
          color: colors.text.withValues(alpha: 0.6),
          fontSize: 12,
        ),
      ),
      activeColor: colors.accent,
      value: value,
      groupValue: groupValue,
      onChanged: (selected) {
        if (selected != null) {
          ref.read(habitSortProvider.notifier).setSort(selected);
          Navigator.pop(context);
        }
      },
    );
  }

  void _showCreateTypeDialog(
    BuildContext context,
    AppColorsExtension colors,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Создать привычку',
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      color: colors.accent,
                    ),
                  ),
                  title: Text(
                    'Да или Нет',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Например: медитировать, сделать зарядку',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HabitEditScreen(type: 'boolean'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.speed, color: colors.warning),
                  ),
                  title: Text(
                    'Измеримая',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Например: выпить 2000 мл воды, прочитать 20 страниц',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const HabitEditScreen(type: 'numerical'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}
