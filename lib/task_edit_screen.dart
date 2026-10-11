import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'providers/tasks_provider.dart';

class TaskEditScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialTask;

  const TaskEditScreen({super.key, this.initialTask});

  @override
  ConsumerState<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends ConsumerState<TaskEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  String _selectedCategory = 'Личное';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isNoDate = false;
  bool _isAllDay = false;

  int _reminderMinutes = -1;
  String _recurrence = 'none';
  String _priority = 'normal';
  String _status = 'todo';
  Color _selectedColor = const Color(0xFF38BDF8);

  final List<Map<String, dynamic>> _subtasks = [];
  final List<String> _attachments = [];

  final List<Color> _availableColors = const [
    Color(0xFF38BDF8),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.initialTask;
    _titleController = TextEditingController(text: t?['title'] ?? '');
    _descController = TextEditingController(text: t?['description'] ?? '');

    if (t != null) {
      _selectedCategory = t['category'] ?? 'Личное';
      _selectedDate = t['date'] as DateTime?;
      if (t['time'] != null && (t['time'] as String).contains(':')) {
        final parts = (t['time'] as String).split(':');
        _selectedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 12,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
      _isNoDate = t['isNoDate'] ?? false;
      _isAllDay = t['isAllDay'] ?? false;
      _reminderMinutes = t['reminderMinutes'] ?? -1;
      _recurrence = t['recurrence'] ?? 'none';
      _priority = t['priority'] ?? 'normal';
      _status = t['status'] ?? 'todo';
      _selectedColor = t['color'] ?? const Color(0xFF38BDF8);

      if (t['subtasks'] != null) {
        for (final item in t['subtasks']) {
          _subtasks.add(Map<String, dynamic>.from(item));
        }
      }
      if (t['attachments'] != null) {
        _attachments.addAll(List<String>.from(t['attachments']));
      }
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _isNoDate = false;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _isAllDay = false;
      });
    }
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickMedia();
    if (pickedFile != null) {
      setState(() {
        if (!_attachments.contains(pickedFile.path)) {
          _attachments.add(pickedFile.path);
        }
      });
    }
  }

  void _addSubtask() {
    if (_subtasks.length >= 20) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Максимум 20 подзадач')));
      return;
    }
    setState(() {
      _subtasks.add({'title': '', 'done': false});
    });
  }

  void _showAddCategoryDialog() {
    final catController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая категория'),
        content: TextField(
          controller: catController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Название категории',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final val = catController.text.trim();
              if (val.isNotEmpty) {
                ref.read(taskCategoriesProvider.notifier).addCategory(val);
                setState(() => _selectedCategory = val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _saveTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Укажите заголовок задачи')));
      return;
    }

    final formattedTime = (_selectedTime != null && !_isAllDay)
        ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
        : null;

    final cleanedSubtasks = _subtasks
        .where((s) => (s['title'] as String).trim().isNotEmpty)
        .toList();

    ref
        .read(tasksProvider.notifier)
        .saveTask(
          id: widget.initialTask?['id'],
          title: title,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          date: _isNoDate ? null : _selectedDate,
          time: formattedTime,
          isNoDate: _isNoDate,
          isAllDay: _isAllDay,
          priority: _priority,
          status: _status,
          category: _selectedCategory,
          color: _selectedColor,
          reminderMinutes: _reminderMinutes,
          recurrence: _recurrence,
          attachments: _attachments,
          subtasks: cleanedSubtasks,
        );

    Navigator.pop(context);
  }

  void _deleteTask() {
    if (widget.initialTask != null) {
      ref.read(tasksProvider.notifier).deleteTask(widget.initialTask!['id']);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(taskCategoriesProvider);
    final isEdit = widget.initialTask != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? 'Редактирование задачи' : 'Создание задачи',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _saveTask,
            child: const Text(
              'Сохранить',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Выбор категории
          Row(
            children: [
              const Text(
                'Категория:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: categories.contains(_selectedCategory)
                        ? _selectedCategory
                        : null,
                    isExpanded: true,
                    hint: const Text('Выберите категорию'),
                    items: [
                      ...categories.map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                      ),
                      const DropdownMenuItem(
                        value: '__add_new__',
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 18, color: Color(0xFF38BDF8)),
                            SizedBox(width: 6),
                            Text(
                              'Создать новую...',
                              style: TextStyle(color: Color(0xFF38BDF8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == '__add_new__') {
                        _showAddCategoryDialog();
                      } else if (val != null) {
                        setState(() => _selectedCategory = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Выбор цвета полоски
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _availableColors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final c = _availableColors[i];
                final isSelected = c.toARGB32() == _selectedColor.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 3. Заголовок
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'Заголовок / Название *',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          // 4. Подзадачи (до 20)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Подзадачи (${_subtasks.length}/20)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _subtasks.length < 20 ? _addSubtask : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Добавить'),
              ),
            ],
          ),
          if (_subtasks.isNotEmpty) ...[
            ...List.generate(_subtasks.length, (idx) {
              final sub = _subtasks[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Checkbox(
                      value: sub['done'] as bool? ?? false,
                      onChanged: (val) {
                        setState(() => sub['done'] = val ?? false);
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: sub['title'] as String? ?? '',
                        decoration: InputDecoration(
                          hintText: 'Подзадача ${idx + 1}',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (val) => sub['title'] = val,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _subtasks.removeAt(idx)),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 12),

          // 5. Дата и "Без срока"
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, size: 20),
            title: Text(
              _isNoDate
                  ? 'Без срока'
                  : (_selectedDate != null
                        ? DateFormat('d MMMM yyyy', 'ru').format(_selectedDate!)
                        : 'Выберите дату'),
            ),
            trailing: FilledButton.tonal(
              onPressed: _pickDate,
              child: const Text('Изменить'),
            ),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Без срока'),
            value: _isNoDate,
            onChanged: (val) => setState(() => _isNoDate = val),
          ),

          // 6. Время и "Весь день"
          if (!_isNoDate) ...[
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time, size: 20),
              title: Text(
                _isAllDay
                    ? 'Весь день'
                    : (_selectedTime != null
                          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                          : 'Указать время'),
              ),
              trailing: FilledButton.tonal(
                onPressed: _isAllDay ? null : _pickTime,
                child: const Text('Выбрать'),
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Весь день'),
              value: _isAllDay,
              onChanged: (val) => setState(() => _isAllDay = val),
            ),
          ],
          const Divider(height: 24),

          // 7. Напоминание
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_none, size: 20),
            title: const Text('Напоминание'),
            trailing: DropdownButton<int>(
              value: _reminderMinutes,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: -1, child: Text('Без напоминания')),
                DropdownMenuItem(value: 0, child: Text('В момент начала')),
                DropdownMenuItem(value: 5, child: Text('За 5 минут')),
                DropdownMenuItem(value: 10, child: Text('За 10 минут')),
                DropdownMenuItem(value: 15, child: Text('За 15 минут')),
                DropdownMenuItem(value: 30, child: Text('За 30 минут')),
                DropdownMenuItem(value: 60, child: Text('За 1 час')),
                DropdownMenuItem(value: 1440, child: Text('За 1 день')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _reminderMinutes = val);
              },
            ),
          ),

          // 8. Повтор
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.repeat, size: 20),
            title: const Text('Повтор'),
            trailing: DropdownButton<String>(
              value: _recurrence,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Не повторять')),
                DropdownMenuItem(value: 'hourly', child: Text('Каждый час')),
                DropdownMenuItem(value: 'daily', child: Text('Ежедневно')),
                DropdownMenuItem(
                  value: 'weekdays',
                  child: Text('Только по будням (пн-пт)'),
                ),
                DropdownMenuItem(value: 'weekly', child: Text('Еженедельно')),
                DropdownMenuItem(
                  value: 'biweekly',
                  child: Text('Раз в 2 недели'),
                ),
                DropdownMenuItem(value: 'monthly', child: Text('Ежемесячно')),
                DropdownMenuItem(value: 'yearly', child: Text('Ежегодно')),
                DropdownMenuItem(
                  value: 'custom',
                  child: Text('Пользовательский'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _recurrence = val);
              },
            ),
          ),

          // 9. Приоритет
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined, size: 20),
            title: const Text('Приоритет'),
            trailing: DropdownButton<String>(
              value: _priority,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Низкий')),
                DropdownMenuItem(value: 'normal', child: Text('Обычный')),
                DropdownMenuItem(value: 'high', child: Text('Высокий')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _priority = val);
              },
            ),
          ),

          // 10. Статус
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fact_check_outlined, size: 20),
            title: const Text('Статус'),
            trailing: DropdownButton<String>(
              value: _status,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'todo', child: Text('К выполнению')),
                DropdownMenuItem(value: 'in_progress', child: Text('В работе')),
                DropdownMenuItem(value: 'done', child: Text('Выполнено')),
                DropdownMenuItem(value: 'canceled', child: Text('Отменено')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _status = val);
              },
            ),
          ),
          const Divider(height: 24),

          // 11. Описание / Заметка
          TextField(
            controller: _descController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Заметка / Описание',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // 12. Вложения
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Вложения',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('Прикрепить файл'),
              ),
            ],
          ),
          if (_attachments.isNotEmpty) ...[
            ..._attachments.map((filePath) {
              final fileName = filePath.split(Platform.pathSeparator).last;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file,
                      size: 20,
                      color: Color(0xFF38BDF8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey,
                      ),
                      onPressed: () =>
                          setState(() => _attachments.remove(filePath)),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 32),

          // 13. Кнопка "Удалить задачу" (если редактируем существующую)
          if (isEdit)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                onPressed: _deleteTask,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Удалить задачу'),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
