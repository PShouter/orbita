import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiaryLockSettingsScreen extends StatefulWidget {
  final bool isDarkMode;

  const DiaryLockSettingsScreen({super.key, required this.isDarkMode});

  @override
  State<DiaryLockSettingsScreen> createState() =>
      _DiaryLockSettingsScreenState();
}

class _DiaryLockSettingsScreenState extends State<DiaryLockSettingsScreen> {
  bool _isLockEnabled = false;
  String _lockType = 'pin'; // 'pin' | 'pattern'
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

  Future<void> _toggleLock(bool val) async {
    if (val && (_savedSecret == null || _savedSecret!.isEmpty)) {
      final success = await _openSetPasswordFlow();
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

  Future<void> _changeLockType(String type) async {
    setState(() => _lockType = type);
    await _openSetPasswordFlow(targetType: type);
  }

  Future<bool> _openSetPasswordFlow({String? targetType}) async {
    final effectiveType = targetType ?? _lockType;
    final secretController = TextEditingController();
    final answerController = TextEditingController();
    String selectedQuestion = _securityQuestion;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = widget.isDarkMode;
          final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
          final textPrimary = isDark
              ? const Color(0xFFF0F6FC)
              : const Color(0xFF24292F);

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  effectiveType == 'pin' ? Icons.pin_outlined : Icons.pattern,
                  color: const Color(0xFF38BDF8),
                ),
                const SizedBox(width: 8),
                Text(
                  effectiveType == 'pin'
                      ? 'Установка 6-значного кода'
                      : 'Графический ключ',
                  style: TextStyle(color: textPrimary, fontSize: 16),
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
                    style: TextStyle(color: textPrimary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: secretController,
                    keyboardType: effectiveType == 'pin'
                        ? TextInputType.number
                        : TextInputType.text,
                    maxLength: effectiveType == 'pin' ? 6 : 12,
                    obscureText: true,
                    style: TextStyle(
                      color: textPrimary,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: effectiveType == 'pin' ? '••••••' : '1-2-3-5',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'КОНТРОЛЬНЫЙ ВОПРОС (ДЛЯ ВОССТАНОВЛЕНИЯ)',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedQuestion,
                    isExpanded: true,
                    dropdownColor: cardBg,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _securityQuestions
                        .map(
                          (q) => DropdownMenuItem(
                            value: q,
                            child: Text(
                              q,
                              style: TextStyle(
                                fontSize: 13,
                                color: textPrimary,
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
                    style: TextStyle(color: textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Ответ на контрольный вопрос',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () async {
                  final secret = secretController.text.trim();
                  final answer = answerController.text.trim();

                  if (effectiveType == 'pin' && secret.length != 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'PIN-код должен состоять ровно из 6 цифр',
                        ),
                      ),
                    );
                    return;
                  }
                  if (secret.isEmpty || answer.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Заполните пароль и ответ на контрольный вопрос',
                        ),
                      ),
                    );
                    return;
                  }

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('diary_lock_secret', secret);
                  await prefs.setString('diary_lock_type', effectiveType);
                  await prefs.setString(
                    'diary_lock_question',
                    selectedQuestion,
                  );
                  await prefs.setString('diary_lock_answer', answer);
                  await prefs.setBool('diary_lock_enabled', true);

                  setState(() {
                    _savedSecret = secret;
                    _lockType = effectiveType;
                    _securityQuestion = selectedQuestion;
                    _securityAnswer = answer;
                    _isLockEnabled = true;
                  });

                  Navigator.pop(ctx, true);
                },
                child: const Text('Сохранить'),
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
        title: const Text('Блокировка дневника'),
        backgroundColor: cardBg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Главный чекбокс / тумблер
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: SwitchListTile(
              secondary: Icon(
                _isLockEnabled ? Icons.lock : Icons.lock_open,
                color: _isLockEnabled ? const Color(0xFF38BDF8) : textSecondary,
              ),
              title: Text(
                'Блокировка дневника',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              subtitle: Text(
                _isLockEnabled
                    ? 'Защита включена'
                    : 'Дневник открывается без пароля',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              activeThumbColor: const Color(0xFF38BDF8),
              value: _isLockEnabled,
              onChanged: _toggleLock,
            ),
          ),
          const SizedBox(height: 20),

          // Зависимые настройки (некликабельны и серые, если блокировка отключена)
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
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.pin,
                            color: Color(0xFF38BDF8),
                          ),
                          title: Text(
                            'Тип пароля',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            _lockType == 'pin'
                                ? 'Код (6 цифр)'
                                : 'Графический ключ',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: DropdownButton<String>(
                            value: _lockType,
                            underline: const SizedBox(),
                            dropdownColor: cardBg,
                            style: TextStyle(
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
                                _changeLockType(v);
                              }
                            },
                          ),
                        ),
                        Divider(height: 1, color: borderColor),
                        ListTile(
                          leading: const Icon(
                            Icons.password,
                            color: Colors.amber,
                          ),
                          title: Text(
                            'Сменить пароль',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            _savedSecret != null
                                ? 'Пароль сохранен'
                                : 'Не установлен',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => _openSetPasswordFlow(),
                        ),
                        Divider(height: 1, color: borderColor),
                        CheckboxListTile(
                          secondary: const Icon(
                            Icons.fingerprint,
                            color: Color(0xFF10B981),
                          ),
                          title: Text(
                            'Включить отпечаток пальца',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Разблокировка биометрией без ручного ввода кода',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          activeColor: const Color(0xFF38BDF8),
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
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.help_outline,
                        color: Colors.purpleAccent,
                      ),
                      title: Text(
                        'Контрольный вопрос',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Вопрос: $_securityQuestion\nОтвет: ${_securityAnswer != null ? "••••••" : "Не задан"}',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => _openSetPasswordFlow(),
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
