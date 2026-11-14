import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../theme/app_theme.dart';
import 'diary_lock_settings_screen.dart';

class DiarySettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  const DiarySettingsScreen({super.key, required this.isDarkMode});

  @override
  State<DiarySettingsScreen> createState() => _DiarySettingsScreenState();
}

class _DiarySettingsScreenState extends State<DiarySettingsScreen> {
  bool _isLockEnabled = false;
  bool _hidePreviewInList = false;

  bool _eveningReminder = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);
  String _soundTitle = 'По умолчанию (системный)';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLockEnabled = prefs.getBool('diary_lock_enabled') ?? false;
      _hidePreviewInList = prefs.getBool('diary_hide_preview') ?? false;

      _eveningReminder = prefs.getBool('diary_reminder_enabled') ?? true;
      final timeStr = prefs.getString('diary_reminder_time') ?? '21:00';
      final parts = timeStr.split(':');
      _reminderTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );

      _soundTitle = prefs.getString('diary_notif_sound_title') ??
          'По умолчанию (системный)';
    });
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'diary_reminder_time',
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
      );
      setState(() => _reminderTime = picked);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _pickNotificationSound(AppColorsExtension colors) async {
    final options = [
      'По умолчанию (системный)',
      'Звездная пыль (Орбита)',
      'Мягкий перезвон',
      'Ночной сигнал',
      'Без звука',
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Сигнал напоминания',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((sound) {
            return RadioListTile<String>(
              title: Text(
                sound,
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
              ),
              value: sound,
              groupValue: _soundTitle,
              activeColor: colors.accent,
              onChanged: (val) => Navigator.pop(ctx, val),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('diary_notif_sound_title', selected);
      setState(() => _soundTitle = selected);
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cardBg = colors.card;
    final textPrimary = colors.text;
    final textSecondary = colors.text.withValues(alpha: 0.6);
    final borderColor = colors.nested;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(
          'Настройки дневника',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        backgroundColor: colors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. ОБЩЕЕ
          _buildSectionHeader('ОБЩЕЕ', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.mood, color: colors.warning),
                  title: Text(
                    'Стиль настроения',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Выбор набора смайлов и эмоций',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing:
                      Icon(Icons.chevron_right, size: 20, color: textSecondary),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Выбор стиля настроения будет доступен в следующем обновлении',
                          style: TextStyle(fontFamily: 'Onest'),
                        ),
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: Icon(Icons.security, color: colors.accent),
                  title: Text(
                    'Блокировка дневника',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _isLockEnabled ? 'Включена (код / биометрия)' : 'Выключена',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: _isLockEnabled ? colors.success : textSecondary,
                      fontSize: 12,
                      fontWeight:
                          _isLockEnabled ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing:
                      Icon(Icons.chevron_right, size: 20, color: textSecondary),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DiaryLockSettingsScreen(
                          isDarkMode: colors.isDark,
                        ),
                      ),
                    );
                    _loadSettings();
                  },
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: Icon(
                    Icons.blur_on,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Скрывать превью текста',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Размывать текст в списке записей для приватности',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeColor: colors.accent,
                  checkColor: colors.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  value: _hidePreviewInList,
                  onChanged: (v) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('diary_hide_preview', v ?? false);
                    setState(() => _hidePreviewInList = v ?? false);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. НАПОМИНАНИЯ
          _buildSectionHeader('НАПОМИНАНИЯ', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.notifications_active_outlined,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Напоминание о записи',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Ежедневное напоминание подвести итоги дня',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: colors.accent,
                  activeTrackColor: colors.accent.withValues(alpha: 0.3),
                  value: _eveningReminder,
                  onChanged: (v) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('diary_reminder_enabled', v);
                    setState(() => _eveningReminder = v);
                  },
                ),
                if (_eveningReminder) ...[
                  Divider(height: 1, color: borderColor),
                  ListTile(
                    leading: Icon(Icons.access_time, color: colors.warning),
                    title: Text(
                      'Время напоминания',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        size: 20, color: textSecondary),
                    onTap: _pickReminderTime,
                  ),
                  Divider(height: 1, color: borderColor),
                  ListTile(
                    leading: Icon(
                      Icons.music_note_outlined,
                      color: colors.accent,
                    ),
                    title: Text(
                      'Сигнал уведомления',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _soundTitle,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        size: 20, color: textSecondary),
                    onTap: () => _pickNotificationSound(colors),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Onest',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
