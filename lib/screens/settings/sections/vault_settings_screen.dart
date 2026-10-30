import 'dart:convert';
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/vault_provider.dart';

class VaultSettingsScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;
  const VaultSettingsScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<VaultSettingsScreen> createState() =>
      _VaultSettingsScreenState();
}

class _VaultSettingsScreenState extends ConsumerState<VaultSettingsScreen> {
  // 1. Безопасность и вход
  bool _useBiometrics = true;
  String _autoLockTime = 'Сразу при выходе';
  String _securityQuestion = 'Любимый цвет';
  String? _securityAnswer;

  // 2. Защита от взлома
  int _maxFailedAttempts = 5;
  bool _wipeOnMaxAttempts = false;

  // 3. Отображение и приватность
  bool _hideTextPreviewInGrid = false;
  String _defaultSort = 'Сначала новые';

  // 4. Статистика хранилища
  int _filesCount = 0;
  String _totalSizeString = '0 КБ';

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
    _loadSettings();
    _calculateStorageUsage();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useBiometrics = prefs.getBool('vault_biometrics') ?? true;
      _autoLockTime = prefs.getString('vault_autolock') ?? 'Сразу при выходе';
      _securityQuestion = prefs.getString('vault_question') ?? 'Любимый цвет';
      _securityAnswer = prefs.getString('vault_answer');

      _maxFailedAttempts = prefs.getInt('vault_max_attempts') ?? 5;
      _wipeOnMaxAttempts = prefs.getBool('vault_wipe_on_max_attempts') ?? false;

