import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'providers/diary_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _currentDiaryId = widget.diaryId;
    _isViewMode = widget.isInitialViewMode && widget.diaryId != null;

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
        await ref
            .read(diaryProvider.notifier)
            .saveDiary(
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

  Future<void> _saveManually() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните заголовок или текст дневника')),
      );
      return;
    }

    _isSavedManually = true;

    try {
      await ref
          .read(diaryProvider.notifier)
          .saveDiary(
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
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showWordAndCharCount() {
    final text = '${_titleController.text} ${_contentController.text}'.trim();
    final chars = text.length;
    final charsWithoutSpaces = text.replaceAll(RegExp(r'\s+'), '').length;
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Статистика текста'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Количество слов: $words',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Символов (с пробелами): $chars',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Символов (без пробелов): $charsWithoutSpaces',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('d MMMM yyyy', 'ru');
    final mood = defaultMoods.firstWhere(
      (m) => m.id == _selectedMood,
      orElse: () => defaultMoods.first,
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

  void _showMoreMenu(BuildContext context, Color cardBg, Color textPrimary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.analytics_outlined,
                color: Color(0xFF38BDF8),
              ),
              title: Text(
                'Подсчет слов и знаков',
                style: TextStyle(color: textPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showWordAndCharCount();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: Colors.orangeAccent,
              ),
              title: Text(
                'Экспорт в PDF',
                style: TextStyle(color: textPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _exportToPdf();
              },
            ),
            if (_currentDiaryId != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Удалить дневник',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(diaryProvider.notifier)
                      .deleteDiary(_currentDiaryId!);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diaries = ref.watch(diaryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
        : const Color(0xFFE1E4E8);

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
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textPrimary),
            onPressed: _handleBack,
          ),
          actions: [
            if (_isViewMode)
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8)),
                tooltip: 'Редактировать',
                onPressed: () => setState(() => _isViewMode = false),
              ),
            IconButton(
              icon: Icon(Icons.more_vert, color: textPrimary),
              tooltip: 'Дополнительно',
              onPressed: () => _showMoreMenu(context, cardBg, textPrimary),
            ),
            if (!_isViewMode)
              TextButton(
                onPressed: _saveManually,
                child: const Text(
                  'Сохранить',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                        borderRadius: BorderRadius.circular(8),
                        onTap: _isViewMode ? null : _pickDate,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Color(0xFF38BDF8),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat(
                                  'd MMMM yyyy',
                                  'ru',
                                ).format(_selectedDate),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              if (!_isViewMode)
                                const Icon(
                                  Icons.arrow_drop_down,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_isViewMode)
                        Text(
                          defaultMoods
                              .firstWhere(
                                (m) => m.id == _selectedMood,
                                orElse: () => defaultMoods.first,
                              )
                              .emoji,
                          style: const TextStyle(fontSize: 26),
                        )
                      else
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: cardBg,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              builder: (ctx) => Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Как ваше настроение?',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      alignment: WrapAlignment.center,
                                      children: defaultMoods.map((m) {
                                        final isSel = m.id == _selectedMood;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(
                                              () => _selectedMood = m.id,
                                            );
                                            Navigator.pop(ctx);
                                          },
                                          child: Column(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isSel
                                                      ? const Color(0xFF38BDF8)
                                                            .withOpacity(0.2)
                                                      : Colors.transparent,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isSel
                                                        ? const Color(
                                                            0xFF38BDF8,
                                                          )
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
                                              const SizedBox(height: 4),
                                              Text(
                                                m.label,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isSel
                                                      ? const Color(0xFF38BDF8)
                                                      : textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  defaultMoods
                                      .firstWhere(
                                        (m) => m.id == _selectedMood,
                                        orElse: () => defaultMoods.first,
                                      )
                                      .emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (_isViewMode)
                    Text(
                      _titleController.text.isEmpty
                          ? 'Без заголовка'
                          : _titleController.text,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    )
                  else
                    TextField(
                      controller: _titleController,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Заголовок дня...',
                        hintStyle: TextStyle(
                          color: textSecondary.withOpacity(0.5),
                          fontSize: 20,
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
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  file,
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (!_isViewMode)
                                Positioned(
                                  top: 4,
                                  right: 4,
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
                        fontSize: 16,
                        height: 1.6,
                        color: textPrimary,
                      ),
                    )
                  else
                    TextField(
                      controller: _contentController,
                      maxLines: null,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Напишите, как прошел ваш день...',
                        hintStyle: TextStyle(
                          color: textSecondary.withOpacity(0.4),
                          fontSize: 16,
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
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: _isViewMode
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 28),
                          tooltip: 'Предыдущая запись',
                          color: hasPrevious
                              ? textPrimary
                              : textSecondary.withOpacity(0.3),
                          onPressed: hasPrevious
                              ? () => _loadDiary(diaries[currentIndex + 1])
                              : null,
                        ),
                        Text(
                          '${currentIndex + 1} из ${diaries.length}',
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 28),
                          tooltip: 'Следующая запись',
                          color: hasNext
                              ? textPrimary
                              : textSecondary.withOpacity(0.3),
                          onPressed: hasNext
                              ? () => _loadDiary(diaries[currentIndex - 1])
                              : null,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: Color(0xFF38BDF8),
                          ),
                          tooltip: 'Прикрепить фото',
                          onPressed: _pickImage,
                        ),
                        const Spacer(),
                        Text(
                          'Черновик сохранится при выходе',
                          style: TextStyle(fontSize: 11, color: textSecondary),
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
