import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/diary_provider.dart';
import '../../theme/app_theme.dart';

class DiaryDetailScreen extends ConsumerStatefulWidget {
  final String? diaryId;
  final bool isInitialViewMode;

  const DiaryDetailScreen({
    super.key,
    this.diaryId,
    this.isInitialViewMode = false,
  });

  @override
  ConsumerState<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends ConsumerState<DiaryDetailScreen> {
  late bool _isViewMode;
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  late DateTime _selectedDate;
  late String _selectedMood;
  final List<String> _images = [];

  bool _isSavedManually = false;
  String? _currentDiaryId;
  List<DiaryMood> _moodList = defaultMoods;

  @override
  void initState() {
    super.initState();
    _currentDiaryId = widget.diaryId;
    _isViewMode = widget.isInitialViewMode && widget.diaryId != null;
    _loadMoodStyle();

    final all = ref.read(diaryProvider);
    final item = all.where((d) => d.id == _currentDiaryId).firstOrNull;

    _titleController = TextEditingController(text: item?.title ?? '');
    _contentController = TextEditingController(text: item?.content ?? '');
    _selectedDate = item?.date ?? DateTime.now();
    _selectedMood = item?.mood ?? 'good';

    if (item != null) {
      _images.addAll(item.images);
    }
  }

  Future<void> _loadMoodStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final style = prefs.getString('diary_mood_style') ?? 'classic';
    if (mounted) {
      setState(() => _moodList = getDiaryMoodStyle(style));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _loadDiary(DiaryItem item) {
    setState(() {
      _currentDiaryId = item.id;
      _titleController.text = item.title;
      _contentController.text = item.content;
      _selectedDate = item.date;
      _selectedMood = item.mood;
      _images.clear();
      _images.addAll(item.images);
    });
  }

  Future<void> _saveAsDraftIfNeeded() async {
    if (_isSavedManually || _isViewMode) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isNotEmpty || content.isNotEmpty || _images.isNotEmpty) {
      try {
        await ref.read(diaryProvider.notifier).saveDiary(
              id: _currentDiaryId,
              title: title.isEmpty ? 'Черновик' : title,
              content: content,
              date: _selectedDate,
              mood: _selectedMood,
              images: _images,
              isDraft: true,
            );
      } catch (e) {
        debugPrint('Ошибка автосохранения черновика: $e');
      }
    }
  }

  Future<void> _handleBack() async {
    await _saveAsDraftIfNeeded();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        if (!_images.contains(picked.path)) {
          _images.add(picked.path);
        }
      });
    }
  }

  Future<void> _saveManually(AppColorsExtension colors) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Заполните заголовок или текст дневника',
              style: TextStyle(fontFamily: 'Onest')),
          backgroundColor: colors.error,
        ),
      );
      return;
    }

    _isSavedManually = true;

    try {
      await ref.read(diaryProvider.notifier).saveDiary(
            id: _currentDiaryId,
            title: title.isEmpty ? 'Без заголовка' : title,
            content: content,
            date: _selectedDate,
            mood: _selectedMood,
            images: _images,
            isDraft: false,
          );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _isSavedManually = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e',
                style: const TextStyle(fontFamily: 'Onest')),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }

  void _showWordAndCharCount(AppColorsExtension colors) {
    final text = '${_titleController.text} ${_contentController.text}'.trim();
    final chars = text.length;
    final charsWithoutSpaces = text.replaceAll(RegExp(r'\s+'), '').length;
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Статистика текста',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Количество слов: $words',
              style: TextStyle(
                  fontFamily: 'Onest', color: colors.text, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Символов (с пробелами): $chars',
              style: TextStyle(
                  fontFamily: 'Onest', color: colors.text, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Символов (без пробелов): $charsWithoutSpaces',
              style: TextStyle(
                  fontFamily: 'Onest', color: colors.text, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Закрыть',
              style: TextStyle(
                  fontFamily: 'Onest',
                  color: colors.accent,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('d MMMM yyyy', 'ru');
    final mood = _moodList.firstWhere(
      (m) => m.id == _selectedMood,
      orElse: () => _moodList.first,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  dateFormat.format(_selectedDate),
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Настроение: ${mood.label}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.blueGrey700,
                  ),
                ),
                pw.Divider(thickness: 1.5),
                pw.SizedBox(height: 12),
                if (_titleController.text.isNotEmpty) ...[
                  pw.Text(
                    _titleController.text,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 14),
                ],
                pw.Text(
                  _contentController.text,
                  style: const pw.TextStyle(fontSize: 13, lineSpacing: 4),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          '${_titleController.text.isEmpty ? "Дневник" : _titleController.text}.pdf',
    );
  }

  void _showMoreMenu(BuildContext context, AppColorsExtension colors) {
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
            ListTile(
              leading: Icon(
                Icons.analytics_outlined,
                color: colors.accent,
              ),
              title: Text(
                'Подсчет слов и знаков',
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showWordAndCharCount(colors);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.picture_as_pdf_outlined,
                color: colors.warning,
              ),
              title: Text(
                'Экспорт в PDF',
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _exportToPdf();
              },
            ),
            if (_currentDiaryId != null)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: colors.error,
                ),
                title: Text(
                  'Удалить дневник',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(diaryProvider.notifier)
                      .deleteDiary(_currentDiaryId!);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final diaries = ref.watch(diaryProvider);

    final currentIndex = diaries.indexWhere((d) => d.id == _currentDiaryId);
    final hasPrevious = currentIndex != -1 && currentIndex < diaries.length - 1;
    final hasNext = currentIndex > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(
          backgroundColor: colors.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.text),
            onPressed: _handleBack,
          ),
          actions: [
            if (_isViewMode)
              IconButton(
                icon: Icon(Icons.edit_outlined, color: colors.accent),
                tooltip: 'Редактировать',
                onPressed: () => setState(() => _isViewMode = false),
              ),
            IconButton(
              icon: Icon(Icons.more_vert, color: colors.text),
              tooltip: 'Дополнительно',
              onPressed: () => _showMoreMenu(context, colors),
            ),
            if (!_isViewMode)
              TextButton(
                onPressed: () => _saveManually(colors),
                child: Text(
                  'Сохранить',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: _isViewMode ? null : _pickDate,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: colors.accent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('d MMMM yyyy', 'ru')
                                    .format(_selectedDate),
                                style: TextStyle(
                                  fontFamily: 'Unbounded',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.text,
                                ),
                              ),
                              if (!_isViewMode)
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 20,
                                  color: colors.text.withValues(alpha: 0.5),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_isViewMode)
                        Text(
                          _moodList
                              .firstWhere(
                                (m) => m.id == _selectedMood,
                                orElse: () => _moodList.first,
                              )
                              .emoji,
                          style: const TextStyle(fontSize: 28),
                        )
                      else
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: colors.card,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(22),
                                ),
                              ),
                              builder: (ctx) => Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Как ваше настроение?',
                                      style: TextStyle(
                                        fontFamily: 'Unbounded',
                                        color: colors.text,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      alignment: WrapAlignment.center,
                                      children: _moodList.map((m) {
                                        final isSel = m.id == _selectedMood;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(
                                                () => _selectedMood = m.id);
                                            Navigator.pop(ctx);
                                          },
                                          child: Column(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: isSel
                                                      ? colors.accent
                                                          .withValues(
                                                              alpha: 0.2)
                                                      : colors.nested
                                                          .withValues(
                                                              alpha: 0.3),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isSel
                                                        ? colors.accent
                                                        : Colors.transparent,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Text(
                                                  m.emoji,
                                                  style: const TextStyle(
                                                    fontSize: 32,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                m.label,
                                                style: TextStyle(
                                                  fontFamily: 'Onest',
                                                  fontSize: 11,
                                                  fontWeight: isSel
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: isSel
                                                      ? colors.accent
                                                      : colors.text.withValues(
                                                          alpha: 0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colors.card,
                              border: Border.all(color: colors.nested),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _moodList
                                      .firstWhere(
                                        (m) => m.id == _selectedMood,
                                        orElse: () => _moodList.first,
                                      )
                                      .emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: colors.text.withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  Divider(height: 24, color: colors.nested),
                  if (_isViewMode)
                    Text(
                      _titleController.text.isEmpty
                          ? 'Без заголовка'
                          : _titleController.text,
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    )
                  else
                    TextField(
                      controller: _titleController,
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Заголовок дня...',
                        hintStyle: TextStyle(
                          fontFamily: 'Unbounded',
                          color: colors.text.withValues(alpha: 0.35),
                          fontSize: 19,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (_images.isNotEmpty) ...[
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final file = File(_images[i]);
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  file,
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (!_isViewMode)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => _images.removeAt(i)),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
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
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_isViewMode)
                    Text(
                      _contentController.text.isEmpty
                          ? 'Текст отсутствует'
                          : _contentController.text,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 15,
                        height: 1.6,
                        color: colors.text,
                      ),
                    )
                  else
                    TextField(
                      controller: _contentController,
                      maxLines: null,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 15,
                        height: 1.6,
                        color: colors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Напишите, как прошел ваш день...',
                        hintStyle: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.text.withValues(alpha: 0.35),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.card,
                border: Border(top: BorderSide(color: colors.nested)),
              ),
              child: _isViewMode
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 28),
                          tooltip: 'Предыдущая запись',
                          color: hasPrevious
                              ? colors.text
                              : colors.text.withValues(alpha: 0.25),
                          onPressed: hasPrevious
                              ? () => _loadDiary(diaries[currentIndex + 1])
                              : null,
                        ),
                        Text(
                          '${currentIndex + 1} из ${diaries.length}',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontSize: 13,
                            color: colors.text.withValues(alpha: 0.6),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 28),
                          tooltip: 'Следующая запись',
                          color: hasNext
                              ? colors.text
                              : colors.text.withValues(alpha: 0.25),
                          onPressed: hasNext
                              ? () => _loadDiary(diaries[currentIndex - 1])
                              : null,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.add_photo_alternate_outlined,
                            color: colors.accent,
                          ),
                          tooltip: 'Прикрепить фото',
                          onPressed: _pickImage,
                        ),
                        const Spacer(),
                        Text(
                          'Черновик сохранится при выходе',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontSize: 11,
                            color: colors.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
