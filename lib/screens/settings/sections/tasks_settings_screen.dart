import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/tasks_provider.dart';

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
  String _enterKeyBehavior = 'new_subtask'; // 'new_subtask' | 'newline'
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

      _notificationSoundTitle =
          prefs.getString('task_notif_sound_title') ??
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

  Future<void> _pickNotificationSound() async {
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
              groupValue: _notificationSoundTitle,
              activeColor: const Color(0xFF38BDF8),
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
    final categories = ref.watch(taskCategoriesProvider);
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

    final effectiveCategory = categories.contains(_defaultCategory)
        ? _defaultCategory
        : (categories.isNotEmpty ? categories.first : 'Личное');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Настройки задач'),
        backgroundColor: cardBg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. ВНЕШНИЙ ВИД
          _buildSectionHeader('ВНЕШНИЙ ВИД', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.folder_outlined,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Категория по умолчанию',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Назначается при создании новой задачи: $effectiveCategory',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: effectiveCategory,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
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
                    'Позволяет менять порядок задач вручную в списке',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF38BDF8),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
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
                    _notificationSoundTitle,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _pickNotificationSound,
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: const Icon(Icons.snooze, color: Colors.amber),
                  title: Text(
                    'Отложить напоминание о задаче',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Отображать действие «Отложить» в системном уведомлении',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF38BDF8),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.keyboard_return,
                    color: Color(0xFF10B981),
                  ),
                  title: Text(
                    'Клавиша Enter в подзадачах',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _enterKeyBehavior == 'new_subtask'
                        ? 'Создать новую подзадачу'
                        : 'Вставить перенос строки',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: _enterKeyBehavior,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
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
                  secondary: const Icon(
                    Icons.done_all,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Автоматическое завершение подзадач',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Выполнять все подзадачи вместе с основной задачей',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF38BDF8),
                  value: _autoCompleteSubtasksWithParent,
                  onChanged: (v) => _setAutoCompleteSubtasks(v ?? true),
                ),
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
