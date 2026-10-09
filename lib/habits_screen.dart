import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/habits_provider.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const HabitsScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final notifier = ref.read(habitsProvider.notifier);

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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF38BDF8),
        onPressed: () => _openHabitDialog(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Привычки',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${habits.where((h) => h['done'] == true).length}/${habits.length} сегодня',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: habits.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.track_changes,
                            size: 48,
                            color: Colors.grey.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Нет активных привычек',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Нажмите «+», чтобы завести новую привычку',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: habits.length,
                      itemBuilder: (ctx, i) {
                        final h = habits[i];
                        final isDone = h['done'] == true;
                        final color =
                            (h['color'] as Color? ?? const Color(0xFF2C69D1));
                        final streak = h['streak'] ?? 0;
                        final isMeasurable = h['type'] == 'measurable';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDone
                                  ? color.withValues(alpha: 0.6)
                                  : borderColor,
                              width: isDone ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  notifier.toggleHabit(h['id'].toString());
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withValues(
                                      alpha: isDone ? 0.25 : 0.1,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: color,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    isDone
                                        ? Icons.check
                                        : (isMeasurable
                                              ? Icons.add
                                              : Icons.circle_outlined),
                                    color: color,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      h['title'] ?? '',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                        decoration: isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.local_fire_department,
                                          size: 14,
                                          color: Colors.orangeAccent,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Серия: $streak дн.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: textSecondary,
                                          ),
                                        ),
                                        if (isMeasurable) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            'Цель: ${(h['target_value'] ?? 1).toString()} ${h['unit'] ?? ''}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: color,
                                            ),
                                          ),
                                        ],
                                      ],
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
                                onPressed: () =>
                                    notifier.deleteHabit(h['id'].toString()),
                              ),
                            ],
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

  void _openHabitDialog() {
    final titleCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'раз');
    final targetCtrl = TextEditingController(text: '1');
    String type = 'binary';
    Color pickedColor = const Color(0xFF2C69D1);

    final palette = [
      const Color(0xFF2C69D1),
      const Color(0xFF38BDF8),
      const Color(0xFF66BB6A),
      const Color(0xFFFF9100),
      const Color(0xFFFF5252),
      const Color(0xFFE040FB),
    ];

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
                  'Новая привычка',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Что хотите закрепить?',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Да / Нет'),
                        selected: type == 'binary',
                        onSelected: (_) => setDState(() => type = 'binary'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Измеримая'),
                        selected: type == 'measurable',
                        onSelected: (_) => setDState(() => type = 'measurable'),
                      ),
                    ),
                  ],
                ),
                if (type == 'measurable') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: targetCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Цель',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: unitCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ед. (мин, км, стак.)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Цвет привычки:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: palette.map((c) {
                    final isSel = pickedColor == c;
                    return GestureDetector(
                      onTap: () => setDState(() => pickedColor = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSel
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
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

                        final target =
                            double.tryParse(targetCtrl.text.trim()) ?? 1.0;

                        ref
                            .read(habitsProvider.notifier)
                            .saveHabit(
                              title: title,
                              type: type,
                              targetValue: target,
                              unit: type == 'measurable'
                                  ? unitCtrl.text.trim()
                                  : null,
                              color: pickedColor,
                            );

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
}
