import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HabitsScreen extends StatefulWidget {
  final bool isDarkMode;
  final List<Map<String, dynamic>> habits;
  final VoidCallback onSaveHabits;

  const HabitsScreen({
    super.key,
    required this.isDarkMode,
    required this.habits,
    required this.onSaveHabits,
  });

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  int _habitDayOffset = 0;

  static const List<Color> _habitColors = [
    Color(0xFF4ADE80),
    Color(0xFF2DD4BF),
    Color(0xFF38BDF8),
    Color(0xFF60A5FA),
    Color(0xFF818CF8),
    Color(0xFFA78BFA),
    Color(0xFFC084FC),
    Color(0xFFE879F9),
    Color(0xFFF472B6),
    Color(0xFFFB7185),
    Color(0xFFF87171),
    Color(0xFFFB923C),
    Color(0xFFFACC15),
    Color(0xFFA3E635),
    Color(0xFF34D399),
  ];

  void _showHabitTypeSelectionDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Какая это привычка?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF38BDF8),
                  size: 30,
                ),
                title: const Text(
                  '1. Да или Нет',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Например: Вы тренировались сегодня? Медитировали?',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openBinaryHabitDialog();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.trending_up,
                  color: Color(0xFF4ADE80),
                  size: 30,
                ),
                title: const Text(
                  '2. Измеримый',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Например: Сколько страниц прочитали? Сколько км пробежали?',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openMeasurableHabitDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBinaryHabitDialog() {
    final titleCtrl = TextEditingController();
    Color selectedColor = _habitColors[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Привычка: Да или Нет'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название привычки*',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Цвет привычки:'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _habitColors
                    .take(10)
                    .map(
                      (c) => GestureDetector(
                        onTap: () => setDlg(() => selectedColor = c),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == c
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    widget.habits.add({
                      'type': 'binary',
                      'title': titleCtrl.text.trim(),
                      'color': selectedColor,
                      'done': false,
                      'streak': 0,
                      'history': <String, dynamic>{},
                    });
                  });
                  widget.onSaveHabits();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  void _openMeasurableHabitDialog() {
    final titleCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'стр');
    final targetCtrl = TextEditingController(text: '15');
    Color selectedColor = _habitColors[2];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Измеримая привычка'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название привычки*',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ед. изм.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: targetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Цель',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    widget.habits.add({
                      'type': 'measurable',
                      'title': titleCtrl.text.trim(),
                      'unit': unitCtrl.text.trim(),
                      'target': targetCtrl.text.trim(),
                      'color': selectedColor,
                      'done': false,
                      'streak': 0,
                      'history': <String, dynamic>{},
                    });
                  });
                  widget.onSaveHabits();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHabitDetails(Map<String, dynamic> h) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              h['title'] ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                setState(() => widget.habits.remove(h));
                widget.onSaveHabits();
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Удалить привычку'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final Color textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final Color textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);

    final baseDate = DateTime.now().add(Duration(days: _habitDayOffset));
    final List<DateTime> days = List.generate(
      4,
      (i) => baseDate.subtract(Duration(days: i)),
    );
    const weekDaysShort = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Привычки'),
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showHabitTypeSelectionDialog,
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -200) {
              setState(() => _habitDayOffset += 4);
            } else if (details.primaryVelocity! > 200) {
              setState(() => _habitDayOffset -= 4);
            }
          }
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Expanded(flex: 5, child: SizedBox()),
                  Expanded(
                    flex: 5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: days
                          .map(
                            (d) => Column(
                              children: [
                                Text(
                                  weekDaysShort[d.weekday - 1],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textSecondary,
                                  ),
                                ),
                                Text(
                                  '${d.day}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.habits.isEmpty
                  ? Center(
                      child: Text(
                        'Привычек пока нет. Нажмите +',
                        style: TextStyle(color: textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: widget.habits.length,
                      itemBuilder: (c, i) {
                        final h = widget.habits[i];
                        final Color itemColor =
                            (h['color'] as Color?) ?? const Color(0xFF4ADE80);
                        final Map<String, dynamic> history =
                            (h['history'] as Map<String, dynamic>?) ?? {};

                        return InkWell(
                          onLongPress: () => _showHabitDetails(h),
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF161B22)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF30363D)
                                    : const Color(0xFFD0D7DE),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    h['title'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: itemColor,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: days.map((d) {
                                      final dateKey =
                                          '${d.year}-${d.month}-${d.day}';
                                      final isDone = history[dateKey] == 'done';

                                      return InkWell(
                                        onTap: () {
                                          HapticFeedback.mediumImpact();
                                          setState(() {
                                            if (isDone) {
                                              history.remove(dateKey);
                                              if (d.day == DateTime.now().day &&
                                                  _habitDayOffset == 0) {
                                                h['done'] = false;
                                              }
                                              if ((h['streak'] as int? ?? 0) >
                                                  0) {
                                                h['streak'] =
                                                    (h['streak'] as int) - 1;
                                              }
                                            } else {
                                              history[dateKey] = 'done';
                                              if (d.day == DateTime.now().day &&
                                                  _habitDayOffset == 0) {
                                                h['done'] = true;
                                              }
                                              h['streak'] =
                                                  (h['streak'] as int? ?? 0) +
                                                  1;
                                            }
                                            h['history'] = history;
                                          });
                                          widget.onSaveHabits();
                                        },
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isDone
                                                ? itemColor
                                                : Colors.transparent,
                                          ),
                                          child: isDone
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 16,
                                                  color: Colors.black87,
                                                )
                                              : Text(
                                                  '✕',
                                                  style: TextStyle(
                                                    color: textSecondary,
                                                  ),
                                                ),
                                        ),
                                      );
                                    }).toList(),
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
    );
  }
}
