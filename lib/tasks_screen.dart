import 'package:flutter/material.dart';

class TasksScreen extends StatefulWidget {
  final bool isDarkMode;
  final List<Map<String, dynamic>> tasks;
  final bool isLoadingTasks;
  final List<Map<String, dynamic>> taskTemplates;
  final Function(Map<String, dynamic>, bool) onToggleTask;
  final Function(Map<String, dynamic>) onDeleteTask;
  final Function({
    Map<String, dynamic>? existingTask,
    required String title,
    required String desc,
    required DateTime date,
    required bool isAllDay,
    required String time,
    required String location,
    required String reminder,
    required String repeat,
    required int priority,
    required List<Map<String, dynamic>> subtasks,
  })
  onSaveTask;
  final Function(Map<String, dynamic>) onSaveTemplate;

  const TasksScreen({
    super.key,
    required this.isDarkMode,
    required this.tasks,
    required this.isLoadingTasks,
    required this.taskTemplates,
    required this.onToggleTask,
    required this.onDeleteTask,
    required this.onSaveTask,
    required this.onSaveTemplate,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _taskFilter = 'all';
  bool _showCompletedTasks = true;
  String _taskSearchQuery = '';
  final TextEditingController _taskSearchController = TextEditingController();

  Widget _buildPriorityBadge(int priority) {
    switch (priority) {
      case -2:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.blueGrey),
            Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.blueGrey),
          ],
        );
      case -1:
        return const Icon(
          Icons.keyboard_arrow_down,
          size: 16,
          color: Colors.blueGrey,
        );
      case 1:
        return const Icon(
          Icons.keyboard_arrow_up,
          size: 16,
          color: Colors.amber,
        );
      case 2:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.keyboard_arrow_up, size: 14, color: Colors.redAccent),
            Icon(Icons.keyboard_arrow_up, size: 14, color: Colors.redAccent),
          ],
        );
      default:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey, width: 1.2),
            borderRadius: BorderRadius.circular(3),
          ),
        );
    }
  }

  void _showTaskEditDialog({Map<String, dynamic>? existingTask}) {
    final titleController = TextEditingController(
      text: existingTask?['title'] ?? '',
    );
    final descController = TextEditingController(
      text: existingTask?['desc'] ?? '',
    );
    DateTime selectedDate = existingTask?['date'] ?? DateTime.now();
    bool isAllDay = existingTask?['isAllDay'] ?? true;
    TimeOfDay selectedTime = const TimeOfDay(hour: 12, minute: 0);
    int priority = existingTask?['priority'] ?? 0;
    String repeat = existingTask?['repeat'] ?? 'Однократно';

    List<Map<String, dynamic>> subtasks = [];
    if (existingTask?['subtasks'] != null) {
      subtasks = List<Map<String, dynamic>>.from(
        existingTask!['subtasks'].map((x) => Map<String, dynamic>.from(x)),
      );
    }
    final newSubtaskController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            existingTask == null ? 'Новая задача' : 'Редактировать задачу',
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
              maxWidth: double.maxFinite,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Название*',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Подзадачи:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  ...subtasks.asMap().entries.map((entry) {
                    final i = entry.key;
                    final st = entry.value;
                    return Row(
                      children: [
                        Checkbox(
                          value: st['done'] ?? false,
                          onChanged: (v) => setDlgState(() => st['done'] = v),
                        ),
                        Expanded(
                          child: Text(
                            st['title'] ?? '',
                            style: TextStyle(
                              decoration: st['done'] == true
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          onPressed: () =>
                              setDlgState(() => subtasks.removeAt(i)),
                        ),
                      ],
                    );
                  }),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newSubtaskController,
                          decoration: const InputDecoration(
                            hintText: 'Добавить подзадачу...',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Color(0xFF2C69D1),
                        ),
                        onPressed: () {
                          if (newSubtaskController.text.trim().isNotEmpty) {
                            setDlgState(() {
                              subtasks.add({
                                'title': newSubtaskController.text.trim(),
                                'done': false,
                              });
                              newSubtaskController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Срок:'),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(
                          '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            locale: const Locale('ru', 'RU'),
                            initialDate: selectedDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setDlgState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Целый день'),
                    value: isAllDay,
                    onChanged: (v) => setDlgState(() => isAllDay = v ?? true),
                  ),
                  if (!isAllDay)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Время:'),
                        TextButton(
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (t != null) setDlgState(() => selectedTime = t);
                          },
                          child: Text(selectedTime.format(context)),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  const Text('Важность:'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ChoiceChip(
                        label: const Text('↓↓'),
                        selected: priority == -2,
                        onSelected: (_) => setDlgState(() => priority = -2),
                      ),
                      ChoiceChip(
                        label: const Text('↓'),
                        selected: priority == -1,
                        onSelected: (_) => setDlgState(() => priority = -1),
                      ),
                      ChoiceChip(
                        label: const Text('□'),
                        selected: priority == 0,
                        onSelected: (_) => setDlgState(() => priority = 0),
                      ),
                      ChoiceChip(
                        label: const Text('↑'),
                        selected: priority == 1,
                        onSelected: (_) => setDlgState(() => priority = 1),
                      ),
                      ChoiceChip(
                        label: const Text('↑↑'),
                        selected: priority == 2,
                        onSelected: (_) => setDlgState(() => priority = 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: repeat,
                    decoration: const InputDecoration(
                      labelText: 'Повторение',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        const [
                              'Однократно',
                              'Каждый день',
                              'Каждые 3 дня',
                              'Каждую неделю',
                              'Каждый месяц',
                            ]
                            .map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)),
                            )
                            .toList(),
                    onChanged: (v) =>
                        setDlgState(() => repeat = v ?? 'Однократно'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Описание',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      if (titleController.text.trim().isNotEmpty) {
                        widget.onSaveTemplate({
                          'title': titleController.text.trim(),
                          'desc': descController.text.trim(),
                          'priority': priority,
                          'repeat': repeat,
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Сохранено в шаблоны!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Сохранить задачу как шаблон'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (existingTask != null)
              TextButton(
                onPressed: () {
                  widget.onDeleteTask(existingTask);
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Удалить',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  widget.onSaveTask(
                    existingTask: existingTask,
                    title: titleController.text.trim(),
                    desc: descController.text.trim(),
                    date: selectedDate,
                    isAllDay: isAllDay,
                    time: selectedTime.format(context),
                    location: '',
                    reminder: 'В момент начала',
                    repeat: repeat,
                    priority: priority,
                    subtasks: subtasks,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  void _openTaskTemplatesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Шаблоны задач'),
        content: SizedBox(
          width: double.maxFinite,
          child: widget.taskTemplates.isEmpty
              ? const Text('У вас пока нет шаблонов.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.taskTemplates.length,
                  itemBuilder: (c, i) {
                    final t = widget.taskTemplates[i];
                    return ListTile(
                      title: Text(t['title'] ?? ''),
                      subtitle: Text(t['desc'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.add, color: Color(0xFF2C69D1)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onSaveTask(
                            title: t['title'] ?? '',
                            desc: t['desc'] ?? '',
                            date: DateTime.now(),
                            isAllDay: true,
                            time: '12:00',
                            location: '',
                            reminder: 'В момент начала',
                            repeat: t['repeat'] ?? 'Однократно',
                            priority: t['priority'] ?? 0,
                            subtasks: [],
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(Map<String, dynamic> task, bool isDark) {
    final Color textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final Color textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final List<Map<String, dynamic>> subtasks =
        (task['subtasks'] as List<dynamic>?)
            ?.map((st) => Map<String, dynamic>.from(st))
            .toList() ??
        [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () => _showTaskEditDialog(existingTask: task),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Checkbox(
              value: task['done'] ?? false,
              onChanged: (val) => widget.onToggleTask(task, val ?? false),
            ),
            const SizedBox(width: 6),
            _buildPriorityBadge(task['priority'] as int? ?? 0),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: task['done'] ? textSecondary : textPrimary,
                      decoration: task['done']
                          ? TextDecoration.lineThrough
                          : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtasks.isNotEmpty)
                    Text(
                      'Подзадач: ${subtasks.where((s) => s['done'] == true).length}/${subtasks.length}',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<Map<String, dynamic>> displayedTasks = List.from(widget.tasks);

    if (_taskSearchQuery.trim().isNotEmpty) {
      final q = _taskSearchQuery.toLowerCase();
      displayedTasks = displayedTasks
          .where(
            (t) =>
                (t['title'] as String).toLowerCase().contains(q) ||
                (t['desc'] as String).toLowerCase().contains(q),
          )
          .toList();
    }
    if (!_showCompletedTasks) {
      displayedTasks = displayedTasks.where((t) => t['done'] != true).toList();
    }
    if (_taskFilter == 'overdue') {
      displayedTasks = displayedTasks
          .where((t) => (t['date'] as DateTime).isBefore(today) && !t['done'])
          .toList();
    } else if (_taskFilter == 'today') {
      displayedTasks = displayedTasks.where((t) {
        final d = t['date'] as DateTime;
        return d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      }).toList();
    } else if (_taskFilter == 'priority') {
      displayedTasks.sort(
        (a, b) => (b['priority'] as int).compareTo(a['priority'] as int),
      );
    }

    final Color textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final Color textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskEditDialog(),
        backgroundColor: const Color(0xFF2C69D1),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF30363D)
                    : const Color(0xFFD0D7DE),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _taskSearchController,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Поиск по задачам...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _taskSearchQuery = val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PopupMenuButton<String>(
                onSelected: (val) => setState(() => _taskFilter = val),
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'all', child: Text('Все задачи')),
                  PopupMenuItem(value: 'overdue', child: Text('Просроченные')),
                  PopupMenuItem(value: 'today', child: Text('На сегодня')),
                  PopupMenuItem(value: 'priority', child: Text('По важности')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF30363D)
                          : const Color(0xFFD0D7DE),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_list,
                        size: 16,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _taskFilter == 'overdue'
                            ? 'Просроченные'
                            : (_taskFilter == 'today'
                                  ? 'На сегодня'
                                  : (_taskFilter == 'priority'
                                        ? 'По важности'
                                        : 'Все задачи')),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () =>
                    setState(() => _showCompletedTasks = !_showCompletedTasks),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _showCompletedTasks
                        ? const Color(0xFF2C69D1).withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF161B22) : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _showCompletedTasks
                          ? const Color(0xFF2C69D1)
                          : (isDark
                                ? const Color(0xFF30363D)
                                : const Color(0xFFD0D7DE)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _showCompletedTasks
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        size: 14,
                        color: _showCompletedTasks
                            ? const Color(0xFF38BDF8)
                            : textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showCompletedTasks
                            ? 'Выполненные: Вкл'
                            : 'Выполненные: Выкл',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _showCompletedTasks
                              ? const Color(0xFF38BDF8)
                              : textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _openTaskTemplatesDialog,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF2C69D1),
                  ),
                ),
                icon: const Icon(Icons.bookmark_border, size: 14),
                label: const Text('Шаблоны', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF30363D)
                    : const Color(0xFFD0D7DE),
              ),
            ),
            child: widget.isLoadingTasks
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    children: displayedTasks.isEmpty
                        ? [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Задач не найдено.',
                                style: TextStyle(color: textSecondary),
                              ),
                            ),
                          ]
                        : displayedTasks
                              .map((t) => _buildTaskRow(t, isDark))
                              .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
