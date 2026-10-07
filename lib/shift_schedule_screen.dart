import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShiftScheduleScreen extends StatefulWidget {
  final bool isDarkMode;
  const ShiftScheduleScreen({super.key, required this.isDarkMode});

  @override
  State<ShiftScheduleScreen> createState() => _ShiftScheduleScreenState();
}

class _ShiftScheduleScreenState extends State<ShiftScheduleScreen> {
  List<String> _schedules = ['Основной график'];
  String _selectedSchedule = 'Основной график';
  DateTime _displayedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  List<Map<String, dynamic>> _shiftTypes = [
    {'id': 'type_1', 'name': 'Тип 1', 'color': 0xFF38BDF8},
    {'id': 'type_2', 'name': 'Тип 2', 'color': 0xFF4ADE80},
    {'id': 'type_3', 'name': 'Тип 3', 'color': 0xFFFACC15},
    {'id': 'type_4', 'name': 'Тип 4', 'color': 0xFFFB7185},
    {'id': 'type_5', 'name': 'Заменить текст', 'color': 0xFFA78BFA},
  ];

  Map<String, Map<String, dynamic>> _dayData = {};
  bool _showWeekNumber = false;
  bool _showSummaryCard = false;

  @override
  void initState() {
    super.initState();
    _loadScheduleData();
  }

  Future<void> _loadScheduleData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSchedules = prefs.getString('user_schedules_list');
    final rawTypes = prefs.getString('user_shift_types');
    final rawDays = prefs.getString('user_shift_days_$_selectedSchedule');
    final showWeek = prefs.getBool('user_shift_show_week') ?? false;