      _hideTextPreviewInGrid =
          prefs.getBool('vault_hide_text_preview') ?? false;
      _defaultSort = prefs.getString('vault_default_sort') ?? 'Сначала новые';
    });
  }

  Future<void> _calculateStorageUsage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      int totalBytes = 0;
      int count = 0;

      final dir = Directory(appDir.path);
      if (await dir.exists()) {
        final list = dir.listSync();
        for (final item in list) {
          if (item is File &&
              (item.path.contains('vault_img_') ||
                  item.path.contains('vault_doc_'))) {
            totalBytes += await item.length();
            count++;
          }
        }
      }

      String sizeStr;
      if (totalBytes < 1024) {
        sizeStr = '$totalBytes Б';
      } else if (totalBytes < 1024 * 1024) {
        sizeStr = '${(totalBytes / 1024).toStringAsFixed(1)} КБ';
      } else {
        sizeStr = '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
      }

      if (mounted) {
        setState(() {
          _filesCount = count;
          _totalSizeString = sizeStr;
        });
      }
    } catch (_) {}
  }

  Future<void> _updateBool(String key, bool val, void Function() onSet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    setState(onSet);
    HapticFeedback.selectionClick();
  }

  Future<void> _updateString(
    String key,
    String val,
    void Function() onSet,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, val);
    setState(onSet);
    HapticFeedback.selectionClick();
  }

  Future<void> _updateInt(String key, int val, void Function() onSet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, val);
    setState(onSet);
    HapticFeedback.selectionClick();
  }

  void _showChangePinDialog() {
    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Смена мастер-PIN'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Текущий PIN',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Новый PIN (4-6 цифр)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Повторите новый PIN',
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final oldPin = oldPinCtrl.text.trim();
              final newPin = newPinCtrl.text.trim();
              final confirmPin = confirmPinCtrl.text.trim();

              if (newPin.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN должен содержать от 4 до 6 цифр'),
                  ),
                );
                return;
              }
              if (newPin != confirmPin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Новые PIN-коды не совпадают')),
                );
                return;
              }

              final vaultNotifier = ref.read(vaultProvider.notifier);
              final isSuccess = await vaultNotifier.changePin(oldPin, newPin);

              if (!isSuccess) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ref.read(vaultProvider).errorMessage ??
                            'Текущий PIN указан неверно',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
                return;
              }

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Мастер-PIN успешно обновлен'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showSecurityQuestionDialog() {
    final answerCtrl = TextEditingController(text: _securityAnswer ?? '');
    String selectedQ = _securityQuestion;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text('Контрольный вопрос'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedQ,
                items: _securityQuestions
                    .map(
                      (q) => DropdownMenuItem(
                        value: q,
                        child: Text(q, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDState(() => selectedQ = v);
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: answerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ответ на вопрос',
                  border: OutlineInputBorder(),
                  isDense: true,
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
              onPressed: () async {
                final ans = answerCtrl.text.trim();
                if (ans.isEmpty) return;

                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('vault_question', selectedQ);
                await prefs.setString('vault_answer', ans);

                setState(() {
                  _securityQuestion = selectedQ;
                  _securityAnswer = ans;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportVaultBackup() async {
    final vault = ref.read(vaultProvider);
    if (!vault.isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала разблокируйте Сейф перед экспортом'),
        ),
      );
      return;
    }

    final backupData = {
      'exported_at': DateTime.now().toIso8601String(),
      'documents_count': vault.documents.length,
      'documents': vault.documents,
    };

    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(backupData)));
    await FileSaver.instance.saveAs(
      name: 'Orbita_Vault_Backup_${DateTime.now().millisecondsSinceEpoch}.json',
      bytes: bytes,
      mimeType: MimeType.json,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Резервная копия сейфа сохранена'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _confirmWipeEntireVault() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Полная очистка сейфа?'),
          ],
        ),
        content: const Text(
          'Все зашифрованные файлы, фото и заметки будут удалены безвозвратно. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final vaultNotifier = ref.read(vaultProvider.notifier);
              await vaultNotifier.wipeVault();
              await _calculateStorageUsage();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Сейф полностью очищен'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text(
              'Стереть всё',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Безопасность Сейфа'),
        backgroundColor: cardBg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. БЕЗОПАСНОСТЬ И ВХОД
          _buildSectionHeader('БЕЗОПАСНОСТЬ И МЕТОДЫ ВХОДА', textSecondary),
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
                    Icons.password_outlined,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Сменить мастер-PIN',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Изменить секретный код доступа к хранилищу',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _showChangePinDialog,
                ),
                Divider(height: 1, color: borderColor),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.fingerprint,
                    color: Color(0xFF10B981),
                  ),
                  title: Text(
                    'Биометрическая аутентификация',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Вход по отпечатку пальца или Face ID',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeThumbColor: const Color(0xFF38BDF8),
                  value: _useBiometrics,
                  onChanged: (v) => _updateBool(
                    'vault_biometrics',
                    v,
                    () => _useBiometrics = v,
                  ),
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: const Icon(
                    Icons.lock_clock_outlined,
                    color: Colors.amber,
                  ),
                  title: Text(
                    'Автоблокировка',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _autoLockTime,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: _autoLockTime,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items:
                        const [
                              'Сразу при выходе',
                              'Через 1 минуту',
                              'Через 5 минут',
                              'Через 15 минут',
                            ]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _updateString(
                          'vault_autolock',
                          v,
                          () => _autoLockTime = v,
                        );
                      }
                    },
                  ),
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
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
                    '$_securityQuestion (${_securityAnswer != null ? "Задан" : "Не задан"})',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: _showSecurityQuestionDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. ЗАЩИТА ОТ ВЗЛОМА
          _buildSectionHeader('ЗАЩИТА ОТ ВЗЛОМА', textSecondary),
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
                    Icons.warning_amber_outlined,
                    color: Colors.orangeAccent,
                  ),
                  title: Text(
                    'Лимит неверных попыток',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Блокировка после $_maxFailedAttempts неудачных вводов',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: DropdownButton<int>(
                    value: _maxFailedAttempts,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('3 попытки')),
                      DropdownMenuItem(value: 5, child: Text('5 попыток')),
                      DropdownMenuItem(value: 10, child: Text('10 попыток')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        _updateInt(
                          'vault_max_attempts',
                          v,
                          () => _maxFailedAttempts = v,
                        );
                      }
                    },
                  ),
                ),
                Divider(height: 1, color: borderColor),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.auto_delete_outlined,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    'Экстренное стирание',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Удалить данные сейфа при исчерпании лимита попыток',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeThumbColor: Colors.redAccent,
                  value: _wipeOnMaxAttempts,
                  onChanged: (v) => _updateBool(
                    'vault_wipe_on_max_attempts',
                    v,
                    () => _wipeOnMaxAttempts = v,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. ОТОБРАЖЕНИЕ И ПРИВАТНОСТЬ
          _buildSectionHeader('ОТОБРАЖЕНИЕ И ПРИВАТНОСТЬ', textSecondary),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                CheckboxListTile(
                  secondary: const Icon(
                    Icons.blur_on,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Скрывать текст заметок в плитках',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Показывать только заголовок до открытия заметки',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF38BDF8),
                  value: _hideTextPreviewInGrid,
                  onChanged: (v) => _updateBool(
                    'vault_hide_text_preview',
                    v ?? false,
                    () => _hideTextPreviewInGrid = v ?? false,
                  ),
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: const Icon(Icons.sort, color: Color(0xFF38BDF8)),
                  title: Text(
                    'Сортировка документов',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _defaultSort,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: _defaultSort,
                    underline: const SizedBox(),
                    dropdownColor: cardBg,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    items:
                        const ['Сначала новые', 'Сначала старые', 'По алфавиту']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _updateString(
                          'vault_default_sort',
                          v,
                          () => _defaultSort = v,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. ХРАНИЛИЩЕ И ОПЕРАЦИИ
          _buildSectionHeader('ХРАНИЛИЩЕ И ОПЕРАЦИИ', textSecondary),
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
                    Icons.storage_outlined,
                    color: Color(0xFF10B981),
                  ),
                  title: Text(
                    'Занятое место',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Зашифрованных файлов: $_filesCount ($_totalSizeString)',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: const Icon(
                    Icons.download_for_offline_outlined,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Экспорт резервной копии',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Сохранить защищенный бэкап данных сейфа',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _exportVaultBackup,
                ),
                Divider(height: 1, color: borderColor),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Полная очистка сейфа',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                  subtitle: Text(
                    'Безвозвратно стереть все файлы и сбросить хранилище',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onTap: _confirmWipeEntireVault,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
