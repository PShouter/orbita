import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/habits_provider.dart';

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
      _soundTitle =
          prefs.getString('habit_notif_sound_title') ??
          'По умолчанию (системный)';
    });
  }

  Future<void> _pickNotificationSound() async {
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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Сигнал напоминания',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((sound) {
            return RadioListTile<String>(
              title: Text(sound, style: const TextStyle(color: Colors.white70)),
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
      await prefs.setString('habit_notif_sound_title', selected);
      setState(() => _soundTitle = selected);
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isShortTap = ref.watch(habitShortTapProvider);
    final isReverseDays = ref.watch(habitReverseDaysProvider);

    const cardBg = Color(0xFF1E293B);
    const borderColor = Color(0xFF334155);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'Настройки привычек',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. ИНТЕРФЕЙС
          _buildSectionHeader('ИНТЕРФЕЙС'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  activeThumbColor: const Color(0xFF38BDF8),
                  title: const Text(
                    'Отмечать коротким нажатием',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: const Text(
                    'Если выключено, отметка ставится долгим нажатием для защиты от случайных кликов',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  value: isShortTap,
                  onChanged: (val) {
                    ref.read(habitShortTapProvider.notifier).toggle(val);
                  },
                ),
                const Divider(height: 1, color: borderColor),
                SwitchListTile(
                  activeThumbColor: const Color(0xFF38BDF8),
                  title: const Text(
                    'Обратный порядок дней',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: const Text(
                    'Слева направо дни идут на убывание: сегодня, вчера, позавчера...',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
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
          _buildSectionHeader('НАПОМИНАНИЯ'),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.music_note_outlined,
                color: Colors.purpleAccent,
              ),
              title: const Text(
                'Сигнал уведомления',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                _soundTitle,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Colors.white54,
                size: 20,
              ),
              onTap: _pickNotificationSound,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white54,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
