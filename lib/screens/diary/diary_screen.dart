import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/diary_provider.dart';
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

  void _showUnlockDialog() {
    final inputCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cardBg =
            widget.isDarkMode ? const Color(0xFF161B22) : Colors.white;
        final textPrimary = widget.isDarkMode
            ? const Color(0xFFF0F6FC)
            : const Color(0xFF24292F);

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.lock_outline, color: Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Text(
                _lockType == 'pin'
                    ? 'Введите 6-значный код'
                    : 'Введите графический ключ',
                style: TextStyle(color: textPrimary, fontSize: 16),
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
                  color: textPrimary,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showRecoveryDialog();
                  },
                  child: const Text(
                    'Забыли пароль?',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                if (inputCtrl.text.trim() == _savedSecret) {
                  Navigator.pop(ctx);
                  setState(() => _isUnlocked = true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Неверный код доступа')),
                  );
                }
              },
              child: const Text('Войти'),
            ),
          ],
        );
      },
    );
  }

  void _showRecoveryDialog() {
    final answerCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final cardBg =
            widget.isDarkMode ? const Color(0xFF161B22) : Colors.white;
        final textPrimary = widget.isDarkMode
            ? const Color(0xFFF0F6FC)
            : const Color(0xFF24292F);

        return AlertDialog(
          backgroundColor: cardBg,
          title: const Text('Восстановление доступа'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Вопрос: $_securityQuestion',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: answerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ваш ответ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (answerCtrl.text.trim().toLowerCase() ==
                    (_securityAnswer ?? '').toLowerCase()) {
                  Navigator.pop(ctx);
                  setState(() => _isUnlocked = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Доступ подтвержден контрольным вопросом'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Неверный ответ на вопрос')),
                  );
                }
              },
              child: const Text('Подтвердить'),
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
    final diaries = ref.watch(filteredDiariesProvider);
    final isDark = widget.isDarkMode;

    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFF0F6FC) : const Color(0xFF24292F);
    final textSecondary =
        isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A);
    final borderColor =
        isDark ? const Color(0xFF30363D) : const Color(0xFFE1E4E8);

    // Заблокированное состояние экрана дневника
    if (_isLockEnabled && !_isUnlocked) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: const Text(
            'Дневник',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 72,
                color: Color(0xFF38BDF8),
              ),
              const SizedBox(height: 16),
              Text(
                'Дневник защищен паролем',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Введите код для доступа к личным записям',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.key),
                label: const Text('Разблокировать'),
                onPressed: _showUnlockDialog,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Поиск по заголовку, дате, тексту...',
                  hintStyle: TextStyle(
                    color: textSecondary.withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  ref.read(diarySearchQueryProvider.notifier).setQuery(val);
                },
              )
            : const Text(
                'Дневник',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: textPrimary,
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
            icon: Icon(Icons.more_vert, color: textPrimary),
            tooltip: 'Настройки',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DiarySettingsScreen(isDarkMode: widget.isDarkMode),
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
                    color: textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isSearching
                        ? 'Ничего не найдено'
                        : 'В дневнике пока нет записей\nНажмите +, чтобы добавить первую',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary, fontSize: 15),
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
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
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
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: item.isDraft
                              ? Colors.amber.withValues(alpha: 0.5)
                              : borderColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.moodObject.emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dateFormat.format(item.date),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      timeFormat.format(item.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
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
                                    color: Colors.amber.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.amber.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit_note,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Черновик',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (item.title.isNotEmpty) ...[
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
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
                                          fontSize: 14,
                                          height: 1.4,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    item.content,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      color: textSecondary,
                                    ),
                                  ),
                          if (item.images.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 60,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: item.images.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (ctx, i) {
                                  final file = File(item.images[i]);
                                  if (!file.existsSync()) {
                                    return const SizedBox.shrink();
                                  }
                                  final imgWidget = ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      file,
                                      width: 60,
                                      height: 60,
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
        backgroundColor: const Color(0xFF38BDF8),
        foregroundColor: Colors.white,
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