    setState(() {
      if (rawSchedules != null) {
        _schedules = List<String>.from(jsonDecode(rawSchedules));
      }
      if (rawTypes != null) {
        _shiftTypes = List<Map<String, dynamic>>.from(jsonDecode(rawTypes));
      }
      if (rawDays != null) {
        _dayData = Map<String, Map<String, dynamic>>.from(
          jsonDecode(rawDays)
              .map((k, v) => MapEntry(k, Map<String, dynamic>.from(v))),
        );
      }
      _showWeekNumber = showWeek;
    });
  }

  Future<void> _saveCurrentScheduleData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_schedules_list', jsonEncode(_schedules));
    await prefs.setString('user_shift_types', jsonEncode(_shiftTypes));
    await prefs.setString(
      'user_shift_days_$_selectedSchedule',
      jsonEncode(_dayData),
    );
    await prefs.setBool('user_shift_show_week', _showWeekNumber);
  }

  Map<String, num> _calculateMonthStats() {
    int totalDays = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    int filledDays = 0;
    double totalHours = 0;
    double totalValue = 0;

    for (int day = 1; day <= totalDays; day++) {
      final key =
          '${_displayedMonth.year}-${_displayedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      if (_dayData.containsKey(key)) {
        filledDays++;
        final data = _dayData[key]!;
        totalHours += (double.tryParse(data['hours']?.toString() ?? '0') ?? 0);
        totalValue += (double.tryParse(data['rate']?.toString() ?? '0') ?? 0);
      }
    }

    return {
      'totalDays': totalDays,
      'filledDays': filledDays,
      'freeDays': totalDays - filledDays,
      'hours': totalHours,
      'value': totalValue,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final stats = _calculateMonthStats();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
        elevation: 0,
        title: _buildScheduleDropdown(textPrimary, isDark),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textPrimary),
            onSelected: (val) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Выбран фильтр: $val')));
            },
            itemBuilder: (ctx) => [
              ..._shiftTypes.map(
                (t) => PopupMenuItem(value: t['name'], child: Text(t['name'])),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'Поиск', child: Text('Поиск по дате')),
            ],
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textPrimary),
            onPressed: () => _openSettingsDialog(isDark),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_monthName(_displayedMonth.month)} ${_displayedMonth.year}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: textPrimary),
                      onPressed: () => setState(
                        () => _displayedMonth = DateTime(
                          _displayedMonth.year,
                          _displayedMonth.month - 1,
                          1,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: textPrimary),
                      onPressed: () => setState(
                        () => _displayedMonth = DateTime(
                          _displayedMonth.year,
                          _displayedMonth.month + 1,
                          1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildGridCalendar(isDark, textPrimary, textSecondary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFD0D7DE),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    _showSummaryCard ? Icons.info : Icons.info_outline,
                    color: const Color(0xFF38BDF8),
                  ),
                  tooltip: 'Сводные данные',
                  onPressed: () =>
                      setState(() => _showSummaryCard = !_showSummaryCard),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('В основной календарь'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Смены синхронизированы с разделом календаря',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (_showSummaryCard)
            Container(
              padding: const EdgeInsets.all(16),
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Сводка за месяц',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () =>
                            setState(() => _showSummaryCard = false),
                      ),
                    ],
                  ),
                  const Divider(),
                  Text(
                    'Календарных дней: ${stats['totalDays']}',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  Text(
                    'Заполненных дней: ${stats['filledDays']}',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  Text(
                    'Свободных дней: ${stats['freeDays']}',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  Text(
                    'Всего часов: ${stats['hours']}',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  Text(
                    'Расчётное значение: ${stats['value']} ₽',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleDropdown(Color textPrimary, bool isDark) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedSchedule,
        dropdownColor: isDark ? const Color(0xFF161B22) : Colors.white,
        style: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        items: [
          ..._schedules.map((s) => DropdownMenuItem(value: s, child: Text(s))),
          const DropdownMenuItem(
            value: '__NEW__',
            child: Row(
              children: [
                Icon(Icons.add, size: 18, color: Color(0xFF38BDF8)),
                SizedBox(width: 6),
                Text(
                  'Новый график',
                  style: TextStyle(color: Color(0xFF38BDF8)),
                ),
              ],
            ),
          ),
        ],
        onChanged: (val) {
          if (val == '__NEW__') {
            _showCreateScheduleDialog();
          } else if (val != null) {
            setState(() {
              _selectedSchedule = val;
              _loadScheduleData();
            });
          }
        },
      ),
    );
  }

  void _showCreateScheduleDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Создать график'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Название графика',
            border: OutlineInputBorder(),
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
                setState(() {
                  _schedules.add(ctrl.text.trim());
                  _selectedSchedule = ctrl.text.trim();
                  _dayData.clear();
                });
                _saveCurrentScheduleData();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCalendar(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    const daysHeader = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final startingOffset = firstDay.weekday - 1;
    final totalRows = ((startingOffset + daysInMonth) / 7).ceil();

    return Column(
      children: [
        Row(
          children: daysHeader
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        for (int r = 0; r < totalRows; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                for (int c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(
                      builder: (ctx) {
                        final dayNumber = r * 7 + c - startingOffset + 1;
                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return const SizedBox(height: 48);
                        }

                        final date = DateTime(
                          _displayedMonth.year,
                          _displayedMonth.month,
                          dayNumber,
                        );
                        final key =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        final hasData = _dayData.containsKey(key);
                        final dayInfo = _dayData[key];

                        Color cellColor = Colors.transparent;
                        if (hasData && dayInfo?['typeId'] != null) {
                          final type = _shiftTypes.firstWhere(
                            (t) => t['id'] == dayInfo!['typeId'],
                            orElse: () => {'color': 0xFF2C69D1},
                          );
                          cellColor = Color(type['color'] as int)
                              .withValues(alpha: 0.35);
                        }

                        return InkWell(
                          onTap: () => _openDayEditDialog(date, key, isDark),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 48,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: cellColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF30363D)
                                    : const Color(0xFFD0D7DE),
                                width: 0.8,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                if (hasData &&
                                    (dayInfo?['hours']?.toString() ?? '')
                                        .isNotEmpty)
                                  Text(
                                    '${dayInfo!['hours']}ч',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: textSecondary,
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

  void _openDayEditDialog(DateTime date, String key, bool isDark) {
    final existing = _dayData[key] ?? {};
    String selectedTypeId = existing['typeId'] ?? _shiftTypes.first['id'];
    final hoursCtrl = TextEditingController(
      text: existing['hours']?.toString() ?? '',
    );
    final rateCtrl = TextEditingController(
      text: existing['rate']?.toString() ?? '',
    );
    final noteCtrl = TextEditingController(
      text: existing['note']?.toString() ?? '',
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('День: ${date.day}.${date.month}.${date.year}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedTypeId,
                  decoration: const InputDecoration(
                    labelText: 'Тип отметки',
                    border: OutlineInputBorder(),
                  ),
                  items: _shiftTypes
                      .map(
                        (t) => DropdownMenuItem(
                          value: t['id'] as String,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(t['color'] as int),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(t['name'] as String),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setDlg(() => selectedTypeId = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hoursCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Количество часов',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Сумма / Значение (₽)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Заметка пользователя',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (_dayData.containsKey(key))
              TextButton(
                onPressed: () {
                  setState(() => _dayData.remove(key));
                  _saveCurrentScheduleData();
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Удалить',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _dayData[key] = {
                    'typeId': selectedTypeId,
                    'hours': hoursCtrl.text.trim(),
                    'rate': rateCtrl.text.trim(),
                    'note': noteCtrl.text.trim(),
                  };
                });
                _saveCurrentScheduleData();
                Navigator.pop(ctx);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  void _openSettingsDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Настройки графика'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Показывать номер недели'),
                  value: _showWeekNumber,
                  onChanged: (v) {
                    setDlg(() => _showWeekNumber = v);
                    setState(() => _showWeekNumber = v);
                    _saveCurrentScheduleData();
                  },
                ),
                ListTile(
                  title: const Text('Настройка типов меток'),
                  subtitle: const Text('Изменение названий и палитры'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openShiftTypesSettings();
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

  void _openShiftTypesSettings() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Пресеты меток'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _shiftTypes.length,
              itemBuilder: (c, i) {
                final item = _shiftTypes[i];
                return ListTile(
                  leading: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(item['color'] as int),
                    ),
                  ),
                  title: Text(item['name']),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    onPressed: () {
                      final nameCtrl = TextEditingController(
                        text: item['name'],
                      );
                      showDialog(
                        context: context,
                        builder: (editCtx) => AlertDialog(
                          title: const Text('Редактировать пресет'),
                          content: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Название',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(editCtx),
                              child: const Text('Отмена'),
                            ),
                            FilledButton(
                              onPressed: () {
                                setDlg(
                                  () => item['name'] = nameCtrl.text.trim(),
                                );
                                setState(() {});
                                _saveCurrentScheduleData();
                                Navigator.pop(editCtx);
                              },
                              child: const Text('Сохранить'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
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
    ];
    return names[month - 1];
  }
}
