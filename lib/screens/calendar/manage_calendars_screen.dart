import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/calendar_provider.dart';
import '../../theme/app_theme.dart';

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
    final colors = context.colors;
    final calendars = ref.watch(userCalendarsProvider);
    final notifier = ref.read(userCalendarsProvider.notifier);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          'Календари',
          style: TextStyle(
            fontFamily: 'Unbounded',
            color: colors.text,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: colors.text),
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
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: colors.text,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle, color: colors.accent, size: 26),
                onPressed: () => _openCalendarDialog(context, notifier, null, colors),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...calendars.map((cal) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: colors.card,
                borderRadius: BorderRadius.circular(18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: colors.nested),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(backgroundColor: cal.color, radius: 10),
                  title: Text(
                    cal.title,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    cal.accountType == 'local'
                        ? 'Локальный'
                        : 'Google Календарь',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: colors.text.withValues(alpha: 0.7),
                        ),
                        onPressed: () =>
                            _openCalendarDialog(context, notifier, cal, colors),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: colors.error,
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
              fontFamily: 'Onest',
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.nested),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_sync_outlined,
                  color: colors.accent,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google Календарь',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Подключите учетную запись для импорта событий',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.text.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.nested),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    minimumSize: const Size(64, 38),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Синхронизация с Google Календарем будет активна при подключении Google Sign-In',
                          style: TextStyle(fontFamily: 'Onest'),
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Войти',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _openCalendarDialog(
    BuildContext context,
    UserCalendarsNotifier notifier,
    UserCalendar? existing,
    AppColorsExtension colors,
  ) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    Color selectedColor = existing?.color ?? _palette.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null
                    ? 'Создать календарь'
                    : 'Редактировать календарь',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
                decoration: InputDecoration(
                  labelText: 'Название календаря',
                  labelStyle: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: colors.nested.withValues(alpha: 0.4),
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
              Text(
                'Цвет календаря (палитра):',
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.text.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: GridView.count(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: _palette.map((c) {
                    final isCurrent = selectedColor.toARGB32() == c.toARGB32();
                    return GestureDetector(
                      onTap: () => setDState(() => selectedColor = c),
                      child: CircleAvatar(
                        backgroundColor: c,
                        radius: 14,
                        child: isCurrent
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
                    backgroundColor: colors.accent,
                    foregroundColor: colors.isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size(44, 46),
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
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}