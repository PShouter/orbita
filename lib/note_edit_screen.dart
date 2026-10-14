import 'dart:convert';
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:share_plus/share_plus.dart';

import 'providers/notes_provider.dart';

class NoteEditScreen extends ConsumerStatefulWidget {
  final NoteItem? initialNote;
  final bool isDarkMode;

  const NoteEditScreen({super.key, this.initialNote, this.isDarkMode = true});

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  List<String> _attachments = [];

  late bool _isViewMode;

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _isHistoryAction = false;

  late DateTime _createdAt;
  DateTime? _updatedAt;

  static const List<Color> _tagPalette = [
    Color(0xFF38BDF8),
    Color(0xFF818CF8),
    Color(0xFFA78BFA),
    Color(0xFFF472B6),
    Color(0xFFFB7185),
    Color(0xFFF87171),
    Color(0xFFFB923C),
    Color(0xFFFBBF24),
    Color(0xFF34D399),
    Color(0xFF2DD4BF),
    Color(0xFF22D3EE),
  ];

  @override
  void initState() {
    super.initState();
    final note = widget.initialNote;

    _isViewMode = note != null;

    _titleController = TextEditingController(text: note?.title ?? '');
    _bodyController = TextEditingController(text: note?.body ?? '');

    _attachments = [];
    if (note != null) {
      if (note.imagePath != null && note.imagePath!.isNotEmpty) {
        _attachments.add(note.imagePath!);
      }
      for (final att in note.attachments) {
        if (!_attachments.contains(att)) {
          _attachments.add(att);
        }
      }
    }

    _createdAt = note?.createdAt ?? DateTime.now();
    _updatedAt = note?.updatedAt;

    _undoStack.add(_bodyController.text);

    _bodyController.addListener(() {
      if (!_isHistoryAction) {
        if (_undoStack.isEmpty || _undoStack.last != _bodyController.text) {
          _undoStack.add(_bodyController.text);
          _redoStack.clear();
        }
      }
    });
  }

  @override
  void dispose() {
    _saveNote();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty && body.isEmpty && _attachments.isEmpty) {
      return;
    }

