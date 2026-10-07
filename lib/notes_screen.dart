import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Кастомный контроллер для Obsidian Live Preview
class MarkdownLiveEditingController extends TextEditingController {
  final bool isDark;
  MarkdownLiveEditingController({super.text, required this.isDark});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> spans = [];
    final pattern = RegExp(
      r'(^#{1,3}\s.*$)|(\*\*.*?\*\*)|(\*.*?\*)|(^- \[ \].*$)|(^- \[x\].*$)|(^>.*$)',
      multiLine: true,
    );

    int currentPosition = 0;
    final matches = pattern.allMatches(text);

    for (final match in matches) {
      if (match.start > currentPosition) {
        spans.add(
          TextSpan(
            text: text.substring(currentPosition, match.start),
            style: style,
          ),
        );
      }

      final matchedText = match.group(0)!;

      if (matchedText.startsWith('# ')) {
        spans.add(
          TextSpan(
            text: matchedText,
            style: style?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF38BDF8),
            ),
          ),
        );
      } else if (matchedText.startsWith('## ')) {
        spans.add(
          TextSpan(
            text: matchedText,
            style: style?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF60A5FA),
            ),
          ),
        );
      } else if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        spans.add(
          TextSpan(
            text: matchedText,
            style: style?.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        spans.add(
          TextSpan(
            text: matchedText,
            style: style?.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (matchedText.startsWith('>')) {
        spans.add(
          TextSpan(
            text: matchedText,
            style: style?.copyWith(
              color: isDark ? Colors.tealAccent : Colors.teal,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else if (matchedText.startsWith('- [x]')) {
        spans.add(
          TextSpan(
            text: matchedText,
            style: style?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: Colors.grey,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: matchedText, style: style));
      }
      currentPosition = match.end;
    }

    if (currentPosition < text.length) {
      spans.add(TextSpan(text: text.substring(currentPosition), style: style));
    }

    return TextSpan(style: style, children: spans);
  }
}

class NotesScreen extends StatefulWidget {
  final bool isDarkMode;
  final List<Map<String, dynamic>> notes;
  final bool isLoadingNotes;
  final Function({
    Map<String, dynamic>? existingNote,
    required String title,
    required String body,
    required String image,
  })
  onSaveNote;
  final Function(Map<String, dynamic>) onDeleteNote;

  const NotesScreen({
    super.key,
    required this.isDarkMode,
    required this.notes,
    required this.isLoadingNotes,
    required this.onSaveNote,
    required this.onDeleteNote,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _noteSearchQuery = '';
  final TextEditingController _noteSearchController = TextEditingController();
  String _notesLayout = 'Плитки';
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadLayoutPreference();
  }

  Future<void> _loadLayoutPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notesLayout = prefs.getString('notes_layout') ?? 'Плитки';
    });
  }

  Future<void> _toggleLayout() async {
    final newLayout = _notesLayout == 'Плитки' ? 'список' : 'Плитки';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes_layout', newLayout);
    setState(() => _notesLayout = newLayout);
  }

  Widget _buildSafeMarkdown(String content, Color textPrimary) {
    if (content.trim().isEmpty) {
      return Text(
        'Пусто...',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: textPrimary.withValues(alpha: 0.5),
        ),
      );
    }
    try {
      return MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: TextStyle(color: textPrimary, fontSize: 15, height: 1.4),
          h1: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          h2: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      );
    } catch (_) {
      return Text(content, style: TextStyle(color: textPrimary));
    }
  }

  void _openObsidianNoteEditor({Map<String, dynamic>? existingNote}) {
    final titleController = TextEditingController(
      text: existingNote?['title'] ?? '',
    );
    final liveController = MarkdownLiveEditingController(
      text: existingNote?['body'] ?? '',
      isDark: widget.isDarkMode,
    );
    String imagePath = existingNote?['image'] ?? '';
    int viewMode = 3; // 1: Чтение, 2: Исходник, 3: Live

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setEditorState) {
            final isDark = widget.isDarkMode;
            final Color textPrimary = isDark
                ? const Color(0xFFF0F6FC)
                : const Color(0xFF24292F);

            void insertMarkdown(String prefix, [String suffix = '']) {
              final text = liveController.text;
              final sel = liveController.selection;
              final start = sel.start >= 0 ? sel.start : text.length;
              final end = sel.end >= 0 ? sel.end : text.length;
              liveController.text = text.replaceRange(
                start,
                end,
                '$prefix${text.substring(start, end)}$suffix',
              );
            }

            return Scaffold(
              backgroundColor: isDark
                  ? const Color(0xFF0D1117)
                  : const Color(0xFFF6F8FA),
              appBar: AppBar(
                title: Text(
                  existingNote == null ? 'Новая заметка' : 'Obsidian Live',
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.remove_red_eye_outlined,
                      color: viewMode == 1 ? const Color(0xFF38BDF8) : null,
                    ),
                    tooltip: 'Режим чтения',
                    onPressed: () => setEditorState(() => viewMode = 1),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.code,
                      color: viewMode == 2 ? const Color(0xFF38BDF8) : null,
                    ),
                    tooltip: 'Исходный код',
                    onPressed: () => setEditorState(() => viewMode = 2),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.edit_note,
                      color: viewMode == 3 ? const Color(0xFF38BDF8) : null,
                    ),
                    tooltip: 'Живое редактирование',
                    onPressed: () => setEditorState(() => viewMode = 3),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Color(0xFF38BDF8)),
                    onPressed: () {
                      widget.onSaveNote(
                        existingNote: existingNote,
                        title: titleController.text.trim().isEmpty
                            ? 'Без названия'
                            : titleController.text.trim(),
                        body: liveController.text.trim(),
                        image: imagePath,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              body: Column(
                children: [
                  if (viewMode != 1)
                    Container(
                      height: 42,
                      color: isDark
                          ? const Color(0xFF161B22)
                          : const Color(0xFFE2E8F0),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          IconButton(
                            icon: const Text(
                              'H1',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => insertMarkdown('# '),
                          ),
                          IconButton(
                            icon: const Text(
                              'H2',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => insertMarkdown('## '),
                          ),
                          IconButton(
                            icon: const Icon(Icons.format_bold, size: 18),
                            onPressed: () => insertMarkdown('**', '**'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.format_italic, size: 18),
                            onPressed: () => insertMarkdown('*', '*'),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.check_box_outlined,
                              size: 18,
                            ),
                            onPressed: () => insertMarkdown('- [ ] '),
                          ),
                          IconButton(
                            icon: const Icon(Icons.format_quote, size: 18),
                            onPressed: () => insertMarkdown('> '),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 20,
                            ),
                            onPressed: () async {
                              final picked = await _imagePicker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (picked != null) {
                                setEditorState(() => imagePath = picked.path);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: titleController,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Заголовок...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const Divider(),
                  if (imagePath.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(imagePath),
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    setEditorState(() => imagePath = ''),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: viewMode == 1
                          ? SingleChildScrollView(
                              child: _buildSafeMarkdown(
                                liveController.text,
                                textPrimary,
                              ),
                            )
                          : TextField(
                              controller: liveController,
                              maxLines: null,
                              style: TextStyle(
                                color: textPrimary,
                                fontFamily: viewMode == 2 ? 'monospace' : null,
                                height: 1.45,
                              ),
                              decoration: InputDecoration(
                                hintText: viewMode == 3
                                    ? 'Живое редактирование (заголовки #, **жирный**, > цитата применяются на лету)...'
                                    : 'Исходный код...',
                                border: InputBorder.none,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final Color textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final Color textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);

    List<Map<String, dynamic>> displayedNotes = List.from(widget.notes);

    if (_noteSearchQuery.trim().isNotEmpty) {
      final q = _noteSearchQuery.toLowerCase();
      displayedNotes = displayedNotes.where((n) {
        final title = (n['title'] as String? ?? '').toLowerCase();
        final body = (n['body'] as String? ?? '').toLowerCase();
        return title.contains(q) || body.contains(q);
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openObsidianNoteEditor(),
        backgroundColor: const Color(0xFF2C69D1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Мои Заметки',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(
                  _notesLayout == 'Плитки' ? Icons.view_list : Icons.grid_view,
                  color: const Color(0xFF38BDF8),
                ),
                tooltip: _notesLayout == 'Плитки'
                    ? 'Режим списка'
                    : 'Режим плиток',
                onPressed: _toggleLayout,
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                    controller: _noteSearchController,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Поиск по заметкам (Obsidian Vault)...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _noteSearchQuery = val),
                  ),
                ),
                if (_noteSearchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      _noteSearchController.clear();
                      setState(() => _noteSearchQuery = '');
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (widget.isLoadingNotes)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (displayedNotes.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'Заметок не найдено.',
                  style: TextStyle(color: textSecondary),
                ),
              ),
            )
          else if (_notesLayout == 'Плитки')
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedNotes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (ctx, i) {
                final n = displayedNotes[i];
                final imagePath = n['image'] as String? ?? '';

                return InkWell(
                  onTap: () => _openObsidianNoteEditor(existingNote: n),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161B22) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF30363D)
                            : const Color(0xFFD0D7DE),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imagePath.isNotEmpty)
                          Image.file(
                            File(imagePath),
                            height: 70,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n['title'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                n['date'] ?? '',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n['body'] ?? '',
                                maxLines: imagePath.isNotEmpty ? 2 : 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedNotes.length,
              itemBuilder: (ctx, i) {
                final n = displayedNotes[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      n['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      n['body'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      n['date'] ?? '',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => _openObsidianNoteEditor(existingNote: n),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
