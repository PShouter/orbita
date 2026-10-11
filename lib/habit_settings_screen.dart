import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/habits_provider.dart';

class HabitSettingsScreen extends ConsumerWidget {
  const HabitSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isShortTap = ref.watch(habitShortTapProvider);

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
        children: [
          SwitchListTile(
            activeThumbColor: const Color(0xFF38BDF8),
            title: const Text(
              'Отмечать коротким нажатием',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            subtitle: const Text(
              'Если выключено, отметка ставится долгим нажатием для защиты от случайных кликов',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            value: isShortTap,
            onChanged: (val) {
              ref.read(habitShortTapProvider.notifier).toggle(val);
            },
          ),
        ],
      ),
    );
  }
}
