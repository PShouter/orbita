import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShiftScheduleScreen extends StatefulWidget {
  final bool isDarkMode;

  const ShiftScheduleScreen({super.key, required this.isDarkMode});

  @override
  State<ShiftScheduleScreen> createState() => _ShiftScheduleScreenState();
}

class _ShiftScheduleScreenState extends State<ShiftScheduleScreen> {
  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  bool _showWeekNumbers = true;

  // Список всех работ
  List<Map<String, dynamic>> _jobs = [];

  // Активная выбранная работа для быстрого проставления смен ("кисть")
  String? _selectedJobId;

  // Карта назначенных смен: key = "YYYY-MM-DD", value = List<String> (jobId)
  Map<String, List<String>> _assignedShifts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  double _calculateHours(TimeOfDay start, TimeOfDay end) {
    double startMin = (start.hour * 60 + start.minute).toDouble();
    double endMin = (end.hour * 60 + end.minute).toDouble();
    if (endMin < startMin) endMin += 24 * 60;
    return (endMin - startMin) / 60.0;
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showWeekNumbers = prefs.getBool('shift_show_week_numbers') ?? true;

      final rawJobs = prefs.getString('user_shift_jobs');
      if (rawJobs != null) {
        try {
          final List decoded = jsonDecode(rawJobs);
          _jobs = decoded.map((e) {
            final m = Map<String, dynamic>.from(e);
            m['color'] = Color(m['color'] as int);
            return m;
          }).toList();
        } catch (_) {}
      }

      if (_jobs.isEmpty) {
        _jobs = [
          {
            'id': 'job_1',
            'name': 'Основная работа',
            'color': const Color(0xFFFF5252),
            'startHour': 8,
            'startMin': 0,
            'endHour': 20,
            'endMin': 0,
          },
          {
            'id': 'job_2',
            'name': 'Подработка',
            'color': const Color(0xFF40C4FF),
            'startHour': 18,
            'startMin': 0,
            'endHour': 23,
            'endMin': 0,
          },
        ];
      }

      _selectedJobId = _jobs.first['id'];

      final rawShifts = prefs.getString('calendar_assigned_shifts');
      if (rawShifts != null) {
        try {
          final Map decoded = jsonDecode(rawShifts);
          _assignedShifts = decoded.map(
            (k, v) => MapEntry(
              k.toString(),
              (v as List).map((id) => id.toString()).toList(),
            ),
          );
        } catch (_) {}
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shift_show_week_numbers', _showWeekNumbers);

    final jobsToSave = _jobs.map((j) {
      return {
        'id': j['id'].toString(),
        'name': j['name'].toString(),
        'color': (j['color'] as Color).toARGB32(),
        'startHour': j['startHour'] as int,
        'startMin': j['startMin'] as int,
        'endHour': j['endHour'] as int,
        'endMin': j['endMin'] as int,
      };
    }).toList();

    await prefs.setString('user_shift_jobs', jsonEncode(jobsToSave));
    await prefs.setString(
      'calendar_assigned_shifts',
      jsonEncode(_assignedShifts),
    );
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Тап по числу в режиме кисти
  void _onDayTapped(DateTime date) {
    if (_selectedJobId == null) return;
    HapticFeedback.selectionClick();

    final key = _dateKey(date);
    final currentList = List<String>.from(_assignedShifts[key] ?? []);

    if (currentList.contains(_selectedJobId)) {
      currentList.remove(_selectedJobId);
    } else {
      currentList.add(_selectedJobId!);
    }

    setState(() {
      if (currentList.isEmpty) {
        _assignedShifts.remove(key);
      } else {
        _assignedShifts[key] = currentList;
      }
    });

    _saveData();
    // Моментальная синхронизация при каждом нажатии
    _syncWithMainCalendarSilently();
  }

  // Долгий тап для открытия меню выбора всех доступных работ
  void _openDayJobSelector(DateTime date) {
    final key = _dateKey(date);
    final assigned = List<String>.from(_assignedShifts[key] ?? []);

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Смены на ${date.day}.${date.month}.${date.year}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._jobs.map((j) {
                final isAssigned = assigned.contains(j['id']);
                final col = j['color'] as Color;

                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: CircleAvatar(radius: 8, backgroundColor: col),
                  title: Text(
                    j['name'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${j['startHour'].toString().padLeft(2, '0')}:${j['startMin'].toString().padLeft(2, '0')} — ${j['endHour'].toString().padLeft(2, '0')}:${j['endMin'].toString().padLeft(2, '0')}',
                  ),
                  value: isAssigned,
                  activeColor: col,
                  onChanged: (v) {
                    setMState(() {
                      if (v == true) {
                        assigned.add(j['id']);
                      } else {
                        assigned.remove(j['id']);
                      }
                    });
                    setState(() {
                      if (assigned.isEmpty) {
                        _assignedShifts.remove(key);
                      } else {
                        _assignedShifts[key] = List.from(assigned);
                      }
                    });
                    _saveData();
                    _syncWithMainCalendarSilently();
                  },
                );
              }),
              const SizedBox(height: 8),
              if (assigned.isNotEmpty)
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Очистить день полностью'),
                    onPressed: () {
                      setState(() {
                        _assignedShifts.remove(key);
                      });
                      _saveData();
                      _syncWithMainCalendarSilently();
                      Navigator.pop(ctx);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Полная моментальная синхронизация с основным календарём
  Future<void> _syncWithMainCalendarSilently({bool notifyUser = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final rawEvents = prefs.getString('cached_calendar_events');
    List<Map<String, dynamic>> events = [];

    if (rawEvents != null) {
      try {
        final List decoded = jsonDecode(rawEvents);
        events = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    // Регистрация категорий в календаре
    final rawCals = prefs.getString('saved_user_calendars');
    List<Map<String, dynamic>> userCalendars = [];
    if (rawCals != null) {
      try {
        final List decoded = jsonDecode(rawCals);
        userCalendars = decoded
            .map((c) => Map<String, dynamic>.from(c))
            .toList();
      } catch (_) {}
    }

    for (final j in _jobs) {
      final name = j['name'].toString();
      final col = (j['color'] as Color).toARGB32();
      if (!userCalendars.any((c) => c['name'] == name)) {
        userCalendars.add({
          'id': 'shift_${j['id']}',
          'name': name,
          'color': col,
          'enabled': true,
        });
      }
    }
    await prefs.setString('saved_user_calendars', jsonEncode(userCalendars));

    // Удаляем все старые события смен (префикс shift_event_)
    events.removeWhere((e) => e['id'].toString().startsWith('shift_event_'));

    int syncedCount = 0;

    // Генерируем актуальные события по карте
    _assignedShifts.forEach((dateKey, jobIds) {
      final dateParts = dateKey.split('-');
      if (dateParts.length == 3) {
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        final shiftDate = DateTime(year, month, day);

        for (final jId in jobIds) {
          final job = _jobs.firstWhere(
            (element) => element['id'] == jId,
            orElse: () => {},
          );
          if (job.isNotEmpty) {
            final sHour = job['startHour'] as int;
            final sMin = job['startMin'] as int;
            final eHour = job['endHour'] as int;
            final eMin = job['endMin'] as int;

            final startStr =
                '${sHour.toString().padLeft(2, '0')}:${sMin.toString().padLeft(2, '0')}';
            final endStr =
                '${eHour.toString().padLeft(2, '0')}:${eMin.toString().padLeft(2, '0')}';

            events.add({
              'id': 'shift_event_${jId}_$dateKey',
              'title': job['name'],
              'date': shiftDate.toIso8601String(),
              'endDate': shiftDate.toIso8601String(),
              'startTime': startStr,
              'endTime': endStr,
              'isAllDay': false,
              'calendar': job['name'],
              'color': (job['color'] as Color).toARGB32(),
              'location': '',
              'desc': 'Смена по графику',
            });
            syncedCount++;
          }
        }
      }
    });

    await prefs.setString('cached_calendar_events', jsonEncode(events));

    if (notifyUser && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Синхронизировано: $syncedCount смен в основном календаре',
          ),
          backgroundColor: const Color(0xFF2C69D1),
        ),
      );
    }
  }

  // Рассинхронизация (удаление всех смен в рамках выбранного месяца)
  Future<void> _unsyncCurrentMonth() async {
    final prefs = await SharedPreferences.getInstance();
    final rawEvents = prefs.getString('cached_calendar_events');
    if (rawEvents == null) return;

    List<Map<String, dynamic>> events = [];
    try {
      final List decoded = jsonDecode(rawEvents);
      events = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return;
    }

    final m = _currentMonth.month;
    final y = _currentMonth.year;

    // Удаляем из основного календаря только смены этого месяца
    events.removeWhere((e) {
      if (e['id'].toString().startsWith('shift_event_')) {
        final d = DateTime.tryParse(e['date'] ?? '');
        if (d != null && d.year == y && d.month == m) {
          return true;
        }
      }
      return false;
    });

    await prefs.setString('cached_calendar_events', jsonEncode(events));

    // Очищаем назначенные смены в модели графика для этого месяца
    setState(() {
      _assignedShifts.removeWhere((key, val) {
        final parts = key.split('-');
        return int.parse(parts[0]) == y && int.parse(parts[1]) == m;
      });
    });

    await _saveData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Все смены за ${_monthName(m)} удалены из основного календаря',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday - 1) ~/ 7) + 1;
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'График смен',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Добавить новую работу',
            icon: const Icon(
              Icons.add_business_outlined,
              color: Color(0xFF38BDF8),
            ),
            onPressed: () => _openJobEditor(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Панель выбора активной работы для проставления (Кисть)
          Text(
            'Выберите работу для проставления на дату:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _jobs.map((job) {
                final isSelected = _selectedJobId == job['id'];
                final col = job['color'] as Color;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    avatar: CircleAvatar(radius: 6, backgroundColor: col),
                    label: Text(
                      job['name'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : textPrimary,
                      ),
                    ),
                    selectedColor: col,
                    backgroundColor: cardBg,
                    side: BorderSide(color: isSelected ? col : borderColor),
                    onSelected: (val) {
                      setState(() => _selectedJobId = job['id']);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Кнопки управления синхронизацией
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2C69D1),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text(
                    'Синхронизировать',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () =>
                      _syncWithMainCalendarSilently(notifyUser: true),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.sync_disabled, size: 18),
                label: const Text(
                  'Рассинхронизировать',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: _unsyncCurrentMonth,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Переключатель месяца
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
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
                '${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
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
          const SizedBox(height: 6),

          // Сетка календаря с быстрым кликом
          _buildMonthGrid(cardBg, borderColor, textPrimary, textSecondary),
          const SizedBox(height: 12),

          const Center(
            child: Text(
              '💡 Тап по числу: проставить/снять выбранную работу. Долгий тап: список всех смен.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Список работ для редактирования/удаления
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Управление работами:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => _openJobEditor(),
                child: const Text('+ Добавить'),
              ),
            ],
          ),
          ..._jobs.map((job) {
            final col = job['color'] as Color;
            final sTime = TimeOfDay(
              hour: job['startHour'],
              minute: job['startMin'],
            );
            final eTime = TimeOfDay(
              hour: job['endHour'],
              minute: job['endMin'],
            );
            final hours = _calculateHours(sTime, eTime);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(radius: 8, backgroundColor: col),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${sTime.format(context)} — ${eTime.format(context)} (${hours.toStringAsFixed(1)} ч.)',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: () => _openJobEditor(existingJob: job),
                  ),
                  if (_jobs.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        setState(() {
                          _jobs.remove(job);
                          if (_selectedJobId == job['id']) {
                            _selectedJobId = _jobs.first['id'];
                          }
                        });
                        _saveData();
                      },
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final int startingOffset = (firstDay.weekday - 1);
    final totalCells = ((startingOffset + daysInMonth + 6) ~/ 7) * 7;
    final int weeksCount = totalCells ~/ 7;

    const weekDays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (_showWeekNumbers)
                SizedBox(
                  width: 26,
                  child: Center(
                    child: Text(
                      '№',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ),
              for (final wd in weekDays)
                Expanded(
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
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          for (int w = 0; w < weeksCount; w++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  if (_showWeekNumbers)
                    Builder(
                      builder: (ctx) {
                        final sampleDayIndex = (w * 7) - startingOffset + 1;
                        DateTime weekDate;
                        if (sampleDayIndex < 1) {
                          weekDate = DateTime(
                            _currentMonth.year,
                            _currentMonth.month,
                            1,
                          );
                        } else if (sampleDayIndex > daysInMonth) {
                          weekDate = DateTime(
                            _currentMonth.year,
                            _currentMonth.month,
                            daysInMonth,
                          );
                        } else {
                          weekDate = DateTime(
                            _currentMonth.year,
                            _currentMonth.month,
                            sampleDayIndex,
                          );
                        }
                        return SizedBox(
                          width: 26,
                          child: Center(
                            child: Text(
                              '${_getWeekNumber(weekDate)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: textSecondary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  for (int d = 0; d < 7; d++)
                    Expanded(
                      child: Builder(
                        builder: (ctx) {
                          final cellIndex = (w * 7) + d;
                          final dayNumber = cellIndex - startingOffset + 1;

                          if (dayNumber < 1 || dayNumber > daysInMonth) {
                            return const SizedBox(height: 44);
                          }

                          final date = DateTime(
                            _currentMonth.year,
                            _currentMonth.month,
                            dayNumber,
                          );
                          final key = _dateKey(date);
                          final assignedJobIds = _assignedShifts[key] ?? [];
                          final hasJobs = assignedJobIds.isNotEmpty;
                          final isToday =
                              date.year == DateTime.now().year &&
                              date.month == DateTime.now().month &&
                              date.day == DateTime.now().day;

                          final assignedColors = assignedJobIds
                              .map(
                                (id) => _jobs.firstWhere(
                                  (j) => j['id'] == id,
                                  orElse: () => {},
                                )['color'],
                              )
                              .whereType<Color>()
                              .toList();

                          return GestureDetector(
                            onTap: () => _onDayTapped(date),
                            onLongPress: () => _openDayJobSelector(date),
                            child: Container(
                              height: 44,
                              margin: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: hasJobs
                                    ? assignedColors.first.withValues(
                                        alpha: 0.18,
                                      )
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isToday
                                      ? const Color(0xFF38BDF8)
                                      : (hasJobs
                                            ? assignedColors.first.withValues(
                                                alpha: 0.8,
                                              )
                                            : borderColor.withValues(
                                                alpha: 0.2,
                                              )),
                                  width: isToday ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$dayNumber',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: hasJobs || isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isToday
                                          ? const Color(0xFF38BDF8)
                                          : textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (hasJobs)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: assignedColors.take(3).map((
                                        col,
                                      ) {
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 1.5,
                                          ),
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: col,
                                          ),
                                        );
                                      }).toList(),
                                    )
                                  else
                                    const SizedBox(height: 5),
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

  // Диалог создания/редактирования работы
  void _openJobEditor({Map<String, dynamic>? existingJob}) {
    final nameCtrl = TextEditingController(text: existingJob?['name'] ?? '');
    TimeOfDay startTime = TimeOfDay(
      hour: existingJob?['startHour'] ?? 8,
      minute: existingJob?['startMin'] ?? 0,
    );
    TimeOfDay endTime = TimeOfDay(
      hour: existingJob?['endHour'] ?? 20,
      minute: existingJob?['endMin'] ?? 0,
    );

    Color pickedColor = existingJob?['color'] ?? const Color(0xFFFF5252);

    final palette = [
      const Color(0xFFFF5252),
      const Color(0xFF40C4FF),
      const Color(0xFF66BB6A),
      const Color(0xFFFFB300),
      const Color(0xFFE040FB),
      const Color(0xFF7C4DFF),
      const Color(0xFFFF9100),
      const Color(0xFF00E676),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final hours = _calculateHours(startTime, endTime);

          return AlertDialog(
            title: Text(
              existingJob == null ? 'Новая работа' : 'Редактировать работу',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Название (Основная, Подработка, Дежурство)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Начало смены',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: Text(
                      startTime.format(context),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: startTime,
                      );
                      if (t != null) setDState(() => startTime = t);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Конец смены',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: Text(
                      endTime.format(context),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: endTime,
                      );
                      if (t != null) setDState(() => endTime = t);
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: pickedColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Длительность смены:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${hours.toStringAsFixed(1)} ч.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: pickedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Цвет смены:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: palette.map((col) {
                      final isSel = pickedColor == col;
                      return GestureDetector(
                        onTap: () => setDState(() => pickedColor = col),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: isSel
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim().isEmpty
                      ? 'Работа'
                      : nameCtrl.text.trim();

                  if (existingJob == null) {
                    final newJob = {
                      'id': 'job_${DateTime.now().millisecondsSinceEpoch}',
                      'name': name,
                      'color': pickedColor,
                      'startHour': startTime.hour,
                      'startMin': startTime.minute,
                      'endHour': endTime.hour,
                      'endMin': endTime.minute,
                    };
                    _jobs.add(newJob);
                    _selectedJobId = newJob['id'].toString();
                  } else {
                    existingJob['name'] = name;
                    existingJob['color'] = pickedColor;
                    existingJob['startHour'] = startTime.hour;
                    existingJob['startMin'] = startTime.minute;
                    existingJob['endHour'] = endTime.hour;
                    existingJob['endMin'] = endTime.minute;
                  }

                  setState(() {});
                  _saveData();
                  _syncWithMainCalendarSilently();
                  Navigator.pop(ctx);
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
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
}
