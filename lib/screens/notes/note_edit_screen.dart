import 'dart:async';
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
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/notes_provider.dart';
import '../../theme/app_theme.dart';

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

  int _fontSize = 16;
  bool _useMonospace = false;
  bool _showFormatToolbar = true;
  bool _useTrashBeforeDelete = true;
  Timer? _autoSaveTimer;

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

    _isViewMode = note != null;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final startInPreview = prefs.getBool('notes_start_in_preview') ?? false;
    final fontSize = prefs.getInt('notes_font_size') ?? 16;
    final monospace = prefs.getBool('notes_use_monospace') ?? false;
    final formatToolbar = prefs.getBool('notes_show_format_toolbar') ?? true;
    final trashBeforeDelete =
        prefs.getBool('notes_use_trash_before_delete') ?? true;
    final autoSaveInterval =
        prefs.getString('notes_autosave_interval') ?? 'Мгновенно при выходе';

    if (mounted) {
      setState(() {
        _fontSize = fontSize;
        _useMonospace = monospace;
        _showFormatToolbar = formatToolbar;
        _useTrashBeforeDelete = trashBeforeDelete;
        if (widget.initialNote != null && startInPreview) {
          _isViewMode = true;
        }
      });
    }

    if (autoSaveInterval == 'Каждые 30 секунд') {
      _autoSaveTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _saveNote(),
      );
    } else if (autoSaveInterval == 'Каждую минуту') {
      _autoSaveTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _saveNote(),
      );
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
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

    ref.read(notesProvider.notifier).saveNote(
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

  void _showHeadingSelector(BuildContext context, AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Выбор заголовка',
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (int i = 1; i <= 5; i++)
                ListTile(
                  title: Text(
                    'Заголовок H$i',
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      color: colors.accent,
                      fontSize: 22.0 - (i * 2.0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyHeading(i);
                  },
                ),
              const SizedBox(height: 8),
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

  Future<void> _exportAsMarkdown(AppColorsExtension colors) async {
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
          SnackBar(
            content: const Text('Файл .md успешно сохранен',
                style: TextStyle(fontFamily: 'Onest')),
            backgroundColor: colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения .md: $e',
                style: const TextStyle(fontFamily: 'Onest')),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportAsWord(AppColorsExtension colors) async {
    try {
      final fileName = _getSanitizedFileName();
      final title = _titleController.text.trim();
      final body = _bodyController.text.trim();

      final bodyHtml = md.markdownToHtml(
        body,
        extensionSet: md.ExtensionSet.gitHubFlavored,
      );

      final wordDocHtml = '''
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
          SnackBar(
            content: const Text('Файл Word успешно сохранен',
                style: TextStyle(fontFamily: 'Onest')),
            backgroundColor: colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения Word: $e',
                style: const TextStyle(fontFamily: 'Onest')),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }

  void _showShareMenu(BuildContext context, AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                    fontFamily: 'Unbounded',
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.send_outlined, color: colors.accent),
                title: Text('Отправить как текст',
                    style: TextStyle(fontFamily: 'Onest', color: colors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  Share.share(
                      '${_titleController.text}\n\n${_bodyController.text}');
                },
              ),
              ListTile(
                leading: Icon(Icons.image_outlined, color: colors.warning),
                title: Text('Отправить прикрепленные фото',
                    style: TextStyle(fontFamily: 'Onest', color: colors.text)),
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
                        content: Text('В заметке нет прикрепленных изображений',
                            style: TextStyle(fontFamily: 'Onest')),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.download_for_offline_outlined,
                    color: colors.accent),
                title: Text('Сохранить в память как Markdown (.md)',
                    style: TextStyle(fontFamily: 'Onest', color: colors.text)),
                subtitle: Text('Выбор папки на устройстве',
                    style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 11,
                        color: colors.text.withValues(alpha: 0.5))),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportAsMarkdown(colors);
                },
              ),
              ListTile(
                leading: Icon(Icons.description_outlined, color: colors.accent),
                title: Text('Сохранить в память для Word (.doc)',
                    style: TextStyle(fontFamily: 'Onest', color: colors.text)),
                subtitle: Text('Выбор папки на устройстве',
                    style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 11,
                        color: colors.text.withValues(alpha: 0.5))),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportAsWord(colors);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showMoreMenu(BuildContext context, AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.alarm, color: colors.accent),
                title: Text('Напоминание',
                    style: TextStyle(fontFamily: 'Onest', color: colors.text)),
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
                            style: const TextStyle(fontFamily: 'Onest')),
                      ),
                    );
                  }
                },
              ),
              if (widget.initialNote != null)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colors.error),
                  title: Text(
                    'Удалить',
                    style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.error,
                        fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_useTrashBeforeDelete) {
                      _confirmDeleteDialog(colors);
                    } else {
                      _performDelete();
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

  void _confirmDeleteDialog(AppColorsExtension colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Удалить заметку?',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: Text(
          'Заметка будет удалена из списка.',
          style: TextStyle(
              fontFamily: 'Onest', color: colors.text.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена',
                style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.6))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _performDelete();
            },
            child: const Text('Удалить',
                style: TextStyle(
                    fontFamily: 'Onest', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _performDelete() {
    if (widget.initialNote != null) {
      ref.read(notesProvider.notifier).deleteNote(widget.initialNote!.id);
    }
    Navigator.pop(context);
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
    AppColorsExtension colors,
  ) {
    if (rawText.trim().isEmpty) {
      return Text(
        'Пустая заметка',
        style: TextStyle(
          fontFamily: 'Onest',
          color: colors.text.withValues(alpha: 0.4),
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
        styleSheet: _getMarkdownStyleSheet(colors),
        builders: {'tag': _TagElementBuilder(onGetColor: _getTagColor)},
      ),
    );
  }

  MarkdownStyleSheet _getMarkdownStyleSheet(AppColorsExtension colors) {
    return MarkdownStyleSheet(
      p: TextStyle(
        fontFamily: _useMonospace ? 'monospace' : 'Onest',
        color: colors.text,
        fontSize: _fontSize.toDouble(),
        height: 1.5,
      ),
      h1: TextStyle(
        fontFamily: 'Unbounded',
        color: colors.accent,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      h2: TextStyle(
        fontFamily: 'Unbounded',
        color: colors.accent,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      h3: TextStyle(
        fontFamily: 'Unbounded',
        color: colors.accent,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      h4: TextStyle(
        fontFamily: 'Onest',
        color: colors.text,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      h5: TextStyle(
        fontFamily: 'Onest',
        color: colors.text,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
      strong: TextStyle(
          fontFamily: 'Onest', color: colors.text, fontWeight: FontWeight.bold),
      em: TextStyle(
          fontFamily: 'Onest', color: colors.text, fontStyle: FontStyle.italic),
      del: TextStyle(
        fontFamily: 'Onest',
        color: colors.text.withValues(alpha: 0.45),
        decoration: TextDecoration.lineThrough,
      ),
      code: TextStyle(
        backgroundColor: colors.nested,
        color: colors.text,
        fontSize: (_fontSize - 2).toDouble(),
        fontFamily: _useMonospace ? 'monospace' : null,
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
                borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
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
    final colors = context.colors;
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () {
            _saveNote();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isViewMode ? Icons.edit_outlined : Icons.visibility_outlined,
              color: colors.accent,
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
            icon: Icon(Icons.share_outlined, color: colors.text),
            tooltip: 'Поделиться',
            onPressed: () => _showShareMenu(context, colors),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: colors.text),
            tooltip: 'Опции',
            onPressed: () => _showMoreMenu(context, colors),
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
                        fontFamily: 'Unbounded',
                        color: colors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  TextField(
                    controller: _titleController,
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      color: colors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Заголовок',
                      hintStyle: TextStyle(
                        fontFamily: 'Unbounded',
                        color: colors.text.withValues(alpha: 0.35),
                        fontSize: 20,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Создано: ${dateFormat.format(_createdAt)}${_updatedAt != null ? '   |   Изменено: ${dateFormat.format(_updatedAt!)}' : ''}',
                    style: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.5),
                        fontSize: 11),
                  ),
                ),
                _buildAttachmentsList(),
                if (_isViewMode)
                  _buildViewBody(_bodyController.text, colors)
                else
                  TextField(
                    controller: _bodyController,
                    maxLines: null,
                    autofocus: widget.initialNote == null,
                    style: TextStyle(
                      fontFamily: _useMonospace ? 'monospace' : 'Onest',
                      color: colors.text,
                      fontSize: _fontSize.toDouble(),
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Начните писать... Используйте #теги',
                      hintStyle: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.35),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
              ],
            ),
          ),
          if (!_isViewMode && _showFormatToolbar)
            Container(
              decoration: BoxDecoration(
                color: colors.card,
                border: Border(top: BorderSide(color: colors.nested)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.undo, size: 20, color: colors.text),
                      tooltip: 'Назад',
                      onPressed: _undo,
                    ),
                    IconButton(
                      icon: Icon(Icons.redo, size: 20, color: colors.text),
                      tooltip: 'Вперед',
                      onPressed: _redo,
                    ),
                    const SizedBox(width: 2),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showHeadingSelector(context, colors),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          'Hn',
                          style: TextStyle(
                            fontFamily: 'Unbounded',
                            color: colors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.format_bold, size: 20, color: colors.text),
                      tooltip: 'Полужирный',
                      onPressed: () => _applyFormat('**', '**'),
                    ),
                    IconButton(
                      icon: Icon(Icons.format_italic,
                          size: 20, color: colors.text),
                      tooltip: 'Курсив',
                      onPressed: () => _applyFormat('*', '*'),
                    ),
                    IconButton(
                      icon: Icon(Icons.format_strikethrough,
                          size: 20, color: colors.text),
                      tooltip: 'Зачеркнутый',
                      onPressed: () => _applyFormat('~~', '~~'),
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.attach_file, size: 20, color: colors.text),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Onest',
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
