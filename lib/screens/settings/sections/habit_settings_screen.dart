import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/habits_provider.dart';
import '../../../theme/app_theme.dart';

class HabitSettingsScreen extends ConsumerStatefulWidget {
  const HabitSettingsScreen({super.key});

  @override
  ConsumerState<HabitSettingsScreen> createState() =>
      _HabitSettingsScreenState();
}

class _HabitSettingsScreenState extends ConsumerState<HabitSettingsScreen> {
  String _soundTitle = 'По умолчанию (системный)';

  @override
  void initState() {
    super.initState();
    _loadSound();
  }

  Future<void> _loadSound() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundTitle = prefs.getString('habit_notif_sound_title') ??
          'По умолчанию (системный)';
    });
  }

  Future<void> _pickNotificationSound(AppColorsExtension colors) async {
    final options = [
      'По умолчанию (системный)',
      'Звон победы (Орбита)',
      'Колокольчик',
      'Струнный аккорд',
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
      await prefs.setString('habit_notif_sound_title', selected);
      setState(() => _soundTitle = selected);
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isShortTap = ref.watch(habitShortTapProvider);
    final isReverseDays = ref.watch(habitReverseDaysProvider);

    final cardBg = colors.card;
    final borderColor = colors.nested;
    final textPrimary = colors.text;
    final textSecondary = colors.text.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          'Настройки привычек',
          style: TextStyle(
            fontFamily: 'Unbounded',
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. ИНТЕРФЕЙС
          _buildSectionHeader('ИНТЕРФЕЙС', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  activeThumbColor: colors.accent,
                  activeTrackColor: colors.accent.withValues(alpha: 0.3),
                  title: Text(
                    'Отмечать коротким нажатием',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    'Если выключено, отметка ставится долгим нажатием для защиты от случайных кликов',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: isShortTap,
                  onChanged: (val) {
                    ref.read(habitShortTapProvider.notifier).toggle(val);
                  },
                ),
                Divider(height: 1, color: borderColor),
                SwitchListTile(
                  activeThumbColor: colors.accent,
                  activeTrackColor: colors.accent.withValues(alpha: 0.3),
                  title: Text(
                    'Обратный порядок дней',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    'Слева направо дни идут на убывание: сегодня, вчера, позавчера...',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: isReverseDays,
                  onChanged: (val) {
                    ref.read(habitReverseDaysProvider.notifier).toggle(val);
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
            child: ListTile(
              leading: Icon(
                Icons.music_note_outlined,
                color: colors.warning,
              ),
              title: Text(
                'Сигнал уведомления',
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
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
              trailing: Icon(
                Icons.chevron_right,
                color: textSecondary,
                size: 20,
              ),
              onTap: () => _pickNotificationSound(colors),
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
