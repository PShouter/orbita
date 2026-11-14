import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/notification_settings_provider.dart';
import '../../theme/app_theme.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  final bool isDarkMode;
  const NotificationSettingsScreen({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final notif = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    final textPrimary = colors.text;
    final textSecondary = colors.text.withValues(alpha: 0.6);
    final cardBg = colors.card;
    final borderColor = colors.nested;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Уведомления',
          style: TextStyle(
            fontFamily: 'Unbounded',
            color: textPrimary,
            fontWeight: FontWeight.w600,
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
            colors: colors,
            title: 'События и задачи',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: colors.accent,
                activeTrackColor: colors.accent.withValues(alpha: 0.3),
                title: Text(
                  'События Календаря',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Напоминания до начала событий',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),
                value: notif.calendarEnabled,
                onChanged: (v) =>
                    notifier.updateSetting('notif_calendar', v.toString()),
              ),
              Divider(height: 1, color: borderColor),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: colors.accent,
                activeTrackColor: colors.accent.withValues(alpha: 0.3),
                title: Text(
                  'Задачи со сроком',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Оповещения в назначенное время',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),
                value: notif.tasksEnabled,
                onChanged: (v) =>
                    notifier.updateSetting('notif_tasks', v.toString()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            cardBg,
            borderColor,
            colors: colors,
            title: 'Привычки и График смен',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: colors.accent,
                activeTrackColor: colors.accent.withValues(alpha: 0.3),
                title: Text(
                  'Привычки',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Индивидуальные напоминания для привычек',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),
                value: notif.habitsEnabled,
                onChanged: (v) =>
                    notifier.updateSetting('notif_habits', v.toString()),
              ),
              Divider(height: 1, color: borderColor),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: colors.accent,
                activeTrackColor: colors.accent.withValues(alpha: 0.3),
                title: Text(
                  'График смен',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Напоминание о смене накануне вечером и до выезда',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),
                value: notif.shiftsEnabled,
                onChanged: (v) =>
                    notifier.updateSetting('notif_shifts', v.toString()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            cardBg,
            borderColor,
            colors: colors,
            title: 'Дневник и Финансы',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: colors.accent,
                activeTrackColor: colors.accent.withValues(alpha: 0.3),
                title: Text(
                  'Вечерний Дневник',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Время: ${notif.diaryTime.format(context)}',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
                    style: TextButton.styleFrom(
                      foregroundColor: colors.accent,
                    ),
                    icon: const Icon(Icons.access_time, size: 16),
                    label: const Text(
                      'Изменить время дневника',
                      style: TextStyle(
                          fontFamily: 'Onest', fontWeight: FontWeight.bold),
                    ),
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
              Divider(height: 1, color: borderColor),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: colors.accent,
                activeTrackColor: colors.accent.withValues(alpha: 0.3),
                title: Text(
                  'Бюджет: Утренний план и вечерний учёт',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Утро: ${notif.budgetMorningTime.format(context)} • Вечер: ${notif.budgetEveningTime.format(context)}',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: notif.budgetEnabled,
                onChanged: (v) =>
                    notifier.updateSetting('notif_budget', v.toString()),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    Color cardBg,
    Color borderColor, {
    required AppColorsExtension colors,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Unbounded',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
