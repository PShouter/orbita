import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/diary_provider.dart';
import '../../theme/app_theme.dart';
import '../settings/sections/diary_settings_screen.dart';
import 'diary_detail_screen.dart';

class DiaryScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const DiaryScreen({super.key, this.isDarkMode = true});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  bool _isUnlocked = false;
  bool _isLockEnabled = false;
  bool _hidePreview = false;
  String _lockType = 'pin';
  String? _savedSecret;
  String _securityQuestion = 'Любимый цвет';
  String? _securityAnswer;

  @override
  void initState() {
    super.initState();
    _checkLockStatus();
  }

  Future<void> _checkLockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lockEnabled = prefs.getBool('diary_lock_enabled') ?? false;
    final hidePreview = prefs.getBool('diary_hide_preview') ?? false;
    final lockType = prefs.getString('diary_lock_type') ?? 'pin';
    final secret = prefs.getString('diary_lock_secret');
    final question = prefs.getString('diary_lock_question') ?? 'Любимый цвет';
    final answer = prefs.getString('diary_lock_answer');

    if (!mounted) return;
    setState(() {
      _isLockEnabled = lockEnabled;
      _hidePreview = hidePreview;
      _lockType = lockType;
      _savedSecret = secret;
      _securityQuestion = question;
      _securityAnswer = answer;
      _isUnlocked = !lockEnabled;
    });
  }

  void _showUnlockDialog(AppColorsExtension colors) {
    final inputCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Icon(Icons.lock_outline, color: colors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _lockType == 'pin'
                      ? 'Введите 6-значный код'
                      : 'Введите ключ доступа',
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    color: colors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: inputCtrl,
                autofocus: true,
                keyboardType: _lockType == 'pin'
                    ? TextInputType.number
                    : TextInputType.text,
                maxLength: _lockType == 'pin' ? 6 : 12,
                obscureText: true,
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  color: colors.text,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.nested.withValues(alpha: 0.4),
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
                  isDense: true,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showRecoveryDialog(colors);
                  },
                  child: Text(
                    'Забыли пароль?',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                minimumSize: const Size(80, 44),
              ),
              onPressed: () {
                if (inputCtrl.text.trim() == _savedSecret) {
                  Navigator.pop(ctx);
                  setState(() => _isUnlocked = true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Неверный код доступа',
                        style: TextStyle(fontFamily: 'Onest'),
                      ),
                      backgroundColor: colors.error,
                    ),
                  );
                }
              },
              child: const Text(
                'Войти',
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRecoveryDialog(AppColorsExtension colors) {
    final answerCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Восстановление доступа',
            style: TextStyle(
              fontFamily: 'Unbounded',
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Вопрос: $_securityQuestion',
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: answerCtrl,
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
                decoration: InputDecoration(
                  labelText: 'Ваш ответ',
                  labelStyle: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: colors.nested.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.nested),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Отмена',
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: colors.text.withValues(alpha: 0.6),
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                minimumSize: const Size(100, 44),
              ),
              onPressed: () {
                if (answerCtrl.text.trim().toLowerCase() ==
                    (_securityAnswer ?? '').toLowerCase()) {
                  Navigator.pop(ctx);
                  setState(() => _isUnlocked = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Доступ подтвержден контрольным вопросом',
                        style: TextStyle(fontFamily: 'Onest'),
                      ),
                      backgroundColor: colors.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Неверный ответ на вопрос',
                        style: TextStyle(fontFamily: 'Onest'),
                      ),
                      backgroundColor: colors.error,
                    ),
                  );
                }
              },
              child: const Text(
                'Подтвердить',
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final diaries = ref.watch(filteredDiariesProvider);

    if (_isLockEnabled && !_isUnlocked) {
      return Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(
          backgroundColor: colors.bg,
          elevation: 0,
          title: Text(
            'Дневник',
            style: TextStyle(
              fontFamily: 'Unbounded',
              fontWeight: FontWeight.w600,
              fontSize: 22,
              color: colors.text,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Дневник защищен паролем',
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    color: colors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Введите код для доступа к личным записям',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor:
                        colors.isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size(180, 48),
                  ),
                  icon: const Icon(Icons.key, size: 20),
                  label: const Text(
                    'Разблокировать',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => _showUnlockDialog(colors),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: colors.text,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Поиск по заголовку, дате, тексту...',
                  hintStyle: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.4),
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  ref.read(diarySearchQueryProvider.notifier).setQuery(val);
                },
              )
            : Text(
                'Дневник',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: colors.text,
            ),
            tooltip: _isSearching ? 'Закрыть поиск' : 'Поиск',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  ref.read(diarySearchQueryProvider.notifier).setQuery('');
                  _isSearching = false;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: colors.text),
            tooltip: 'Настройки',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DiarySettingsScreen(isDarkMode: colors.isDark),
                ),
              );
              _checkLockStatus();
            },
          ),
        ],
      ),
      body: diaries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 64,
                    color: colors.text.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _isSearching
                        ? 'Ничего не найдено'
                        : 'В дневнике пока нет записей\nНажмите +, чтобы добавить первую',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 84,
              ),
              itemCount: diaries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = diaries[index];
                final dateFormat = DateFormat('d MMMM yyyy, EEEE', 'ru');
                final timeFormat = DateFormat('HH:mm');

                return Material(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DiaryDetailScreen(
                            diaryId: item.id,
                            isInitialViewMode: true,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: item.isDraft
                              ? colors.warning.withValues(alpha: 0.5)
                              : colors.nested,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.moodObject.emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dateFormat.format(item.date),
                                      style: TextStyle(
                                        fontFamily: 'Onest',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colors.text,
                                      ),
                                    ),
                                    Text(
                                      timeFormat.format(item.createdAt),
                                      style: TextStyle(
                                        fontFamily: 'Onest',
                                        fontSize: 12,
                                        color:
                                            colors.text.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (item.isDraft)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        colors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color:
                                          colors.warning.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit_note,
                                        size: 14,
                                        color: colors.warning,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Черновик',
                                        style: TextStyle(
                                          fontFamily: 'Onest',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: colors.warning,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (item.title.isNotEmpty) ...[
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Unbounded',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (item.content.isNotEmpty)
                            _hidePreview
                                ? ClipRect(
                                    child: ImageFiltered(
                                      imageFilter: ImageFilter.blur(
                                        sigmaX: 5,
                                        sigmaY: 5,
                                      ),
                                      child: Text(
                                        item.content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Onest',
                                          fontSize: 14,
                                          height: 1.45,
                                          color: colors.text
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    item.content,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Onest',
                                      fontSize: 14,
                                      height: 1.45,
                                      color: colors.text.withValues(alpha: 0.7),
                                    ),
                                  ),
                          if (item.images.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 64,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: item.images.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (ctx, i) {
                                  final file = File(item.images[i]);
                                  if (!file.existsSync()) {
                                    return const SizedBox.shrink();
                                  }
                                  final imgWidget = ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      file,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                  return _hidePreview
                                      ? ImageFiltered(
                                          imageFilter: ImageFilter.blur(
                                            sigmaX: 6,
                                            sigmaY: 6,
                                          ),
                                          child: imgWidget,
                                        )
                                      : imgWidget;
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
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
              builder: (_) => const DiaryDetailScreen(
                diaryId: null,
                isInitialViewMode: false,
              ),
            ),
          );
        },
      ),
    );
  }
}
