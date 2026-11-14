import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/habits_provider.dart';
import '../../theme/app_theme.dart';

class HabitArchiveScreen extends ConsumerWidget {
  final bool isDarkMode;

  const HabitArchiveScreen({super.key, this.isDarkMode = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final archived = ref.watch(archivedHabitsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          'Архив привычек',
          style: TextStyle(
            fontFamily: 'Unbounded',
            color: colors.text,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: colors.text),
      ),
      body: archived.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 64,
                    color: colors.text.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Архив пуст',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Заархивированные привычки появятся здесь',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: archived.length,
              itemBuilder: (context, index) {
                final habit = archived[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.nested),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 32,
                        decoration: BoxDecoration(
                          color: habit.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              habit.title,
                              style: TextStyle(
                                fontFamily: 'Onest',
                                color: colors.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (habit.question != null &&
                                habit.question!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                habit.question!,
                                style: TextStyle(
                                  fontFamily: 'Onest',
                                  color: colors.text.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.unarchive_outlined,
                          color: colors.accent,
                        ),
                        tooltip: 'Восстановить',
                        onPressed: () {
                          ref
                              .read(habitsProvider.notifier)
                              .unarchiveHabit(habit.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Привычка "${habit.title}" восстановлена',
                                style: const TextStyle(fontFamily: 'Onest'),
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: colors.error,
                        ),
                        tooltip: 'Удалить навсегда',
                        onPressed: () =>
                            _confirmDelete(context, ref, habit, colors),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    HabitItem habit,
    AppColorsExtension colors,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Удалить привычку навсегда?',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: Text(
          'Привычка "${habit.title}" и вся её история будут безвозвратно удалены.',
          style: TextStyle(
            fontFamily: 'Onest',
            color: colors.text.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(
                fontFamily: 'Onest',
                color: colors.text.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              ref.read(habitsProvider.notifier).deleteHabit(habit.id);
              Navigator.pop(ctx);
            },
            child: const Text(
              'Удалить',
              style: TextStyle(
                fontFamily: 'Onest',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
