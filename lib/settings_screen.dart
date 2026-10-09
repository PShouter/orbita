import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_info_screen.dart';

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
  late String _currentName;
  late String _currentUsername;

  bool _taskEnableDrag = true;
  bool _taskAutoCompleteParent = true;
  String _notesLayout = 'Плитки';
  bool _habitShortTap = false;

  @override
  void initState() {
    super.initState();
    _currentName = widget.userName;
    _currentUsername = widget.customUsername;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _taskEnableDrag = prefs.getBool('task_enable_drag') ?? true;
      _taskAutoCompleteParent =
          prefs.getBool('task_auto_complete_parent') ?? true;
      _notesLayout = prefs.getString('notes_layout') ?? 'Плитки';
      _habitShortTap = prefs.getBool('habit_short_tap') ?? false;
    });
  }

  // Полноценный диалог редактирования профиля
  void _openEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _currentName);
    final usernameCtrl = TextEditingController(text: _currentUsername);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_pin, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Text('Редактировать профиль'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF2C69D1),
                  child: Text(
                    _currentName.isNotEmpty
                        ? _currentName.substring(0, 1).toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ваше имя',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Юзернейм (ID)',
                  prefixText: '@',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newUsername = usernameCtrl.text.trim().replaceAll('@', '');

              if (newName.isNotEmpty && newUsername.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_full_name', newName);
                await prefs.setString('user_custom_username', newUsername);

                // Попытка обновить профиль в Supabase, если залогинен
                try {
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user != null) {
                    await Supabase.instance.client.from('profiles').upsert({
                      'id': user.id,
                      'full_name': newName,
                      'username': newUsername,
                      'updated_at': DateTime.now().toIso8601String(),
                    });
                  }
                } catch (_) {}

                setState(() {
                  _currentName = newName;
                  _currentUsername = newUsername;
                });

                widget.onProfileUpdated(newName, newUsername);
                Navigator.pop(ctx);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Профиль успешно обновлен!')),
                  );
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final Color textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final Color textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

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
          // 1. КАРТОЧКА ПРОФИЛЯ С ПЕРЕХОДОМ
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF2C69D1),
                  child: Text(
                    _currentName.isNotEmpty
                        ? _currentName.substring(0, 1).toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$_currentUsername',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _openEditProfileDialog,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Изменить',
                    style: TextStyle(fontSize: 12, color: Color(0xFF38BDF8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. ВНЕШНИЙ ВИД И ТЕМА
          _buildSectionHeader('Внешний вид', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    color: isDark ? const Color(0xFF38BDF8) : Colors.amber,
                  ),
                  title: Text(
                    'Тёмная тема',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    isDark ? 'Включена тёмная тема' : 'Включена светлая тема',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  value: isDark,
                  onChanged: (val) => widget.onToggleTheme(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. ПАРАМЕТРЫ МОДУЛЕЙ
          _buildSectionHeader('Параметры разделов', textSecondary),
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
                    Icons.drag_indicator,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Перетаскивание задач',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Позволяет менять порядок задач вручную',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  value: _taskEnableDrag,
                  onChanged: (v) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('task_enable_drag', v);
                    setState(() => _taskEnableDrag = v);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.done_all,
                    color: Color(0xFF4ADE80),
                  ),
                  title: Text(
                    'Автозавершение задач',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Завершать задачу при выполнении всех подзадач',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  value: _taskAutoCompleteParent,
                  onChanged: (v) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('task_auto_complete_parent', v);
                    setState(() => _taskAutoCompleteParent = v);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.edit_note,
                    color: Colors.purpleAccent,
                  ),
                  title: Text(
                    'Макет заметок Obsidian',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Текущий режим: $_notesLayout',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: _notesLayout,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(color: textPrimary),
                    items: const ['Плитки', 'список']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) async {
                      if (v != null) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('notes_layout', v);
                        setState(() => _notesLayout = v);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.touch_app_outlined,
                    color: Colors.tealAccent,
                  ),
                  title: Text(
                    'Короткий тап по привычкам',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Отмечать статус привычки без удержания',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  value: _habitShortTap,
                  onChanged: (v) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('habit_short_tap', v);
                    setState(() => _habitShortTap = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. О ПРИЛОЖЕНИИ И ПОЛИТИКА
          _buildSectionHeader('Информация', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.info_outline,
                color: Colors.orangeAccent,
              ),
              title: Text(
                'О приложении и обратная связь',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              subtitle: Text(
                'Контакты разработчика, Telegram, политика',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AppInfoScreen(isDarkMode: widget.isDarkMode),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          // Подвал
          Center(
            child: Column(
              children: [
                Text(
                  'Орбита — персональный второй мозг',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Версия: Global Demo 0.3.0',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Разработчик: Pavel Krikun (Shouter)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
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
