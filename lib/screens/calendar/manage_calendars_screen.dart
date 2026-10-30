import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/calendar_provider.dart';

class ManageCalendarsScreen extends ConsumerWidget {
  final bool isDarkMode;

  const ManageCalendarsScreen({super.key, required this.isDarkMode});

  static const List<Color> _palette = [
    Color(0xFF2C69D1),
    Color(0xFF38BDF8),
    Color(0xFF00ACC1),
    Color(0xFF00897B),
    Color(0xFF43A047),
    Color(0xFF7CB342),
    Color(0xFFC0CA33),
    Color(0xFFFDD835),
    Color(0xFFFFB300),
    Color(0xFFFB8C00),
    Color(0xFFF4511E),
    Color(0xFFE53935),
    Color(0xFFD81B60),
    Color(0xFF8E24AA),
    Color(0xFF5E35B1),
    Color(0xFF3949AB),
    Color(0xFF1E88E5),
    Color(0xFF039BE5),
    Color(0xFF6D4C41),
    Color(0xFF546E7A),
    Color(0xFFEC407A),
    Color(0xFF26A69A),
    Color(0xFFFFA726),
    Color(0xFF78909C),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendars = ref.watch(userCalendarsProvider);
    final notifier = ref.read(userCalendarsProvider.notifier);

    final bg = isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final cardBg = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final textPrimary =
        isDarkMode ? const Color(0xFFF0F6FC) : const Color(0xFF24292F);
    final textSecondary =
        isDarkMode ? const Color(0xFF8B949E) : const Color(0xFF57606A);
    final borderColor =
        isDarkMode ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Календари',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Мои календари',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFF38BDF8)),
                onPressed: () => _openCalendarDialog(context, notifier, null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...calendars.map((cal) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: cal.color, radius: 10),
                  title: Text(
                    cal.title,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    cal.accountType == 'local'
                        ? 'Локальный'
                        : 'Google Календарь',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () =>
                            _openCalendarDialog(context, notifier, cal),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => notifier.deleteCalendar(cal.id),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Text(
            'Аккаунты Google Календаря',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_sync_outlined,
                  color: Color(0xFF38BDF8),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google Календарь',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Подключите учетную запись для импорта событий',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Синхронизация с Google Календарем будет активна при подключении Google Sign-In',
                        ),
                      ),
                    );
                  },
                  child: const Text('Войти', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCalendarDialog(
    BuildContext context,
    UserCalendarsNotifier notifier,
    UserCalendar? existing,
  ) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    Color selectedColor = existing?.color ?? _palette.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF161B22) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null
                    ? 'Создать календарь'
                    : 'Редактировать календарь',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название календаря',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Цвет календаря (палитра):',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 120,
                child: GridView.count(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: _palette.map((c) {
                    return GestureDetector(
                      onTap: () => setDState(() => selectedColor = c),
                      child: CircleAvatar(
                        backgroundColor: c,
                        radius: 14,
                        child: selectedColor == c
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                  ),
                  onPressed: () {
                    final t = titleCtrl.text.trim();
                    if (t.isEmpty) return;

                    if (existing == null) {
                      notifier.addCalendar(t, selectedColor);
                    } else {
                      notifier.updateCalendar(existing.id, t, selectedColor);
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Сохранить',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
