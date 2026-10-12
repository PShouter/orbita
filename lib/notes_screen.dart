import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'providers/notes_provider.dart';
import 'note_edit_screen.dart';

class NotesScreen extends ConsumerWidget {
  final bool isDarkMode;

  const NotesScreen({super.key, this.isDarkMode = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(filteredNotesProvider);
    final allNotes = ref.watch(notesProvider);
    final viewMode = ref.watch(notesViewModeProvider);
    final selectedTag = ref.watch(notesSelectedTagProvider);
    final allTags = ref.watch(allNotesTagsProvider);

    final isDark = isDarkMode;
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Заметки',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          // Подсчет заметок
          Center(
            child: Text(
              '${allNotes.length} шт.',
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Кнопка Фильтр (#теги)
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: selectedTag != null
                  ? const Color(0xFF38BDF8)
                  : textSecondary,
            ),
            tooltip: 'Фильтр по тегам',
            onPressed: () => _showTagsFilter(
              context,
              ref,
              allTags,
              selectedTag,
              cardBg,
              textPrimary,
              textSecondary,
            ),
          ),
          // Кнопка Настройки вида
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textSecondary),
            tooltip: 'Настройки вида',
            onPressed: () => _showSettingsDialog(
              context,
              ref,
              viewMode,
              cardBg,
              textPrimary,
              textSecondary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Поисковая строка (по заголовку и по содержанию)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) {
                ref.read(notesSearchQueryProvider.notifier).setQuery(val);
              },
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Поиск по заголовку и содержанию...',
                hintStyle: TextStyle(
                  color: textSecondary.withOpacity(0.6),
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search, size: 20, color: textSecondary),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                ),
              ),
            ),
          ),

          // Активный выбранный тег
          if (selectedTag != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      selectedTag,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: const Color(0xFF38BDF8),
                    deleteIcon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                    onDeleted: () {
                      ref.read(notesSelectedTagProvider.notifier).setTag(null);
                    },
                  ),
                ],
              ),
            ),

          // Блоки заметок: Плитки или Список
          Expanded(
            child: notes.isEmpty
                ? Center(
                    child: Text(
                      allNotes.isEmpty
                          ? 'Заметок пока нет'
                          : 'Ничего не найдено',
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  )
                : viewMode == NotesViewMode.grid
                ? _buildGridView(
                    context,
                    notes,
                    cardBg,
                    borderColor,
                    textPrimary,
                    textSecondary,
                  )
                : _buildListView(
                    context,
                    notes,
                    cardBg,
                    borderColor,
                    textPrimary,
                    textSecondary,
                  ),
          ),
        ],
      ),
      // Кнопка добавления заметки в правом нижнем углу
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF38BDF8),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoteEditScreen(isDarkMode: isDarkMode),
            ),
          );
        },
      ),
    );
  }

  // ВИД: "Плитки" — 2 равные колонки, блоки одинаковой высоты
  Widget _buildGridView(
    BuildContext context,
    List<NoteItem> notes,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: notes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85, // Одинаковый фиксированный размер каждого блока
      ),
      itemBuilder: (context, index) {
        final note = notes[index];
        final preview = note.previewImage;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openNote(context, note),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Предпросмотр первой картинки
                if (preview != null && File(preview).existsSync())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(preview),
                        height: 72,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                // Заголовок
                Text(
                  note.title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Описание, которое умещается в блоке
                Expanded(
                  child: Text(
                    note.body,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),

                // Дата создания / редактирования
                Text(
                  DateFormat('dd.MM.yyyy').format(note.updatedAt),
                  style: TextStyle(
                    color: textSecondary.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ВИД: "Список" — каждый блок на всю ширину, картинка справа
  Widget _buildListView(
    BuildContext context,
    List<NoteItem> notes,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final preview = note.previewImage;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            onTap: () => _openNote(context, note),
            title: Text(
              note.title,
              style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  note.body,
                  style: TextStyle(color: textSecondary, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('dd.MM.yyyy HH:mm').format(note.updatedAt),
                  style: TextStyle(
                    color: textSecondary.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            // Превью первой картинки справа
            trailing: preview != null && File(preview).existsSync()
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(preview),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  void _openNote(BuildContext context, NoteItem note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NoteEditScreen(initialNote: note, isDarkMode: isDarkMode),
      ),
    );
  }

  // Фильтр по тегам
  void _showTagsFilter(
    BuildContext context,
    WidgetRef ref,
    List<String> tags,
    String? currentTag,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Фильтр по тегам',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (tags.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Теги пока не найдены. Добавляйте #теги прямо в текст заметок.',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((t) {
                      final isSelected = t == currentTag;
                      return ChoiceChip(
                        label: Text(t),
                        selected: isSelected,
                        selectedColor: const Color(0xFF38BDF8),
                        onSelected: (val) {
                          ref
                              .read(notesSelectedTagProvider.notifier)
                              .setTag(val ? t : null);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Настройки вида
  void _showSettingsDialog(
    BuildContext context,
    WidgetRef ref,
    NotesViewMode currentMode,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Настройки вида заметок',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              RadioListTile<NotesViewMode>(
                title: Text('Плитки', style: TextStyle(color: textPrimary)),
                subtitle: Text(
                  '2 колонки, карточки одинакового размера',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                value: NotesViewMode.grid,
                groupValue: currentMode,
                activeColor: const Color(0xFF38BDF8),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(notesViewModeProvider.notifier).setMode(val);
                    Navigator.pop(ctx);
                  }
                },
              ),
              RadioListTile<NotesViewMode>(
                title: Text('Список', style: TextStyle(color: textPrimary)),
                subtitle: Text(
                  'Блоки на всю ширину с картинкой справа',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                value: NotesViewMode.list,
                groupValue: currentMode,
                activeColor: const Color(0xFF38BDF8),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(notesViewModeProvider.notifier).setMode(val);
                    Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
