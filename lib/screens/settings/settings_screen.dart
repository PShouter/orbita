import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/sync_service.dart';
import 'sections/habit_settings_screen.dart';
import '../info/app_info_screen.dart';
import 'bottom_bar_settings_screen.dart';
import 'sections/budget_settings_screen.dart';
import 'sections/calendar_settings_screen.dart';
import 'sections/diary_settings_screen.dart';
import 'sections/notes_settings_screen.dart';
import 'sections/shifts_settings_screen.dart';
import 'sections/tasks_settings_screen.dart';
import 'sections/theme_settings_screen.dart';
import 'sections/vault_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final String userName;
  final String customUsername;
  final Function(String newName, String newUsername) onProfileUpdated;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.userName,
    required this.customUsername,
    required this.onProfileUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    try {
      await SyncService.instance.syncAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Синхронизация завершена успешно!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка синхронизации: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _navigate(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    final currentUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: cardBg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. СИНХРОНИЗАЦИЯ
          _buildSectionHeader('Синхронизация', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    currentUser != null ? Icons.cloud_done : Icons.cloud_off,
                    color: currentUser != null
                        ? const Color(0xFF10B981)
                        : Colors.orangeAccent,
                  ),
                  title: Text(
                    'Статус аккаунта',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    currentUser != null
                        ? 'Подключен: ${currentUser.email ?? "Email"}'
                        : 'Гостевой автономный режим',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync, color: Color(0xFF38BDF8)),
                  title: Text(
                    'Синхронизировать сейчас',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Принудительная выгрузка и получение изменений',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: _isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isSyncing ? null : _triggerManualSync,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. НАСТРОЙКИ РАЗДЕЛОВ
          _buildSectionHeader('Настройки разделов', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildNavRow(
                  icon: Icons.calendar_today_outlined,
                  color: const Color(0xFF38BDF8),
                  title: 'Календарь',
                  textPrimary: textPrimary,
                  onTap: () =>
                      _navigate(CalendarSettingsScreen(isDarkMode: isDark)),
                ),
                const Divider(height: 1),
                _buildNavRow(
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF4ADE80),
                  title: 'Задачи',
                  textPrimary: textPrimary,
                  onTap: () =>
                      _navigate(TasksSettingsScreen(isDarkMode: isDark)),
                ),
                const Divider(height: 1),
                _buildNavRow(
                  icon: Icons.repeat,
                  color: Colors.amber,
                  title: 'Привычки',
                  textPrimary: textPrimary,
                  onTap: () => _navigate(const HabitSettingsScreen()),
                ),
                const Divider(height: 1),
                _buildNavRow(
                  icon: Icons.description_outlined,
                  color: Colors.purpleAccent,
                  title: 'Заметки',
                  textPrimary: textPrimary,
                  onTap: () =>
                      _navigate(NotesSettingsScreen(isDarkMode: isDark)),
                ),
                const Divider(height: 1),
                _buildNavRow(
                  icon: Icons.book_outlined,
                  color: Colors.pinkAccent,
                  title: 'Дневник',
                  textPrimary: textPrimary,
                  onTap: () =>
                      _navigate(DiarySettingsScreen(isDarkMode: isDark)),
                ),
                const Divider(height: 1),
                _buildNavRow(
                  icon: Icons.work_outline,
                  color: const Color(0xFF6366F1),
                  title: 'График смен',
                  textPrimary: textPrimary,
                  onTap: () =>
                      _navigate(ShiftsSettingsScreen(isDarkMode: isDark)),
                ),
                const Divider(height: 1),
                _buildNavRow(
                  icon: Icons.shield_outlined,
                  color: const Color(0xFF06B6D4),
                  title: 'Сейф',
                  textPrimary: textPrimary,
                  onTap: () =>
                      _navigate(VaultSettingsScreen(isDarkMode: isDark)),
                ),
                const Divider(height: 1),
                _buildNavRow(
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFF10B981),
                  title: 'Бюджет',
                  textPrimary: textPrimary,
                  onTap: () =>
                      _navigate(BudgetSettingsScreen(isDarkMode: isDark)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. ИНТЕРФЕЙС И НАВИГАЦИЯ
          _buildSectionHeader('Интерфейс и навигация', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildNavRow(
                  icon: Icons.palette_outlined,
                  color: Colors.orangeAccent,
                  title: 'Выбор темы',
                  textPrimary: textPrimary,
                  onTap: () => _navigate(
                    ThemeSettingsScreen(
                      isDarkMode: isDark,
                      onToggleTheme: widget.onToggleTheme,
                    ),
                  ),
                ),
                const Divider(height: 1),
                _buildNavRow(
                  icon: Icons.view_carousel_outlined,
                  color: const Color(0xFF38BDF8),
                  title: 'Нижняя панель навигации',
                  textPrimary: textPrimary,
                  onTap: () =>
                      _navigate(BottomBarSettingsScreen(isDarkMode: isDark)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. ИНФОРМАЦИЯ
          _buildSectionHeader('Информация', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: _buildNavRow(
              icon: Icons.info_outline,
              color: textSecondary,
              title: 'О приложении',
              textPrimary: textPrimary,
              onTap: () => _navigate(AppInfoScreen(isDarkMode: isDark)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildNavRow({
    required IconData icon,
    required Color color,
    required String title,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
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
