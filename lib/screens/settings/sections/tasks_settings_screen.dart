import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/tasks_provider.dart';
import '../../../theme/app_theme.dart';

class TasksSettingsScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  const TasksSettingsScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<TasksSettingsScreen> createState() =>
      _TasksSettingsScreenState();
}

class _TasksSettingsScreenState extends ConsumerState<TasksSettingsScreen> {
  // Внешний вид
  String _defaultCategory = 'Личное';
  bool _taskEnableDrag = true;

  // Напоминания
  String _notificationSoundTitle = 'По умолчанию (системный)';
  bool _snoozeReminderEnabled = true;
  int _snoozeDurationMinutes = 15;

  // Подзадачи
  String _enterKeyBehavior = 'new_subtask';
  bool _autoCompleteSubtasksWithParent = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultCategory = prefs.getString('task_default_category') ?? 'Личное';
      _taskEnableDrag = prefs.getBool('task_enable_drag') ?? true;

      _notificationSoundTitle = prefs.getString('task_notif_sound_title') ??
          'По умолчанию (системный)';
      _snoozeReminderEnabled =
          prefs.getBool('task_snooze_reminder_enabled') ?? true;
      _snoozeDurationMinutes =
          prefs.getInt('task_snooze_duration_minutes') ?? 15;

      _enterKeyBehavior =
          prefs.getString('task_enter_key_behavior') ?? 'new_subtask';
      _autoCompleteSubtasksWithParent =
          prefs.getBool('task_auto_complete_subtasks_with_parent') ?? true;
    });
  }

  Future<void> _setDefaultCategory(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('task_default_category', val);
    setState(() => _defaultCategory = val);
  }

  Future<void> _setTaskEnableDrag(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('task_enable_drag', val);
    setState(() => _taskEnableDrag = val);
  }

  Future<void> _setSnoozeReminderEnabled(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('task_snooze_reminder_enabled', val);
    setState(() => _snoozeReminderEnabled = val);
  }

  Future<void> _setSnoozeDuration(int val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('task_snooze_duration_minutes', val);
    setState(() => _snoozeDurationMinutes = val);
  }

  Future<void> _setEnterKeyBehavior(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('task_enter_key_behavior', val);
    setState(() => _enterKeyBehavior = val);
  }

  Future<void> _setAutoCompleteSubtasks(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('task_auto_complete_subtasks_with_parent', val);
    setState(() => _autoCompleteSubtasksWithParent = val);
  }

  Future<void> _pickNotificationSound(AppColorsExtension colors) async {
    final options = [
      'По умолчанию (системный)',
      'Сигнал задачи (Орбита)',
      'Короткий щелчок',
      'Электронный сигнал',
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
              groupValue: _notificationSoundTitle,
              activeColor: colors.accent,
              onChanged: (val) => Navigator.pop(ctx, val),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('task_notif_sound_title', selected);
      setState(() => _notificationSoundTitle = selected);
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final categories = ref.watch(taskCategoriesProvider);
    final cardBg = colors.card;
    final textPrimary = colors.text;
    final textSecondary = colors.text.withValues(alpha: 0.6);
    final borderColor = colors.nested;

    final effectiveCategory = categories.contains(_defaultCategory)
        ? _defaultCategory
        : (categories.isNotEmpty ? categories.first : 'Личное');

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(
          'Настройки задач',
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
          // 1. ВНЕШНИЙ ВИД
          _buildSectionHeader('ВНЕШНИЙ ВИД', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.folder_outlined,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Категория по умолчанию',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Назначается при создании новой задачи: $effectiveCategory',
                    style: TextStyle(
                        fontFamily: 'Onest',
                        color: textSecondary,
                        fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: effectiveCategory,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _setDefaultCategory(v);
                    },
                  ),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: Icon(
                    Icons.drag_indicator,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Перетаскивание задач',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Позволяет менять порядок задач вручную в списке',
                    style: TextStyle(
                        fontFamily: 'Onest',
                        color: textSecondary,
                        fontSize: 12),
                  ),
                  activeColor: colors.accent,
                  checkColor: colors.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  value: _taskEnableDrag,
                  onChanged: (v) => _setTaskEnableDrag(v ?? true),
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
                ListTile(
                  leading: Icon(
                    Icons.music_note_outlined,
                    color: colors.warning,
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
                    _notificationSoundTitle,
                    style: TextStyle(
                        fontFamily: 'Onest',
                        color: textSecondary,
                        fontSize: 12),
                  ),
                  trailing:
                      Icon(Icons.chevron_right, size: 20, color: textSecondary),
                  onTap: () => _pickNotificationSound(colors),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: Icon(Icons.snooze, color: colors.warning),
                  title: Text(
                    'Отложить напоминание о задаче',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Отображать действие «Отложить» в системном уведомлении',
                    style: TextStyle(
                        fontFamily: 'Onest',
                        color: textSecondary,
                        fontSize: 12),
                  ),
                  activeColor: colors.accent,
                  checkColor: colors.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  value: _snoozeReminderEnabled,
                  onChanged: (v) => _setSnoozeReminderEnabled(v ?? false),
                ),
                if (_snoozeReminderEnabled) ...[
                  Divider(height: 1, color: borderColor),
                  ListTile(
                    leading: const SizedBox(width: 24),
                    title: Text(
                      'Продолжительность откладывания',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    trailing: DropdownButton<int>(
                      value: _snoozeDurationMinutes,
                      underline: const SizedBox(),
                      dropdownColor: cardBg,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('5 минут')),
                        DropdownMenuItem(value: 10, child: Text('10 минут')),
                        DropdownMenuItem(value: 15, child: Text('15 минут')),
                        DropdownMenuItem(value: 30, child: Text('30 минут')),
                      ],
                      onChanged: (v) {
                        if (v != null) _setSnoozeDuration(v);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. ПОДЗАДАЧИ
          _buildSectionHeader('ПОДЗАДАЧИ', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.keyboard_return,
                    color: colors.success,
                  ),
                  title: Text(
                    'Клавиша Enter в подзадачах',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _enterKeyBehavior == 'new_subtask'
                        ? 'Создать новую подзадачу'
                        : 'Вставить перенос строки',
                    style: TextStyle(
                        fontFamily: 'Onest',
                        color: textSecondary,
                        fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: _enterKeyBehavior,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'new_subtask',
                        child: Text('Новая подзадача'),
                      ),
                      DropdownMenuItem(
                        value: 'newline',
                        child: Text('Перенос строки'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) _setEnterKeyBehavior(v);
                    },
                  ),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: Icon(
                    Icons.done_all,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Автоматическое завершение подзадач',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Выполнять все подзадачи вместе с основной задачей',
                    style: TextStyle(
                        fontFamily: 'Onest',
                        color: textSecondary,
                        fontSize: 12),
                  ),
                  activeColor: colors.accent,
                  checkColor: colors.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  value: _autoCompleteSubtasksWithParent,
                  onChanged: (v) => _setAutoCompleteSubtasks(v ?? true),
                ),
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
