import 'package:flutter/material.dart';

enum CalendarViewType { month, dayTimeline, agenda, yearHeatmap }

class CalendarScreen extends StatefulWidget {
  final bool isDarkMode;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> calendarEvents;
  final Function(Map<String, dynamic>, bool) onToggleTask;
  final Function(Map<String, dynamic>) onAddCalendarEvent;

  const CalendarScreen({
    super.key,
    required this.isDarkMode,
    required this.tasks,
    required this.calendarEvents,
    required this.onToggleTask,
    required this.onAddCalendarEvent,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarViewType _currentView = CalendarViewType.month;
  DateTime _focusedDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  // Список доступных календарей (нажатие переключает видимость)
  final List<Map<String, dynamic>> _userCalendars = [
    {
      'id': 'personal',
      'name': 'Личное',
      'color': const Color(0xFF66BB6A),
      'enabled': true,
    },
    {
      'id': 'work',
      'name': 'Работа',
      'color': const Color(0xFFFF5252),
      'enabled': true,
    },
  ];

  late PageController _monthPageController;
  late PageController _dayPageController;
  static const int _baseDayPage = 10000;
  static const int _baseMonthPage = 1200;

  @override
  void initState() {
    super.initState();
    _monthPageController = PageController(initialPage: _baseMonthPage);
    _dayPageController = PageController(initialPage: _baseDayPage);
  }

  @override
  void dispose() {
    _monthPageController.dispose();
    _dayPageController.dispose();
    super.dispose();
  }

  DateTime _monthFromPageIndex(int page) {
    final offset = page - _baseMonthPage;
    return DateTime(DateTime.now().year, DateTime.now().month + offset, 1);
  }

  DateTime _dayFromPageIndex(int page) {
    final offset = page - _baseDayPage;
    return DateTime.now().add(Duration(days: offset));
  }

  int _pageIndexFromDay(DateTime date) {
    final now = DateTime.now();
    final d1 = DateTime(date.year, date.month, date.day);
    final d2 = DateTime(now.year, now.month, now.day);
    return _baseDayPage + d1.difference(d2).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF191919) : const Color(0xFFF3F4F6);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderColor = isDark
        ? const Color(0xFF2E2E2E)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 10,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _formatMonthHeader(_focusedDate),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () {
                _monthPageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () {
                _monthPageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Сегодня',
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _focusedDate = now;
                _selectedDate = now;
              });
              if (_currentView == CalendarViewType.month) {
                _monthPageController.jumpToPage(_baseMonthPage);
              } else if (_currentView == CalendarViewType.dayTimeline) {
                _dayPageController.jumpToPage(_baseDayPage);
              }
            },
          ),
          IconButton(
            tooltip: _currentView == CalendarViewType.month
                ? 'Дневной вид'
                : 'Сетка месяца',
            icon: Icon(
              _currentView == CalendarViewType.month
                  ? Icons.view_day_outlined
                  : Icons.calendar_view_month,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _currentView = _currentView == CalendarViewType.month
                    ? CalendarViewType.dayTimeline
                    : CalendarViewType.month;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (val) {
              if (val == 'mode_month')
                setState(() => _currentView = CalendarViewType.month);
              if (val == 'mode_day')
                setState(() => _currentView = CalendarViewType.dayTimeline);
              if (val == 'mode_agenda')
                setState(() => _currentView = CalendarViewType.agenda);
              if (val == 'mode_heatmap')
                setState(() => _currentView = CalendarViewType.yearHeatmap);
              if (val == 'settings') _openCalendarSettingsDialog();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'mode_month',
                child: Text('Вид: Месяц'),
              ),
              const PopupMenuItem(
                value: 'mode_day',
                child: Text('Вид: День (таймлайн)'),
              ),
              const PopupMenuItem(
                value: 'mode_agenda',
                child: Text('Вид: Повестка дня'),
              ),
              const PopupMenuItem(
                value: 'mode_heatmap',
                child: Text('Вид: Годовая теплокарта'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 18, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text('Настройки и синхронизация'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: isDark
            ? const Color(0xFF383838)
            : const Color(0xFF2C69D1),
        shape: const CircleBorder(),
        elevation: 4,
        onPressed: () => _openEventCreationScreen(initialDate: _selectedDate),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildCurrentViewBody(isDark, textPrimary, borderColor),
          ),
          _buildBottomCalendarsBar(isDark, textPrimary),
        ],
      ),
    );
  }

