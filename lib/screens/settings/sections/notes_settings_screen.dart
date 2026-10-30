import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/notes_provider.dart';

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
        title: const Text('Настройки заметок'),
        backgroundColor: cardBg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. ВНЕШНИЙ ВИД И ОТОБРАЖЕНИЕ
          _buildSectionHeader('ВНЕШНИЙ ВИД И ОТОБРАЖЕНИЕ', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.grid_view,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Макет по умолчанию',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _layout,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: _layout,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: const ['Плитки', 'Список']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _updateString('notes_layout', v, () => _layout = v);
                        ref
                            .read(notesViewModeProvider.notifier)
                            .setMode(
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
                  leading: const Icon(Icons.sort, color: Color(0xFF38BDF8)),
                  title: Text(
                    'Сортировка по умолчанию',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _sortBy,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: _sortBy,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items:
                        const [
                              'По дате изменения',
                              'По дате создания',
                              'По названию (А–Я)',
                            ]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
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
                  leading: const Icon(
                    Icons.format_size,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Размер шрифта в редакторе',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _fontSize == 14
                        ? 'Маленький (14)'
                        : (_fontSize == 16 ? 'Обычный (16)' : 'Крупный (18)'),
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: DropdownButton<int>(
                    value: _fontSize,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
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
                  secondary: const Icon(
                    Icons.visibility_outlined,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Открывать в режиме предпросмотра',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Рендерить Markdown сразу при открытии заметки',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF38BDF8),
                  value: _startInPreview,
                  onChanged: (v) => _updateBool(
                    'notes_start_in_preview',
                    v ?? false,
                    () => _startInPreview = v ?? false,
                  ),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Показ даты на карточке',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Отображать время последнего изменения в списке',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF38BDF8),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.save_outlined,
                    color: Color(0xFF10B981),
                  ),
                  title: Text(
                    'Автосохранение',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _autoSaveInterval,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: _autoSaveInterval,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items:
                        const [
                              'Мгновенно при выходе',
                              'Каждые 30 секунд',
                              'Каждую минуту',
                            ]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
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
                  secondary: const Icon(Icons.code, color: Colors.purpleAccent),
                  title: Text(
                    'Моноширинный шрифт',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Использовать шрифт кода в режиме редактирования Markdown',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF38BDF8),
                  value: _useMonospaceFont,
                  onChanged: (v) => _updateBool(
                    'notes_use_monospace',
                    v ?? false,
                    () => _useMonospaceFont = v ?? false,
                  ),
                ),
                Divider(height: 1, color: borderColor),
                CheckboxListTile(
                  secondary: const Icon(Icons.text_format, color: Colors.amber),
                  title: Text(
                    'Панель быстрого форматирования',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Отображать панель инструментов Markdown над клавиатурой',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF38BDF8),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.folder_open_outlined,
                    color: Colors.orangeAccent,
                  ),
                  title: Text(
                    'Папка по умолчанию',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Основной раздел для новых заметок: $_defaultFolder',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: _defaultFolder,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
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
                  secondary: const Icon(
                    Icons.delete_sweep_outlined,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    'Подтверждать удаление заметки',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Запрашивать подтверждение перед удалением',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF38BDF8),
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
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
