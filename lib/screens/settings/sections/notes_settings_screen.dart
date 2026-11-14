import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/notes_provider.dart';
import '../../../theme/app_theme.dart';

class NotesSettingsScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  const NotesSettingsScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<NotesSettingsScreen> createState() =>
      _NotesSettingsScreenState();
}

class _NotesSettingsScreenState extends ConsumerState<NotesSettingsScreen> {
  // Внешний вид
  String _layout = 'Плитки';
  String _sortBy = 'По дате изменения';
  int _fontSize = 16;
  bool _startInPreview = false;
  bool _showDateOnCard = true;

  // Редактор
  String _autoSaveInterval = 'Мгновенно при выходе';
  bool _useMonospaceFont = false;
  bool _showFormatToolbar = true;

  // Хранилище
  String _defaultFolder = 'Входящие';
  bool _useTrashBeforeDelete = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _layout = prefs.getString('notes_layout') ?? 'Плитки';
      _sortBy = prefs.getString('notes_sort_by') ?? 'По дате изменения';
      _fontSize = prefs.getInt('notes_font_size') ?? 16;
      _startInPreview = prefs.getBool('notes_start_in_preview') ?? false;
      _showDateOnCard = prefs.getBool('notes_show_date_on_card') ?? true;

      _autoSaveInterval =
          prefs.getString('notes_autosave_interval') ?? 'Мгновенно при выходе';
      _useMonospaceFont = prefs.getBool('notes_use_monospace') ?? false;
      _showFormatToolbar = prefs.getBool('notes_show_format_toolbar') ?? true;

      _defaultFolder = prefs.getString('notes_default_folder') ?? 'Входящие';
      _useTrashBeforeDelete =
          prefs.getBool('notes_use_trash_before_delete') ?? true;
    });
  }

  Future<void> _updateString(
    String key,
    String value,
    void Function() onSet,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    setState(onSet);
    HapticFeedback.selectionClick();
  }

  Future<void> _updateBool(
    String key,
    bool value,
    void Function() onSet,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(onSet);
    HapticFeedback.selectionClick();
  }

  Future<void> _updateInt(String key, int value, void Function() onSet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
    setState(onSet);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cardBg = colors.card;
    final textPrimary = colors.text;
    final textSecondary = colors.text.withValues(alpha: 0.6);
    final borderColor = colors.nested;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(
          'Настройки заметок',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        backgroundColor: colors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. ВНЕШНИЙ ВИД И ОТОБРАЖЕНИЕ
          _buildSectionHeader('ВНЕШНИЙ ВИД И ОТОБРАЖЕНИЕ', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.grid_view,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Макет по умолчанию',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _layout,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: DropdownButton<String>(
                    value: _layout,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: const ['Плитки', 'Список']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _updateString('notes_layout', v, () => _layout = v);
                        ref.read(notesViewModeProvider.notifier).setMode(
                              v == 'Список'
                                  ? NotesViewMode.list
                                  : NotesViewMode.grid,
                            );
                      }
                    },
                  ),
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: Icon(Icons.sort, color: colors.accent),
                  title: Text(
                    'Сортировка по умолчанию',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _sortBy,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: DropdownButton<String>(
                    value: _sortBy,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: const [
                      'По дате изменения',
                      'По дате создания',
                      'По названию (А–Я)',
                    ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _updateString('notes_sort_by', v, () => _sortBy = v);
                      }
                    },
                  ),
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: Icon(
                    Icons.format_size,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Размер шрифта в редакторе',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _fontSize == 14
                        ? 'Маленький (14)'
                        : (_fontSize == 16 ? 'Обычный (16)' : 'Крупный (18)'),
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: DropdownButton<int>(
                    value: _fontSize,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    items: const [
                      DropdownMenuItem(value: 14, child: Text('14')),
                      DropdownMenuItem(value: 16, child: Text('16')),
                      DropdownMenuItem(value: 18, child: Text('18')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        _updateInt('notes_font_size', v, () => _fontSize = v);
                      }
                    },
                  ),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: Icon(
                    Icons.visibility_outlined,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Открывать в режиме предпросмотра',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Рендерить Markdown сразу при открытии заметки',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeColor: colors.accent,
                  checkColor: colors.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  value: _startInPreview,
                  onChanged: (v) => _updateBool(
                    'notes_start_in_preview',
                    v ?? false,
                    () => _startInPreview = v ?? false,
                  ),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: Icon(
                    Icons.calendar_today_outlined,
                    color: colors.accent,
                  ),
                  title: Text(
                    'Показ даты на карточке',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Отображать время последнего изменения в списке',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeColor: colors.accent,
                  checkColor: colors.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  value: _showDateOnCard,
                  onChanged: (v) => _updateBool(
                    'notes_show_date_on_card',
                    v ?? true,
                    () => _showDateOnCard = v ?? true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. РЕДАКТОР И ВВОД ТЕКСТА
          _buildSectionHeader('РЕДАКТОР И ВВОД ТЕКСТА', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.save_outlined,
                    color: colors.success,
                  ),
                  title: Text(
                    'Автосохранение',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _autoSaveInterval,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: DropdownButton<String>(
                    value: _autoSaveInterval,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: const [
                      'Мгновенно при выходе',
                      'Каждые 30 секунд',
                      'Каждую минуту',
                    ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _updateString(
                          'notes_autosave_interval',
                          v,
                          () => _autoSaveInterval = v,
                        );
                      }
                    },
                  ),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: Icon(Icons.code, color: colors.accent),
                  title: Text(
                    'Моноширинный шрифт',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Использовать шрифт кода в режиме редактирования Markdown',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeColor: colors.accent,
                  checkColor: colors.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  value: _useMonospaceFont,
                  onChanged: (v) => _updateBool(
                    'notes_use_monospace',
                    v ?? false,
                    () => _useMonospaceFont = v ?? false,
                  ),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: Icon(Icons.text_format, color: colors.warning),
                  title: Text(
                    'Панель быстрого форматирования',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Отображать панель инструментов Markdown над клавиатурой',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeColor: colors.accent,
                  checkColor: colors.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  value: _showFormatToolbar,
                  onChanged: (v) => _updateBool(
                    'notes_show_format_toolbar',
                    v ?? true,
                    () => _showFormatToolbar = v ?? true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. ХРАНИЛИЩЕ И ОРГАНИЗАЦИЯ
          _buildSectionHeader('ХРАНИЛИЩЕ И ОРГАНИЗАЦИЯ', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.folder_open_outlined,
                    color: colors.warning,
                  ),
                  title: Text(
                    'Папка по умолчанию',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Основной раздел для новых заметок: $_defaultFolder',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: DropdownButton<String>(
                    value: _defaultFolder,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: const ['Входящие', 'Идеи', 'Работа', 'Личное']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _updateString(
                          'notes_default_folder',
                          v,
                          () => _defaultFolder = v,
                        );
                      }
                    },
                  ),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: Icon(
                    Icons.delete_sweep_outlined,
                    color: colors.error,
                  ),
                  title: Text(
                    'Подтверждать удаление заметки',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Запрашивать подтверждение перед удалением',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  activeColor: colors.accent,
                  checkColor: colors.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  value: _useTrashBeforeDelete,
                  onChanged: (v) => _updateBool(
                    'notes_use_trash_before_delete',
                    v ?? true,
                    () => _useTrashBeforeDelete = v ?? true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Onest',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
