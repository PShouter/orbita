import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiaryScreen extends StatefulWidget {
  final bool isDarkMode;

  const DiaryScreen({super.key, required this.isDarkMode});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final List<Map<String, dynamic>> _entries = [];
  String _selectedMoodFilter = 'Все';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<Map<String, String>> _moods = [
    {'emoji': '⚡', 'label': 'Энергично'},
    {'emoji': '😊', 'label': 'Радостно'},
    {'emoji': ' спокойствие', 'label': 'Спокойно'},
    {'emoji': '🤔', 'label': 'Задумчиво'},
    {'emoji': ' усталость', 'label': 'Устало'},
    {'emoji': '🔥', 'label': 'Продуктивно'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDiaryEntries();
  }

  Future<void> _loadDiaryEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cached_diary_entries');
    if (raw != null) {
      final List decoded = jsonDecode(raw);
      setState(() {
        _entries.clear();
        _entries.addAll(decoded.map((e) => Map<String, dynamic>.from(e)));
      });
    }
  }

  Future<void> _saveDiaryEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_diary_entries', jsonEncode(_entries));
  }

  void _openEntryEditor({Map<String, dynamic>? existingEntry}) {
    final titleController = TextEditingController(
      text: existingEntry?['title'] ?? '',
    );
    final bodyController = TextEditingController(
      text: existingEntry?['body'] ?? '',
    );
    String selectedMood = existingEntry?['mood'] ?? '😊';

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
        builder: (ctx, setSheetState) {
          final isDark = widget.isDarkMode;
          final textPrimary = isDark
              ? const Color(0xFFF0F6FC)
              : const Color(0xFF24292F);

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existingEntry == null
                            ? 'Новая запись'
                            : 'Редактировать запись',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Настроение:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _moods.map((m) {
                      final isSelected = selectedMood == m['emoji'];
                      return ChoiceChip(
                        label: Text('${m['emoji']} ${m['label']}'),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() => selectedMood = m['emoji']!);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Заголовок или главная мысль',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Что у вас на уме?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (titleController.text.trim().isEmpty &&
                            bodyController.text.trim().isEmpty) {
                          return;
                        }

                        final now = DateTime.now();
                        final dateStr =
                            '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

                        setState(() {
                          if (existingEntry == null) {
                            _entries.insert(0, {
                              'id': DateTime.now().millisecondsSinceEpoch
                                  .toString(),
                              'title': titleController.text.trim().isEmpty
                                  ? 'Запись без названия'
                                  : titleController.text.trim(),
                              'body': bodyController.text.trim(),
                              'mood': selectedMood,
                              'date': dateStr,
                            });
                          } else {
                            existingEntry['title'] =
                                titleController.text.trim().isEmpty
                                ? 'Запись без названия'
                                : titleController.text.trim();
                            existingEntry['body'] = bodyController.text.trim();
                            existingEntry['mood'] = selectedMood;
                          }
                        });
                        _saveDiaryEntries();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    var filteredEntries = _entries.where((e) {
      final matchesSearch =
          (e['title'] ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (e['body'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesMood =
          _selectedMoodFilter == 'Все' || e['mood'] == _selectedMoodFilter;
      return matchesSearch && matchesMood;
    }).toList();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Дневник'),
        backgroundColor: cardBg,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEntryEditor(),
        backgroundColor: const Color(0xFF2C69D1),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Поиск
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Поиск по записям дневника...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Фильтр по настроению
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Все'),
                  selected: _selectedMoodFilter == 'Все',
                  onSelected: (v) =>
                      setState(() => _selectedMoodFilter = 'Все'),
                ),
                const SizedBox(width: 6),
                ..._moods.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(m['emoji']!),
                      selected: _selectedMoodFilter == m['emoji'],
                      onSelected: (v) => setState(
                        () => _selectedMoodFilter = v ? m['emoji']! : 'Все',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Список записей
          if (filteredEntries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Записей в дневнике пока нет',
                  style: TextStyle(color: textSecondary),
                ),
              ),
            )
          else
            ...filteredEntries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: InkWell(
                  onTap: () => _openEntryEditor(existingEntry: entry),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                entry['mood'] ?? '😊',
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entry['title'] ?? '',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              setState(() => _entries.remove(entry));
                              _saveDiaryEntries();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry['body'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: textSecondary,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry['date'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
