import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'providers/tasks_provider.dart';
import 'task_edit_screen.dart';

class TasksScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const TasksScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Фильтры
  bool _filterAll = true;
  String? _filterDueDate; // 'overdue', 'today', 'upcoming'
  String? _filterPriority; // 'low', 'normal', 'high'
  String? _filterStatus; // 'done', 'todo', 'in_progress', 'canceled'
  String? _filterCategory; // выбранная категория

  // Режим множественного выбора
  bool _isSelectionMode = false;
  final Set<String> _selectedTaskIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _filterAll = true;
      _filterDueDate = null;
      _filterPriority = null;
      _filterStatus = null;
      _filterCategory = null;
    });
  }

  void _enterSelectionMode(String initialTaskId) {
    setState(() {
      _isSelectionMode = true;
      _selectedTaskIds.add(initialTaskId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedTaskIds.clear();
    });
  }

  void _toggleTaskSelection(String taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
        if (_selectedTaskIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  // --- Массовые операции ---
  void _deleteSelectedTasks() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление задач'),
        content: Text('Удалить выбранные задачи (${_selectedTaskIds.length})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref
                  .read(tasksProvider.notifier)
                  .deleteMultipleTasks(_selectedTaskIds);
              Navigator.pop(ctx);
              _exitSelectionMode();
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _changeStatusForSelected() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Отметить как...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.radio_button_unchecked,
                color: Colors.blue,
              ),
              title: const Text('К выполнению'),
              onTap: () {
                ref
                    .read(tasksProvider.notifier)
                    .updateStatusForMultiple(_selectedTaskIds, 'todo');
                Navigator.pop(ctx);
                _exitSelectionMode();
              },
            ),
            ListTile(
              leading: const Icon(Icons.timelapse, color: Colors.orange),
              title: const Text('В работе'),
              onTap: () {
                ref
                    .read(tasksProvider.notifier)
                    .updateStatusForMultiple(_selectedTaskIds, 'in_progress');
                Navigator.pop(ctx);
                _exitSelectionMode();
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Выполнено'),
              onTap: () {
                ref
                    .read(tasksProvider.notifier)
                    .updateStatusForMultiple(_selectedTaskIds, 'done');
                Navigator.pop(ctx);
                _exitSelectionMode();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.grey),
              title: const Text('Отменено'),
              onTap: () {
                ref
                    .read(tasksProvider.notifier)
                    .updateStatusForMultiple(_selectedTaskIds, 'canceled');
                Navigator.pop(ctx);
                _exitSelectionMode();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _moveCategoryForSelected() {
    final categories = ref.read(taskCategoriesProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Перенести в категорию',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Expanded(
              child: ListView(
                children: categories.map((cat) {
                  return ListTile(
                    leading: const Icon(
                      Icons.folder_outlined,
                      color: Color(0xFF38BDF8),
                    ),
                    title: Text(cat),
                    onTap: () {
                      ref
                          .read(tasksProvider.notifier)
                          .moveCategoryForMultiple(_selectedTaskIds, cat);
                      Navigator.pop(ctx);
                      _exitSelectionMode();
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(tasksProvider);
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

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final todayTasksCount = allTasks.where((t) {
      final d = t['date'] as DateTime?;
      if (d == null) return false;
      return !d.isBefore(todayStart) && !d.isAfter(todayEnd);
    }).length;

    final totalTasksCount = allTasks.length;

    // Фильтрация
    final filteredTasks = allTasks.where((t) {
      // 1. Полнотекстовый поиск (заголовок, описание, подзадачи)
      if (_searchQuery.isNotEmpty) {
        final title = (t['title'] as String).toLowerCase();
        final desc = ((t['description'] as String?) ?? '').toLowerCase();
        final subtasks = (t['subtasks'] as List<Map<String, dynamic>>? ?? []);
        final matchSubtasks = subtasks.any(
          (s) => (s['title'] as String? ?? '').toLowerCase().contains(
            _searchQuery,
          ),
        );

        if (!title.contains(_searchQuery) &&
            !desc.contains(_searchQuery) &&
            !matchSubtasks) {
          return false;
        }
      }

      if (_filterAll) return true;

      // 2. Срок
      if (_filterDueDate != null) {
        final d = t['date'] as DateTime?;
        final isNoDate = t['isNoDate'] as bool? ?? false;
        if (isNoDate || d == null) return false;

        if (_filterDueDate == 'overdue' && !d.isBefore(todayStart))
          return false;
        if (_filterDueDate == 'today' &&
            (d.isBefore(todayStart) || d.isAfter(todayEnd)))
          return false;
        if (_filterDueDate == 'upcoming' && !d.isAfter(todayEnd)) return false;
      }

      // 3. Приоритет
      if (_filterPriority != null && t['priority'] != _filterPriority) {
        return false;
      }

      // 4. Статус
      if (_filterStatus != null && t['status'] != _filterStatus) {
        return false;
      }

      // 5. Категория
      if (_filterCategory != null && t['category'] != _filterCategory) {
        return false;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Верхняя полоса (обычный вид или панель массовых операций)
            if (_isSelectionMode)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _exitSelectionMode,
                    ),
                    Text(
                      'Выбрано: ${_selectedTaskIds.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Действия',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (val) {
                        if (val == 'status') _changeStatusForSelected();
                        if (val == 'category') _moveCategoryForSelected();
                        if (val == 'delete') _deleteSelectedTasks();
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'status',
                          child: Text('Отметить как...'),
                        ),
                        const PopupMenuItem(
                          value: 'category',
                          child: Text('Перенести в др. категорию...'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Удалить выбранные',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Задачи',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Задачи на сегодня: $todayTasksCount',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Всего задач: $totalTasksCount',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Поисковая строка
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Поиск по заголовку, заметке, подзадачам...',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: Colors.grey,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim().toLowerCase());
                  },
                ),
              ),
            ),

            // Горизонтальная полоса фильтров
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                children: [
                  // 1. Все
                  FilterChip(
                    label: const Text('Все', style: TextStyle(fontSize: 12)),
                    selected: _filterAll,
                    onSelected: (val) {
                      if (val) _clearFilters();
                    },
                  ),
                  const SizedBox(width: 8),

                  // 2. Срок
                  PopupMenuButton<String>(
                    tooltip: 'Срок',
                    child: Chip(
                      label: Text(
                        _filterDueDate == 'overdue'
                            ? 'Просроченные'
                            : _filterDueDate == 'today'
                            ? 'Сегодня'
                            : _filterDueDate == 'upcoming'
                            ? 'Предстоящие'
                            : 'Срок',
                        style: TextStyle(
                          fontSize: 12,
                          color: _filterDueDate != null
                              ? const Color(0xFF38BDF8)
                              : textPrimary,
                        ),
                      ),
                      backgroundColor: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _filterDueDate != null
                              ? const Color(0xFF38BDF8)
                              : borderColor,
                        ),
                      ),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _filterDueDate = val == 'clear' ? null : val;
                        _filterAll = false;
                      });
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'overdue',
                        child: Text('Просроченные'),
                      ),
                      const PopupMenuItem(
                        value: 'today',
                        child: Text('Сегодня'),
                      ),
                      const PopupMenuItem(
                        value: 'upcoming',
                        child: Text('Предстоящие'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Text('Сбросить'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // 3. Приоритет
                  PopupMenuButton<String>(
                    tooltip: 'Приоритет',
                    child: Chip(
                      label: Text(
                        _filterPriority == 'low'
                            ? 'Низкий'
                            : _filterPriority == 'normal'
                            ? 'Обычный'
                            : _filterPriority == 'high'
                            ? 'Высокий'
                            : 'Приоритет',
                        style: TextStyle(
                          fontSize: 12,
                          color: _filterPriority != null
                              ? const Color(0xFF38BDF8)
                              : textPrimary,
                        ),
                      ),
                      backgroundColor: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _filterPriority != null
                              ? const Color(0xFF38BDF8)
                              : borderColor,
                        ),
                      ),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _filterPriority = val == 'clear' ? null : val;
                        _filterAll = false;
                      });
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'low', child: Text('Низкий')),
                      const PopupMenuItem(
                        value: 'normal',
                        child: Text('Обычный'),
                      ),
                      const PopupMenuItem(
                        value: 'high',
                        child: Text('Высокий'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Text('Сбросить'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // 4. Статус
                  PopupMenuButton<String>(
                    tooltip: 'Статус',
                    child: Chip(
                      label: Text(
                        _filterStatus == 'done'
                            ? 'Выполнено'
                            : _filterStatus == 'todo'
                            ? 'К выполнению'
                            : _filterStatus == 'in_progress'
                            ? 'В работе'
                            : _filterStatus == 'canceled'
                            ? 'Отменено'
                            : 'Статус',
                        style: TextStyle(
                          fontSize: 12,
                          color: _filterStatus != null
                              ? const Color(0xFF38BDF8)
                              : textPrimary,
                        ),
                      ),
                      backgroundColor: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _filterStatus != null
                              ? const Color(0xFF38BDF8)
                              : borderColor,
                        ),
                      ),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _filterStatus = val == 'clear' ? null : val;
                        _filterAll = false;
                      });
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'done',
                        child: Text('Выполнено'),
                      ),
                      const PopupMenuItem(
                        value: 'todo',
                        child: Text('К выполнению'),
                      ),
                      const PopupMenuItem(
                        value: 'in_progress',
                        child: Text('В работе'),
                      ),
                      const PopupMenuItem(
                        value: 'canceled',
                        child: Text('Отменено'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Text('Сбросить'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // 5. Категория
                  PopupMenuButton<String>(
                    tooltip: 'Категория',
                    child: Chip(
                      label: Text(
                        _filterCategory ?? 'Категория',
                        style: TextStyle(
                          fontSize: 12,
                          color: _filterCategory != null
                              ? const Color(0xFF38BDF8)
                              : textPrimary,
                        ),
                      ),
                      backgroundColor: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _filterCategory != null
                              ? const Color(0xFF38BDF8)
                              : borderColor,
                        ),
                      ),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _filterCategory = val == '__clear__' ? null : val;
                        _filterAll = false;
                      });
                    },
                    itemBuilder: (ctx) => [
                      ...categories.map(
                        (cat) => PopupMenuItem(value: cat, child: Text(cat)),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: '__clear__',
                        child: Text('Сбросить'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Список заметок/задач
            Expanded(
              child: filteredTasks.isEmpty
                  ? Center(
                      child: Text(
                        'Нет задач',
                        style: TextStyle(color: textSecondary, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemCount: filteredTasks.length,
                      itemBuilder: (ctx, idx) {
                        final task = filteredTasks[idx];
                        final taskId = task['id'] as String;
                        final isSelected = _selectedTaskIds.contains(taskId);
                        final taskColor =
                            task['color'] as Color? ?? const Color(0xFF38BDF8);
                        final isDone = task['done'] as bool? ?? false;
                        final status = task['status'] as String? ?? 'todo';
                        final subtasks =
                            task['subtasks'] as List<Map<String, dynamic>>? ??
                            [];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                _enterSelectionMode(taskId);
                              } else {
                                _toggleTaskSelection(taskId);
                              }
                            },
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleTaskSelection(taskId);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TaskEditScreen(initialTask: task),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF38BDF8)
                                          .withValues(alpha: 0.15)
                                    : cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF38BDF8)
                                      : borderColor,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Основной блок задачи
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // 1. Левая цветная полоса
                                        Container(
                                          width: 5,
                                          decoration: BoxDecoration(
                                            color: taskColor,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(12),
                                                  bottomLeft: Radius.circular(
                                                    12,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // 2. Чекбокс / индикатор статуса
                                        Center(
                                          child: _isSelectionMode
                                              ? Checkbox(
                                                  value: isSelected,
                                                  onChanged: (_) =>
                                                      _toggleTaskSelection(
                                                        taskId,
                                                      ),
                                                )
                                              : Checkbox(
                                                  value: isDone,
                                                  activeColor: taskColor,
                                                  onChanged: (val) {
                                                    ref
                                                        .read(
                                                          tasksProvider
                                                              .notifier,
                                                        )
                                                        .toggleTask(
                                                          taskId,
                                                          val ?? false,
                                                        );
                                                  },
                                                ),
                                        ),

                                        // 3. Заголовок и заметка/описание
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                              horizontal: 6,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  task['title'] as String,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: isDone
                                                        ? textSecondary
                                                        : textPrimary,
                                                    decoration: isDone
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                  ),
                                                ),
                                                if (task['description'] !=
                                                        null &&
                                                    (task['description']
                                                            as String)
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    task['description']
                                                        as String,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Бейдж категории
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                            right: 12,
                                          ),
                                          child: Text(
                                            task['category'] as String? ?? '',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Связанный блок подзадач (чуть меньше, без описания)
                                  if (subtasks.isNotEmpty) ...[
                                    Container(
                                      margin: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        12,
                                        10,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.black.withValues(
                                                alpha: 0.25,
                                              )
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: borderColor.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        children: List.generate(
                                          subtasks.length,
                                          (sIdx) {
                                            final sub = subtasks[sIdx];
                                            final subDone =
                                                sub['done'] as bool? ?? false;
                                            return Row(
                                              children: [
                                                SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: Checkbox(
                                                    value: subDone,
                                                    activeColor: taskColor,
                                                    onChanged: (val) {
                                                      ref
                                                          .read(
                                                            tasksProvider
                                                                .notifier,
                                                          )
                                                          .toggleSubtask(
                                                            taskId,
                                                            sIdx,
                                                            val ?? false,
                                                          );
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    sub['title'] as String? ??
                                                        '',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: subDone
                                                          ? textSecondary
                                                          : textPrimary,
                                                      decoration: subDone
                                                          ? TextDecoration
                                                                .lineThrough
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // Плавающая кнопка (+) с иконкой assets/icons/plus.svg
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF38BDF8),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskEditScreen()),
          );
        },
        child: SvgPicture.asset(
          'assets/icons/plus.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          placeholderBuilder: (_) =>
              const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
