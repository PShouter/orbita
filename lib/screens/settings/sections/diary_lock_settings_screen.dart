import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/diary_lock_service.dart';
import '../../../theme/app_theme.dart';

class DiaryLockSettingsScreen extends StatefulWidget {
  final bool isDarkMode;

  const DiaryLockSettingsScreen({super.key, required this.isDarkMode});

  @override
  State<DiaryLockSettingsScreen> createState() =>
      _DiaryLockSettingsScreenState();
}

class _DiaryLockSettingsScreenState extends State<DiaryLockSettingsScreen> {
  bool _isLockEnabled = false;
  String _lockType = 'pin';
  bool _useFingerprint = false;
  String? _savedSecret;
  String _securityQuestion = 'Любимый цвет';
  String? _securityAnswer;

  static const List<String> _securityQuestions = [
    'Любимый цвет',
    'Любимая еда',
    'Любимый фильм',
    'Кличка первого питомца',
    'Девичья фамилия матери',
    'Город, в котором вы родились',
  ];

  @override
  void initState() {
    super.initState();
    _loadLockSettings();
  }

  Future<void> _loadLockSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLockEnabled = prefs.getBool('diary_lock_enabled') ?? false;
      _lockType = prefs.getString('diary_lock_type') ?? 'pin';
      _useFingerprint = prefs.getBool('diary_lock_use_biometrics') ?? false;
      _savedSecret = prefs.getString('diary_lock_secret');
      _securityQuestion =
          prefs.getString('diary_lock_question') ?? 'Любимый цвет';
      _securityAnswer = prefs.getString('diary_lock_answer');
    });
  }

  Future<void> _toggleLock(bool val, AppColorsExtension colors) async {
    if (val && (_savedSecret == null || _savedSecret!.isEmpty)) {
      final success = await _openSetPasswordFlow(colors: colors);
      if (!success) return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('diary_lock_enabled', val);
    setState(() => _isLockEnabled = val);
    HapticFeedback.selectionClick();
  }

  Future<void> _toggleFingerprint(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('diary_lock_use_biometrics', val);
    setState(() => _useFingerprint = val);
    HapticFeedback.selectionClick();
  }

  Future<void> _changeLockType(String type, AppColorsExtension colors) async {
    setState(() => _lockType = type);
    await _openSetPasswordFlow(targetType: type, colors: colors);
  }

  Future<bool> _openSetPasswordFlow({
    String? targetType,
    required AppColorsExtension colors,
  }) async {
    final effectiveType = targetType ?? _lockType;
    final secretController = TextEditingController();
    final answerController = TextEditingController();
    String selectedQuestion = _securityQuestion;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: colors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Row(
              children: [
                Icon(
                  effectiveType == 'pin' ? Icons.pin_outlined : Icons.pattern,
                  color: colors.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    effectiveType == 'pin'
                        ? 'Установка 6-значного кода'
                        : 'Графический ключ',
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effectiveType == 'pin'
                        ? 'Введите 6 цифр пароля для входа:'
                        : 'Введите узлы ключа (например, 1-2-3-5):',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: secretController,
                    keyboardType: effectiveType == 'pin'
                        ? TextInputType.number
                        : TextInputType.text,
                    maxLength: effectiveType == 'pin' ? 6 : 12,
                    obscureText: true,
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      color: colors.text,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: effectiveType == 'pin' ? '••••••' : '1-2-3-5',
                      hintStyle: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.35),
                        letterSpacing: 0,
                      ),
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
                        borderSide:
                            BorderSide(color: colors.accent, width: 1.5),
                      ),
                      isDense: true,
                    ),
                  ),
                  Divider(height: 24, color: colors.nested),
                  Text(
                    'КОНТРОЛЬНЫЙ ВОПРОС (ДЛЯ ВОССТАНОВЛЕНИЯ)',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedQuestion,
                    isExpanded: true,
                    dropdownColor: colors.card,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text,
                      fontSize: 14,
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
                      isDense: true,
                    ),
                    items: _securityQuestions
                        .map(
                          (q) => DropdownMenuItem(
                            value: q,
                            child: Text(
                              q,
                              style: TextStyle(
                                fontFamily: 'Onest',
                                fontSize: 13,
                                color: colors.text,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedQuestion = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: answerController,
                    style: TextStyle(
                        fontFamily: 'Onest', color: colors.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Ответ на контрольный вопрос',
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
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.nested),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: colors.accent, width: 1.5),
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
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
                ),
                onPressed: () async {
                  final secret = secretController.text.trim();
                  final answer = answerController.text.trim();

                  if (effectiveType == 'pin' && secret.length != 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'PIN-код должен состоять ровно из 6 цифр',
                          style: TextStyle(fontFamily: 'Onest'),
                        ),
                        backgroundColor: colors.error,
                      ),
                    );
                    return;
                  }
                  if (secret.isEmpty || answer.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Заполните пароль и ответ на контрольный вопрос',
                          style: TextStyle(fontFamily: 'Onest'),
                        ),
                        backgroundColor: colors.error,
                      ),
                    );
                    return;
                  }

                  final prefs = await SharedPreferences.getInstance();
                  await DiaryLockService().saveLockData(secret, answer);
                  await prefs.setString('diary_lock_type', effectiveType);
                  await prefs.setString(
                    'diary_lock_question',
                    selectedQuestion,
                  );
                  await prefs.setBool('diary_lock_enabled', true);

                  setState(() {
                    _savedSecret = secret;
                    _lockType = effectiveType;
                    _securityQuestion = selectedQuestion;
                    _securityAnswer = answer;
                    _isLockEnabled = true;
                  });

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text(
                  'Сохранить',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return result ?? false;
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
          'Блокировка дневника',
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
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: SwitchListTile(
              secondary: Icon(
                _isLockEnabled ? Icons.lock : Icons.lock_open,
                color: _isLockEnabled ? colors.accent : textSecondary,
              ),
              title: Text(
                'Блокировка дневника',
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              subtitle: Text(
                _isLockEnabled
                    ? 'Защита включена'
                    : 'Дневник открывается без пароля',
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: textSecondary,
                  fontSize: 12,
                ),
              ),
              activeThumbColor: colors.accent,
              activeTrackColor: colors.accent.withValues(alpha: 0.3),
              value: _isLockEnabled,
              onChanged: (val) => _toggleLock(val, colors),
            ),
          ),
          const SizedBox(height: 20),
          Opacity(
            opacity: _isLockEnabled ? 1.0 : 0.4,
            child: IgnorePointer(
              ignoring: !_isLockEnabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'СПОСОБ АУТЕНТИФИКАЦИИ',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
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
                            Icons.pin,
                            color: colors.accent,
                          ),
                          title: Text(
                            'Тип пароля',
                            style: TextStyle(
                              fontFamily: 'Onest',
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            _lockType == 'pin'
                                ? 'Код (6 цифр)'
                                : 'Графический ключ',
                            style: TextStyle(
                              fontFamily: 'Onest',
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: DropdownButton<String>(
                            value: _lockType,
                            underline: const SizedBox(),
                            dropdownColor: cardBg,
                            style: TextStyle(
                              fontFamily: 'Onest',
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'pin',
                                child: Text('Код (6 цифр)'),
                              ),
                              DropdownMenuItem(
                                value: 'pattern',
                                child: Text('Графический ключ'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null && v != _lockType) {
                                _changeLockType(v, colors);
                              }
                            },
                          ),
                        ),
                        Divider(height: 1, color: borderColor),
                        ListTile(
                          leading: Icon(
                            Icons.password,
                            color: colors.warning,
                          ),
                          title: Text(
                            'Сменить пароль',
                            style: TextStyle(
                              fontFamily: 'Onest',
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            _savedSecret != null
                                ? 'Пароль сохранен'
                                : 'Не установлен',
                            style: TextStyle(
                              fontFamily: 'Onest',
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right,
                              size: 20, color: textSecondary),
                          onTap: () => _openSetPasswordFlow(colors: colors),
                        ),
                        Divider(height: 1, color: borderColor),
                        CheckboxListTile(
                          secondary: Icon(
                            Icons.fingerprint,
                            color: colors.success,
                          ),
                          title: Text(
                            'Включить биометрию',
                            style: TextStyle(
                              fontFamily: 'Onest',
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Разблокировка биометрией без ручного ввода кода',
                            style: TextStyle(
                              fontFamily: 'Onest',
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          activeColor: colors.accent,
                          checkColor:
                              colors.isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          value: _useFingerprint,
                          onChanged: (v) => _toggleFingerprint(v ?? false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'ВОССТАНОВЛЕНИЕ ДОСТУПА',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: borderColor),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.help_outline,
                        color: colors.accent,
                      ),
                      title: Text(
                        'Контрольный вопрос',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Вопрос: $_securityQuestion\nОтвет: ${_securityAnswer != null ? "••••••" : "Не задан"}',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      trailing: Icon(Icons.edit_outlined,
                          size: 20, color: colors.accent),
                      onTap: () => _openSetPasswordFlow(colors: colors),
                    ),
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
