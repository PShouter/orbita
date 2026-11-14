import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../info/app_info_screen.dart';
import 'bottom_bar_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'sections/budget_settings_screen.dart';
import 'sections/calendar_settings_screen.dart';
import 'sections/diary_settings_screen.dart';
import 'sections/habit_settings_screen.dart';
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

  Future<void> _triggerManualSync(AppColorsExtension colors) async {
    setState(() => _isSyncing = true);
    try {
      await SyncService.instance.syncAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Синхронизация завершена успешно!',
              style: TextStyle(fontFamily: 'Onest'),
            ),
            backgroundColor: colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка синхронизации: $e',
              style: const TextStyle(fontFamily: 'Onest'),
            ),
            backgroundColor: colors.error,
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
    final colors = context.colors;
    final isDark = colors.isDark;
    final textPrimary = colors.text;
    final textSecondary = colors.text.withValues(alpha: 0.6);
    final cardBg = colors.card;
    final borderColor = colors.nested;

    final currentUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(
          'Настройки',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        backgroundColor: colors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. СИНХРОНИЗАЦИЯ
          _buildSectionHeader('Синхронизация', textSecondary),
          Material(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    currentUser != null ? Icons.cloud_done : Icons.cloud_off,
                    color:
                        currentUser != null ? colors.success : colors.warning,
                  ),
                  title: Text(
                    'Статус аккаунта',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    currentUser != null
                        ? 'Подключен: ${currentUser.email ?? "Email"}'
                        : 'Гостевой автономный режим',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: Icon(Icons.sync, color: colors.accent),
                  title: Text(
                    'Синхронизировать сейчас',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Принудительная выгрузка и получение изменений',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: _isSyncing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.accent,
                          ),
                        )
                      : Icon(Icons.chevron_right, color: textSecondary),
                  onTap: _isSyncing ? null : () => _triggerManualSync(colors),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. НАСТРОЙКИ РАЗДЕЛОВ
          _buildSectionHeader('Настройки разделов', textSecondary),
          Material(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildNavRow(
                  icon: Icons.calendar_today_outlined,
                  color: colors.accent,
                  title: 'Календарь',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () =>
                      _navigate(CalendarSettingsScreen(isDarkMode: isDark)),
                ),
                Divider(height: 1, color: borderColor),
                _buildNavRow(
                  icon: Icons.check_circle_outline,
                  color: colors.success,
                  title: 'Задачи',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () =>
                      _navigate(TasksSettingsScreen(isDarkMode: isDark)),
                ),
                Divider(height: 1, color: borderColor),
                _buildNavRow(
                  icon: Icons.repeat,
                  color: colors.warning,
                  title: 'Привычки',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _navigate(const HabitSettingsScreen()),
                ),
                Divider(height: 1, color: borderColor),
                _buildNavRow(
                  icon: Icons.description_outlined,
                  color: const Color(0xFFA855F7),
                  title: 'Заметки',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () =>
                      _navigate(NotesSettingsScreen(isDarkMode: isDark)),
                ),
                Divider(height: 1, color: borderColor),
                _buildNavRow(
                  icon: Icons.book_outlined,
                  color: const Color(0xFFEC4899),
                  title: 'Дневник',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () =>
                      _navigate(DiarySettingsScreen(isDarkMode: isDark)),
                ),
                Divider(height: 1, color: borderColor),
                _buildNavRow(
                  icon: Icons.work_outline,
                  color: const Color(0xFF6366F1),
                  title: 'График смен',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () =>
                      _navigate(ShiftsSettingsScreen(isDarkMode: isDark)),
                ),
                Divider(height: 1, color: borderColor),
                _buildNavRow(
                  icon: Icons.shield_outlined,
                  color: const Color(0xFF06B6D4),
                  title: 'Сейф',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () =>
                      _navigate(VaultSettingsScreen(isDarkMode: isDark)),
                ),
                Divider(height: 1, color: borderColor),
                _buildNavRow(
                  icon: Icons.account_balance_wallet_outlined,
                  color: colors.success,
                  title: 'Бюджет',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () =>
                      _navigate(BudgetSettingsScreen(isDarkMode: isDark)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. ИНТЕРФЕЙС И НАВИГАЦИЯ
          _buildSectionHeader('Интерфейс и навигация', textSecondary),
          Material(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildNavRow(
                  icon: Icons.palette_outlined,
                  color: colors.warning,
                  title: 'Выбор темы',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _navigate(ThemeSettingsScreen()),
                ),
                Divider(height: 1, color: borderColor),
                _buildNavRow(
                  icon: Icons.notifications_none_outlined,
                  color: colors.accent,
                  title: 'Уведомления',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () =>
                      _navigate(NotificationSettingsScreen(isDarkMode: isDark)),
                ),
                Divider(height: 1, color: borderColor),
                _buildNavRow(
                  icon: Icons.view_carousel_outlined,
                  color: colors.accent,
                  title: 'Нижняя панель навигации',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () =>
                      _navigate(BottomBarSettingsScreen(isDarkMode: isDark)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. ИНФОРМАЦИЯ
          _buildSectionHeader('Информация', textSecondary),
          Material(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildNavRow(
              icon: Icons.info_outline,
              color: textSecondary,
              title: 'О приложении',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
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
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Onest',
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      trailing: Icon(Icons.chevron_right, size: 20, color: textSecondary),
      onTap: onTap,
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Onest',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
