import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

      _soundTitle =
          prefs.getString('diary_notif_sound_title') ??
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

  Future<void> _pickNotificationSound() async {
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
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF161B22)
            : Colors.white,
        title: const Text('Сигнал напоминания'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((sound) {
            return RadioListTile<String>(
              title: Text(sound),
              value: sound,
              groupValue: _soundTitle,
              activeColor: const Color(0xFF38BDF8),
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
        title: const Text('Настройки дневника'),
        backgroundColor: cardBg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. ОБЩЕЕ
          _buildSectionHeader('ОБЩЕЕ', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.mood, color: Colors.amber),
                  title: Text(
                    'Стиль настроения',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Выбор набора смайлов и эмоций',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Выбор стиля настроения будет доступен в следующем обновлении',
                        ),
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.security, color: Color(0xFF38BDF8)),
                  title: Text(
                    'Блокировка дневника',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _isLockEnabled ? 'Включена (код / биометрия)' : 'Выключена',
                    style: TextStyle(
                      color: _isLockEnabled
                          ? const Color(0xFF10B981)
                          : textSecondary,
                      fontSize: 12,
                      fontWeight: _isLockEnabled
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DiaryLockSettingsScreen(
                          isDarkMode: widget.isDarkMode,
                        ),
                      ),
                    );
                    _loadSettings();
                  },
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: const Icon(
                    Icons.blur_on,
                    color: Colors.purpleAccent,
                  ),
                  title: Text(
                    'Скрывать превью текста',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Размывать текст в списке записей для приватности',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF38BDF8),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Напоминание о записи',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Ежедневное напоминание подвести итоги дня',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeThumbColor: const Color(0xFF38BDF8),
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
                    leading: const Icon(Icons.access_time, color: Colors.amber),
                    title: Text(
                      'Время напоминания',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _pickReminderTime,
                  ),
                  Divider(height: 1, color: borderColor),
                  ListTile(
                    leading: const Icon(
                      Icons.music_note_outlined,
                      color: Colors.purpleAccent,
                    ),
                    title: Text(
                      'Сигнал уведомления',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _soundTitle,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _pickNotificationSound,
                  ),
                ],
              ],
            ),
          ),
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
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
