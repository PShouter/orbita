import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/shift_provider.dart';

class ShiftScheduleScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const ShiftScheduleScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<ShiftScheduleScreen> createState() =>
      _ShiftScheduleScreenState();
}

class _ShiftScheduleScreenState extends ConsumerState<ShiftScheduleScreen> {
  DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(shiftProvider);
    final notifier = ref.read(shiftProvider.notifier);

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
        : const Color(0xFFD0D7DE);

    final currentDayShift = schedule?.getShiftForDate(_selectedDate);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          schedule?.name ?? 'График смен',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Настроить шаблон смен',
            icon: const Icon(Icons.tune, color: Color(0xFF38BDF8)),
            onPressed: () => _openScheduleSettingsDialog(schedule, notifier),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Шапка месяца
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_monthName(_focusedMonth.month)} ${_focusedMonth.year}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() {
                      _focusedMonth = DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month - 1,
                        1,
                      );
                    }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() {
                      _focusedMonth = DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month + 1,
                        1,
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Сетка календаря со сменами
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: _buildMonthCalendar(
              schedule,
              cardBg,
              borderColor,
              textPrimary,
              textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Инфо-карточка выбранного дня
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                if (currentDayShift != null && currentDayShift['color'] != null)
                  Container(
                    width: 12,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(currentDayShift['color'] as int),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedDate.day} ${_monthNameGenitive(_selectedDate.month)} ${_selectedDate.year}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        currentDayShift?['name'] ?? 'Нет данных',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: currentDayShift?['type'] == 'work'
                              ? const Color(0xFF38BDF8)
                              : Colors.green,
                        ),
                      ),
                      if (currentDayShift?['time'] != null)
                        Text(
                          'Время: ${currentDayShift!['time']}',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _openDayOverrideDialog(
                    _selectedDate,
                    currentDayShift,
                    notifier,
                  ),
                  child: const Text(
                    'Замена / Отгул',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Легенда шаблона
          if (schedule != null && schedule.cycleDays.isNotEmpty) ...[
            Text(
              'Цикл шаблона:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: schedule.cycleDays.map((cd) {
                final c = cd['color'] != null
                    ? Color(cd['color'] as int)
                    : Colors.blue;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 4, backgroundColor: c),
                      const SizedBox(width: 6),
                      Text(
                        cd['name'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      if (cd['time'] != null)
                        Text(
                          ' (${cd['time']})',
                          style: TextStyle(fontSize: 10, color: textSecondary),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthCalendar(
    ShiftSchedule? schedule,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final int offset = (firstDay.weekday - 1);
    final totalCells = ((offset + daysInMonth + 6) ~/ 7) * 7;
    final weeksCount = totalCells ~/ 7;

    const weekDays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

    return Column(
      children: [
        Row(
          children: weekDays
              .map(
                (wd) => Expanded(
                  child: Center(
                    child: Text(
                      wd,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1),

        for (int w = 0; w < weeksCount; w++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (int d = 0; d < 7; d++)
                  Expanded(
                    child: Builder(
                      builder: (ctx) {
                        final cellIdx = (w * 7) + d;
                        final dayNum = cellIdx - offset + 1;
                        if (dayNum < 1 || dayNum > daysInMonth) {
                          return const SizedBox(height: 48);
                        }

                        final date = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month,
                          dayNum,
                        );
                        final isSel =
                            date.year == _selectedDate.year &&
                            date.month == _selectedDate.month &&
                            date.day == _selectedDate.day;
                        final isToday =
                            date.year == DateTime.now().year &&
                            date.month == DateTime.now().month &&
                            date.day == DateTime.now().day;

                        final shift = schedule?.getShiftForDate(date);
                        final Color shiftColor = shift?['color'] != null
                            ? Color(shift!['color'] as int)
                            : Colors.transparent;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedDate = date),
                          child: Container(
                            height: 48,
                            margin: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? const Color(0xFF38BDF8)
                                        .withValues(alpha: 0.25)
                                  : shiftColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSel
                                    ? const Color(0xFF38BDF8)
                                    : (isToday
                                          ? Colors.blueAccent
                                          : Colors.transparent),
                                width: isSel || isToday ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayNum',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel || isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: textPrimary,
                                  ),
                                ),
                                if (shift != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: shiftColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      (shift['name'] as String?)
                                              ?.characters
                                              .first ??
                                          '',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _openScheduleSettingsDialog(
    ShiftSchedule? current,
    ShiftNotifier notifier,
  ) {
    String preset = '2/2';
    DateTime startDate = current?.startDate ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Настройка шаблона графика',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              const Text(
                'Выберите популярный цикл:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['2/2', 'сутки/трое', 'день/ночь/48', '5/2'].map((p) {
                  return ChoiceChip(
                    label: Text(p),
                    selected: preset == p,
                    onSelected: (_) => setDState(() => preset = p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Дата отсчёта графика',
                  style: TextStyle(fontSize: 13),
                ),
                trailing: Text(
                  '${startDate.day}.${startDate.month}.${startDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setDState(() => startDate = picked);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                  ),
                  onPressed: () {
                    List<Map<String, dynamic>> cycle = [];
                    if (preset == '2/2') {
                      cycle = [
                        {
                          'name': 'Дневная',
                          'type': 'work',
                          'time': '08:00 - 20:00',
                          'color': const Color(0xFF2C69D1).toARGB32(),
                        },
                        {
                          'name': 'Дневная',
                          'type': 'work',
                          'time': '08:00 - 20:00',
                          'color': const Color(0xFF2C69D1).toARGB32(),
                        },
                        {
                          'name': 'Выходной',
                          'type': 'rest',
                          'time': null,
                          'color': const Color(0xFF66BB6A).toARGB32(),
                        },
                        {
                          'name': 'Выходной',
                          'type': 'rest',
                          'time': null,
                          'color': const Color(0xFF66BB6A).toARGB32(),
                        },
                      ];
                    } else if (preset == 'сутки/трое') {
                      cycle = [
                        {
                          'name': 'Сутки',
                          'type': 'work',
                          'time': '09:00 - 09:00',
                          'color': const Color(0xFFFF9800).toARGB32(),
                        },
                        {
                          'name': 'Выходной',
                          'type': 'rest',
                          'time': null,
                          'color': const Color(0xFF66BB6A).toARGB32(),
                        },
                        {
                          'name': 'Выходной',
                          'type': 'rest',
                          'time': null,
                          'color': const Color(0xFF66BB6A).toARGB32(),
                        },
                        {
                          'name': 'Выходной',
                          'type': 'rest',
                          'time': null,
                          'color': const Color(0xFF66BB6A).toARGB32(),
                        },
                      ];
                    } else if (preset == 'день/ночь/48') {
                      cycle = [
                        {
                          'name': 'День',
                          'type': 'work',
                          'time': '08:00 - 20:00',
                          'color': const Color(0xFF2C69D1).toARGB32(),
                        },
                        {
                          'name': 'Ночь',
                          'type': 'work',
                          'time': '20:00 - 08:00',
                          'color': const Color(0xFF9C27B0).toARGB32(),
                        },
                        {
                          'name': 'Отсыпной',
                          'type': 'rest',
                          'time': null,
                          'color': const Color(0xFF80CBC4).toARGB32(),
                        },
                        {
                          'name': 'Выходной',
                          'type': 'rest',
                          'time': null,
                          'color': const Color(0xFF66BB6A).toARGB32(),
                        },
                      ];
                    } else {
                      cycle = [
                        {
                          'name': 'Работа',
                          'type': 'work',
                          'time': '09:00 - 18:00',
                          'color': const Color(0xFF2C69D1).toARGB32(),
                        },
                        {
                          'name': 'Работа',
                          'type': 'work',
                          'time': '09:00 - 18:00',
                          'color': const Color(0xFF2C69D1).toARGB32(),
                        },
                        {
                          'name': 'Работа',
                          'type': 'work',
                          'time': '09:00 - 18:00',
                          'color': const Color(0xFF2C69D1).toARGB32(),
                        },
                        {
                          'name': 'Работа',
                          'type': 'work',
                          'time': '09:00 - 18:00',
                          'color': const Color(0xFF2C69D1).toARGB32(),
                        },
                        {
                          'name': 'Работа',
                          'type': 'work',
                          'time': '09:00 - 18:00',
                          'color': const Color(0xFF2C69D1).toARGB32(),
                        },
                        {
                          'name': 'Выходной',
                          'type': 'rest',
                          'time': null,
                          'color': const Color(0xFF66BB6A).toARGB32(),
                        },
                        {
                          'name': 'Выходной',
                          'type': 'rest',
                          'time': null,
                          'color': const Color(0xFF66BB6A).toARGB32(),
                        },
                      ];
                    }

                    notifier.saveSchedule(
                      ShiftSchedule(
                        id:
                            current?.id ??
                            'shift_${DateTime.now().millisecondsSinceEpoch}',
                        name: 'График $preset',
                        startDate: startDate,
                        cycleDays: cycle,
                        overrides: current?.overrides ?? {},
                      ),
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Применить шаблон',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _openDayOverrideDialog(
    DateTime date,
    Map<String, dynamic>? currentShift,
    ShiftNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Изменение на ${date.day}.${date.month}.${date.year}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.beach_access, color: Colors.green),
              title: const Text('Отгул / Отпуск'),
              onTap: () {
                notifier.setOverride(date, {
                  'name': 'Отпуск',
                  'type': 'rest',
                  'color': const Color(0xFF4CAF50).toARGB32(),
                });
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.medical_services_outlined,
                color: Colors.orangeAccent,
              ),
              title: const Text('Больничный'),
              onTap: () {
                notifier.setOverride(date, {
                  'name': 'Больничный',
                  'type': 'rest',
                  'color': const Color(0xFFFF9800).toARGB32(),
                });
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Color(0xFF38BDF8)),
              title: const Text('Подмена (Выход в смену)'),
              onTap: () {
                notifier.setOverride(date, {
                  'name': 'Подмена',
                  'type': 'work',
                  'time': '08:00 - 20:00',
                  'color': const Color(0xFFE91E63).toARGB32(),
                });
                Navigator.pop(ctx);
              },
            ),
            if (currentShift != null)
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.grey),
                title: const Text('Сбросить к шаблону'),
                onTap: () {
                  notifier.setOverride(date, null);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  String _monthName(int m) => const [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ][m - 1];

  String _monthNameGenitive(int m) => const [
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
  ][m - 1];
}
