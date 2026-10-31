import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/tasks_provider.dart';
import '../settings/sections/tasks_settings_screen.dart';
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
  bool _hideCompleted = false;
  String? _filterDueDate;
  String? _filterPriority;
  String? _filterStatus;
  String? _filterCategory;

  // Множественный выбор
  bool _isSelectionMode = false;
  final Set<String> _selectedTaskIds = {};

  bool _taskEnableDrag = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _taskEnableDrag = prefs.getBool('task_enable_drag') ?? true;
        _hideCompleted = prefs.getBool('tasks_hide_completed') ?? false;
      });
    }
  }

  Future<void> _toggleHideCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tasks_hide_completed', value);
    if (mounted) {
      setState(() {
        _hideCompleted = value;
      });
    }
  }

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

  void _deleteSelectedTasks() {
    final count = _selectedTaskIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление задач'),
        content: Text('Удалить выбранные задачи ($count)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final idsToDelete = Set<String>.from(_selectedTaskIds);
              Navigator.pop(ctx);
              _exitSelectionMode();
              ref.read(tasksProvider.notifier).deleteMultipleTasks(idsToDelete);
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
                final ids = Set<String>.from(_selectedTaskIds);
                Navigator.pop(ctx);
                _exitSelectionMode();
                ref
                    .read(tasksProvider.notifier)
                    .updateStatusForMultiple(ids, 'todo');
              },
            ),
            ListTile(
              leading: const Icon(Icons.timelapse, color: Colors.orange),
              title: const Text('В работе'),
              onTap: () {
                final ids = Set<String>.from(_selectedTaskIds);
                Navigator.pop(ctx);
                _exitSelectionMode();
                ref
                    .read(tasksProvider.notifier)
                    .updateStatusForMultiple(ids, 'in_progress');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Выполнено'),
              onTap: () {
                final ids = Set<String>.from(_selectedTaskIds);
                Navigator.pop(ctx);
                _exitSelectionMode();
                ref
                    .read(tasksProvider.notifier)
                    .updateStatusForMultiple(ids, 'done');
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.grey),
              title: const Text('Отменено'),
              onTap: () {
                final ids = Set<String>.from(_selectedTaskIds);
                Navigator.pop(ctx);
                _exitSelectionMode();
                ref
                    .read(tasksProvider.notifier)
                    .updateStatusForMultiple(ids, 'canceled');
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
                      final ids = Set<String>.from(_selectedTaskIds);
                      Navigator.pop(ctx);
                      _exitSelectionMode();
                      ref
                          .read(tasksProvider.notifier)
                          .moveCategoryForMultiple(ids, cat);
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

  void _openShoppingListDialog() {
    final titleCtrl = TextEditingController(text: 'Список покупок');
    final itemsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shopping_cart_outlined, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Text('Быстрый список'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название задачи',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemsCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Пункты (каждый с новой строки)',
                  hintText: 'Хлеб\nМолоко\nЯблоки',
                  isDense: true,
                  border: OutlineInputBorder(),
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
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
            ),
            onPressed: () {
              final title = titleCtrl.text.trim();
              final raw = itemsCtrl.text.trim();
              if (title.isNotEmpty) {
                final lines = raw
                    .split('\n')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .map((item) => {'title': item, 'done': false})
                    .toList();

                ref.read(tasksProvider.notifier).saveTask(
                      title: title,
                      category: 'Покупки',
                      date: DateTime.now(),
                      isNoDate: false,
                      subtasks: lines,
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    if (priority == 'high') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag, size: 11, color: Colors.redAccent),
            SizedBox(width: 3),
            Text(
              'Высокий',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      );
    } else if (priority == 'low') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.blueGrey.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 11, color: Colors.blueGrey),
            SizedBox(width: 3),
            Text(
              'Низкий',
              style: TextStyle(fontSize: 10, color: Colors.blueGrey),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTaskCard(
    Map<String, dynamic> task,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    DateTime todayStart,
    DateTime todayEnd,
    bool isDark,
  ) {
    final taskId = task['id'] as String;
    final isSelected = _selectedTaskIds.contains(taskId);
    final taskColor = task['color'] as Color? ?? const Color(0xFF38BDF8);
    final isDone = task['done'] as bool? ?? false;
    final isNoDate = task['isNoDate'] as bool? ?? false;
    final taskDate = task['date'] as DateTime?;
    final taskTime = task['time'] as String?;
    final isAllDay = task['isAllDay'] as bool? ?? false;
    final priority = (task['priority'] as String? ?? 'normal').toLowerCase();
    final subtasks = (task['subtasks'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final bool hasDueDate = !isNoDate && taskDate != null;
    final bool isOverdue =
        !isDone && hasDueDate && taskDate.isBefore(todayStart);
    final bool isTodayTask = !isNoDate &&
        taskDate != null &&
        !taskDate.isBefore(todayStart) &&
        !taskDate.isAfter(todayEnd);

    String dateBadgeText = '';
    if (hasDueDate) {
      if (isTodayTask) {
        dateBadgeText = 'Сегодня';
      } else {
        dateBadgeText = DateFormat('d MMM', 'ru').format(taskDate);
      }
      if (taskTime != null && !isAllDay) {
        dateBadgeText += ', $taskTime';
      }
    }

    return Container(
      key: ValueKey('task_$taskId'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
            : cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF38BDF8)
              : (isOverdue
                  ? Colors.redAccent.withValues(alpha: 0.6)
                  : borderColor),
          width: isSelected || isOverdue ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
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
                  builder: (_) => TaskEditScreen(initialTask: task),
                ),
              );
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 5,
                      decoration: BoxDecoration(
                        color: isOverdue ? Colors.redAccent : taskColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Center(
                      child: _isSelectionMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleTaskSelection(taskId),
                            )
                          : Checkbox(
                              value: isDone,
                              activeColor: taskColor,
                              onChanged: (val) {
                                ref
                                    .read(tasksProvider.notifier)
                                    .toggleTask(taskId, val ?? false);
                              },
                            ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['title'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDone ? textSecondary : textPrimary,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (task['description'] != null &&
                                (task['description'] as String).isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                task['description'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (hasDueDate)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isOverdue
                                            ? Icons.error_outline
                                            : Icons.event,
                                        size: 13,
                                        color: isOverdue
                                            ? Colors.redAccent
                                            : (isTodayTask
                                                ? const Color(0xFF38BDF8)
                                                : textSecondary),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isOverdue
                                            ? 'Просрочено ($dateBadgeText)'
                                            : dateBadgeText,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isOverdue || isTodayTask
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isOverdue
                                              ? Colors.redAccent
                                              : (isTodayTask
                                                  ? const Color(0xFF38BDF8)
                                                  : textSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                _buildPriorityBadge(priority),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10, right: 12),
                      child: Text(
                        task['category'] as String? ?? '',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              if (subtasks.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 12, 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: List.generate(subtasks.length, (sIdx) {
                      final sub = subtasks[sIdx];
                      final subDone = sub['done'] as bool? ?? false;
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
                                    .read(tasksProvider.notifier)
                                    .toggleSubtask(taskId, sIdx, val ?? false);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sub['title'] as String? ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: subDone ? textSecondary : textPrimary,
                                decoration: subDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ],
          ),
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

    // Подсчет активных (невыполненных) задач
    final activeTodayTasksCount = allTasks.where((t) {
      final isDone = t['done'] as bool? ?? false;
      final isNoDate = t['isNoDate'] as bool? ?? false;
      final d = t['date'] as DateTime?;
      if (isDone || isNoDate || d == null) return false;
      return !d.isBefore(todayStart) && !d.isAfter(todayEnd);
    }).length;

    final activeTotalTasksCount = allTasks.where((t) {
      return (t['done'] as bool? ?? false) == false;
    }).length;

    final overdueTasks = allTasks.where((t) {
      final isDone = t['done'] as bool? ?? false;
      final isNoDate = t['isNoDate'] as bool? ?? false;
      final d = t['date'] as DateTime?;
      return !isDone && !isNoDate && d != null && d.isBefore(todayStart);
    }).toList();

    final filteredTasks = allTasks.where((t) {
      final isDone = t['done'] as bool? ?? false;

      // Скрытие выполненных
      if (_hideCompleted && isDone) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final title = (t['title'] as String).toLowerCase();
        final desc = ((t['description'] as String?) ?? '').toLowerCase();
        final subtasks = (t['subtasks'] as List<dynamic>? ?? []);
        final matchSubtasks = subtasks.any(
          (s) => ((s as Map)['title'] as String? ?? '').toLowerCase().contains(
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

      if (_filterDueDate != null) {
        final d = t['date'] as DateTime?;
        final isNoDate = t['isNoDate'] as bool? ?? false;
        if (isNoDate || d == null) return false;

        if (_filterDueDate == 'overdue' && !d.isBefore(todayStart)) {
          return false;
        }
        if (_filterDueDate == 'today' &&
            (d.isBefore(todayStart) || d.isAfter(todayEnd))) {
          return false;
        }
        if (_filterDueDate == 'upcoming' && !d.isAfter(todayEnd)) return false;
      }

      if (_filterPriority != null && t['priority'] != _filterPriority) {
        return false;
      }
      if (_filterStatus != null && t['status'] != _filterStatus) return false;
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'На сегодня: $activeTodayTasksCount',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Активных: $activeTotalTasksCount',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.playlist_add_check_rounded,
                        color: Color(0xFF38BDF8),
                        size: 24,
                      ),
                      tooltip: 'Быстрый список покупок',
                      onPressed: _openShoppingListDialog,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.settings_outlined,
                        color: textSecondary,
                        size: 22,
                      ),
                      tooltip: 'Настройки задач',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TasksSettingsScreen(
                              isDarkMode: widget.isDarkMode,
                            ),
                          ),
                        );
                        _loadPreferences();
                      },
                    ),
                  ],
                ),
              ),

            // Баннер переноса просроченных задач
            if (overdueTasks.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Просрочено задач: ${overdueTasks.length}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final count = await ref
                            .read(tasksProvider.notifier)
                            .postponeOverdueToToday();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Перенесено на сегодня: $count',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'На сегодня',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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

            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                children: [
                  FilterChip(
                    label: const Text('Все', style: TextStyle(fontSize: 12)),
                    selected: _filterAll,
                    onSelected: (val) {
                      if (val) _clearFilters();
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text(
                      'Скрыть выполненные',
                      style: TextStyle(fontSize: 12),
                    ),
                    selected: _hideCompleted,
                    onSelected: (val) {
                      _toggleHideCompleted(val);
                    },
                  ),
                  const SizedBox(width: 8),
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

            Expanded(
              child: filteredTasks.isEmpty
                  ? Center(
                      child: Text(
                        'Нет задач',
                        style: TextStyle(color: textSecondary, fontSize: 14),
                      ),
                    )
                  : (_taskEnableDrag && _filterAll && _searchQuery.isEmpty)
                      ? ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: filteredTasks.length,
                          onReorder: (oldIndex, newIndex) {
                            ref
                                .read(tasksProvider.notifier)
                                .reorderTasks(oldIndex, newIndex);
                          },
                          itemBuilder: (ctx, idx) {
                            final task = filteredTasks[idx];
                            return _buildTaskCard(
                              task,
                              cardBg,
                              borderColor,
                              textPrimary,
                              textSecondary,
                              todayStart,
                              todayEnd,
                              isDark,
                            );
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: filteredTasks.length,
                          itemBuilder: (ctx, idx) {
                            final task = filteredTasks[idx];
                            return _buildTaskCard(
                              task,
                              cardBg,
                              borderColor,
                              textPrimary,
                              textSecondary,
                              todayStart,
                              todayEnd,
                              isDark,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
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