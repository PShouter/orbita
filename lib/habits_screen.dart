import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'providers/habits_provider.dart';
import 'habit_edit_screen.dart';
import 'habit_detail_screen.dart';
import 'habit_settings_screen.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const HabitsScreen({super.key, this.isDarkMode = true});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  int _dayOffset = 0;
  static const int _visibleDaysCount = 5;

  // Накопитель смещения для плавного свайпа без борьбы со скроллом
  double _dragDistance = 0.0;
  static const double _dragThreshold = 26.0;

  List<DateTime> _getVisibleDates() {
    final today = DateTime.now();
    final List<DateTime> dates = [];
    for (int i = _visibleDaysCount - 1; i >= 0; i--) {
      dates.add(today.subtract(Duration(days: _dayOffset + i)));
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
      _shiftDays(1); // Свайп вправо -> листаем назад в прошлое
      _dragDistance = 0.0;
    } else if (_dragDistance < -_dragThreshold) {
      _shiftDays(-1); // Свайп влево -> возвращаемся к сегодняшнему дню
      _dragDistance = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(sortedHabitsProvider);
    final sortType = ref.watch(habitSortProvider);
    final isShortTap = ref.watch(habitShortTapProvider);
    final visibleDates = _getVisibleDates();

    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Привычки',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: textSecondary),
            tooltip: 'Фильтр',
            onPressed: () => _showFilterDialog(
              context,
              isDark,
              cardBg,
              textPrimary,
              textSecondary,
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textSecondary),
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
          ? _buildEmptyState(textSecondary)
          : Column(
              children: [
                _buildDatesHeader(
                  visibleDates,
                  cardBg,
                  textPrimary,
                  textSecondary,
                ),
                Divider(height: 1, color: borderColor),
                Expanded(
                  child: sortType == HabitSortType.manual
                      ? ReorderableListView.builder(
                          itemCount: habits.length,
                          onReorder: (oldIndex, newIndex) {
                            ref
                                .read(habitsProvider.notifier)
                                .reorder(oldIndex, newIndex);
                          },
                          itemBuilder: (context, index) {
                            final habit = habits[index];
                            return _buildHabitRow(
                              key: ValueKey(habit.id),
                              habit: habit,
                              visibleDates: visibleDates,
                              isShortTap: isShortTap,
                              isDark: isDark,
                              cardBg: cardBg,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              borderColor: borderColor,
                            );
                          },
                        )
                      : ListView.builder(
                          itemCount: habits.length,
                          itemBuilder: (context, index) {
                            final habit = habits[index];
                            return _buildHabitRow(
                              key: ValueKey(habit.id),
                              habit: habit,
                              visibleDates: visibleDates,
                              isShortTap: isShortTap,
                              isDark: isDark,
                              cardBg: cardBg,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              borderColor: borderColor,
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF38BDF8),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
        onPressed: () => _showCreateTypeDialog(
          context,
          isDark,
          cardBg,
          textPrimary,
          textSecondary,
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textSecondary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat,
            size: 64,
            color: textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Нет привычек',
            style: TextStyle(color: textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите "+", чтобы создать первую привычку',
            style: TextStyle(
              color: textSecondary.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Заголовок с датами и плавным накопительным свайпом
  Widget _buildDatesHeader(
    List<DateTime> visibleDates,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _handleDragStart(),
      onHorizontalDragUpdate: _handleDragUpdate,
      child: Container(
        color: cardBg,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Привычка',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_dayOffset > 0) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() => _dayOffset = 0);
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Сегодня',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
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
                  width: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Text(
                        weekdayStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isToday
                              ? const Color(0xFF38BDF8)
                              : textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isToday ? textPrimary : textSecondary,
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

  /// Строка отдельной привычки
  Widget _buildHabitRow({
    required Key key,
    required HabitItem habit,
    required List<DateTime> visibleDates,
    required bool isShortTap,
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          // Название привычки + индикатор цвета
          Expanded(
            child: InkWell(
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
                    height: 28,
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
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (habit.question != null &&
                            habit.question!.isNotEmpty)
                          Text(
                            habit.question!,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Ячейки дней с поддержкой того же свайпа
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _handleDragStart(),
            onHorizontalDragUpdate: _handleDragUpdate,
            child: Row(
              children: visibleDates.map((date) {
                final dateStr =
                    "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                final isDone = habit.isCompletedOn(dateStr);
                final val = habit.valueOn(dateStr);

                return Container(
                  width: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  child: _buildDayCheckCell(
                    habit: habit,
                    dateStr: dateStr,
                    isDone: isDone,
                    value: val,
                    isShortTap: isShortTap,
                    isDark: isDark,
                    cardBg: cardBg,
                    textPrimary: textPrimary,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Ячейка отметки за день
  Widget _buildDayCheckCell({
    required HabitItem habit,
    required String dateStr,
    required bool isDone,
    required double value,
    required bool isShortTap,
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
  }) {
    final isNumerical = habit.type == 'numerical';

    final cellBody = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? habit.color : Colors.transparent,
        border: Border.all(
          color: isDone
              ? habit.color
              : (isDark ? Colors.white24 : Colors.black26),
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
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : (value > 0
                      ? Text(
                          value.toStringAsFixed(0),
                          style: TextStyle(
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
      onTap: () {
        if (isNumerical) {
          _showNumericalInputDialog(habit, dateStr, value, cardBg, textPrimary);
        } else {
          if (isShortTap) {
            HapticFeedback.selectionClick();
            ref.read(habitsProvider.notifier).toggleHabitDay(habit.id, dateStr);
          }
        }
      },
      onLongPress: () {
        if (isNumerical) {
          _showNumericalInputDialog(habit, dateStr, value, cardBg, textPrimary);
        } else {
          if (!isShortTap) {
            HapticFeedback.mediumImpact();
            ref.read(habitsProvider.notifier).toggleHabitDay(habit.id, dateStr);
          }
        }
      },
      child: cellBody,
    );
  }

  /// Ввод значения для измеримой привычки
  void _showNumericalInputDialog(
    HabitItem habit,
    String dateStr,
    double currentValue,
    Color cardBg,
    Color textPrimary,
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
              backgroundColor: cardBg,
              title: Text(
                habit.title,
                style: TextStyle(color: textPrimary, fontSize: 17),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Цель: ${habit.targetValue} ${habit.unit ?? ""}',
                    style: TextStyle(
                      color: textPrimary.withValues(alpha: 0.6),
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
                          color: textPrimary,
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
                          style: TextStyle(color: textPrimary, fontSize: 20),
                          decoration: InputDecoration(
                            suffixText: habit.unit,
                            suffixStyle: TextStyle(
                              color: textPrimary.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                            border: const UnderlineInputBorder(),
                          ),
                          onChanged: (v) {
                            tempVal = double.tryParse(v) ?? tempVal;
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: textPrimary,
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
                  child: const Text(
                    'Сбросить',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: habit.color,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final entered = double.tryParse(controller.text) ?? tempVal;
                    ref
                        .read(habitsProvider.notifier)
                        .setNumericalValue(habit.id, dateStr, entered);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Диалог сортировки
  void _showFilterDialog(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
              _buildSortTile(
                title: 'Вручную',
                subtitle: 'Перетаскивание элементов вверх/вниз',
                value: HabitSortType.manual,
                groupValue: currentSort,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _buildSortTile(
                title: 'По названию',
                subtitle: 'Алфавитный порядок (А–Я)',
                value: HabitSortType.name,
                groupValue: currentSort,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _buildSortTile(
                title: 'По цвету',
                subtitle: 'Группировка по оттенкам',
                value: HabitSortType.color,
                groupValue: currentSort,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _buildSortTile(
                title: 'По результатам',
                subtitle: 'По силе привычки за 30 дней',
                value: HabitSortType.score,
                groupValue: currentSort,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              _buildSortTile(
                title: 'По статусу',
                subtitle: 'Сначала невыполненные на сегодня',
                value: HabitSortType.status,
                groupValue: currentSort,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
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
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return RadioListTile<HabitSortType>(
      title: Text(title, style: TextStyle(color: textPrimary)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: textSecondary, fontSize: 12),
      ),
      activeColor: const Color(0xFF38BDF8),
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

  /// Диалог выбора типа привычки при нажатии на "+"
  void _showCreateTypeDialog(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  title: Text(
                    'Да или Нет',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Например: медитировать, сделать зарядку',
                    style: TextStyle(color: textSecondary, fontSize: 12),
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
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.speed, color: Colors.amber),
                  ),
                  title: Text(
                    'Измеримая',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Например: выпить 2000 мл воды, прочитать 20 страниц',
                    style: TextStyle(color: textSecondary, fontSize: 12),
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
