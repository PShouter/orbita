import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/notes_provider.dart';
import '../../theme/app_theme.dart';
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
    final colors = context.colors;
    final notes = ref.watch(filteredNotesProvider);
    final allNotes = ref.watch(notesProvider);
    final viewMode = ref.watch(notesViewModeProvider);
    final selectedTag = ref.watch(notesSelectedTagProvider);
    final allTags = ref.watch(allNotesTagsProvider);

    final sortedNotes = _applySorting(notes);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          'Заметки',
          style: TextStyle(
            fontFamily: 'Unbounded',
            color: colors.text,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        actions: [
          Center(
            child: Text(
              '${allNotes.length} шт.',
              style: TextStyle(
                fontFamily: 'Onest',
                color: colors.text.withValues(alpha: 0.6),
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
                  ? colors.accent
                  : colors.text.withValues(alpha: 0.6),
            ),
            tooltip: 'Фильтр по тегам',
            onPressed: () =>
                _showTagsFilter(context, allTags, selectedTag, colors),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: colors.text.withValues(alpha: 0.6)),
            tooltip: 'Настройки заметок',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      NotesSettingsScreen(isDarkMode: colors.isDark),
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
              style: TextStyle(
                  fontFamily: 'Onest', color: colors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Поиск по заголовку и содержанию...',
                hintStyle: TextStyle(
                  fontFamily: 'Onest',
                  color: colors.text.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search,
                    size: 20, color: colors.text.withValues(alpha: 0.5)),
                filled: true,
                fillColor: colors.card,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.nested),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.nested),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.accent, width: 1.5),
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
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.isDark ? Colors.black : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: colors.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 16,
                      color: colors.isDark ? Colors.black : Colors.white,
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
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  )
                : viewMode == NotesViewMode.grid
                    ? _buildGridView(context, sortedNotes, colors)
                    : _buildListView(context, sortedNotes, colors),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.accent,
        foregroundColor: colors.isDark ? Colors.black : Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoteEditScreen(isDarkMode: colors.isDark),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridView(
    BuildContext context,
    List<NoteItem> notes,
    AppColorsExtension colors,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 84),
      itemCount: notes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final note = notes[index];
        final preview = note.previewImage;

        return Material(
          color: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: colors.nested),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openNote(context, note),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview != null && File(preview).existsSync())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                      fontFamily: 'Onest',
                      color: colors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      note.body,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.6),
                        fontSize: 12,
                        height: 1.35,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_showDateOnCard) ...[
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('dd.MM.yyyy').format(note.updatedAt),
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView(
    BuildContext context,
    List<NoteItem> notes,
    AppColorsExtension colors,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 84),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final preview = note.previewImage;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: colors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.nested),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              onTap: () => _openNote(context, note),
              title: Text(
                note.title,
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: colors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_showDateOnCard) ...[
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(note.updatedAt),
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: preview != null && File(preview).existsSync()
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(preview),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    )
                  : null,
            ),
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
    AppColorsExtension colors,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Фильтр по тегам',
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                if (tags.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Теги пока не найдены. Добавляйте #теги прямо в текст заметок.',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((t) {
                      final isSelected = t == currentTag;
                      return ChoiceChip(
                        label: Text(
                          t,
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? (colors.isDark ? Colors.black : Colors.white)
                                : colors.text,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: colors.accent,
                        backgroundColor: colors.nested.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                          side: BorderSide(
                              color:
                                  isSelected ? colors.accent : colors.nested),
                        ),
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
