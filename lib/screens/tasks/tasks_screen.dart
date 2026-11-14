import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/tasks_provider.dart';
import '../../theme/app_theme.dart';
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

  void _deleteSelectedTasks(AppColorsExtension colors) {
    final count = _selectedTaskIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Удаление задач',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: Text(
          'Удалить выбранные задачи ($count)?',
          style: TextStyle(
            fontFamily: 'Onest',
            fontSize: 14,
            color: colors.text.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(
                fontFamily: 'Onest',
                fontWeight: FontWeight.w600,
                color: colors.text.withValues(alpha: 0.6),
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              final idsToDelete = Set<String>.from(_selectedTaskIds);
              Navigator.pop(ctx);
              _exitSelectionMode();
              ref.read(tasksProvider.notifier).deleteMultipleTasks(idsToDelete);
            },
            child: const Text(
              'Удалить',
              style: TextStyle(
                fontFamily: 'Onest',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeStatusForSelected(AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Отметить как...',
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: colors.text,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.radio_button_unchecked,
                color: colors.accent,
              ),
              title: Text(
                'К выполнению',
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
              ),
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
              leading: Icon(Icons.timelapse, color: colors.warning),
              title: Text(
                'В работе',
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
              ),
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
              leading: Icon(Icons.check_circle, color: colors.success),
              title: Text(
                'Выполнено',
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
              ),
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
              leading: Icon(
                Icons.cancel,
                color: colors.text.withValues(alpha: 0.4),
              ),
              title: Text(
                'Отменено',
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
              ),
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

  void _moveCategoryForSelected(AppColorsExtension colors) {
    final categories = ref.read(taskCategoriesProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Перенести в категорию',
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: colors.text,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: categories.map((cat) {
                  return ListTile(
                    leading: Icon(
                      Icons.folder_outlined,
                      color: colors.accent,
                    ),
                    title: Text(
                      cat,
                      style: TextStyle(fontFamily: 'Onest', color: colors.text),
                    ),
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

  void _openShoppingListDialog(AppColorsExtension colors) {
    final titleCtrl = TextEditingController(text: 'Список покупок');
    final itemsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(Icons.shopping_cart_outlined, color: colors.accent),
            const SizedBox(width: 8),
            Text(
              'Быстрый список',
              style: TextStyle(
                fontFamily: 'Unbounded',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
                decoration: InputDecoration(
                  labelText: 'Название задачи',
                  labelStyle: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.6),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemsCtrl,
                maxLines: 5,
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
                decoration: InputDecoration(
                  labelText: 'Пункты (каждый с новой строки)',
                  hintText: 'Хлеб\nМолоко\nЯблоки',
                  labelStyle: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.6),
                  ),
                  hintStyle: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.3),
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.nested),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(
                fontFamily: 'Onest',
                color: colors.text.withValues(alpha: 0.6),
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
            child: const Text(
              'Создать',
              style: TextStyle(
                fontFamily: 'Onest',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority, AppColorsExtension colors) {
    if (priority == 'high') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: colors.error.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag, size: 11, color: colors.error),
            const SizedBox(width: 4),
            Text(
              'Высокий',
              style: TextStyle(
                fontFamily: 'Onest',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.error,
              ),
            ),
          ],
        ),
      );
    } else if (priority == 'low') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.text.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: colors.nested,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 11,
              color: colors.text.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              'Низкий',
              style: TextStyle(
                fontFamily: 'Onest',
                fontSize: 10,
                color: colors.text.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTaskCard(
    Map<String, dynamic> task,
    AppColorsExtension colors,
    DateTime todayStart,
    DateTime todayEnd,
  ) {
    final taskId = task['id'] as String;
    final isSelected = _selectedTaskIds.contains(taskId);
    final taskColor = task['color'] as Color? ?? colors.accent;
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
        color: isSelected ? colors.accent.withValues(alpha: 0.15) : colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected
              ? colors.accent
              : (isOverdue
                  ? colors.error.withValues(alpha: 0.6)
                  : colors.nested),
          width: isSelected || isOverdue ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
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
                        color: isOverdue ? colors.error : taskColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(21),
                          bottomLeft: Radius.circular(21),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Center(
                      child: _isSelectionMode
                          ? Checkbox(
                              value: isSelected,
                              activeColor: colors.accent,
                              checkColor:
                                  colors.isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              onChanged: (_) => _toggleTaskSelection(taskId),
                            )
                          : Checkbox(
                              value: isDone,
                              activeColor: taskColor,
                              checkColor:
                                  colors.isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              side: BorderSide(
                                color: colors.text.withValues(alpha: 0.4),
                              ),
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
                          vertical: 12,
                          horizontal: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task['title'] as String,
                              style: TextStyle(
                                fontFamily: 'Onest',
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: isDone
                                    ? colors.text.withValues(alpha: 0.45)
                                    : colors.text,
                                decoration:
                                    isDone ? TextDecoration.lineThrough : null,
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
                                  fontFamily: 'Onest',
                                  fontSize: 12,
                                  color: colors.text.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
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
                                            ? colors.error
                                            : (isTodayTask
                                                ? colors.accent
                                                : colors.text
                                                    .withValues(alpha: 0.6)),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isOverdue
                                            ? 'Просрочено ($dateBadgeText)'
                                            : dateBadgeText,
                                        style: TextStyle(
                                          fontFamily: 'Onest',
                                          fontSize: 11,
                                          fontWeight: isOverdue || isTodayTask
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isOverdue
                                              ? colors.error
                                              : (isTodayTask
                                                  ? colors.accent
                                                  : colors.text
                                                      .withValues(alpha: 0.6)),
                                        ),
                                      ),
                                    ],
                                  ),
                                _buildPriorityBadge(priority, colors),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12, right: 14),
                      child: Text(
                        task['category'] as String? ?? '',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.text.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (subtasks.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 14, 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.nested.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.nested,
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
                              checkColor:
                                  colors.isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
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
                                fontFamily: 'Onest',
                                fontSize: 13,
                                color: subDone
                                    ? colors.text.withValues(alpha: 0.45)
                                    : colors.text,
                                decoration:
                                    subDone ? TextDecoration.lineThrough : null,
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
    final colors = context.colors;
    final allTasks = ref.watch(tasksProvider);
    final categories = ref.watch(taskCategoriesProvider);

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
      backgroundColor: colors.bg,
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
                  color: colors.card,
                  border: Border(bottom: BorderSide(color: colors.nested)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: colors.text),
                      onPressed: _exitSelectionMode,
                    ),
                    Text(
                      'Выбрано: ${_selectedTaskIds.length}',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: colors.text,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Действия',
                      color: colors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colors.nested),
                      ),
                      icon: Icon(Icons.more_vert, color: colors.text),
                      onSelected: (val) {
                        if (val == 'status') _changeStatusForSelected(colors);
                        if (val == 'category') _moveCategoryForSelected(colors);
                        if (val == 'delete') _deleteSelectedTasks(colors);
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'status',
                          child: Text(
                            'Отметить как...',
                            style: TextStyle(
                                fontFamily: 'Onest', color: colors.text),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'category',
                          child: Text(
                            'Перенести в др. категорию...',
                            style: TextStyle(
                                fontFamily: 'Onest', color: colors.text),
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Удалить выбранные',
                            style: TextStyle(
                              fontFamily: 'Onest',
                              color: colors.error,
                              fontWeight: FontWeight.w600,
                            ),
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
                        fontFamily: 'Unbounded',
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'На сегодня: $activeTodayTasksCount',
                              style: TextStyle(
                                fontFamily: 'Onest',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Активных: $activeTotalTasksCount',
                              style: TextStyle(
                                fontFamily: 'Onest',
                                fontSize: 12,
                                color: colors.text.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.playlist_add_check_rounded,
                        color: colors.accent,
                        size: 24,
                      ),
                      tooltip: 'Быстрый список покупок',
                      onPressed: () => _openShoppingListDialog(colors),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.settings_outlined,
                        color: colors.text.withValues(alpha: 0.6),
                        size: 22,
                      ),
                      tooltip: 'Настройки задач',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TasksSettingsScreen(
                              isDarkMode: colors.isDark,
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
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: colors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Просрочено задач: ${overdueTasks.length}',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
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
                              content: Text('Перенесено на сегодня: $count'),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'На сегодня',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Поле поиска
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.nested),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Поиск по заголовку, заметке, подзадачам...',
                    hintStyle: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: colors.text.withValues(alpha: 0.4),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 18,
                              color: colors.text.withValues(alpha: 0.5),
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

            // Горизонтальная лента фильтров
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                children: [
                  FilterChip(
                    label: const Text(
                      'Все',
                      style: TextStyle(fontFamily: 'Onest', fontSize: 12),
                    ),
                    selected: _filterAll,
                    selectedColor: colors.nested,
                    checkmarkColor: colors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                      side: BorderSide(
                        color: _filterAll ? colors.accent : colors.nested,
                      ),
                    ),
                    onSelected: (val) {
                      if (val) _clearFilters();
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text(
                      'Скрыть выполненные',
                      style: TextStyle(fontFamily: 'Onest', fontSize: 12),
                    ),
                    selected: _hideCompleted,
                    selectedColor: colors.nested,
                    checkmarkColor: colors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                      side: BorderSide(
                        color: _hideCompleted ? colors.accent : colors.nested,
                      ),
                    ),
                    onSelected: (val) {
                      _toggleHideCompleted(val);
                    },
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Срок',
                    color: colors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colors.nested),
                    ),
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
                          fontFamily: 'Onest',
                          fontSize: 12,
                          color: _filterDueDate != null
                              ? colors.accent
                              : colors.text,
                        ),
                      ),
                      backgroundColor: colors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                        side: BorderSide(
                          color: _filterDueDate != null
                              ? colors.accent
                              : colors.nested,
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
                      PopupMenuItem(
                        value: 'overdue',
                        child: Text(
                          'Просроченные',
                          style: TextStyle(
                              fontFamily: 'Onest', color: colors.text),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'today',
                        child: Text(
                          'Сегодня',
                          style: TextStyle(
                              fontFamily: 'Onest', color: colors.text),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'upcoming',
                        child: Text(
                          'Предстоящие',
                          style: TextStyle(
                              fontFamily: 'Onest', color: colors.text),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'clear',
                        child: Text(
                          'Сбросить',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            color: colors.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Приоритет',
                    color: colors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colors.nested),
                    ),
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
                          fontFamily: 'Onest',
                          fontSize: 12,
                          color: _filterPriority != null
                              ? colors.accent
                              : colors.text,
                        ),
                      ),
                      backgroundColor: colors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                        side: BorderSide(
                          color: _filterPriority != null
                              ? colors.accent
                              : colors.nested,
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
                      PopupMenuItem(
                        value: 'low',
                        child: Text(
                          'Низкий',
                          style: TextStyle(
                              fontFamily: 'Onest', color: colors.text),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'normal',
                        child: Text(
                          'Обычный',
                          style: TextStyle(
                              fontFamily: 'Onest', color: colors.text),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'high',
                        child: Text(
                          'Высокий',
                          style: TextStyle(
                              fontFamily: 'Onest', color: colors.text),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'clear',
                        child: Text(
                          'Сбросить',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            color: colors.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Статус',
                    color: colors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colors.nested),
                    ),
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
                          fontFamily: 'Onest',
                          fontSize: 12,
                          color: _filterStatus != null
                              ? colors.accent
                              : colors.text,
                        ),
                      ),
                      backgroundColor: colors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                        side: BorderSide(
                          color: _filterStatus != null
                              ? colors.accent
                              : colors.nested,
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
                      PopupMenuItem(
                        value: 'done',
                        child: Text(
                          'Выполнено',
                          style: TextStyle(
                              fontFamily: 'Onest', color: colors.text),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'todo',
                        child: Text(
                          'К выполнению',
                          style: TextStyle(
                              fontFamily: 'Onest', color: colors.text),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'in_progress',
                        child: Text(
                          'В работе',
                          style: TextStyle(
                              fontFamily: 'Onest', color: colors.text),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'canceled',
                        child: Text(
                          'Отменено',
                          style: TextStyle(
                              fontFamily: 'Onest', color: colors.text),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'clear',
                        child: Text(
                          'Сбросить',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            color: colors.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Категория',
                    color: colors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colors.nested),
                    ),
                    child: Chip(
                      label: Text(
                        _filterCategory ?? 'Категория',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          fontSize: 12,
                          color: _filterCategory != null
                              ? colors.accent
                              : colors.text,
                        ),
                      ),
                      backgroundColor: colors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                        side: BorderSide(
                          color: _filterCategory != null
                              ? colors.accent
                              : colors.nested,
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
                        (cat) => PopupMenuItem(
                          value: cat,
                          child: Text(
                            cat,
                            style: TextStyle(
                                fontFamily: 'Onest', color: colors.text),
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: '__clear__',
                        child: Text(
                          'Сбросить',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            color: colors.text.withValues(alpha: 0.5),
                          ),
                        ),
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
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.text.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : (_taskEnableDrag && _filterAll && _searchQuery.isEmpty)
                      ? ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
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
                              colors,
                              todayStart,
                              todayEnd,
                            );
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                          itemCount: filteredTasks.length,
                          itemBuilder: (ctx, idx) {
                            final task = filteredTasks[idx];
                            return _buildTaskCard(
                              task,
                              colors,
                              todayStart,
                              todayEnd,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.accent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          colorFilter: ColorFilter.mode(
            colors.isDark ? Colors.black : Colors.white,
            BlendMode.srcIn,
          ),
          placeholderBuilder: (_) => Icon(
            Icons.add,
            color: colors.isDark ? Colors.black : Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
