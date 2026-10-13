import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'providers/shift_provider.dart';
import 'shift_constructor_screen.dart';

class ShiftScheduleScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  const ShiftScheduleScreen({super.key, this.isDarkMode = true});

  @override
  ConsumerState<ShiftScheduleScreen> createState() =>
      _ShiftScheduleScreenState();
}

class _ShiftScheduleScreenState extends ConsumerState<ShiftScheduleScreen> {
  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  final Set<String> _selectedDateKeys = {};
  bool _isMultiSelectMode = false;

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  void _toggleSelectDate(DateTime date) {
    HapticFeedback.selectionClick();
    final key = _dateKey(date);
    setState(() {
      if (_selectedDateKeys.contains(key)) {
        _selectedDateKeys.remove(key);
        if (_selectedDateKeys.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedDateKeys.add(key);
      }
    });
  }

  /// Первое зажатие: запрос на переход в режим мультивыбора
  void _onFirstLongPress(DateTime date) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выбор смен'),
        content: const Text('Выбрать несколько смен для редактирования?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isMultiSelectMode = true;
                _selectedDateKeys.add(_dateKey(date));
              });
            },
            child: const Text('Да'),
          ),
        ],
      ),
    );
  }

  /// Повторное долгое удержание: выбор смены и точная настройка рабочих часов
  void _showShiftAndHoursSheet(
    ShiftScheduleState schedule,
    List<DateTime> targetDates,
  ) {
    if (targetDates.isEmpty) return;

    final workType = schedule.customShiftTypes.firstWhere(
      (t) => t.isWork,
      orElse: () => defaultWorkShift,
    );
    final startCtrl = TextEditingController(text: workType.startTime);
    final endCtrl = TextEditingController(text: workType.endTime);
    String selectedShiftId = workType.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final currentType = schedule.customShiftTypes.firstWhere(
            (t) => t.id == selectedShiftId,
            orElse: () => defaultRestShift,
          );

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Настройка смены (${targetDates.length} выбр. дн.)',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Выбор типа смены
                Wrap(
                  spacing: 8,
                  children: schedule.customShiftTypes.map((type) {
                    final isSel = type.id == selectedShiftId;
                    return ChoiceChip(
                      selected: isSel,
                      label: Text(type.name),
                      avatar: CircleAvatar(
                        backgroundColor: Color(type.color),
                        radius: 8,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setSheetState(() {
                            selectedShiftId = type.id;
                            if (type.isWork) {
                              startCtrl.text = type.startTime;
                              endCtrl.text = type.endTime;
                            }
                          });
                        }
                      },
                    );
                  }).toList(),
                ),

                // Установка рабочих часов (если рабочая смена)
                if (currentType.isWork) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Рабочие часы для этих дней:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Начало (08:00)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: endCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Конец (20:00)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        ref
                            .read(shiftProvider.notifier)
                            .clearShiftsForDates(targetDates);
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedDateKeys.clear();
                          _isMultiSelectMode = false;
                        });
                      },
                      child: const Text(
                        'Сделать пустыми',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        ref
                            .read(shiftProvider.notifier)
                            .assignShiftToDates(
                              targetDates,
                              selectedShiftId,
                              customStartTime: currentType.isWork
                                  ? startCtrl.text.trim()
                                  : null,
                              customEndTime: currentType.isWork
                                  ? endCtrl.text.trim()
                                  : null,
                            );
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedDateKeys.clear();
                          _isMultiSelectMode = false;
                        });
                      },
                      child: const Text('Применить'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddScheduleDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый график'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Название (например: Подработка)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(shiftProvider.notifier)
                  .addNewSchedule(nameCtrl.text.trim());
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Синхронизация с календарём'),
        content: const Text(
          'Перенести рабочие смены из ВСЕХ ваших графиков в основной календарь Орбиты?\n\nВыберите период:',
        ),
        actions: [
          TextButton(
            child: const Text('1 месяц'),
            onPressed: () => _performSync(ctx, 1),
          ),
          TextButton(
            child: const Text('2 месяца'),
            onPressed: () => _performSync(ctx, 2),
          ),
          TextButton(
            child: const Text('Полгода (6 мес)'),
            onPressed: () => _performSync(ctx, 6),
          ),
        ],
      ),
    );
  }

  Future<void> _performSync(BuildContext dialogCtx, int months) async {
    Navigator.pop(dialogCtx);
    final count = await ref
        .read(shiftProvider.notifier)
        .syncAllSchedulesToCalendar(months);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'В календарь успешно перенесено смен со всех графиков: $count',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftState = ref.watch(shiftProvider);
    final schedule = shiftState.activeSchedule;

    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFE1E4E8);

    if (schedule == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final daysInMonth = DateUtils.getDaysInMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
    int workDaysCount = 0;
    int restDaysCount = 0;
    double totalWorkHours = 0.0;

    for (int day = 1; day <= daysInMonth; day++) {
      final d = DateTime(_currentMonth.year, _currentMonth.month, day);
      final shift = schedule.getShiftForDate(d);
      if (shift != null) {
        if (shift.isWork) {
          workDaysCount++;
          totalWorkHours += shift.durationHours;
        } else {
          restDaysCount++;
        }
      }
    }

    final monthTitle = DateFormat('LLLL yyyy', 'ru').format(_currentMonth);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: _isMultiSelectMode
            ? Text(
                'Выбрано: ${_selectedDateKeys.length}',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              )
            : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: schedule.id,
                  dropdownColor: cardBg,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF38BDF8),
                  ),
                  items: [
                    ...shiftState.schedules.map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ),
                  ],
                  onChanged: (id) {
                    if (id != null)
                      ref.read(shiftProvider.notifier).switchSchedule(id);
                  },
                ),
              ),
        actions: [
          if (_isMultiSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.tune, color: Color(0xFF38BDF8), size: 26),
              tooltip: 'Настроить выбранные смены',
              onPressed: () {
                final dates = _selectedDateKeys
                    .map((k) => DateTime.parse(k))
                    .toList();
                _showShiftAndHoursSheet(schedule, dates);
              },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Снять выделение',
              onPressed: () => setState(() {
                _selectedDateKeys.clear();
                _isMultiSelectMode = false;
              }),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFF38BDF8),
              ),
              tooltip: 'Добавить новый график',
              onPressed: _showAddScheduleDialog,
            ),
            IconButton(
              icon: const Icon(Icons.sync, color: Color(0xFF38BDF8)),
              tooltip: 'Синхронизировать все графики',
              onPressed: _showSyncDialog,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Настройка графика',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ShiftConstructorScreen(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month - 1,
                      1,
                    );
                  }),
                ),
                Text(
                  monthTitle[0].toUpperCase() + monthTitle.substring(1),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month + 1,
                      1,
                    );
                  }),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((d) {
                return Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _buildMonthGrid(
              schedule,
              cardBg,
              textPrimary,
              textSecondary,
              borderColor,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Рабочих', '$workDaysCount', Colors.redAccent),
                _buildStatItem('Выходных', '$restDaysCount', Colors.green),
                _buildStatItem(
                  'Часов',
                  '${totalWorkHours.toStringAsFixed(totalWorkHours % 1 == 0 ? 0 : 1)} ч',
                  const Color(0xFF38BDF8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMonthGrid(
    ShiftScheduleState schedule,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final firstDayOffset = _currentMonth.weekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
    final totalCells = firstDayOffset + daysInMonth;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.85,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        if (index < firstDayOffset) return const SizedBox.shrink();

        final dayNum = index - firstDayOffset + 1;
        final cellDate = DateTime(
          _currentMonth.year,
          _currentMonth.month,
          dayNum,
        );
        final key = _dateKey(cellDate);
        final isSelected = _selectedDateKeys.contains(key);
        final isToday = DateUtils.isSameDay(cellDate, DateTime.now());

        final shift = schedule.getShiftForDate(cellDate);
        final isOverride = schedule.overrides.containsKey(key);

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (_isMultiSelectMode) {
              _toggleSelectDate(cellDate);
            } else {
              _showShiftAndHoursSheet(schedule, [cellDate]);
            }
          },
          onLongPress: () {
            if (!_isMultiSelectMode) {
              _onFirstLongPress(cellDate);
            } else {
              HapticFeedback.heavyImpact();
              if (!_selectedDateKeys.contains(key)) {
                _selectedDateKeys.add(key);
              }
              final dates = _selectedDateKeys
                  .map((k) => DateTime.parse(k))
                  .toList();
              _showShiftAndHoursSheet(schedule, dates);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.35)
                  : cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF38BDF8)
                    : (isToday
                          ? Colors.amber
                          : borderColor.withValues(alpha: 0.3)),
                width: isSelected ? 2.5 : (isToday ? 2 : 1),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday || isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF38BDF8)
                              : textPrimary,
                        ),
                      ),
                      if (isOverride)
                        const Icon(
                          Icons.star,
                          size: 10,
                          color: Colors.orangeAccent,
                        ),
                    ],
                  ),
                ),
                if (shift != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(shift.color),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      shift.shortName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Icon(Icons.add, size: 14, color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
