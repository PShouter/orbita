import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tasks_provider.dart';

class TasksScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  final List<Map<String, dynamic>> taskTemplates;
  final Function(Map<String, dynamic>) onSaveTemplate;

  const TasksScreen({
    super.key,
    required this.isDarkMode,
    required this.taskTemplates,
    required this.onSaveTemplate,
  });

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _selectedFilter =
      'Все'; // 'Все', 'Сегодня', 'Предстоящие', 'Без срока', 'Выполненные'
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final tasksNotifier = ref.read(tasksProvider.notifier);

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

    final today = DateTime.now();

    // Фильтрация задач
    final filteredTasks = tasks.where((t) {
      final titleMatch = (t['title'] ?? '').toString().toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      if (!titleMatch) return false;

      final isDone = t['done'] == true;
      final isNoDate = t['isNoDate'] == true || t['date'] == null;
      final d = t['date'] as DateTime?;

      switch (_selectedFilter) {
        case 'Сегодня':
          if (isDone) return false;
          return d != null &&
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        case 'Предстоящие':
          if (isDone || isNoDate || d == null) return false;
          final cleanD = DateTime(d.year, d.month, d.day);
          final cleanToday = DateTime(today.year, today.month, today.day);
          return cleanD.isAfter(cleanToday);
        case 'Без срока':
          if (isDone) return false;
          return isNoDate;
        case 'Выполненные':
          return isDone;
        default:
          return !isDone; // 'Все' показывает невыполненные
      }
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF38BDF8),
        elevation: 4,
        onPressed: () => _openTaskEditor(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Заголовок и поиск
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Задачи',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // Быстрый счетчик открытых задач
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tasks.where((t) => t['done'] != true).length} в работе',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Поисковая строка
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  style: TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Поиск задач...',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 12),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.grey,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Горизонтальный переключатель категорий
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children:
                    [
                      'Все',
                      'Сегодня',
                      'Предстоящие',
                      'Без срока',
                      'Выполненные',
                    ].map((filter) {
                      final isSel = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: isSel,
                          label: Text(filter),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSel ? Colors.white : textSecondary,
                          ),
                          selectedColor: const Color(0xFF2C69D1),
                          backgroundColor: cardBg,
                          side: BorderSide(
                            color: isSel
                                ? const Color(0xFF2C69D1)
                                : borderColor,
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedFilter = filter),
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Список задач
            Expanded(
              child: filteredTasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: Colors.grey.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selectedFilter == 'Выполненные'
                                ? 'Нет завершенных задач'
                                : 'Список пуст',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Нажмите «+», чтобы создать задачу',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: filteredTasks.length,
                      itemBuilder: (ctx, i) {
                        final task = filteredTasks[i];
                        final isDone = task['done'] == true;
                        final isNoDate =
                            task['isNoDate'] == true || task['date'] == null;
                        final time = task['time'];
                        final d = task['date'] as DateTime?;

                        Color priorityColor = Colors.transparent;
                        if (task['priority'] == 'high') {
                          priorityColor = Colors.redAccent;
                        }
                        if (task['priority'] == 'medium') {
                          priorityColor = Colors.orangeAccent;
                        }
                        if (task['priority'] == 'low') {
                          priorityColor = Colors.blueAccent;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDone
                                  ? borderColor.withValues(alpha: 0.5)
                                  : borderColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Индикатор приоритета
                              if (priorityColor != Colors.transparent)
                                Container(
                                  width: 3.5,
                                  height: 28,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: priorityColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),

                              // Чекбокс
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: isDone,
                                  onChanged: (v) {
                                    tasksNotifier.toggleTask(
                                      task['id'].toString(),
                                      v ?? false,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Название и дата/время
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task['title'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDone
                                            ? textSecondary
                                            : textPrimary,
                                        decoration: isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (!isNoDate && d != null) ...[
                                          Text(
                                            '${d.day}.${d.month}.${d.year}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: textSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        if (task['isAllDay'] != true &&
                                            time != null) ...[
                                          Text(
                                            '⏱ $time',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF38BDF8),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Действия: редактировать и удалить
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                onPressed: () =>
                                    _openTaskEditor(existingTask: task),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  tasksNotifier.deleteTask(
                                    task['id'].toString(),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Диалог создания и редактирования задачи
  void _openTaskEditor({Map<String, dynamic>? existingTask}) {
    final titleCtrl = TextEditingController(text: existingTask?['title'] ?? '');
    final descCtrl = TextEditingController(
      text: existingTask?['description'] ?? existingTask?['desc'] ?? '',
    );

    bool isNoDate = existingTask?['isNoDate'] ?? false;
    bool isAllDay = existingTask?['isAllDay'] ?? false;
    DateTime? taskDate = existingTask?['date'] as DateTime? ?? DateTime.now();

    TimeOfDay taskTime = const TimeOfDay(hour: 12, minute: 0);
    if (existingTask?['time'] != null) {
      final parts = existingTask!['time'].toString().split(':');
      if (parts.length == 2) {
        taskTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 12,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    String priority = existingTask?['priority'] ?? 'none';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existingTask == null
                      ? 'Новая задача'
                      : 'Редактировать задачу',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Что нужно сделать?',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Описание / Заметка (необязательно)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),

                // Дата и Срок
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Без конкретного срока',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: isNoDate,
                  onChanged: (v) => setDState(() => isNoDate = v),
                ),

                if (!isNoDate) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Дата выполнения',
                      style: TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      taskDate != null
                          ? '${taskDate!.day}.${taskDate!.month}.${taskDate!.year}'
                          : 'Не выбрана',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: taskDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (p != null) setDState(() => taskDate = p);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Весь день',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: isAllDay,
                    onChanged: (v) => setDState(() => isAllDay = v),
                  ),
                  if (!isAllDay)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Время',
                        style: TextStyle(fontSize: 13),
                      ),
                      trailing: Text(
                        taskTime.format(context),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: taskTime,
                        );
                        if (t != null) setDState(() => taskTime = t);
                      },
                    ),
                ],
                const Divider(),

                // Приоритет
                const Text(
                  'Приоритет:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _priorityChip(
                      'none',
                      'Обычный',
                      Colors.grey,
                      priority,
                      (p) => setDState(() => priority = p),
                    ),
                    const SizedBox(width: 8),
                    _priorityChip(
                      'low',
                      'Низкий',
                      Colors.blueAccent,
                      priority,
                      (p) => setDState(() => priority = p),
                    ),
                    const SizedBox(width: 8),
                    _priorityChip(
                      'medium',
                      'Средний',
                      Colors.orangeAccent,
                      priority,
                      (p) => setDState(() => priority = p),
                    ),
                    const SizedBox(width: 8),
                    _priorityChip(
                      'high',
                      'Высокий',
                      Colors.redAccent,
                      priority,
                      (p) => setDState(() => priority = p),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                      ),
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) return;

                        final timeStr = isAllDay
                            ? null
                            : '${taskTime.hour.toString().padLeft(2, '0')}:${taskTime.minute.toString().padLeft(2, '0')}';

                        ref
                            .read(tasksProvider.notifier)
                            .saveTask(
                              existingTask: existingTask,
                              title: title,
                              desc: descCtrl.text.trim(),
                              date: isNoDate ? null : taskDate,
                              isNoDate: isNoDate,
                              isAllDay: isAllDay,
                              time: timeStr,
                              priority: priority,
                              subtasks: existingTask?['subtasks'] ?? [],
                              tags: existingTask?['tags'] ?? [],
                            );

                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Сохранить',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _priorityChip(
    String val,
    String label,
    Color color,
    String current,
    Function(String) onSelect,
  ) {
    final isSel = current == val;
    return GestureDetector(
      onTap: () => onSelect(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSel ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSel ? color : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
            color: isSel ? color : Colors.grey,
          ),
        ),
      ),
    );
  }
}