  Widget _buildCurrentViewBody(
    bool isDark,
    Color textPrimary,
    Color borderColor,
  ) {
    switch (_currentView) {
      case CalendarViewType.month:
        return PageView.builder(
          controller: _monthPageController,
          onPageChanged: (page) {
            setState(() {
              _focusedDate = _monthFromPageIndex(page);
            });
          },
          itemBuilder: (ctx, page) {
            final monthDate = _monthFromPageIndex(page);
            return _buildMonthGrid(monthDate, isDark, textPrimary, borderColor);
          },
        );

      case CalendarViewType.dayTimeline:
        return PageView.builder(
          controller: _dayPageController,
          onPageChanged: (page) {
            setState(() {
              _selectedDate = _dayFromPageIndex(page);
            });
          },
          itemBuilder: (ctx, page) {
            final dayDate = _dayFromPageIndex(page);
            return _buildSingleDayTimeline(
              dayDate,
              isDark,
              textPrimary,
              borderColor,
            );
          },
        );

      case CalendarViewType.agenda:
        return _buildAgendaView(isDark, textPrimary, borderColor);

      case CalendarViewType.yearHeatmap:
        return _buildYearHeatmapView(isDark, textPrimary, borderColor);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWeekdayHeader(bool isDark) {
    const weekDays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
    final color = isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B);

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          for (final d in weekDays)
            Expanded(
              child: Center(
                child: Text(
                  d,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- 1. СЕТКА МЕСЯЦА ---
  Widget _buildMonthGrid(
    DateTime targetMonth,
    bool isDark,
    Color textPrimary,
    Color borderColor,
  ) {
    final firstDayOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final daysInMonth = DateTime(
      targetMonth.year,
      targetMonth.month + 1,
      0,
    ).day;
    final int startingOffset = (firstDayOfMonth.weekday - 1);
    final totalCells = ((startingOffset + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      children: [
        _buildWeekdayHeader(isDark),
        Expanded(
          child: GridView.builder(
            physics: const ClampingScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.62,
            ),
            itemBuilder: (ctx, i) {
              final dayIndex = i - startingOffset + 1;
              final isCurrentMonth = dayIndex >= 1 && dayIndex <= daysInMonth;

              DateTime cellDate;
              if (dayIndex < 1) {
                final prevMonthLastDay = DateTime(
                  targetMonth.year,
                  targetMonth.month,
                  0,
                ).day;
                cellDate = DateTime(
                  targetMonth.year,
                  targetMonth.month - 1,
                  prevMonthLastDay + dayIndex,
                );
              } else if (dayIndex > daysInMonth) {
                cellDate = DateTime(
                  targetMonth.year,
                  targetMonth.month + 1,
                  dayIndex - daysInMonth,
                );
              } else {
                cellDate = DateTime(
                  targetMonth.year,
                  targetMonth.month,
                  dayIndex,
                );
              }

              final isToday = _isSameDay(cellDate, DateTime.now());
              final isSelected = _isSameDay(cellDate, _selectedDate);
              final events = _getVisibleEventsForDate(cellDate);
              final isMonday = cellDate.weekday == DateTime.monday;
              final weekNumber = _getWeekNumber(cellDate);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = cellDate;
                    _currentView = CalendarViewType.dayTimeline;
                  });
                  final targetPage = _pageIndexFromDay(cellDate);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_dayPageController.hasClients) {
                      _dayPageController.jumpToPage(targetPage);
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday
                        ? (isDark
                              ? const Color(0xFF383838)
                              : const Color(0xFFCBD5E1))
                        : (isSelected
                              ? (isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFE2E8F0))
                              : Colors.transparent),
                    border: Border.all(
                      color: borderColor.withOpacity(0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${cellDate.day}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isCurrentMonth
                                    ? (isToday ? Colors.white : textPrimary)
                                    : (isDark
                                          ? const Color(0xFF555555)
                                          : const Color(0xFF94A3B8)),
                              ),
                            ),
                            if (isMonday)
                              Text(
                                '$weekNumber',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isDark
                                      ? const Color(0xFF666666)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          itemCount: events.length > 3 ? 3 : events.length,
                          itemBuilder: (ctx, evIdx) {
                            final ev = events[evIdx];
                            final Color evColor = ev['color'] is Color
                                ? ev['color']
                                : const Color(0xFF40C4FF);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 1.5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: evColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                ev['title'] ?? '',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
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
    );
  }

  // --- 2. ДНЕВНОЙ ТАЙМЛАЙН ---
  Widget _buildSingleDayTimeline(
    DateTime dayDate,
    bool isDark,
    Color textPrimary,
    Color borderColor,
  ) {
    final events = _getVisibleEventsForDate(dayDate);
    final now = DateTime.now();
    final isToday = _isSameDay(dayDate, now);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF202020) : const Color(0xFFE2E8F0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_weekdayShort(dayDate.weekday)}, ${dayDate.day} ${_monthNameGenitive(dayDate.month)} ${dayDate.year}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Сегодня',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 24,
            itemBuilder: (ctx, hour) {
              final hourEvents = events.where((e) {
                if (e['isAllDay'] == true) return hour == 0;
                final start = e['startTime'] ?? '00:00';
                final h = int.tryParse(start.split(':').first) ?? 0;
                return h == hour;
              }).toList();

              final isCurrentHour = isToday && now.hour == hour;

              return SizedBox(
                height: 56,
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            hour.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF888888)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: borderColor.withOpacity(0.4),
                                  width: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isCurrentHour)
                      Positioned(
                        top: (now.minute / 60) * 56,
                        left: 44,
                        right: 0,
                        child: Container(height: 1.5, color: Colors.white),
                      ),
                    if (hourEvents.isNotEmpty)
                      Positioned(
                        top: 2,
                        bottom: 2,
                        left: 48,
                        right: 8,
                        child: Row(
                          children: hourEvents.map((ev) {
                            final Color color = ev['color'] is Color
                                ? ev['color']
                                : const Color(0xFFE040FB);
                            final isAllDay = ev['isAllDay'] == true;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    _openEventCreationScreen(existingEvent: ev),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isAllDay
                                        ? 'Весь день: ${ev['title']}'
                                        : '${ev['startTime'] ?? '00:00'} ${ev['title'] ?? ''}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 3. ПОВЕСТКА ДНЯ ---
  Widget _buildAgendaView(bool isDark, Color textPrimary, Color borderColor) {
    final sortedEvents = widget.calendarEvents.where((e) {
      final calName = e['calendar'] ?? 'Личное';
      final cal = _userCalendars.firstWhere(
        (c) => c['name'] == calName,
        orElse: () => {'enabled': true},
      );
      return cal['enabled'] == true;
    }).toList();

    if (sortedEvents.isEmpty) {
      return const Center(child: Text('Нет запланированных событий'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedEvents.length,
      itemBuilder: (ctx, i) {
        final ev = sortedEvents[i];
        final d = ev['date'] as DateTime;
        final color = ev['color'] is Color
            ? ev['color']
            : const Color(0xFF38BDF8);

        return Card(
          color: isDark ? const Color(0xFF222222) : Colors.white,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color, radius: 8),
            title: Text(
              ev['title'] ?? '',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
            ),
            subtitle: Text(
              '${d.day} ${_monthNameGenitive(d.month)} • ${ev['isAllDay'] == true ? 'Весь день' : ev['startTime']}',
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: Text(
              ev['calendar'] ?? 'Личное',
              style: TextStyle(color: color, fontSize: 12),
            ),
            onTap: () => _openEventCreationScreen(existingEvent: ev),
          ),
        );
      },
    );
  }

  // --- 4. ГОДОВАЯ ТЕПЛОКАРТА ---
  Widget _buildYearHeatmapView(
    bool isDark,
    Color textPrimary,
    Color borderColor,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 12,
      itemBuilder: (ctx, mIdx) {
        final m = mIdx + 1;
        final days = DateTime(_focusedDate.year, m + 1, 0).day;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF222222) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _monthName(m),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: List.generate(days, (dIdx) {
                  final cur = DateTime(_focusedDate.year, m, dIdx + 1);
                  final cnt = _getVisibleEventsForDate(cur).length;
                  Color cellColor = isDark
                      ? const Color(0xFF2D2D2D)
                      : const Color(0xFFE2E8F0);
                  if (cnt == 1) cellColor = const Color(0xFF0E4429);
                  if (cnt == 2) cellColor = const Color(0xFF006D32);
                  if (cnt >= 3) cellColor = const Color(0xFF39D353);

                  return Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- СТРОКА КАЛЕНДАРЕЙ ВНИЗУ ---
  Widget _buildBottomCalendarsBar(bool isDark, Color textPrimary) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF282828) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: _userCalendars.map((cal) {
          final isEnabled = cal['enabled'] as bool;
          final Color calColor = cal['color'] as Color;

          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  cal['enabled'] = !isEnabled;
                });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isEnabled
                              ? calColor
                              : Colors.grey.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        cal['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isEnabled
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isEnabled ? textPrimary : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 2.5,
                    width: double.infinity,
                    color: isEnabled ? calColor : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _openCalendarSettingsDialog() {
    final nameCtrl = TextEditingController();
    Color selectedColor = const Color(0xFFE040FB);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Календари и синхронизация'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ваши календари:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._userCalendars.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: c['color'],
                      radius: 6,
                    ),
                    title: Text(c['name']),
                    trailing: Switch(
                      value: c['enabled'],
                      onChanged: (v) {
                        setDState(() => c['enabled'] = v);
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const Divider(),
                const Text(
                  'Создать локальный календарь:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Имя календаря (например, "Учеба")',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _userCalendars.add({
                          'id': DateTime.now().millisecondsSinceEpoch
                              .toString(),
                          'name': nameCtrl.text.trim(),
                          'color': selectedColor,
                          'enabled': true,
                        });
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Добавить локальный календарь'),
                ),
                const Divider(),
                const Text(
                  'Облачная синхронизация:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sync, color: Colors.blueAccent),
                  title: const Text('Google Calendar / CalDAV'),
                  subtitle: const Text(
                    'Подключить аккаунт для двусторонней синхронизации',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Служба синхронизации CalDAV готова к авторизации',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
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

  void _openEventCreationScreen({
    DateTime? initialDate,
    Map<String, dynamic>? existingEvent,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventCreationScreen(
          isDarkMode: widget.isDarkMode,
          initialDate: initialDate ?? _selectedDate,
          existingEvent: existingEvent,
          availableCalendars: _userCalendars,
          onSave: (newEvent) {
            if (existingEvent == null) {
              widget.onAddCalendarEvent(newEvent);
            } else {
              setState(() => existingEvent.addAll(newEvent));
            }
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getVisibleEventsForDate(DateTime date) {
    return widget.calendarEvents.where((e) {
      final d = e['date'] as DateTime;
      if (!_isSameDay(d, date)) return false;
      final calName = e['calendar'] ?? 'Личное';
      final cal = _userCalendars.firstWhere(
        (c) => c['name'] == calName,
        orElse: () => {'enabled': true},
      );
      return cal['enabled'] == true;
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday - 1) ~/ 7) + 1;
  }

  String _formatMonthHeader(DateTime date) {
    return '${_monthName(date.month)} ${date.year} г.';
  }

  String _monthName(int m) => const [
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ][m - 1];

  String _monthNameGenitive(int m) => const [
    'янв.',
    'февр.',
    'марта',
    'апр.',
    'мая',
    'июня',
    'июля',
    'авг.',
    'сент.',
    'окт.',
    'нояб.',
    'дек.',
  ][m - 1];

  String _weekdayShort(int d) =>
      const ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'][d - 1];
}

// =======================================================================
// ФОРМА СОЗДАНИЯ СОБЫТИЯ
// =======================================================================
class EventCreationScreen extends StatefulWidget {
  final bool isDarkMode;
  final DateTime initialDate;
  final Map<String, dynamic>? existingEvent;
  final List<Map<String, dynamic>> availableCalendars;
  final Function(Map<String, dynamic>) onSave;

  const EventCreationScreen({
    super.key,
    required this.isDarkMode,
    required this.initialDate,
    this.existingEvent,
    required this.availableCalendars,
    required this.onSave,
  });

  @override
  State<EventCreationScreen> createState() => _EventCreationScreenState();
}

class _EventCreationScreenState extends State<EventCreationScreen> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descController;

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;

  bool _isAllDay = false;
  late String _selectedCalendar;
  late Color _selectedColor;

  String _repeatOption = 'Однократно';
  String _reminderOption = 'За 15 минут';
  String _userStatus = 'Занят';
  String _privacy = 'Стандартная';
  final List<String> _participants = [];
  final List<String> _attachments = [];
  bool _saveAsTemplate = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.existingEvent;
    _titleController = TextEditingController(text: ev?['title'] ?? '');
    _locationController = TextEditingController(text: ev?['location'] ?? '');
    _descController = TextEditingController(text: ev?['desc'] ?? '');

    _startDate = ev?['date'] ?? widget.initialDate;
    _endDate = _startDate;

    _startTime = const TimeOfDay(hour: 17, minute: 0);
    _endTime = const TimeOfDay(hour: 18, minute: 0);
    _isAllDay = ev?['isAllDay'] ?? false;

    _selectedCalendar =
        ev?['calendar'] ??
        (widget.availableCalendars.isNotEmpty
            ? widget.availableCalendars.first['name']
            : 'Личное');
    final matchCal = widget.availableCalendars.firstWhere(
      (c) => c['name'] == _selectedCalendar,
      orElse: () => widget.availableCalendars.first,
    );
    _selectedColor = matchCal['color'] as Color;

    if (ev?['reminder'] != null) _reminderOption = ev!['reminder'];
    if (ev?['repeat'] != null) _repeatOption = ev!['repeat'];
    if (ev?['status'] != null) _userStatus = ev!['status'];
    if (ev?['privacy'] != null) _privacy = ev!['privacy'];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC);
    final fieldBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark
        ? const Color(0xFF9E9E9E)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: _selectedColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCalendar,
                      dropdownColor: _selectedColor,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.black87,
                      ),
                      items: widget.availableCalendars.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['name'] as String,
                          child: Text(
                            c['name'] as String,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCalendar = val;
                            final c = widget.availableCalendars.firstWhere(
                              (x) => x['name'] == val,
                            );
                            _selectedColor = c['color'] as Color;
                          });
                        }
                      },
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(
                      Icons.check,
                      color: Colors.black87,
                      size: 20,
                    ),
                    label: const Text(
                      'СОХРАНИТЬ',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: _saveEvent,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _titleController,
                    style: TextStyle(fontSize: 18, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Название',
                      hintStyle: TextStyle(color: textSecondary),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'с  ${_formatDateDay(_startDate)}',
                      style: TextStyle(color: textPrimary, fontSize: 15),
                    ),
                    trailing: _isAllDay
                        ? null
                        : TextButton(
                            child: Text(
                              _startTime.format(context),
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: _startTime,
                              );
                              if (t != null) setState(() => _startTime = t);
                            },
                          ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked;
                          if (_isAllDay || _endDate.isBefore(_startDate)) {
                            _endDate = _startDate;
                          }
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'до  ${_formatDateDay(_endDate)}',
                      style: TextStyle(color: textPrimary, fontSize: 15),
                    ),
                    trailing: _isAllDay
                        ? null
                        : TextButton(
                            child: Text(
                              _endTime.format(context),
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: _endTime,
                              );
                              if (t != null) setState(() => _endTime = t);
                            },
                          ),
                    onTap: _isAllDay
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: _startDate,
                              lastDate: DateTime(2035),
                            );
                            if (picked != null)
                              setState(() => _endDate = picked);
                          },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GMT+3 Москва, стан...',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      Row(
                        children: [
                          Text(
                            'Весь день',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _isAllDay,
                            onChanged: (v) {
                              setState(() {
                                _isAllDay = v;
                                if (_isAllDay) _endDate = _startDate;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFormBox(
                    fieldBg,
                    TextField(
                      controller: _locationController,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Место',
                        hintStyle: TextStyle(color: textSecondary),
                        prefixIcon: Icon(
                          Icons.location_on_outlined,
                          color: textSecondary,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFormBox(
                    fieldBg,
                    TextField(
                      controller: _descController,
                      maxLines: 2,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Описание',
                        hintStyle: TextStyle(color: textSecondary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFormBox(
                    fieldBg,
                    ListTile(
                      leading: Icon(
                        Icons.notification_add_outlined,
                        color: textSecondary,
                      ),
                      title: Text(
                        'Напоминание',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      subtitle: Text(
                        _reminderOption,
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickReminder,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFormBox(
                    fieldBg,
                    ListTile(
                      title: Text(
                        'ПОВТОРЕНИЕ',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                      subtitle: Text(
                        _repeatOption,
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickRepeat,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFormBox(
                    fieldBg,
                    ListTile(
                      title: Text(
                        'Участники (${_participants.length})',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      subtitle: _participants.isEmpty
                          ? const Text(
                              'Нет участников',
                              style: TextStyle(color: Colors.grey),
                            )
                          : Text(
                              _participants.join(', '),
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      trailing: const Icon(Icons.person_add_alt),
                      onTap: _addParticipantDialog,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFormBox(
                    fieldBg,
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: _pickStatus,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'МОЙ СТАТУС',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _userStatus,
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                          ),
                          const Divider(height: 20),
                          InkWell(
                            onTap: _pickPrivacy,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ПРИВАТНОСТЬ',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _privacy,
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ДОБАВИТЬ ВЛОЖЕНИЯ',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildFormBox(
                    fieldBg,
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.smartphone),
                                tooltip: 'Файл с устройства',
                                onPressed: () => _addAttachment(
                                  'Файл устройства #${_attachments.length + 1}',
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cloud_outlined),
                                tooltip: 'Облачный документ',
                                onPressed: () => _addAttachment(
                                  'Документ из облака #${_attachments.length + 1}',
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.image_outlined),
                                tooltip: 'Фотография',
                                onPressed: () => _addAttachment(
                                  'Фото #${_attachments.length + 1}.jpg',
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.mic_none),
                                tooltip: 'Голосовая заметка',
                                onPressed: () => _addAttachment(
                                  'Аудиозапись #${_attachments.length + 1}',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_attachments.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 8,
                              left: 12,
                              right: 12,
                            ),
                            child: Wrap(
                              spacing: 6,
                              children: _attachments.map((att) {
                                return Chip(
                                  label: Text(
                                    att,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onDeleted: () =>
                                      setState(() => _attachments.remove(att)),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _saveAsTemplate,
                    title: Text(
                      'Сохранить как шаблон',
                      style: TextStyle(color: textPrimary, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Для быстрой вставки типовых встреч',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                    onChanged: (v) =>
                        setState(() => _saveAsTemplate = v ?? false),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addAttachment(String name) {
    setState(() => _attachments.add(name));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Вложение "$name" прикреплено')));
  }

  void _pickReminder() {
    final opts = [
      'Нет',
      'В момент начала',
      'За 5 минут',
      'За 15 минут',
      'За 30 минут',
      'За 1 час',
      'За 1 день',
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: opts
            .map(
              (o) => ListTile(
                title: Text(o),
                trailing: _reminderOption == o
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _reminderOption = o);
                  Navigator.pop(ctx);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  void _pickRepeat() {
    final opts = [
      'Однократно',
      'Каждый день',
      'По будням',
      'Каждую неделю',
      'Каждый месяц',
      'Каждый год',
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: opts
            .map(
              (o) => ListTile(
                title: Text(o),
                trailing: _repeatOption == o
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _repeatOption = o);
                  Navigator.pop(ctx);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  void _pickStatus() {
    final opts = ['Занят', 'Свободен', 'Под вопросом', 'Вне офиса'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: opts
            .map(
              (o) => ListTile(
                title: Text(o),
                trailing: _userStatus == o
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _userStatus = o);
                  Navigator.pop(ctx);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  void _pickPrivacy() {
    final opts = ['Стандартная', 'Личное', 'Конфиденциально'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: opts
            .map(
              (o) => ListTile(
                title: Text(o),
                trailing: _privacy == o
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _privacy = o);
                  Navigator.pop(ctx);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  void _addParticipantDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить участника'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Email или имя участника',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _participants.add(ctrl.text.trim()));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormBox(Color bg, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }

  void _saveEvent() {
    if (_titleController.text.trim().isEmpty) return;

    widget.onSave({
      'id':
          widget.existingEvent?['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'title': _titleController.text.trim(),
      'date': _startDate,
      'endDate': _endDate,
      'startTime':
          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      'endTime':
          '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
      'isAllDay': _isAllDay,
      'calendar': _selectedCalendar,
      'color': _selectedColor,
      'location': _locationController.text.trim(),
      'desc': _descController.text.trim(),
      'reminder': _reminderOption,
      'repeat': _repeatOption,
      'status': _userStatus,
      'privacy': _privacy,
      'participants': _participants,
      'attachments': _attachments,
    });

    Navigator.pop(context);
  }

  String _formatDateDay(DateTime d) {
    const days = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    return '${days[d.weekday - 1]}, ${d.day} ${_monthNameGenitive(d.month)}';
  }

  String _monthNameGenitive(int m) => const [
    'янв.',
    'февр.',
    'марта',
    'апр.',
    'мая',
    'июня',
    'июля',
    'авг.',
    'сент.',
    'окт.',
    'нояб.',
    'дек.',
  ][m - 1];
}
