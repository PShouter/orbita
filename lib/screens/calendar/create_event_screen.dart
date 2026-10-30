import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/calendar_provider.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  final DateTime initialDate;
  final Map<String, dynamic>? templateData;

  const CreateEventScreen({
    super.key,
    required this.isDarkMode,
    required this.initialDate,
    this.templateData,
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

  int _reminderMinutes = -1; // -1 = без напоминания, 0 = вовремя, >0 минуты
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
      _recurrence = t['recurrence'] ?? 'none';
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
    final calendars = ref.watch(userCalendarsProvider);
    if (_selectedCalendar == null && calendars.isNotEmpty) {
      _selectedCalendar = calendars.first;
    }

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
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Новое событие',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Сохранить как шаблон',
            icon: const Icon(
              Icons.bookmark_add_outlined,
              color: Color(0xFF38BDF8),
            ),
            onPressed: _saveAsTemplate,
          ),
          TextButton.icon(
            icon: const Icon(Icons.check, color: Color(0xFF38BDF8)),
            label: const Text(
              'Сохранить',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF38BDF8),
              ),
            ),
            onPressed: _saveEvent,
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Название события',
              hintStyle: TextStyle(color: textSecondary),
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Выбор календаря
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 8,
                  backgroundColor:
                      _selectedCalendar?.color ?? const Color(0xFF38BDF8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserCalendar>(
                      isExpanded: true,
                      value: _selectedCalendar,
                      dropdownColor: cardBg,
                      items: calendars.map((c) {
                        return DropdownMenuItem<UserCalendar>(
                          value: c,
                          child: Text(
                            c.title,
                            style: TextStyle(
                              color: textPrimary,
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Весь день',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  value: _isAllDay,
                  onChanged: (v) => setState(() => _isAllDay = v),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Начало',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  trailing: Text(
                    '${_startDate.day}.${_startDate.month}.${_startDate.year}',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
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
                    leading: const Icon(
                      Icons.access_time,
                      size: 20,
                      color: Color(0xFF38BDF8),
                    ),
                    title: Text(
                      'Время начала',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    trailing: Text(
                      _startTime.format(context),
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
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
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.event_available,
                    size: 20,
                    color: Colors.orangeAccent,
                  ),
                  title: Text(
                    'Конец',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  trailing: Text(
                    '${_endDate.day}.${_endDate.month}.${_endDate.year}',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
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
                    leading: const Icon(
                      Icons.timer_outlined,
                      size: 20,
                      color: Colors.orangeAccent,
                    ),
                    title: Text(
                      'Время окончания',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    trailing: Text(
                      _endTime.format(context),
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                // Напоминание
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFF38BDF8),
                    size: 22,
                  ),
                  title: Text(
                    'Напоминание',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Text(
                    _presetReminders[_reminderMinutes] ??
                        '$_reminderMinutes мин.',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  onTap: _pickReminder,
                ),
                const Divider(),
                // Повторение
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.repeat,
                    color: Colors.purpleAccent,
                    size: 22,
                  ),
                  title: Text(
                    'Повторение',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Text(
                    _formatRecurrence(_recurrence),
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  onTap: _pickRecurrence,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Добавление друга / участника
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_add_alt_1,
                  color: Color(0xFF38BDF8),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _attendeeCtrl,
                    decoration: InputDecoration(
                      hintText: 'Пригласить друга / имя участника',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 14),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Colors.redAccent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _locationCtrl,
                    decoration: InputDecoration(
                      hintText: 'Место проведения',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 14),
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
            decoration: InputDecoration(
              hintText: 'Описание или заметка к событию',
              hintStyle: TextStyle(color: textSecondary, fontSize: 14),
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickReminder() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Установить напоминание',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ..._presetReminders.entries.map(
            (e) => ListTile(
              title: Text(e.value),
              trailing: _reminderMinutes == e.key
                  ? const Icon(Icons.check, color: Color(0xFF38BDF8))
                  : null,
              onTap: () {
                setState(() => _reminderMinutes = e.key);
                Navigator.pop(ctx);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Color(0xFF38BDF8)),
            title: const Text('Другой интервал...'),
            onTap: () {
              Navigator.pop(ctx);
              _pickCustomReminder();
            },
          ),
        ],
      ),
    );
  }

  void _pickCustomReminder() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Свой интервал (в минутах)'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Например, 15'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val >= 0) {
                setState(() => _reminderMinutes = val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('ОК'),
          ),
        ],
      ),
    );
  }

  void _pickRecurrence() {
    final options = {
      'none': 'Не повторяется',
      'daily': 'Каждый день',
      'weekly': 'Каждую неделю',
      'monthly': 'Каждый месяц',
      'yearly': 'Каждый год',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Повторение события',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ...options.entries.map(
            (e) => ListTile(
              title: Text(e.value),
              trailing: _recurrence == e.key
                  ? const Icon(Icons.check, color: Colors.purpleAccent)
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

  void _saveAsTemplate() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название для шаблона')),
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

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Шаблон сохранен!')));
  }

  void _saveEvent() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Укажите название события')));
      return;
    }

    final attendee = _attendeeCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final fullDesc = attendee.isNotEmpty
        ? '$desc\nУчастник: $attendee'.trim()
        : desc;

    ref
        .read(calendarProvider.notifier)
        .addEvent(
          title: title,
          date: _startDate,
          endDate: _endDate,
          startTime: _isAllDay
              ? null
              : '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
          endTime: _isAllDay
              ? null
              : '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
          isAllDay: _isAllDay,
          calendar: _selectedCalendar?.title ?? 'Основной',
          color: _selectedCalendar?.color ?? const Color(0xFF2C69D1),
          location: _locationCtrl.text.trim().isNotEmpty
              ? _locationCtrl.text.trim()
              : null,
          description: fullDesc.isNotEmpty ? fullDesc : null,
          reminderMinutes: _reminderMinutes,
          recurrence: _recurrence,
        );

    Navigator.pop(context);
  }
}
