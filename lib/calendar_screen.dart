import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/calendar_provider.dart';
import 'providers/tasks_provider.dart';
import 'screens/create_event_screen.dart';
import 'screens/manage_calendars_screen.dart';

enum CalendarViewType { month, day }

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

  static const int _initialWeekOffset = 520; // 10 лет назад от текущей недели
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
    _scrollController.animateTo(
      _initialWeekOffset * 68.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final calendars = ref.watch(userCalendarsProvider);
    final allEvents = ref.watch(calendarProvider);
    final allTasks = ref.watch(tasksProvider);

    // Фильтруем события по включенным календарям
    final visibleCalendarTitles = calendars
        .where((c) => c.isVisible)
        .map((c) => c.title)
        .toSet();
    final events = allEvents
        .where((e) => visibleCalendarTitles.contains(e['calendar']))
        .toList();

    // Задачи с заданной датой
    final datedTasks = allTasks.where((t) {
      if (t['isNoDate'] == true || t['date'] == null) return false;
      return t['date'] is DateTime;
    }).toList();

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
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(textPrimary, textSecondary),

                // Строка дней недели отображается только в виде месяца
                if (_currentView == CalendarViewType.month) ...[
                  _buildWeekHeader(textSecondary),
                  Divider(height: 1, color: borderColor),
                ],

                Expanded(
                  child: _currentView == CalendarViewType.month
                      ? _buildContinuousWeekList(
                          events,
                          datedTasks,
                          cardBg,
                          borderColor,
                          textPrimary,
                          textSecondary,
                        )
                      : _buildDayView(
                          events,
                          datedTasks,
                          cardBg,
                          borderColor,
                          textPrimary,
                          textSecondary,
                        ),
                ),

                _buildBottomCalendarBar(
                  calendars,
                  cardBg,
                  borderColor,
                  textPrimary,
                ),
              ],
            ),

            Positioned(
              right: 16,
              bottom: 60,
              child: FloatingActionButton(
                backgroundColor: const Color(0xFF38BDF8),
                elevation: 4,
                onPressed: _openAddMenu,
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_monthName(_visibleDate.month)} ${_visibleDate.year}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Сегодня',
                icon: const Icon(
                  Icons.today,
                  color: Color(0xFF38BDF8),
                  size: 22,
                ),
                onPressed: _scrollToToday,
              ),
              IconButton(
                tooltip: 'Вид календаря',
                icon: Icon(
                  _currentView == CalendarViewType.month
                      ? Icons.calendar_view_day
                      : Icons.calendar_view_month,
                  color: textPrimary,
                  size: 22,
                ),
                onPressed: () {
                  setState(() {
                    _currentView = _currentView == CalendarViewType.month
                        ? CalendarViewType.day
                        : CalendarViewType.month;
                  });
                },
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: textPrimary, size: 22),
                onSelected: (val) {
                  if (val == 'slider') {
                    setState(() => _showWeekNumbers = !_showWeekNumbers);
                  } else if (val == 'invites') {
                    _showInvitesDialog();
                  } else if (val == 'calendars') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManageCalendarsScreen(
                          isDarkMode: widget.isDarkMode,
                        ),
                      ),
                    );
                  } else if (val == 'settings') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Дополнительные настройки календаря'),
                      ),
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'slider',
                    child: Row(
                      children: [
                        Icon(
                          _showWeekNumbers
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text('Номера недель'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'invites',
                    child: Row(
                      children: [
                        Icon(Icons.mail_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Приглашения'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'calendars',
                    child: Row(
                      children: [
                        Icon(Icons.tune, size: 18),
                        SizedBox(width: 8),
                        Text('Календари'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Другие настройки'),
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

  Widget _buildWeekHeader(Color textSecondary) {
    const weekDays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          if (_showWeekNumbers)
            const SizedBox(
              width: 24,
              child: Center(
                child: Text(
                  '#',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
          ...weekDays.map(
            (wd) => Expanded(
              child: Center(
                child: Text(
                  wd,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: (wd == 'СБ' || wd == 'ВС')
                        ? Colors.redAccent.withValues(alpha: 0.8)
                        : textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Непрерывная вертикальная лента недель
  Widget _buildContinuousWeekList(
    List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> tasks,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
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
        itemCount: 1040, // 20 лет недель
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
                        fontSize: 9,
                        color: textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Row(
                  children: List.generate(7, (d) {
                    final date = startOfWeek.add(Duration(days: d));
                    return Expanded(
                      child: _buildDayCell(
                        date,
                        events,
                        tasks,
                        borderColor,
                        textPrimary,
                        textSecondary,
                      ),
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
    List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> tasks,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isSel =
        date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;
    final isCurrentMonth = date.month == _visibleDate.month;

    // События этого дня
    final dayEvents = events.where((e) {
      final ed = e['date'] as DateTime;
      return ed.year == date.year &&
          ed.month == date.month &&
          ed.day == date.day;
    }).toList();

    // Задачи этого дня
    final dayTasks = tasks.where((t) {
      final td = t['date'] as DateTime;
      return td.year == date.year &&
          td.month == date.month &&
          td.day == date.day;
    }).toList();

    // Объединяем элементы для отображения в ячейке
    final List<Widget> cellItems = [];

    // Плашки событий
    for (final ev in dayEvents) {
      final c = ev['color'] as Color? ?? const Color(0xFF2C69D1);
      cellItems.add(
        Container(
          margin: const EdgeInsets.only(top: 1, left: 1, right: 1),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            ev['title'] ?? '',
            style: const TextStyle(
              fontSize: 8,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // Плашки задач (с префиксом чекбокса)
    for (final t in dayTasks) {
      final isDone = t['done'] == true;
      cellItems.add(
        Container(
          margin: const EdgeInsets.only(top: 1, left: 1, right: 1),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
          decoration: BoxDecoration(
            color: isDone
                ? Colors.grey.withValues(alpha: 0.3)
                : const Color(0xFF0284C7).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: isDone ? Colors.grey : const Color(0xFF38BDF8),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Text(
                isDone ? '✓ ' : '□ ',
                style: TextStyle(
                  fontSize: 7,
                  color: isDone ? Colors.grey : const Color(0xFF38BDF8),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  t['title'] ?? '',
                  style: TextStyle(
                    fontSize: 8,
                    color: isDone ? textSecondary : textPrimary,
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
        _showDayPopup(date, dayEvents, dayTasks);
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
              ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
              : (isToday
                    ? Colors.blue.withValues(alpha: 0.05)
                    : Colors.transparent),
          border: Border.all(
            color: isSel
                ? const Color(0xFF38BDF8)
                : (isToday
                      ? Colors.blueAccent
                      : borderColor.withValues(alpha: 0.2)),
            width: isSel || isToday ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 3),
              child: Text(
                '${date.day}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isToday || isSel
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: isToday
                      ? const Color(0xFF38BDF8)
                      : (isCurrentMonth
                            ? textPrimary
                            : textSecondary.withValues(alpha: 0.5)),
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
                  fontSize: 7,
                  color: textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDayPopup(
    DateTime date,
    List<Map<String, dynamic>> dayEvents,
    List<Map<String, dynamic>> dayTasks,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _currentView = CalendarViewType.day);
                      },
                      child: const Text('Открыть день'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (dayEvents.isEmpty && dayTasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Событий и задач нет',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),

                // Список событий
                if (dayEvents.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'События:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ...dayEvents.map(
                    (ev) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 6,
                        backgroundColor: ev['color'] as Color? ?? Colors.blue,
                      ),
                      title: Text(
                        ev['title'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        ev['isAllDay'] == true
                            ? 'Весь день'
                            : '${ev['startTime'] ?? ''} - ${ev['endTime'] ?? ''}',
                      ),
                    ),
                  ),
                ],

                // Список задач
                if (dayTasks.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Задачи:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ...dayTasks.map((t) {
                    final isDone = t['done'] == true;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Checkbox(
                        value: isDone,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: t['time'] != null
                          ? Text(
                              'Время: ${t['time']}',
                              style: const TextStyle(fontSize: 11),
                            )
                          : null,
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

  void _openAddMenu() {
    final templates = ref.read(eventTemplatesProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ListTile(
              leading: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFF38BDF8),
              ),
              title: const Text(
                'Создать событие',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateEventScreen(
                      isDarkMode: widget.isDarkMode,
                      initialDate: _selectedDate,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.bookmark_outline,
                color: Colors.orangeAccent,
              ),
              title: const Text(
                'Загрузить из шаблона',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(ctx);
                if (templates.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Сохраненных шаблонов пока нет'),
                    ),
                  );
                } else {
                  _showSelectTemplateDialog(templates);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectTemplateDialog(List<Map<String, dynamic>> templates) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        itemCount: templates.length,
        itemBuilder: (ctx, i) {
          final tpl = templates[i];
          return ListTile(
            leading: const Icon(Icons.bookmark, color: Color(0xFF38BDF8)),
            title: Text(
              tpl['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(tpl['calendar'] ?? 'Основной'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateEventScreen(
                    isDarkMode: widget.isDarkMode,
                    initialDate: _selectedDate,
                    templateData: tpl,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showInvitesDialog() {
    final invites = ref.watch(eventInvitesProvider);
    final notifier = ref.read(eventInvitesProvider.notifier);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF161B22)
            : Colors.white,
        title: const Text('Приглашения'),
        content: SizedBox(
          width: double.maxFinite,
          child: invites.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Приглашений пока нет',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: invites.length,
                  itemBuilder: (ctx, i) {
                    final item = invites[i];
                    return ListTile(
                      title: Text(item['title'] ?? ''),
                      subtitle: Text('От: ${item['sender'] ?? 'Друг'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () {
                              notifier.acceptInvite(item['id'].toString());
                              Navigator.pop(ctx);
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              notifier.declineInvite(item['id'].toString());
                              Navigator.pop(ctx);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(
    List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> tasks,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
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
          padding: const EdgeInsets.all(12),
          color: cardBg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedDate.day} ${_monthNameGenitive(_selectedDate.month)} ${_selectedDate.year}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              Text(
                '${dayEvents.length} соб. • ${dayTasks.length} зад.',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: (dayEvents.isEmpty && dayTasks.isEmpty)
              ? Center(
                  child: Text(
                    'На этот день ничего не запланировано',
                    style: TextStyle(color: textSecondary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // События
                    if (dayEvents.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'События',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      ...dayEvents.map((ev) {
                        final c =
                            ev['color'] as Color? ?? const Color(0xFF2C69D1);
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
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      ev['isAllDay'] == true
                                          ? 'Весь день'
                                          : '${ev['startTime'] ?? ''} - ${ev['endTime'] ?? ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.redAccent,
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

                    // Задачи
                    if (dayTasks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Text(
                          'Задачи',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      ...dayTasks.map((t) {
                        final isDone = t['done'] == true;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
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
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t['title'] ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
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
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDone
                                              ? textSecondary
                                              : const Color(0xFF38BDF8),
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
    Color cardBg,
    Color borderColor,
    Color textPrimary,
  ) {
    final notifier = ref.read(userCalendarsProvider.notifier);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: calendars.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
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
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cal.isVisible
                      ? cal.color.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: cal.isVisible
                        ? cal.color
                        : Colors.grey.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: cal.isVisible ? cal.color : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cal.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cal.isVisible ? textPrimary : Colors.grey,
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
