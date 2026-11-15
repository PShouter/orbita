import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/calendar_provider.dart';
import '../../theme/app_theme.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  final DateTime initialDate;
  final Map<String, dynamic>? templateData;
  final Map<String, dynamic>? eventToEdit;

  const CreateEventScreen({
    super.key,
    required this.isDarkMode,
    required this.initialDate,
    this.templateData,
    this.eventToEdit,
  });

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _attendeeCtrl = TextEditingController();

  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  bool _isAllDay = false;
  UserCalendar? _selectedCalendar;

  int _reminderMinutes = -1;
  final Set<int> _reminderMinutesList = {};
  String _recurrence = 'none';

  final Map<int, String> _presetReminders = {
    -1: 'Нет напоминания',
    0: 'В момент начала',
    10: 'За 10 минут',
    20: 'За 20 минут',
    30: 'За 30 минут',
    45: 'За 45 минут',
    60: 'За 1 час',
    120: 'За 2 часа',
    180: 'За 3 часа',
    1440: 'За 1 день',
    2880: 'За 2 дня',
  };

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDate;
    _endDate = widget.initialDate;

    if (widget.templateData != null) {
      final t = widget.templateData!;
      _titleCtrl.text = t['title'] ?? '';
      _descCtrl.text = t['description'] ?? '';
      _locationCtrl.text = t['location'] ?? '';
      _isAllDay = t['isAllDay'] == true;
      _reminderMinutes = t['reminderMinutes'] ?? -1;
      final ext = t['reminderMinutesList'];
      if (ext is List) {
        _reminderMinutesList.addAll(ext.cast<int>());
      }
      _recurrence = t['recurrence'] ?? 'none';
    }

    if (widget.eventToEdit != null) {
      final e = widget.eventToEdit!;
      _titleCtrl.text = e['title']?.toString() ?? '';
      _descCtrl.text = e['description']?.toString() ?? '';
      _locationCtrl.text = e['location']?.toString() ?? '';
      _isAllDay = e['isAllDay'] == true;
      final start = e['date'] as DateTime?;
      if (start != null) {
        _startDate = start;
        _endDate = e['endDate'] as DateTime? ?? start;
        final st = e['startTime']?.toString();
        if (st != null && st.isNotEmpty) {
          final p = st.split(':');
          if (p.length == 2) {
            _startTime = TimeOfDay(
              hour: int.tryParse(p[0]) ?? 0,
              minute: int.tryParse(p[1]) ?? 0,
            );
          }
        }
        final et = e['endTime']?.toString();
        if (et != null && et.isNotEmpty) {
          final p = et.split(':');
          if (p.length == 2) {
            _endTime = TimeOfDay(
              hour: int.tryParse(p[0]) ?? 0,
              minute: int.tryParse(p[1]) ?? 0,
            );
          }
        }
      }
      final calTitle = e['calendar']?.toString();
      final calColor = e['color'];
      if (calTitle != null) {
        _selectedCalendar = UserCalendar(
          id: e['id']?.toString() ?? 'edit',
          title: calTitle,
          color: calColor is Color
              ? calColor
              : const Color(0xFF2C69D1),
          accountType: 'local',
        );
      }
      final ext = e['reminderMinutesList'];
      if (ext is List) {
        _reminderMinutesList.addAll(ext.cast<int>());
      } else if (e['reminderMinutes'] is int && (e['reminderMinutes'] as int) >= 0) {
        _reminderMinutesList.add(e['reminderMinutes'] as int);
      }
      _recurrence = e['recurrence']?.toString() ?? 'none';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _attendeeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final calendars = ref.watch(userCalendarsProvider);
    if (_selectedCalendar == null && calendars.isNotEmpty) {
      _selectedCalendar = calendars.first;
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Новое событие',
          style: TextStyle(
            fontFamily: 'Unbounded',
            color: colors.text,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Сохранить как шаблон',
            icon: Icon(
              Icons.bookmark_add_outlined,
              color: colors.accent,
            ),
            onPressed: () => _saveAsTemplate(colors),
          ),
          TextButton.icon(
            icon: Icon(Icons.check, color: colors.accent),
            label: Text(
              'Сохранить',
              style: TextStyle(
                fontFamily: 'Onest',
                fontWeight: FontWeight.bold,
                color: colors.accent,
                fontSize: 15,
              ),
            ),
            onPressed: () => _saveEvent(colors),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Название
          TextField(
            controller: _titleCtrl,
            style: TextStyle(
              fontFamily: 'Onest',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
            decoration: InputDecoration(
              hintText: 'Название события',
              hintStyle: TextStyle(
                fontFamily: 'Onest',
                color: colors.text.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: colors.card,
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
                borderSide: BorderSide(color: colors.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Выбор календаря
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.nested),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 8,
                  backgroundColor: _selectedCalendar?.color ?? colors.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserCalendar>(
                      isExpanded: true,
                      value: _selectedCalendar,
                      dropdownColor: colors.card,
                      items: calendars.map((c) {
                        return DropdownMenuItem<UserCalendar>(
                          value: c,
                          child: Text(
                            c.title,
                            style: TextStyle(
                              fontFamily: 'Onest',
                              color: colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (cal) =>
                          setState(() => _selectedCalendar = cal),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Блок времени и даты
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.nested),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: colors.accent,
                  title: Text(
                    'Весь день',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: _isAllDay,
                  onChanged: (v) => setState(() => _isAllDay = v),
                ),
                Divider(color: colors.nested),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Начало',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  trailing: Text(
                    '${_startDate.day}.${_startDate.month}.${_startDate.year}',
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      fontSize: 13,
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (d != null) setState(() => _startDate = d);
                  },
                ),
                if (!_isAllDay)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.access_time,
                      size: 20,
                      color: colors.accent,
                    ),
                    title: Text(
                      'Время начала',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                    trailing: Text(
                      _startTime.format(context),
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        fontSize: 13,
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (t != null) setState(() => _startTime = t);
                    },
                  ),
                Divider(color: colors.nested),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.event_available,
                    size: 20,
                    color: colors.warning,
                  ),
                  title: Text(
                    'Конец',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  trailing: Text(
                    '${_endDate.day}.${_endDate.month}.${_endDate.year}',
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      fontSize: 13,
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (d != null) setState(() => _endDate = d);
                  },
                ),
                if (!_isAllDay)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.timer_outlined,
                      size: 20,
                      color: colors.warning,
                    ),
                    title: Text(
                      'Время окончания',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                    trailing: Text(
                      _endTime.format(context),
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        fontSize: 13,
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (t != null) setState(() => _endTime = t);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Блок Напоминания и Повторения
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.nested),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.notifications_active_outlined,
                    color: colors.accent,
                    size: 22,
                  ),
                  title: Text(
                    'Напоминание',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Text(
                    _formatReminders(),
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () => _pickReminder(colors),
                ),
                Divider(color: colors.nested),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.repeat,
                    color: colors.accent,
                    size: 22,
                  ),
                  title: Text(
                    'Повторение',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Text(
                    _formatRecurrence(_recurrence),
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () => _pickRecurrence(colors),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Добавление друга / участника
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.nested),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_add_alt_1,
                  color: colors.accent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _attendeeCtrl,
                    style: TextStyle(fontFamily: 'Onest', color: colors.text),
                    decoration: InputDecoration(
                      hintText: 'Пригласить друга / имя участника',
                      hintStyle: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. Место
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.nested),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: colors.error,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _locationCtrl,
                    style: TextStyle(fontFamily: 'Onest', color: colors.text),
                    decoration: InputDecoration(
                      hintText: 'Место проведения',
                      hintStyle: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 7. Описание
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            style: TextStyle(fontFamily: 'Onest', color: colors.text),
            decoration: InputDecoration(
              hintText: 'Описание или заметка к событию',
              hintStyle: TextStyle(
                fontFamily: 'Onest',
                color: colors.text.withValues(alpha: 0.4),
                fontSize: 14,
              ),
              filled: true,
              fillColor: colors.card,
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
                borderSide: BorderSide(color: colors.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _pickReminder(AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Напоминания (можно выбрать несколько)',
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                ),
                // «Нет напоминания» очищает список
                ListTile(
                  title: Text(
                    'Нет напоминания',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text,
                    ),
                  ),
                  trailing: _reminderMinutesList.isEmpty
                      ? Icon(Icons.check, color: colors.accent)
                      : null,
                  onTap: () {
                    setSheet(() => _reminderMinutesList.clear());
                  },
                ),
                ..._presetReminders.entries
                    .where((e) => e.key >= 0)
                    .map(
                      (e) => CheckboxListTile(
                        value: _reminderMinutesList.contains(e.key),
                        activeColor: colors.accent,
                        title: Text(
                          e.value,
                          style: TextStyle(
                            fontFamily: 'Onest',
                            color: colors.text,
                          ),
                        ),
                        onChanged: (checked) {
                          setSheet(() {
                            if (checked == true) {
                              _reminderMinutesList.add(e.key);
                            } else {
                              _reminderMinutesList.remove(e.key);
                            }
                          });
                        },
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _pickRecurrence(AppColorsExtension colors) {
    final options = {
      'none': 'Не повторяется',
      'daily': 'Каждый день',
      'weekly': 'Каждую неделю',
      'monthly': 'Каждый месяц',
      'yearly': 'Каждый год',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Повторение события',
              style: TextStyle(
                fontFamily: 'Unbounded',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
          ...options.entries.map(
            (e) => ListTile(
              title: Text(
                e.value,
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
              ),
              trailing: _recurrence == e.key
                  ? Icon(Icons.check, color: colors.accent)
                  : null,
              onTap: () {
                setState(() => _recurrence = e.key);
                Navigator.pop(ctx);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatRecurrence(String rec) {
    switch (rec) {
      case 'daily':
        return 'Каждый день';
      case 'weekly':
        return 'Каждую неделю';
      case 'monthly':
        return 'Каждый месяц';
      case 'yearly':
        return 'Каждый год';
      default:
        return 'Не повторяется';
    }
  }

  String _formatReminders() {
    final chosen = _presetReminders.entries
        .where((e) => e.key >= 0 && _reminderMinutesList.contains(e.key))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (chosen.isEmpty) return 'Нет напоминания';
    final labels = chosen.map((e) => e.value).toList();
    if (labels.length > 2) {
      return '${labels.length} напоминания';
    }
    return labels.join(' + ');
  }

  void _saveAsTemplate(AppColorsExtension colors) {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название для шаблона',
              style: TextStyle(fontFamily: 'Onest')),
        ),
      );
      return;
    }

    ref.read(eventTemplatesProvider.notifier).addTemplate({
      'title': title,
      'description': _descCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'isAllDay': _isAllDay,
      'reminderMinutes': _reminderMinutes,
      'recurrence': _recurrence,
      'calendar': _selectedCalendar?.title ?? 'Основной',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Шаблон сохранен!', style: TextStyle(fontFamily: 'Onest')),
      ),
    );
  }

  void _saveEvent(AppColorsExtension colors) {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите название события',
              style: TextStyle(fontFamily: 'Onest')),
        ),
      );
      return;
    }

    final attendee = _attendeeCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final fullDesc =
        attendee.isNotEmpty ? '$desc\nУчастник: $attendee'.trim() : desc;

    final startTimeStr = _isAllDay
        ? null
        : '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final endTimeStr = _isAllDay
        ? null
        : '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

    final notifier = ref.read(calendarProvider.notifier);
    if (widget.eventToEdit != null) {
      notifier.updateEvent(
        id: widget.eventToEdit!['id'].toString(),
        title: title,
        date: _startDate,
        endDate: _endDate,
        startTime: startTimeStr,
        endTime: endTimeStr,
        isAllDay: _isAllDay,
        calendar: _selectedCalendar?.title ?? 'Основной',
        color: _selectedCalendar?.color ?? colors.accent,
        location: _locationCtrl.text.trim().isNotEmpty
            ? _locationCtrl.text.trim()
            : null,
        description: fullDesc.isNotEmpty ? fullDesc : null,
        reminderMinutesList: _reminderMinutesList.toList(),
        recurrence: _recurrence,
      );
    } else {
      notifier.addEvent(
        title: title,
        date: _startDate,
        endDate: _endDate,
        startTime: startTimeStr,
        endTime: endTimeStr,
        isAllDay: _isAllDay,
        calendar: _selectedCalendar?.title ?? 'Основной',
        color: _selectedCalendar?.color ?? colors.accent,
        location: _locationCtrl.text.trim().isNotEmpty
            ? _locationCtrl.text.trim()
            : null,
        description: fullDesc.isNotEmpty ? fullDesc : null,
        reminderMinutesList: _reminderMinutesList.toList(),
        recurrence: _recurrence,
      );
    }

    Navigator.pop(context);
  }
}
