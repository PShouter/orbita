import 'package:flutter/material.dart';

class DiarySettingsScreen extends StatelessWidget {
  const DiarySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки дневника')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Color(0xFF38BDF8)),
            title: const Text('Защита паролем'),
            subtitle: const Text('PIN-код или отпечаток пальца (скоро)'),
            trailing: const Switch(value: false, onChanged: null),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(
              Icons.palette_outlined,
              color: Color(0xFF818CF8),
            ),
            title: const Text('Наборы смайлов'),
            subtitle: const Text('Смайлы, котики и стикеры (в разработке)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Раздел находится в разработке')),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(
              Icons.notifications_none,
              color: Color(0xFF34D399),
            ),
            title: const Text('Напоминание вести дневник'),
            subtitle: const Text('Ежедневное напоминание'),
            trailing: const Switch(value: false, onChanged: null),
          ),
        ],
      ),
    );
  }
}
