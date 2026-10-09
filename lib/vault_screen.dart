import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VaultScreen extends StatefulWidget {
  final bool isDarkMode;
  final String? savedVaultPin;
  final List<Map<String, dynamic>> documents;
  final Function(String) onPinCreated;
  final VoidCallback onSaveDocuments;

  const VaultScreen({
    super.key,
    required this.isDarkMode,
    required this.savedVaultPin,
    required this.documents,
    required this.onPinCreated,
    required this.onSaveDocuments,
  });

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isUnlocked = false;
  String _enteredPin = '';
  String? _currentPin;
  bool _canCheckBiometrics = false;

  List<Map<String, dynamic>> _vaultItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentPin = widget.savedVaultPin;
    _checkBiometrics();
    _loadVaultIndex();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canBio = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      setState(() {
        _canCheckBiometrics = canBio && isDeviceSupported;
      });

      if (_canCheckBiometrics && _currentPin != null) {
        _authenticateBiometric();
      }
    } catch (_) {}
  }

  Future<void> _authenticateBiometric() async {
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Подтвердите личность для доступа к Сейфу',
      );
      if (didAuth && mounted) {
        setState(() {
          _isUnlocked = true;
        });
      }
    } catch (_) {}
  }

  // Директория изолированного хранилища
  Future<Directory> _getVaultDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${appDir.path}/orbita_vault');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  // Получение 256-битного ключа из PIN-кода
  enc.Key _deriveKeyFromPin(String pin) {
    final hash = sha256.convert(utf8.encode(pin)).bytes;
    return enc.Key(Uint8List.fromList(hash));
  }

  Future<void> _loadVaultIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('vault_items_index');
    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw);
        setState(() {
          _vaultItems = decoded
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      } catch (_) {}
    }
  }

  Future<void> _saveVaultIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vault_items_index', jsonEncode(_vaultItems));
  }

  // Шифрование и сохранение в изолированную директорию
  Future<void> _encryptAndSaveFile({
    required File sourceFile,
    required String title,
    required String category,
  }) async {
    if (_currentPin == null) return;
    setState(() => _isLoading = true);

    try {
      final bytes = await sourceFile.readAsBytes();
      final key = _deriveKeyFromPin(_currentPin!);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final encrypted = encrypter.encryptBytes(bytes, iv: iv);

      final vaultDir = await _getVaultDirectory();
      final fileName = 'doc_${DateTime.now().millisecondsSinceEpoch}.enc';
      final encFile = File('${vaultDir.path}/$fileName');

      // Сохраняем IV (16 байт) + зашифрованные данные
      final combined = Uint8List(iv.bytes.length + encrypted.bytes.length)
        ..setRange(0, iv.bytes.length, iv.bytes)
        ..setRange(
          iv.bytes.length,
          iv.bytes.length + encrypted.bytes.length,
          encrypted.bytes,
        );

      await encFile.writeAsBytes(combined);

      final newItem = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'category': category,
        'encryptedPath': encFile.path,
        'sizeBytes': combined.length,
        'createdAt': DateTime.now().toIso8601String(),
      };

      setState(() {
        _vaultItems.insert(0, newItem);
      });
      await _saveVaultIndex();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Документ зашифрован (AES-256) и сохранен в сейф'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка шифрования: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Расшифровка файла в оперативную память для просмотра
  Future<Uint8List?> _decryptFile(String encryptedPath) async {
    if (_currentPin == null) return null;
    try {
      final file = File(encryptedPath);
      if (!await file.exists()) return null;

      final allBytes = await file.readAsBytes();
      if (allBytes.length <= 16) return null;

      final ivBytes = allBytes.sublist(0, 16);
      final cipherBytes = allBytes.sublist(16);

      final key = _deriveKeyFromPin(_currentPin!);
      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(cipherBytes),
        iv: iv,
      );
      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('Ошибка дешифрования: $e');
      return null;
    }
  }

  Future<void> _deleteVaultItem(Map<String, dynamic> item) async {
    final path = item['encryptedPath'] as String?;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    setState(() {
      _vaultItems.remove(item);
    });
    await _saveVaultIndex();
  }

  // Добавление документа (Камера или Галерея)
  Future<void> _pickDocument(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    if (!mounted) return;
    final titleCtrl = TextEditingController(
      text: 'Документ #${_vaultItems.length + 1}',
    );
    String selectedCategory = 'Паспорт / ID';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Сохранить в Сейф'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название документа',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items:
                    [
                          'Паспорт / ID',
                          'Водительские права',
                          'Договор',
                          'Медицина',
                          'Другое',
                        ]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                onChanged: (v) =>
                    setDState(() => selectedCategory = v ?? selectedCategory),
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
                Navigator.pop(ctx);
                _encryptAndSaveFile(
                  sourceFile: File(picked.path),
                  title: titleCtrl.text.trim().isEmpty
                      ? 'Документ'
                      : titleCtrl.text.trim(),
                  category: selectedCategory,
                );
              },
              child: const Text('Зашифровать'),
            ),
          ],
        ),
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

    if (!_isUnlocked) {
      return _buildLockScreen(
        bg,
        cardBg,
        textPrimary,
        textSecondary,
        borderColor,
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Сейф документов',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Заблокировать',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => setState(() {
              _isUnlocked = false;
              _enteredPin = '';
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF38BDF8),
        icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
        label: const Text(
          'Добавить',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: _showAddMenu,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vaultItems.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 64,
                    color: Colors.grey.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'В сейфе пока пусто',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Сканируйте или прикрепите документы с шифрованием AES-256',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: _vaultItems.length,
              itemBuilder: (ctx, i) {
                final doc = _vaultItems[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Color(0xFF38BDF8),
                        size: 24,
                      ),
                    ),
                    title: Text(
                      doc['title'] ?? 'Документ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${doc['category']} • Зашифровано AES-256',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.visibility_outlined,
                            color: Color(0xFF38BDF8),
                          ),
                          onPressed: () => _viewDecryptedDocument(doc),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _deleteVaultItem(doc),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFF38BDF8),
              ),
              title: const Text('Сфотографировать документ (Камера)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickDocument(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: Colors.purpleAccent,
              ),
              title: const Text('Выбрать из галереи'),
              onTap: () {
                Navigator.pop(ctx);
                _pickDocument(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewDecryptedDocument(Map<String, dynamic> doc) async {
    final encPath = doc['encryptedPath'] as String?;
    if (encPath == null) return;

    final bytes = await _decryptFile(encPath);
    if (!mounted) return;

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось расшифровать документ')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    doc['title'] ?? 'Просмотр',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Экран ввода / установки PIN-кода
  Widget _buildLockScreen(
    Color bg,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final isSettingUp = _currentPin == null;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          isSettingUp ? 'Создание PIN-кода Сейфа' : 'Вход в Сейф',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSettingUp ? Icons.lock_reset : Icons.shield,
              size: 54,
              color: const Color(0xFF38BDF8),
            ),
            const SizedBox(height: 16),
            Text(
              isSettingUp
                  ? 'Задайте 4-значный PIN для шифрования'
                  : 'Введите PIN-код для расшифровки',
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? const Color(0xFF38BDF8) : borderColor,
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            _buildNumpad(cardBg, textPrimary),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad(Color cardBg, Color textPrimary) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        children: [
          for (var r = 0; r < 3; r++)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var c = 1; c <= 3; c++)
                  _numpadBtn(
                    '${r * 3 + c}',
                    () => _onKeyTap('${r * 3 + c}'),
                    cardBg,
                    textPrimary,
                  ),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (_canCheckBiometrics && _currentPin != null)
                IconButton(
                  icon: const Icon(
                    Icons.fingerprint,
                    size: 36,
                    color: Color(0xFF38BDF8),
                  ),
                  onPressed: _authenticateBiometric,
                )
              else
                const SizedBox(width: 64, height: 64),
              _numpadBtn('0', () => _onKeyTap('0'), cardBg, textPrimary),
              IconButton(
                icon: const Icon(Icons.backspace_outlined, size: 26),
                onPressed: () {
                  if (_enteredPin.isNotEmpty) {
                    setState(
                      () => _enteredPin = _enteredPin.substring(
                        0,
                        _enteredPin.length - 1,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numpadBtn(
    String text,
    VoidCallback onTap,
    Color cardBg,
    Color textPrimary,
  ) {
    return Container(
      margin: const EdgeInsets.all(6),
      width: 64,
      height: 64,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          backgroundColor: cardBg,
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
      ),
    );
  }

  void _onKeyTap(String digit) async {
    if (_enteredPin.length >= 4) return;
    setState(() => _enteredPin += digit);

    if (_enteredPin.length == 4) {
      if (_currentPin == null) {
        // Создание PIN-кода
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('vault_pin', _enteredPin);
        widget.onPinCreated(_enteredPin);
        setState(() {
          _currentPin = _enteredPin;
          _isUnlocked = true;
        });
      } else {
        // Проверка PIN-кода
        if (_enteredPin == _currentPin) {
          setState(() {
            _isUnlocked = true;
          });
        } else {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Неверный PIN-код'),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _enteredPin = '');
        }
      }
    }
  }
}
