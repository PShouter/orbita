import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/notification_settings_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  final bool isDarkMode;
  const NotificationSettingsScreen({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notif = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    final bg = isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final cardBg = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final textPrimary = isDarkMode
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final textSecondary = isDarkMode
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final borderColor = isDarkMode
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Уведомления',
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
          _buildSectionCard(
            cardBg,
            borderColor,
            title: 'События и задачи',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xFF38BDF8),
                title: Text(
                  'События Календаря',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Напоминания до начала событий',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                value: notif.calendarEnabled,
                onChanged: (v) =>
                    notifier.updateSetting('notif_calendar', v.toString()),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xFF38BDF8),
                title: Text(
                  'Задачи со сроком',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Оповещения в назначенное время',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                value: notif.tasksEnabled,
                onChanged: (v) =>
                    notifier.updateSetting('notif_tasks', v.toString()),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildSectionCard(
            cardBg,
            borderColor,
            title: 'Привычки и График смен',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xFF38BDF8),
                title: Text(
                  'Привычки',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Индивидуальные напоминания для привычек',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                value: notif.habitsEnabled,
                onChanged: (v) =>
                    notifier.updateSetting('notif_habits', v.toString()),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xFF38BDF8),
                title: Text(
                  'График смен',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Напоминание о смене накануне вечером и до выезда',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                value: notif.shiftsEnabled,
                onChanged: (v) =>
                    notifier.updateSetting('notif_shifts', v.toString()),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildSectionCard(
            cardBg,
            borderColor,
            title: 'Дневник и Финансы',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xFF38BDF8),
                title: Text(
                  'Вечерний Дневник',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Время: ${notif.diaryTime.format(context)}',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 12,
                  ),
                ),
                value: notif.diaryEnabled,
                onChanged: (v) =>
                    notifier.updateSetting('notif_diary', v.toString()),
              ),
              if (notif.diaryEnabled)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.access_time, size: 16),
                    label: const Text('Изменить время дневника'),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: notif.diaryTime,
                      );
                      if (t != null) {
                        notifier.updateSetting(
                          'notif_diary_time',
                          '${t.hour}:${t.minute}',
                        );
                      }
                    },
                  ),
                ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xFF38BDF8),
                title: Text(
                  'Бюджет: Утренний план и вечерний учёт',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Утро: ${notif.budgetMorningTime.format(context)} • Вечер: ${notif.budgetEveningTime.format(context)}',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 12,
                  ),
                ),
                value: notif.budgetEnabled,
                onChanged: (v) =>
                    notifier.updateSetting('notif_budget', v.toString()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    Color cardBg,
    Color borderColor, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
