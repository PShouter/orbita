import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/notes_provider.dart';
import '../settings/sections/notes_settings_screen.dart';
import 'note_edit_screen.dart';

class NotesScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const NotesScreen({super.key, this.isDarkMode = true});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _sortBy = 'По дате изменения';
  bool _showDateOnCard = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _sortBy = prefs.getString('notes_sort_by') ?? 'По дате изменения';
        _showDateOnCard = prefs.getBool('notes_show_date_on_card') ?? true;
      });
    }
  }

  List<NoteItem> _applySorting(List<NoteItem> list) {
    final copy = List<NoteItem>.from(list);
    switch (_sortBy) {
      case 'По дате создания':
        copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'По названию (А–Я)':
        copy.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case 'По дате изменения':
      default:
        copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(filteredNotesProvider);
    final allNotes = ref.watch(notesProvider);
    final viewMode = ref.watch(notesViewModeProvider);
    final selectedTag = ref.watch(notesSelectedTagProvider);
    final allTags = ref.watch(allNotesTagsProvider);

    final sortedNotes = _applySorting(notes);

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
              allTags,
              selectedTag,
              cardBg,
              textPrimary,
              textSecondary,
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textSecondary),
            tooltip: 'Настройки заметок',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      NotesSettingsScreen(isDarkMode: widget.isDarkMode),
                ),
              );
              _loadPreferences();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
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
                  color: textSecondary.withValues(alpha: 0.6),
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
          Expanded(
            child: sortedNotes.isEmpty
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
                    sortedNotes,
                    cardBg,
                    borderColor,
                    textPrimary,
                    textSecondary,
                  )
                : _buildListView(
                    context,
                    sortedNotes,
                    cardBg,
                    borderColor,
                    textPrimary,
                    textSecondary,
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF38BDF8),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoteEditScreen(isDarkMode: widget.isDarkMode),
            ),
          );
        },
      ),
    );
  }

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
        childAspectRatio: 0.85,
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
                Expanded(
                  child: Text(
                    note.body,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_showDateOnCard) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd.MM.yyyy').format(note.updatedAt),
                    style: TextStyle(
                      color: textSecondary.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

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
                if (_showDateOnCard) ...[
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(note.updatedAt),
                    style: TextStyle(
                      color: textSecondary.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
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
            NoteEditScreen(initialNote: note, isDarkMode: widget.isDarkMode),
      ),
    );
  }

  void _showTagsFilter(
    BuildContext context,
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
}
