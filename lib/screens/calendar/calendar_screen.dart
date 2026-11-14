import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/calendar_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../services/google_calendar_service.dart';
import '../../theme/app_theme.dart';
import '../settings/sections/calendar_settings_screen.dart';
import 'create_event_screen.dart';
import 'manage_calendars_screen.dart';

typedef JsonMap = Map<String, dynamic>;

enum CalendarViewType { month, week, day }

class CalendarScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const CalendarScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final ScrollController _scrollController;
  CalendarViewType _currentView = CalendarViewType.month;
  bool _showWeekNumbers = false;
  bool _isSyncingGoogle = false;

  static const int _initialWeekOffset = 520;
  late final DateTime _baseMonday;
  DateTime _visibleDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _baseMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    _scrollController = ScrollController(
      initialScrollOffset: _initialWeekOffset * 68.0,
    );

    _loadCalendarPreferences();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(calendarProvider.notifier).loadEvents();
      ref.read(userCalendarsProvider.notifier).loadCalendars();

      try {
        final hasSession = await GoogleCalendarService.instance.init();
        if (hasSession && mounted) {
          setState(() => _isSyncingGoogle = true);
          await ref.read(calendarProvider.notifier).syncWithGoogleCalendar();
          if (mounted) {
            setState(() => _isSyncingGoogle = false);
          }
        }
      } catch (e) {
        debugPrint('Ошибка автоматической фоновой синхронизации: $e');
        if (mounted) {
          setState(() => _isSyncingGoogle = false);
        }
      }
    });

    ref.listenManual(shiftProvider, (previous, next) {
      ref.read(calendarProvider.notifier).loadEvents();
    });
  }

  Future<void> _loadCalendarPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showWeekNumbers = prefs.getBool('cal_show_week_numbers') ?? false;
      final initialViewStr = prefs.getString('cal_initial_view') ?? 'Месяц';
      if (initialViewStr == 'День') {
        _currentView = CalendarViewType.day;
      } else if (initialViewStr == 'Неделя') {
        _currentView = CalendarViewType.week;
      } else {
        _currentView = CalendarViewType.month;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToToday() {
    setState(() {
      _selectedDate = DateTime.now();
      _visibleDate = DateTime.now();
    });
    if (_currentView == CalendarViewType.month) {
      _scrollController.animateTo(
        _initialWeekOffset * 68.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  Future<void> _handleGoogleSync(AppColorsExtension colors) async {
    setState(() => _isSyncingGoogle = true);
    try {
      final count =
          await ref.read(calendarProvider.notifier).syncWithGoogleCalendar();
      if (!mounted) return;

      final email = GoogleCalendarService.instance.currentUser?.email;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Синхронизировано $count событий Google ($email)'
                : 'События Google актуальны или авторизация отменена',
            style: const TextStyle(fontFamily: 'Onest'),
          ),
          backgroundColor: colors.accent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка синхронизации: $e',
              style: const TextStyle(fontFamily: 'Onest')),
          backgroundColor: colors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncingGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final calendars = ref.watch(userCalendarsProvider);
    final allEvents = ref.watch(calendarProvider);
    final allTasks = ref.watch(tasksProvider);

    final visibleCalendarTitles =
        calendars.where((c) => c.isVisible).map((c) => c.title).toSet();

    final events = allEvents.where((e) {
      final calTitle = e['calendar'] as String? ?? 'Основной';
      if (calendars.any((c) => c.title == calTitle)) {
        return visibleCalendarTitles.contains(calTitle);
      }
      return true;
    }).toList();

    final datedTasks = allTasks.where((t) {
      if (t['isNoDate'] == true || t['date'] == null) return false;
      return t['date'] is DateTime;
    }).toList();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(colors),
                if (_isSyncingGoogle)
                  LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  ),
                if (_currentView == CalendarViewType.month) ...[
                  _buildWeekHeader(colors),
                  Divider(height: 1, color: colors.nested),
                ],
                Expanded(
                  child: _buildCurrentView(events, datedTasks, colors),
                ),
                _buildBottomCalendarBar(calendars, colors),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 64,
              child: FloatingActionButton(
                backgroundColor: colors.accent,
                foregroundColor: colors.isDark ? Colors.black : Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                onPressed: () => _openAddMenu(colors),
                child: const Icon(Icons.add, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView(
    List<JsonMap> events,
    List<JsonMap> tasks,
    AppColorsExtension colors,
  ) {
    switch (_currentView) {
      case CalendarViewType.month:
        return _buildContinuousWeekList(events, tasks, colors);
      case CalendarViewType.week:
        return _buildWeekView(events, tasks, colors);
      case CalendarViewType.day:
        return _buildDayView(events, tasks, colors);
    }
  }

  Widget _buildHeader(AppColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_monthName(_visibleDate.month)} ${_visibleDate.year}',
            style: TextStyle(
              fontFamily: 'Unbounded',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Сегодня',
                icon: Icon(
                  Icons.today,
                  color: colors.accent,
                  size: 22,
                ),
                onPressed: _scrollToToday,
              ),

              // Переключатель режимов: Месяц / Неделя / День
              PopupMenuButton<CalendarViewType>(
                tooltip: 'Режим отображения',
                color: colors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colors.nested),
                ),
                icon: Icon(
                  _currentView == CalendarViewType.month
                      ? Icons.calendar_view_month
                      : (_currentView == CalendarViewType.week
                          ? Icons.calendar_view_week
                          : Icons.calendar_view_day),
                  color: colors.text,
                  size: 22,
                ),
                onSelected: (view) {
                  setState(() {
                    _currentView = view;
                  });
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: CalendarViewType.month,
                    child: Row(
                      children: [
                        Icon(Icons.calendar_view_month,
                            size: 18, color: colors.text),
                        const SizedBox(width: 8),
                        Text('Месяц',
                            style: TextStyle(
                                fontFamily: 'Onest', color: colors.text)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: CalendarViewType.week,
                    child: Row(
                      children: [
                        Icon(Icons.calendar_view_week,
                            size: 18, color: colors.text),
                        const SizedBox(width: 8),
                        Text('Неделя',
                            style: TextStyle(
                                fontFamily: 'Onest', color: colors.text)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: CalendarViewType.day,
                    child: Row(
                      children: [
                        Icon(Icons.calendar_view_day,
                            size: 18, color: colors.text),
                        const SizedBox(width: 8),
                        Text('День',
                            style: TextStyle(
                                fontFamily: 'Onest', color: colors.text)),
                      ],
                    ),
                  ),
                ],
              ),

              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: colors.text, size: 22),
                color: colors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colors.nested),
                ),
                onSelected: (val) async {
                  if (val == 'google_sync') {
                    _handleGoogleSync(colors);
                  } else if (val == 'invites') {
                    _showInvitesDialog(colors);
                  } else if (val == 'calendars') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManageCalendarsScreen(
                          isDarkMode: colors.isDark,
                        ),
                      ),
                    );
                  } else if (val == 'settings') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CalendarSettingsScreen(
                          isDarkMode: colors.isDark,
                        ),
                      ),
                    );
                    _loadCalendarPreferences();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'google_sync',
                    child: Row(
                      children: [
                        Icon(Icons.sync, color: colors.accent, size: 18),
                        const SizedBox(width: 8),
                        Text('Синхронизировать Google',
                            style: TextStyle(
                                fontFamily: 'Onest', color: colors.text)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'invites',
                    child: Row(
                      children: [
                        Icon(Icons.mail_outline, size: 18, color: colors.text),
                        const SizedBox(width: 8),
                        Text('Приглашения',
                            style: TextStyle(
                                fontFamily: 'Onest', color: colors.text)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'calendars',
                    child: Row(
                      children: [
                        Icon(Icons.tune, size: 18, color: colors.text),
                        const SizedBox(width: 8),
                        Text('Календари',
                            style: TextStyle(
                                fontFamily: 'Onest', color: colors.text)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          color: colors.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text('Настройки',
                            style: TextStyle(
                                fontFamily: 'Onest', color: colors.text)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekHeader(AppColorsExtension colors) {
    const weekDays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          if (_showWeekNumbers)
            SizedBox(
              width: 24,
              child: Center(
                child: Text(
                  '#',
                  style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 10,
                      color: colors.text.withValues(alpha: 0.4)),
                ),
              ),
            ),
          ...weekDays.map(
            (wd) => Expanded(
              child: Center(
                child: Text(
                  wd,
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: (wd == 'СБ' || wd == 'ВС')
                        ? colors.error.withValues(alpha: 0.85)
                        : colors.text.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinuousWeekList(
    List<JsonMap> events,
    List<JsonMap> tasks,
    AppColorsExtension colors,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        final currentWeekIdx = (_scrollController.offset / 68.0).round();
        final offsetWeeks = currentWeekIdx - _initialWeekOffset;
        final midWeekDay = _baseMonday.add(Duration(days: offsetWeeks * 7 + 3));
        if (midWeekDay.month != _visibleDate.month ||
            midWeekDay.year != _visibleDate.year) {
          setState(() {
            _visibleDate = midWeekDay;
          });
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: 1040,
        itemExtent: 68.0,
        itemBuilder: (ctx, index) {
          final offsetWeeks = index - _initialWeekOffset;
          final startOfWeek = _baseMonday.add(Duration(days: offsetWeeks * 7));
          final weekNum = _getWeekNumber(startOfWeek);

          return Row(
            children: [
              if (_showWeekNumbers)
                SizedBox(
                  width: 24,
                  child: Center(
                    child: Text(
                      '$weekNum',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 9,
                        color: colors.text.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Row(
                  children: List.generate(7, (d) {
                    final date = startOfWeek.add(Duration(days: d));
                    return Expanded(
                      child: _buildDayCell(date, events, tasks, colors),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    List<JsonMap> events,
    List<JsonMap> tasks,
    AppColorsExtension colors,
  ) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isSel = date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;
    final isCurrentMonth = date.month == _visibleDate.month;

    final dayEvents = events.where((e) {
      final ed = e['date'] as DateTime;
      return ed.year == date.year &&
          ed.month == date.month &&
          ed.day == date.day;
    }).toList();

    final dayTasks = tasks.where((t) {
      final td = t['date'] as DateTime;
      return td.year == date.year &&
          td.month == date.month &&
          td.day == date.day;
    }).toList();

    final List<Widget> cellItems = [];

    for (final ev in dayEvents) {
      final c = ev['color'] as Color? ?? colors.accent;
      final isShift = ev['calendar'] == 'Смены';
      final isGoogle = ev['calendar'] == 'Google';

      cellItems.add(
        Container(
          margin: const EdgeInsets.only(top: 1, left: 1, right: 1),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            border: isShift || isGoogle
                ? Border.all(color: Colors.white70, width: 0.5)
                : null,
          ),
          child: Text(
            (isGoogle ? 'G: ' : '') + (ev['title'] ?? ''),
            style: const TextStyle(
              fontFamily: 'Onest',
              fontSize: 8,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    for (final t in dayTasks) {
      final isDone = t['done'] == true;
      cellItems.add(
        Container(
          margin: const EdgeInsets.only(top: 1, left: 1, right: 1),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: isDone
                ? colors.nested.withValues(alpha: 0.5)
                : colors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color:
                  isDone ? colors.nested : colors.accent.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Text(
                isDone ? '✓ ' : '□ ',
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontSize: 7,
                  color: isDone
                      ? colors.text.withValues(alpha: 0.4)
                      : colors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  t['title'] ?? '',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 8,
                    color: isDone
                        ? colors.text.withValues(alpha: 0.4)
                        : colors.text,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalCount = dayEvents.length + dayTasks.length;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedDate = date);
        _showDayPopup(date, dayEvents, dayTasks, colors);
      },
      onDoubleTap: () {
        setState(() {
          _selectedDate = date;
          _currentView = CalendarViewType.day;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(
          color: isSel
              ? colors.accent.withValues(alpha: 0.18)
              : (isToday
                  ? colors.accent.withValues(alpha: 0.08)
                  : Colors.transparent),
          border: Border.all(
            color: isSel
                ? colors.accent
                : (isToday
                    ? colors.accent
                    : colors.nested.withValues(alpha: 0.4)),
            width: isSel || isToday ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(
                '${date.day}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: isToday || isSel ? 'Unbounded' : 'Onest',
                  fontSize: 10,
                  fontWeight:
                      isToday || isSel ? FontWeight.w600 : FontWeight.normal,
                  color: isToday
                      ? colors.accent
                      : (isCurrentMonth
                          ? colors.text
                          : colors.text.withValues(alpha: 0.35)),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: cellItems.take(2).toList(),
              ),
            ),
            if (totalCount > 2)
              Text(
                '+${totalCount - 2}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontSize: 8,
                  color: colors.text.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Режим недели (7 дней с расписанием событий и задач)
  Widget _buildWeekView(
    List<JsonMap> events,
    List<JsonMap> tasks,
    AppColorsExtension colors,
  ) {
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          color: colors.card,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final d = startOfWeek.add(Duration(days: i));
              final isSel = d.year == _selectedDate.year &&
                  d.month == _selectedDate.month &&
                  d.day == _selectedDate.day;
              final now = DateTime.now();
              final isToday = d.year == now.year &&
                  d.month == now.month &&
                  d.day == now.day;
              const wds = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

              return InkWell(
                onTap: () => setState(() => _selectedDate = d),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? colors.accent.withValues(alpha: 0.2)
                        : (isToday
                            ? colors.accent.withValues(alpha: 0.08)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel
                          ? colors.accent
                          : (isToday ? colors.accent : Colors.transparent),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        wds[i],
                        style: TextStyle(
                          fontFamily: 'Onest',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: (i >= 5)
                              ? colors.error
                              : colors.text.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontFamily: isToday || isSel ? 'Unbounded' : 'Onest',
                          fontSize: 13,
                          fontWeight: isSel || isToday
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isToday ? colors.accent : colors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        Divider(height: 1, color: colors.nested),
        Expanded(
          child: _buildDayView(events, tasks, colors),
        ),
      ],
    );
  }

  void _showDayPopup(
    DateTime date,
    List<JsonMap> dayEvents,
    List<JsonMap> dayTasks,
    AppColorsExtension colors,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${date.day} ${_monthNameGenitive(date.month)} ${date.year}',
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _currentView = CalendarViewType.day);
                      },
                      child: Text(
                        'Открыть день',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (dayEvents.isEmpty && dayTasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Событий и задач нет',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.text.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                if (dayEvents.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'СОБЫТИЯ',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.8,
                        color: colors.text.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  ...dayEvents.map(
                    (ev) => Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 6,
                          backgroundColor:
                              ev['color'] as Color? ?? colors.accent,
                        ),
                        title: Text(
                          ev['title'] ?? '',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: colors.text,
                          ),
                        ),
                        subtitle: Text(
                          ev['isAllDay'] == true
                              ? 'Весь день (${ev['calendar']})'
                              : '${ev['startTime'] ?? ''} - ${ev['endTime'] ?? ''} (${ev['calendar']})',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontSize: 12,
                            color: colors.text.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (dayTasks.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    child: Text(
                      'ЗАДАЧИ',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.8,
                        color: colors.text.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  ...dayTasks.map((t) {
                    final isDone = t['done'] == true;
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Checkbox(
                          value: isDone,
                          activeColor: colors.accent,
                          checkColor:
                              colors.isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                          onChanged: (v) {
                            ref
                                .read(tasksProvider.notifier)
                                .toggleTask(t['id'].toString(), v ?? false);
                            Navigator.pop(ctx);
                          },
                        ),
                        title: Text(
                          t['title'] ?? '',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDone
                                ? colors.text.withValues(alpha: 0.45)
                                : colors.text,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: t['time'] != null
                            ? Text(
                                'Время: ${t['time']}',
                                style: TextStyle(
                                  fontFamily: 'Onest',
                                  fontSize: 12,
                                  color: colors.accent,
                                ),
                              )
                            : null,
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _openAddMenu(AppColorsExtension colors) {
    final templates = ref.read(eventTemplatesProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(
                  Icons.add_circle_outline,
                  color: colors.accent,
                ),
                title: Text(
                  'Создать событие',
                  style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: colors.text),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateEventScreen(
                        isDarkMode: colors.isDark,
                        initialDate: _selectedDate,
                      ),
                    ),
                  );
                },
              ),
            ),
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(
                  Icons.bookmark_outline,
                  color: colors.warning,
                ),
                title: Text(
                  'Загрузить из шаблона',
                  style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: colors.text),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (templates.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Сохраненных шаблонов пока нет',
                            style: TextStyle(fontFamily: 'Onest')),
                      ),
                    );
                  } else {
                    _showSelectTemplateDialog(templates, colors);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectTemplateDialog(
      List<JsonMap> templates, AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        itemCount: templates.length,
        itemBuilder: (ctx, i) {
          final tpl = templates[i];
          return Material(
            color: Colors.transparent,
            child: ListTile(
              leading: Icon(Icons.bookmark, color: colors.accent),
              title: Text(
                tpl['title'] ?? '',
                style: TextStyle(
                    fontFamily: 'Onest',
                    fontWeight: FontWeight.w600,
                    color: colors.text),
              ),
              subtitle: Text(
                tpl['calendar'] ?? 'Основной',
                style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.6)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEventScreen(
                      isDarkMode: colors.isDark,
                      initialDate: _selectedDate,
                      templateData: tpl,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showInvitesDialog(AppColorsExtension colors) {
    final invites = ref.watch(eventInvitesProvider);
    final notifier = ref.read(eventInvitesProvider.notifier);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Приглашения',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: invites.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Приглашений пока нет',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.5)),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: invites.length,
                  itemBuilder: (ctx, i) {
                    final item = invites[i];
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        title: Text(
                          item['title'] ?? '',
                          style: TextStyle(
                              fontFamily: 'Onest',
                              fontWeight: FontWeight.w600,
                              color: colors.text),
                        ),
                        subtitle: Text(
                          'От: ${item['sender'] ?? 'Друг'}',
                          style: TextStyle(
                              fontFamily: 'Onest',
                              color: colors.text.withValues(alpha: 0.6)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.check,
                                color: colors.success,
                              ),
                              onPressed: () {
                                notifier.acceptInvite(item['id'].toString());
                                Navigator.pop(ctx);
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: colors.error,
                              ),
                              onPressed: () {
                                notifier.declineInvite(item['id'].toString());
                                Navigator.pop(ctx);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Закрыть',
              style: TextStyle(
                fontFamily: 'Onest',
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(
    List<JsonMap> events,
    List<JsonMap> tasks,
    AppColorsExtension colors,
  ) {
    final dayEvents = events.where((e) {
      final ed = e['date'] as DateTime;
      return ed.year == _selectedDate.year &&
          ed.month == _selectedDate.month &&
          ed.day == _selectedDate.day;
    }).toList();

    final dayTasks = tasks.where((t) {
      final td = t['date'] as DateTime;
      return td.year == _selectedDate.year &&
          td.month == _selectedDate.month &&
          td.day == _selectedDate.day;
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: colors.card,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedDate.day} ${_monthNameGenitive(_selectedDate.month)} ${_selectedDate.year}',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              Text(
                '${dayEvents.length} соб. • ${dayTasks.length} зад.',
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: colors.text.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.nested),
        Expanded(
          child: (dayEvents.isEmpty && dayTasks.isEmpty)
              ? Center(
                  child: Text(
                    'На этот день ничего не запланировано',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (dayEvents.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'События',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.text.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      ...dayEvents.map((ev) {
                        final c = ev['color'] as Color? ?? colors.accent;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: colors.nested),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ev['title'] ?? '',
                                      style: TextStyle(
                                        fontFamily: 'Onest',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: colors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ev['isAllDay'] == true
                                          ? 'Весь день'
                                          : '${ev['startTime'] ?? ''} - ${ev['endTime'] ?? ''}',
                                      style: TextStyle(
                                        fontFamily: 'Onest',
                                        fontSize: 12,
                                        color:
                                            colors.text.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: colors.error,
                                ),
                                onPressed: () => ref
                                    .read(calendarProvider.notifier)
                                    .deleteEvent(ev['id'].toString()),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    if (dayTasks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Text(
                          'Задачи',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.text.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      ...dayTasks.map((t) {
                        final isDone = t['done'] == true;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: colors.nested),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isDone,
                                activeColor: colors.accent,
                                checkColor:
                                    colors.isDark ? Colors.black : Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5)),
                                onChanged: (v) {
                                  ref.read(tasksProvider.notifier).toggleTask(
                                        t['id'].toString(),
                                        v ?? false,
                                      );
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t['title'] ?? '',
                                      style: TextStyle(
                                        fontFamily: 'Onest',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isDone
                                            ? colors.text
                                                .withValues(alpha: 0.45)
                                            : colors.text,
                                        decoration: isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    if (t['time'] != null)
                                      Text(
                                        '⏱ ${t['time']}',
                                        style: TextStyle(
                                          fontFamily: 'Onest',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
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
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildBottomCalendarBar(
    List<UserCalendar> calendars,
    AppColorsExtension colors,
  ) {
    final notifier = ref.read(userCalendarsProvider.notifier);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.nested)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: calendars.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final cal = calendars[i];
          return Center(
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                notifier.toggleVisibility(cal.id);
              },
              onLongPress: () {
                HapticFeedback.heavyImpact();
                notifier.isolateCalendar(cal.id);
              },
              borderRadius: BorderRadius.circular(13),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: cal.isVisible
                      ? cal.color.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: cal.isVisible ? cal.color : colors.nested,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: cal.isVisible
                          ? cal.color
                          : colors.text.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cal.title,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cal.isVisible
                            ? colors.text
                            : colors.text.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
