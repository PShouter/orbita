import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/shift_provider.dart';
import '../../theme/app_theme.dart';
import '../settings/sections/shifts_settings_screen.dart';
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

  bool _highlightWeekends = true;
  bool _showTimeInDayCell = false;
  bool _showMonthlyStats = true;

  @override
  void initState() {
    super.initState();
    _loadDisplayPreferences();
  }

  Future<void> _loadDisplayPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _highlightWeekends = prefs.getBool('shifts_highlight_weekends') ?? true;
        _showTimeInDayCell = prefs.getBool('shifts_show_time_in_cell') ?? false;
        _showMonthlyStats = prefs.getBool('shifts_show_monthly_stats') ?? true;
      });
    }
  }

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

  void _onFirstLongPress(DateTime date, AppColorsExtension colors) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Выбор смен',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: Text(
          'Выбрать несколько смен для редактирования?',
          style: TextStyle(
            fontFamily: 'Onest',
            fontSize: 14,
            color: colors.text.withValues(alpha: 0.8),
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
              backgroundColor: colors.accent,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isMultiSelectMode = true;
                _selectedDateKeys.add(_dateKey(date));
              });
            },
            child: const Text(
              'Да',
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

  void _showShiftAndHoursSheet(
    ShiftScheduleState schedule,
    List<DateTime> targetDates,
    AppColorsExtension colors,
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
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final currentType = schedule.customShiftTypes.firstWhere(
            (t) => t.id == selectedShiftId,
            orElse: () => defaultRestShift,
          );

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Настройка смены (${targetDates.length} выбр. дн.)',
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: schedule.customShiftTypes.map((type) {
                    final isSel = type.id == selectedShiftId;
                    return ChoiceChip(
                      selected: isSel,
                      selectedColor: colors.accent.withValues(alpha: 0.2),
                      backgroundColor: colors.nested.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                        side: BorderSide(
                          color: isSel ? colors.accent : colors.nested,
                        ),
                      ),
                      label: Text(
                        type.name,
                        style: TextStyle(
                          fontFamily: 'Onest',
                          fontWeight:
                              isSel ? FontWeight.w600 : FontWeight.normal,
                          color: isSel
                              ? colors.text
                              : colors.text.withValues(alpha: 0.7),
                        ),
                      ),
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
                if (currentType.isWork) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Рабочие часы для этих дней:',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startCtrl,
                          style: TextStyle(
                              fontFamily: 'Onest', color: colors.text),
                          decoration: InputDecoration(
                            labelText: 'Начало (08:00)',
                            labelStyle: TextStyle(
                                fontFamily: 'Onest',
                                color: colors.text.withValues(alpha: 0.6)),
                            filled: true,
                            fillColor: colors.nested.withValues(alpha: 0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: colors.nested),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: colors.nested),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: colors.accent, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: endCtrl,
                          style: TextStyle(
                              fontFamily: 'Onest', color: colors.text),
                          decoration: InputDecoration(
                            labelText: 'Конец (20:00)',
                            labelStyle: TextStyle(
                                fontFamily: 'Onest',
                                color: colors.text.withValues(alpha: 0.6)),
                            filled: true,
                            fillColor: colors.nested.withValues(alpha: 0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: colors.nested),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: colors.nested),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: colors.accent, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
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
                      child: Text(
                        'Сделать пустыми',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor:
                            colors.isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        ref.read(shiftProvider.notifier).assignShiftToDates(
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
                      child: const Text(
                        'Применить',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  void _showAddScheduleDialog(AppColorsExtension colors) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Новый график',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: TextStyle(fontFamily: 'Onest', color: colors.text),
          decoration: InputDecoration(
            hintText: 'Название (например: Подработка)',
            hintStyle: TextStyle(
              fontFamily: 'Onest',
              color: colors.text.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: colors.nested.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.nested),
            ),
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
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(shiftProvider.notifier)
                  .addNewSchedule(nameCtrl.text.trim());
            },
            child: const Text(
              'Создать',
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

  void _showSyncDialog(AppColorsExtension colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Синхронизация с календарём',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: Text(
          'Перенести рабочие смены из ВСЕХ ваших графиков в основной календарь Орбиты?\n\nВыберите период:',
          style: TextStyle(
            fontFamily: 'Onest',
            fontSize: 14,
            color: colors.text.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            child: Text('1 месяц',
                style: TextStyle(fontFamily: 'Onest', color: colors.accent)),
            onPressed: () => _performSync(ctx, 1, colors),
          ),
          TextButton(
            child: Text('3 месяца',
                style: TextStyle(fontFamily: 'Onest', color: colors.accent)),
            onPressed: () => _performSync(ctx, 3, colors),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text('Полгода (6 мес)',
                style: TextStyle(
                    fontFamily: 'Onest', fontWeight: FontWeight.bold)),
            onPressed: () => _performSync(ctx, 6, colors),
          ),
        ],
      ),
    );
  }

  Future<void> _performSync(
    BuildContext dialogCtx,
    int months,
    AppColorsExtension colors,
  ) async {
    Navigator.pop(dialogCtx);
    final count = await ref
        .read(shiftProvider.notifier)
        .syncAllSchedulesToCalendar(months);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'В календарь перенесено рабочих смен: $count',
            style: const TextStyle(fontFamily: 'Onest'),
          ),
          backgroundColor: colors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shiftState = ref.watch(shiftProvider);
    final schedule = shiftState.activeSchedule;

    if (schedule == null) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: Center(
          child: CircularProgressIndicator(color: colors.accent),
        ),
      );
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
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: _isMultiSelectMode
            ? Text(
                'Выбрано: ${_selectedDateKeys.length}',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: schedule.id,
                    dropdownColor: colors.card,
                    isExpanded: true,
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      color: colors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: colors.accent,
                    ),
                    items: shiftState.schedules.map((s) {
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (id) {
                      if (id != null) {
                        ref.read(shiftProvider.notifier).switchSchedule(id);
                      }
                    },
                  ),
                ),
              ),
        actions: [
          if (_isMultiSelectMode) ...[
            IconButton(
              icon: Icon(Icons.tune, color: colors.accent, size: 26),
              tooltip: 'Настроить выбранные смены',
              onPressed: () {
                final dates =
                    _selectedDateKeys.map((k) => DateTime.parse(k)).toList();
                _showShiftAndHoursSheet(schedule, dates, colors);
              },
            ),
            IconButton(
              icon: Icon(Icons.close, color: colors.text),
              tooltip: 'Снять выделение',
              onPressed: () => setState(() {
                _selectedDateKeys.clear();
                _isMultiSelectMode = false;
              }),
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: colors.accent,
              ),
              tooltip: 'Добавить новый график',
              onPressed: () => _showAddScheduleDialog(colors),
            ),
            IconButton(
              icon: Icon(Icons.sync, color: colors.accent),
              tooltip: 'Синхронизировать все графики',
              onPressed: () => _showSyncDialog(colors),
            ),
            IconButton(
              icon: Icon(Icons.tune, color: colors.text),
              tooltip: 'Конструктор графика',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ShiftConstructorScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.settings_outlined,
                  color: colors.text.withValues(alpha: 0.6)),
              tooltip: 'Настройки смен',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ShiftsSettingsScreen(isDarkMode: colors.isDark),
                  ),
                );
                _loadDisplayPreferences();
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: colors.text),
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
                    fontFamily: 'Unbounded',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: colors.text),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                  .asMap()
                  .entries
                  .map((entry) {
                final isWeekend = entry.key >= 5;
                final weekendColor = _highlightWeekends
                    ? colors.error
                    : colors.text.withValues(alpha: 0.6);

                return Expanded(
                  child: Center(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: isWeekend
                            ? weekendColor
                            : colors.text.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _buildMonthGrid(schedule, colors),
          ),
          if (_showMonthlyStats)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                border: Border(top: BorderSide(color: colors.nested)),
                boxShadow: [
                  BoxShadow(
                      color: colors.nested.withValues(alpha: 0.2),
                      blurRadius: 8),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                      'Рабочих', '$workDaysCount', colors.error, colors),
                  _buildStatItem(
                      'Выходных', '$restDaysCount', colors.success, colors),
                  _buildStatItem(
                    'Часов',
                    '${totalWorkHours.toStringAsFixed(totalWorkHours % 1 == 0 ? 0 : 1)} ч',
                    colors.accent,
                    colors,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color valueColor,
    AppColorsExtension colors,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Onest',
            fontSize: 12,
            color: colors.text.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(
    ShiftScheduleState schedule,
    AppColorsExtension colors,
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
        childAspectRatio: 0.76,
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

        final isOverride = schedule.overrides.containsKey(key) &&
            schedule.overrides[key]?.shiftId != 'empty';

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (_isMultiSelectMode) {
              _toggleSelectDate(cellDate);
            } else {
              _showShiftAndHoursSheet(schedule, [cellDate], colors);
            }
          },
          onLongPress: () {
            if (!_isMultiSelectMode) {
              _onFirstLongPress(cellDate, colors);
            } else {
              HapticFeedback.heavyImpact();
              if (!_selectedDateKeys.contains(key)) {
                _selectedDateKeys.add(key);
              }
              final dates =
                  _selectedDateKeys.map((k) => DateTime.parse(k)).toList();
              _showShiftAndHoursSheet(schedule, dates, colors);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.accent.withValues(alpha: 0.25)
                  : colors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? colors.accent
                    : (isToday
                        ? colors.accent
                        : colors.nested.withValues(alpha: 0.6)),
                width: isSelected ? 2.0 : (isToday ? 2.0 : 0.8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontFamily:
                              isToday || isSelected ? 'Unbounded' : 'Onest',
                          fontSize: 10,
                          fontWeight: isToday || isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? colors.accent
                              : (isToday ? colors.accent : colors.text),
                        ),
                      ),
                      if (isOverride)
                        Icon(
                          Icons.star,
                          size: 10,
                          color: colors.warning,
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                if (shift != null)
                  Container(
                    margin: const EdgeInsets.only(left: 3, right: 3, bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      vertical: 3,
                      horizontal: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Color(shift.color),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          shift.shortName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Onest',
                            color: ThemeData.estimateBrightnessForColor(
                                        Color(shift.color)) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_showTimeInDayCell &&
                            shift.isWork &&
                            shift.startTime.isNotEmpty)
                          Text(
                            shift.startTime,
                            style: TextStyle(
                              fontFamily: 'Onest',
                              color: ThemeData.estimateBrightnessForColor(
                                          Color(shift.color)) ==
                                      Brightness.dark
                                  ? Colors.white70
                                  : Colors.black54,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.add,
                        size: 12, color: colors.text.withValues(alpha: 0.3)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
