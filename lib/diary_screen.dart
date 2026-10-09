import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/diary_provider.dart';

class DiaryScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const DiaryScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  String _searchQuery = '';

  static const Map<String, Map<String, dynamic>> _moodMeta = {
    'great': {'emoji': '🤩', 'label': 'Отлично', 'color': Colors.amber},
    'good': {'emoji': '😊', 'label': 'Хорошо', 'color': Colors.green},
    'neutral': {'emoji': '😐', 'label': 'Нейтрально', 'color': Colors.blueGrey},
    'tired': {
      'emoji': '🥱',
      'label': 'Усталость',
      'color': Colors.deepOrangeAccent,
    },
    'sad': {'emoji': '😔', 'label': 'Грустно', 'color': Colors.blueAccent},
  };

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(diaryProvider);
    final notifier = ref.read(diaryProvider.notifier);

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

    final filtered = entries.where((e) {
      final text = (e['content'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return text.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF38BDF8),
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text(
          'Запись дня',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _openEntryDialog(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Личный дневник',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
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
                      '${entries.length} записей',
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

            // Поиск
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
                    hintText: 'Поиск по дневнику...',
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

            // Список записей
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_stories_outlined,
                            size: 48,
                            color: Colors.grey.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Дневник пуст',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Запишите мысли, итоги или события сегодняшнего дня',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final entry = filtered[i];
                        final d = entry['date'] as DateTime;
                        final moodKey = entry['mood'] ?? 'neutral';
                        final meta =
                            _moodMeta[moodKey] ?? _moodMeta['neutral']!;
                        final List tags = (entry['tags'] as List?) ?? [];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openEntryDialog(existingEntry: entry),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        meta['emoji'] as String,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${d.day} ${_monthNameGenitive(d.month)} ${d.year}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: textPrimary,
                                            ),
                                          ),
                                          Text(
                                            meta['label'] as String,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: meta['color'] as Color,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () => notifier.deleteEntry(
                                          entry['id'].toString(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    entry['content'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.45,
                                      color: textPrimary,
                                    ),
                                  ),
                                  if (tags.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      children: tags.map((t) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF38BDF8)
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '#$t',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF38BDF8),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      }).toList(),
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
    );
  }

  void _openEntryDialog({Map<String, dynamic>? existingEntry}) {
    final contentCtrl = TextEditingController(
      text: existingEntry?['content'] ?? '',
    );
    final tagCtrl = TextEditingController();
    String selectedMood = existingEntry?['mood'] ?? 'good';
    DateTime selectedDate =
        existingEntry?['date'] as DateTime? ?? DateTime.now();
    List<String> currentTags = existingEntry?['tags'] != null
        ? List<String>.from(existingEntry!['tags'])
        : <String>[];

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      existingEntry == null
                          ? 'Новая запись'
                          : 'Редактировать запись',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
                      ),
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (p != null) setDState(() => selectedDate = p);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Выбор настроения
                const Text(
                  'Как прошел день?',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _moodMeta.entries.map((entry) {
                    final key = entry.key;
                    final val = entry.value;
                    final isSel = selectedMood == key;

                    return GestureDetector(
                      onTap: () => setDState(() => selectedMood = key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? (val['color'] as Color).withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel
                                ? val['color'] as Color
                                : Colors.grey.withValues(alpha: 0.2),
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              val['emoji'] as String,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              val['label'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSel
                                    ? val['color'] as Color
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Поле ввода текста
                TextField(
                  controller: contentCtrl,
                  maxLines: 6,
                  autofocus: existingEntry == null,
                  decoration: const InputDecoration(
                    hintText: 'Опишите ваши мысли, события или инсайты...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Теги
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tagCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Добавить тег (#спорт, #работа)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (val) {
                          final clean = val.trim().replaceAll('#', '');
                          if (clean.isNotEmpty &&
                              !currentTags.contains(clean)) {
                            setDState(() {
                              currentTags.add(clean);
                              tagCtrl.clear();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: Color(0xFF38BDF8),
                      ),
                      onPressed: () {
                        final clean = tagCtrl.text.trim().replaceAll('#', '');
                        if (clean.isNotEmpty && !currentTags.contains(clean)) {
                          setDState(() {
                            currentTags.add(clean);
                            tagCtrl.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (currentTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: currentTags.map((t) {
                      return Chip(
                        label: Text(
                          '#$t',
                          style: const TextStyle(fontSize: 11),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => setDState(() => currentTags.remove(t)),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),

                // Кнопки Сохранить / Отмена
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
                        final text = contentCtrl.text.trim();
                        if (text.isEmpty) return;

                        ref
                            .read(diaryProvider.notifier)
                            .saveEntry(
                              existingId: existingEntry?['id']?.toString(),
                              date: selectedDate,
                              mood: selectedMood,
                              content: text,
                              tags: currentTags,
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

  String _monthNameGenitive(int m) => const [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ][m - 1];
}