    ref
        .read(notesProvider.notifier)
        .saveNote(
          id: widget.initialNote?.id,
          title: title.isEmpty ? 'Без названия' : title,
          body: body,
          imagePath: _attachments.isNotEmpty ? _attachments.first : null,
          attachments: _attachments,
        );
  }

  void _undo() {
    if (_undoStack.length > 1) {
      _isHistoryAction = true;
      final current = _undoStack.removeLast();
      _redoStack.add(current);
      final previous = _undoStack.last;
      _bodyController.text = previous;
      _bodyController.selection = TextSelection.collapsed(
        offset: previous.length,
      );
      _isHistoryAction = false;
      setState(() {});
      HapticFeedback.selectionClick();
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      _isHistoryAction = true;
      final next = _redoStack.removeLast();
      _undoStack.add(next);
      _bodyController.text = next;
      _bodyController.selection = TextSelection.collapsed(offset: next.length);
      _isHistoryAction = false;
      setState(() {});
      HapticFeedback.selectionClick();
    }
  }

  void _applyFormat(String prefix, [String suffix = '']) {
    HapticFeedback.lightImpact();
    final text = _bodyController.text;
    final selection = _bodyController.selection;

    if (!selection.isValid || selection.isCollapsed) {
      final insertPos = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(insertPos, insertPos, '$prefix$suffix');
      _bodyController.text = newText;
      _bodyController.selection = TextSelection.collapsed(
        offset: insertPos + prefix.length,
      );
      return;
    }

    final selectedText = selection.textInside(text);
    final replacement = '$prefix$selectedText$suffix';
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      replacement,
    );
    _bodyController.text = newText;
    _bodyController.selection = TextSelection(
      baseOffset: selection.start + prefix.length,
      extentOffset: selection.start + prefix.length + selectedText.length,
    );
  }

  void _applyHeading(int level) {
    HapticFeedback.selectionClick();
    final hashes = '${'#' * level} ';
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final pos = selection.isValid ? selection.start : text.length;

    final prefix = (pos > 0 && !text.substring(0, pos).endsWith('\n'))
        ? '\n$hashes'
        : hashes;
    final newText = text.replaceRange(pos, pos, prefix);
    _bodyController.text = newText;
    _bodyController.selection = TextSelection.collapsed(
      offset: pos + prefix.length,
    );
  }

  Future<void> _attachImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        if (!_attachments.contains(picked.path)) {
          _attachments.add(picked.path);
        }
      });
      HapticFeedback.mediumImpact();
    }
  }

  void _showHeadingSelector(
    BuildContext context,
    Color cardBg,
    Color textPrimary,
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
                padding: const EdgeInsets.all(14.0),
                child: Text(
                  'Выбор заголовка',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              for (int i = 1; i <= 5; i++)
                ListTile(
                  title: Text(
                    'Заголовок H$i',
                    style: TextStyle(
                      color: const Color(0xFF38BDF8),
                      fontSize: 24.0 - (i * 2.0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyHeading(i);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  String _getSanitizedFileName() {
    final rawTitle = _titleController.text.trim();
    final name = rawTitle.isEmpty ? 'Заметка' : rawTitle;
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  Future<void> _exportAsMarkdown() async {
    try {
      final fileName = _getSanitizedFileName();
      final content =
          '# ${_titleController.text.trim()}\n\n${_bodyController.text.trim()}';
      final bytes = Uint8List.fromList(utf8.encode(content));

      final path = await FileSaver.instance.saveAs(
        name: '$fileName.md',
        bytes: bytes,
        mimeType: MimeType.other,
      );

      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл .md успешно сохранен'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка сохранения .md: $e')));
      }
    }
  }

  Future<void> _exportAsWord() async {
    try {
      final fileName = _getSanitizedFileName();
      final title = _titleController.text.trim();
      final body = _bodyController.text.trim();

      final bodyHtml = md.markdownToHtml(
        body,
        extensionSet: md.ExtensionSet.gitHubFlavored,
      );

      final wordDocHtml =
          '''
<html xmlns:o='urn:schemas-microsoft-com:office:office' 
      xmlns:w='urn:schemas-microsoft-com:office:word' 
      xmlns='http://www.w3.org/TR/REC-html40'>
<head>
  <meta charset='utf-8'>
  <title>$title</title>
  <style>
    body { font-family: 'Calibri', sans-serif; font-size: 11pt; line-height: 1.5; color: #000; }
    h1 { font-size: 18pt; color: #1F4E79; margin-bottom: 8pt; }
    h2 { font-size: 15pt; color: #2E75B6; margin-bottom: 6pt; }
    h3 { font-size: 13pt; color: #5B9BD5; margin-bottom: 4pt; }
    p { margin-bottom: 6pt; }
  </style>
</head>
<body>
  <h1>$title</h1>
  $bodyHtml
</body>
</html>
''';

      final List<int> bytesList = [
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode(wordDocHtml),
      ];
      final bytes = Uint8List.fromList(bytesList);

      final path = await FileSaver.instance.saveAs(
        name: '$fileName.doc',
        bytes: bytes,
        mimeType: MimeType.microsoftWord,
      );

      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл Word успешно сохранен'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка сохранения Word: $e')));
      }
    }
  }

  void _showShareMenu(BuildContext context, Color cardBg, Color textPrimary) {
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
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Поделиться и экспорт',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.send_outlined,
                  color: Color(0xFF38BDF8),
                ),
                title: Text(
                  'Отправить как текст',
                  style: TextStyle(color: textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Share.share(
                    '${_titleController.text}\n\n${_bodyController.text}',
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.image_outlined,
                  color: Colors.orangeAccent,
                ),
                title: Text(
                  'Отправить прикрепленные фото',
                  style: TextStyle(color: textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (_attachments.isNotEmpty &&
                      File(_attachments.first).existsSync()) {
                    Share.shareXFiles(
                      _attachments.map((p) => XFile(p)).toList(),
                      text: _titleController.text,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'В заметке нет прикрепленных изображений',
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.download_for_offline_outlined,
                  color: Colors.tealAccent,
                ),
                title: Text(
                  'Сохранить в память как Markdown (.md)',
                  style: TextStyle(color: textPrimary),
                ),
                subtitle: const Text(
                  'Выбор папки на устройстве',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportAsMarkdown();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: Colors.blueAccent,
                ),
                title: Text(
                  'Сохранить в память для Word (.doc)',
                  style: TextStyle(color: textPrimary),
                ),
                subtitle: const Text(
                  'Выбор папки на устройстве',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportAsWord();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMoreMenu(BuildContext context, Color cardBg, Color textPrimary) {
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
              ListTile(
                leading: const Icon(Icons.alarm, color: Color(0xFF38BDF8)),
                title: Text(
                  'Напоминание',
                  style: TextStyle(color: textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Напоминание установлено на ${time.format(context)}',
                        ),
                      ),
                    );
                  }
                },
              ),
              if (widget.initialNote != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Удалить',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(notesProvider.notifier)
                        .deleteNote(widget.initialNote!.id);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Color _getTagColor(String tag) {
    final int hash = tag.hashCode.abs();
    return _tagPalette[hash % _tagPalette.length];
  }

  String _prepareMarkdownForView(String source) {
    if (source.isEmpty) return '';

    String formatted = source;

    formatted = formatted.replaceAllMapped(
      RegExp(r'#([а-яА-Яa-zA-Z0-9_\-]+)'),
      (m) => '[${m.group(0)}](tag:${m.group(0)})',
    );

    final lines = formatted.split('\n');
    final processedLines = lines.map((line) {
      if (line.trim().isEmpty) return '';
      return '$line  ';
    }).toList();

    return processedLines.join('\n');
  }

  Widget _buildViewBody(
    String rawText,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    if (rawText.trim().isEmpty) {
      return Text(
        'Пустая заметка',
        style: TextStyle(
          color: textSecondary.withValues(alpha: 0.5),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final markdownData = _prepareMarkdownForView(rawText);

    return Align(
      alignment: Alignment.topLeft,
      child: MarkdownBody(
        data: markdownData,
        selectable: true,
        softLineBreak: true,
        styleSheet: _getMarkdownStyleSheet(textPrimary, textSecondary, isDark),
        builders: {'tag': _TagElementBuilder(onGetColor: _getTagColor)},
      ),
    );
  }

  MarkdownStyleSheet _getMarkdownStyleSheet(
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return MarkdownStyleSheet(
      p: TextStyle(color: textPrimary, fontSize: 16, height: 1.5),
      h1: const TextStyle(
        color: Color(0xFF38BDF8),
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
      h2: const TextStyle(
        color: Color(0xFF38BDF8),
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      h3: const TextStyle(
        color: Color(0xFF38BDF8),
        fontSize: 19,
        fontWeight: FontWeight.bold,
      ),
      h4: TextStyle(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
      h5: TextStyle(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
      strong: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
      em: TextStyle(color: textPrimary, fontStyle: FontStyle.italic),
      del: TextStyle(
        color: textSecondary,
        decoration: TextDecoration.lineThrough,
      ),
      code: TextStyle(
        backgroundColor: isDark
            ? const Color(0xFF21262D)
            : const Color(0xFFE1E4E8),
        color: textPrimary,
        fontSize: 14,
      ),
    );
  }

  Widget _buildAttachmentsList() {
    if (_attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _attachments.map((path) {
        final file = File(path);
        if (!file.existsSync()) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  file,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              if (!_isViewMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _attachments.remove(path);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () {
            _saveNote();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isViewMode ? Icons.edit_outlined : Icons.visibility_outlined,
              color: const Color(0xFF38BDF8),
            ),
            tooltip: _isViewMode ? 'Редактировать' : 'Просмотр',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isViewMode = !_isViewMode;
              });
              if (_isViewMode) {
                FocusScope.of(context).unfocus();
                _saveNote();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.share_outlined, color: textPrimary),
            tooltip: 'Поделиться',
            onPressed: () => _showShareMenu(context, cardBg, textPrimary),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: textPrimary),
            tooltip: 'Опции',
            onPressed: () => _showMoreMenu(context, cardBg, textPrimary),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (_isViewMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _titleController.text.isEmpty
                          ? 'Без названия'
                          : _titleController.text,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  TextField(
                    controller: _titleController,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Заголовок',
                      hintStyle: TextStyle(
                        color: textSecondary.withValues(alpha: 0.5),
                        fontSize: 22,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Создано: ${dateFormat.format(_createdAt)}${_updatedAt != null ? '   |   Изменено: ${dateFormat.format(_updatedAt!)}' : ''}',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ),
                _buildAttachmentsList(),
                if (_isViewMode)
                  _buildViewBody(
                    _bodyController.text,
                    textPrimary,
                    textSecondary,
                    isDark,
                  )
                else
                  TextField(
                    controller: _bodyController,
                    maxLines: null,
                    autofocus: widget.initialNote == null,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Начните писать... Используйте #теги',
                      hintStyle: TextStyle(
                        color: textSecondary.withValues(alpha: 0.4),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
              ],
            ),
          ),
          if (!_isViewMode)
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.undo, size: 20, color: textPrimary),
                      tooltip: 'Назад',
                      onPressed: _undo,
                    ),
                    IconButton(
                      icon: Icon(Icons.redo, size: 20, color: textPrimary),
                      tooltip: 'Вперед',
                      onPressed: _redo,
                    ),
                    const SizedBox(width: 2),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () =>
                          _showHeadingSelector(context, cardBg, textPrimary),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Text(
                          'Hn',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.format_bold,
                        size: 20,
                        color: textPrimary,
                      ),
                      tooltip: 'Полужирный',
                      onPressed: () => _applyFormat('**', '**'),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.format_italic,
                        size: 20,
                        color: textPrimary,
                      ),
                      tooltip: 'Курсив',
                      onPressed: () => _applyFormat('*', '*'),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.format_strikethrough,
                        size: 20,
                        color: textPrimary,
                      ),
                      tooltip: 'Зачеркнутый',
                      onPressed: () => _applyFormat('~~', '~~'),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.attach_file,
                        size: 20,
                        color: textPrimary,
                      ),
                      tooltip: 'Прикрепить файл',
                      onPressed: _attachImage,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TagElementBuilder extends MarkdownElementBuilder {
  final Color Function(String tag) onGetColor;

  _TagElementBuilder({required this.onGetColor});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    final color = onGetColor(text);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
