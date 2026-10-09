import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/calendar_provider.dart';
import '../providers/tasks_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const CalendarScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  final String _viewMode = 'Месяц'; // 'Месяц', 'Неделя', 'День'

  List<Map<String, dynamic>> _userCalendars = [];

  @override
  void initState() {
    super.initState();
    _loadUserCalendars();
  }

  Future<void> _loadUserCalendars() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_user_calendars');
    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw);
        setState(() {
          _userCalendars = decoded
              .map((c) => Map<String, dynamic>.from(c))
              .toList();
        });
      } catch (_) {}
    }

    if (_userCalendars.isEmpty) {
      _userCalendars = [
        {
          'id': 'main',
          'name': 'Основной',
          'color': const Color(0xFF2C69D1).toARGB32(),
          'enabled': true,
        },
        {
          'id': 'work',
          'name': 'Работа',
          'color': const Color(0xFFFF5252).toARGB32(),
          'enabled': true,
        },
        {
          'id': 'personal',
          'name': 'Личное',
          'color': const Color(0xFF66BB6A).toARGB32(),
          'enabled': true,
        },
      ];
    }
  }

  bool _isCalendarEnabled(String? calName) {
    if (calName == null) return true;
    final found = _userCalendars.firstWhere(
      (c) => c['name'] == calName,
      orElse: () => {'enabled': true},
    );
    return found['enabled'] != false;
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = ref.watch(calendarProvider);
    final allTasks = ref.watch(tasksProvider);

    // Фильтруем события по включенным календарям
    final visibleEvents = allEvents
        .where((e) => _isCalendarEnabled(e['calendar']))
        .toList();

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

    // События и задачи на выбранный день
    final dayEvents = visibleEvents.where((e) {
      final d = e['date'] as DateTime?;
      return d != null &&
          d.year == _selectedDate.year &&
          d.month == _selectedDate.month &&
          d.day == _selectedDate.day;
    }).toList();

    final dayTasks = allTasks.where((t) {
      if (t['isNoDate'] == true || t['date'] == null) return false;
      final d = t['date'] as DateTime?;
      return d != null &&
          d.year == _selectedDate.year &&
          d.month == _selectedDate.month &&
          d.day == _selectedDate.day;
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF38BDF8),
        onPressed: () => _openCreateEventDialog(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Шапка: Месяц/Год и переключатели режимов
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    '${_monthName(_focusedMonth.month)} ${_focusedMonth.year}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 22),
                    onPressed: () => setState(() {
                      _focusedMonth = DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month - 1,
                        1,
                      );
                    }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 22),
                    onPressed: () => setState(() {
                      _focusedMonth = DateTime(
                        _focusedMonth.year,
                        _focusedMonth.month + 1,
                        1,
                      );
                    }),
                  ),
                  IconButton(
                    tooltip: 'Фильтр календарей',
                    icon: const Icon(Icons.tune, size: 20),
                    onPressed: _openCalendarsFilterDialog,
                  ),
                ],
              ),
            ),

            // Сетка месяца
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildMonthGrid(
                cardBg,
                borderColor,
                textPrimary,
                textSecondary,
                visibleEvents,
              ),
            ),
            const SizedBox(height: 12),

            // Заголовок выбранного дня
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Планы на ${_selectedDate.day} ${_monthNameGenitive(_selectedDate.month)}:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${dayEvents.length} событий • ${dayTasks.length} задач',
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Список событий и задач на день
            Expanded(
              child: (dayEvents.isEmpty && dayTasks.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 40,
                            color: Colors.grey.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'На этот день планов нет',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      children: [
                        // События
                        ...dayEvents.map((ev) {
                          final color = ev['color'] is Color
                              ? ev['color'] as Color
                              : const Color(0xFF2C69D1);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ev['title'] ?? 'Событие',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        ev['isAllDay'] == true
                                            ? 'Весь день • ${ev['calendar'] ?? 'Основной'}'
                                            : '${ev['startTime'] ?? ''} - ${ev['endTime'] ?? ''} • ${ev['calendar'] ?? 'Основной'}',
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(calendarProvider.notifier)
                                        .deleteEvent(ev['id'].toString());
                                  },
                                ),
                              ],
                            ),
                          );
                        }),

                        // Задачи
                        ...dayTasks.map((t) {
                          final isDone = t['done'] == true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
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
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t['title'] ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDone
                                              ? textSecondary
                                              : textPrimary,
                                          decoration: isDone
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      if (t['time'] != null)
                                        Text(
                                          '⏱ ${t['time']}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF38BDF8),
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
    );
  }

  Widget _buildMonthGrid(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    List<Map<String, dynamic>> events,
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

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
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
                            return const SizedBox(height: 38);
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

                          final dateEvents = events.where((e) {
                            final ed = e['date'] as DateTime?;
                            return ed != null &&
                                ed.year == date.year &&
                                ed.month == date.month &&
                                ed.day == date.day;
                          }).toList();

                          return GestureDetector(
                            onTap: () => setState(() => _selectedDate = date),
                            child: Container(
                              height: 38,
                              margin: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFF38BDF8)
                                          .withValues(alpha: 0.2)
                                    : (isToday
                                          ? Colors.blueGrey.withValues(
                                              alpha: 0.1,
                                            )
                                          : Colors.transparent),
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
                                      color: isSel
                                          ? const Color(0xFF38BDF8)
                                          : textPrimary,
                                    ),
                                  ),
                                  if (dateEvents.isNotEmpty)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: dateEvents.take(3).map((ev) {
                                        final col = ev['color'] is Color
                                            ? ev['color'] as Color
                                            : const Color(0xFF2C69D1);
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 1,
                                          ),
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: col,
                                          ),
                                        );
                                      }).toList(),
                                    )
                                  else
                                    const SizedBox(height: 4),
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
      ),
    );
  }

  void _openCreateEventDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    DateTime eventDate = _selectedDate;
    TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 0);
    bool isAllDay = false;
    String selectedCal = _userCalendars.isNotEmpty
        ? _userCalendars.first['name']
        : 'Основной';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Новое событие',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Название события',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedCal,
                  decoration: const InputDecoration(
                    labelText: 'Календарь',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _userCalendars
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['name'].toString(),
                          child: Text(c['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDState(() => selectedCal = v ?? selectedCal),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Весь день',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: isAllDay,
                  onChanged: (v) => setDState(() => isAllDay = v),
                ),
                if (!isAllDay) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Начало',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            startTime.format(context),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                            );
                            if (t != null) setDState(() => startTime = t);
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Конец',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            endTime.format(context),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: endTime,
                            );
                            if (t != null) setDState(() => endTime = t);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Местоположение',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                      ),
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) return;

                        final calMeta = _userCalendars.firstWhere(
                          (c) => c['name'] == selectedCal,
                          orElse: () => {},
                        );
                        final calColor = calMeta['color'] != null
                            ? Color(calMeta['color'] as int)
                            : const Color(0xFF2C69D1);

                        ref.read(calendarProvider.notifier).addEvent({
                          'id':
                              'event_${DateTime.now().millisecondsSinceEpoch}',
                          'title': title,
                          'date': eventDate,
                          'endDate': eventDate,
                          'startTime': isAllDay
                              ? null
                              : '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                          'endTime': isAllDay
                              ? null
                              : '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                          'isAllDay': isAllDay,
                          'calendar': selectedCal,
                          'color': calColor,
                          'location': locationCtrl.text.trim(),
                          'desc': descCtrl.text.trim(),
                        });

                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Создать',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCalendarsFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Мои календари'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _userCalendars.map((c) {
              final col = Color(c['color'] as int);
              final isEn = c['enabled'] != false;
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                secondary: CircleAvatar(radius: 6, backgroundColor: col),
                title: Text(c['name']),
                value: isEn,
                activeColor: col,
                onChanged: (v) async {
                  setDState(() => c['enabled'] = v ?? true);
                  setState(() {});
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                    'saved_user_calendars',
                    jsonEncode(_userCalendars),
                  );
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Закрыть'),
            ),
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
