import 'package:flutter/material.dart';

class ThemeSettingsScreen extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const ThemeSettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final cardBg = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final textPrimary = isDarkMode
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final textSecondary = isDarkMode
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Тема оформления'),
        backgroundColor: bg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                RadioListTile<bool>(
                  title: Text(
                    'Тёмная тема',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Экономит батарею и снижает нагрузку на глаза',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  value: true,
                  groupValue: isDarkMode,
                  activeColor: const Color(0xFF38BDF8),
                  onChanged: (v) {
                    if (!isDarkMode) onToggleTheme();
                  },
                ),
                const Divider(height: 1),
                RadioListTile<bool>(
                  title: Text(
                    'Светлая тема',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Классический светлый интерфейс',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  value: false,
                  groupValue: isDarkMode,
                  activeColor: const Color(0xFF38BDF8),
                  onChanged: (v) {
                    if (isDarkMode) onToggleTheme();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
