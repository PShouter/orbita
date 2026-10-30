import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/vault_provider.dart';
import '../settings/sections/vault_settings_screen.dart';

class VaultScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const VaultScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _hasAutoTriggeredBio = false;

  // Настройки
  bool _hideTextPreviewInGrid = false;
  String _defaultSort = 'Сначала новые';
  int _failedAttempts = 0;
  int _maxAttempts = 5;
  bool _wipeOnMax = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricUnlockAuto();
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hideTextPreviewInGrid =
            prefs.getBool('vault_hide_text_preview') ?? false;
        _defaultSort = prefs.getString('vault_default_sort') ?? 'Сначала новые';
        _maxAttempts = prefs.getInt('vault_max_attempts') ?? 5;
        _wipeOnMax = prefs.getBool('vault_wipe_on_max_attempts') ?? false;
      });
    }
  }

  Future<void> _tryBiometricUnlockAuto() async {
    if (_hasAutoTriggeredBio) return;
    final vault = ref.read(vaultProvider);
    if (!vault.isUnlocked && vault.hasPin) {
      _hasAutoTriggeredBio = true;
      await ref.read(vaultProvider.notifier).unlockWithBiometrics();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applySorting(List<Map<String, dynamic>> docs) {
    final copy = List<Map<String, dynamic>>.from(docs);
    switch (_defaultSort) {
      case 'Сначала старые':
        copy.sort(
          (a, b) => (a['updated_at'] ?? '').toString().compareTo(
                (b['updated_at'] ?? '').toString(),
              ),
        );
        break;
      case 'По алфавиту':
        copy.sort(
          (a, b) => (a['title'] ?? '').toString().toLowerCase().compareTo(
                (b['title'] ?? '').toString().toLowerCase(),
              ),
        );
        break;
      case 'Сначала новые':
      default:
        copy.sort(
          (a, b) => (b['updated_at'] ?? '').toString().compareTo(
                (a['updated_at'] ?? '').toString(),
              ),
        );
        break;
    }
    return copy;
  }

  Future<void> _handleUnlockAttempt(String pin, VaultNotifier notifier) async {
    final ok = await notifier.unlock(pin);
    if (!ok) {
      HapticFeedback.heavyImpact();
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        if (_wipeOnMax) {
          final docs = List.from(ref.read(vaultProvider).documents);
          for (final doc in docs) {
            await notifier.deleteDocument(doc['id'].toString());
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Превышен лимит попыток. Данные сейфа очищены.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Превышен лимит попыток ($_maxAttempts). Ввод временно ограничен.',
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      }
    } else {
      _failedAttempts = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultProvider);
    final notifier = ref.read(vaultProvider.notifier);

    if (!vault.isUnlocked && vault.hasPin && !_hasAutoTriggeredBio) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tryBiometricUnlockAuto(),
      );
    }

    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF07090E) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF131826) : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    final sortedDocs = _applySorting(vault.documents);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Сейф',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: vault.isUnlocked ? 'Заблокировать сейф' : 'Разблокировать',
            icon: Icon(
              vault.isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: vault.isUnlocked
                  ? const Color(0xFF8B5CF6)
                  : Colors.orangeAccent,
            ),
            onPressed: () {
              if (vault.isUnlocked) {
                notifier.lock();
                _pinController.clear();
                _hasAutoTriggeredBio = false;
              } else {
                notifier.unlockWithBiometrics();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textPrimary),
            tooltip: 'Настройки сейфа',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      VaultSettingsScreen(isDarkMode: widget.isDarkMode),
                ),
              );
              _loadPreferences();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: vault.isUnlocked
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add, size: 28),
              onPressed: () => _showAddOptions(notifier),
            )
          : null,
      body: vault.isUnlocked
          ? _buildUnlockedGrid(
              sortedDocs,
              notifier,
              cardBg,
              borderColor,
              textPrimary,
              textSecondary,
            )
          : _buildLockedView(
              vault,
              notifier,
              cardBg,
              borderColor,
              textPrimary,
              textSecondary,
            ),
    );
  }

  Widget _buildLockedView(
    VaultState vault,
    VaultNotifier notifier,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final needsSetup = !vault.hasPin;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF8B5CF6),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                needsSetup ? 'Создание мастер-PIN' : 'Сейф заблокирован',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                needsSetup
                    ? 'Придумайте PIN для шифрования документов и включения биометрии'
                    : 'Введите PIN или подтвердите вход отпечатком / Face ID',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: TextStyle(
                        fontSize: 22,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  if (!needsSetup) ...[
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF7C3AED).withValues(alpha: 0.2),
                        padding: const EdgeInsets.all(12),
                      ),
                      icon: const Icon(
                        Icons.fingerprint,
                        color: Color(0xFFC4B5FD),
                        size: 28,
                      ),
                      tooltip: 'Войти по биометрии',
                      onPressed: () => notifier.unlockWithBiometrics(),
                    ),
                  ],
                ],
              ),
              if (needsSetup) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: TextStyle(
                    fontSize: 22,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Повторите PIN',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
              if (vault.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  vault.errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final pin = _pinController.text.trim();
                    if (pin.length < 4) return;

                    if (needsSetup) {
                      final confirm = _confirmPinController.text.trim();
                      if (pin != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN-коды не совпадают'),
                          ),
                        );
                        return;
                      }
                      await notifier.setupPin(pin);
                    } else {
                      await _handleUnlockAttempt(pin, notifier);
                    }
                  },
                  child: Text(
                    needsSetup ? 'Создать сейф' : 'Разблокировать',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockedGrid(
    List<Map<String, dynamic>> documents,
    VaultNotifier notifier,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 54,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'В сейфе пока пусто',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Нажмите «+», чтобы зашифровать файл, фото или заметку',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: documents.length,
      itemBuilder: (ctx, i) {
        final doc = documents[i];
        final category = doc['category'] ?? 'text';
        final payload = doc['payload'] ?? '';
        final title = doc['title'] ?? 'Без названия';
        final file = File(payload);
        final bool isImage = category == 'image';
        final bool isDocument = category == 'document';
        final bool fileExists = (isImage || isDocument) && file.existsSync();

        Widget previewWidget;
        if (isImage && fileExists) {
          previewWidget = Hero(
            tag: 'vault_img_${doc['id']}',
            child: Image.file(
              file,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image, color: Colors.grey, size: 36),
              ),
            ),
          );
        } else if (isImage && !fileExists) {
          previewWidget = const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
                SizedBox(height: 4),
                Text(
                  'Файл не найден',
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          );
        } else if (isDocument) {
          final ext = title.split('.').last.toUpperCase();
          previewWidget = Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.insert_drive_file_outlined,
                    color: Color(0xFFC4B5FD),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ext.length <= 4 ? ext : 'DOC',
                    style: const TextStyle(
                      color: Color(0xFFC4B5FD),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          previewWidget = Padding(
            padding: const EdgeInsets.all(12),
            child: _hideTextPreviewInGrid
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: textSecondary,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Текст скрыт',
                          style: TextStyle(fontSize: 10, color: textSecondary),
                        ),
                      ],
                    ),
                  )
                : Text(
                    payload,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.fade,
                  ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isImage) {
                  if (fileExists) {
                    _openImageFullscreen(file, title, doc['id'].toString());
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Файл изображения недоступен на устройстве',
                        ),
                      ),
                    );
                  }
                } else if (isDocument) {
                  if (fileExists) {
                    OpenFilex.open(file.path);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Файл документа не найден на устройстве'),
                      ),
                    );
                  }
                } else {
                  _openTextDocFullscreen(title, payload);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: Colors.black.withValues(alpha: 0.15),
                      child: previewWidget,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isImage
                                    ? 'Фото'
                                    : (isDocument ? 'Документ' : 'Заметка'),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: () =>
                              notifier.deleteDocument(doc['id'].toString()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openImageFullscreen(File file, String title, String tagId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.7),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          body: Center(
            child: Hero(
              tag: 'vault_img_$tagId',
              child: InteractiveViewer(
                clipBehavior: Clip.none,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openTextDocFullscreen(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Скопировать'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Скопировано в буфер')),
              );
            },
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showAddOptions(VaultNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF131826) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_back_outlined,
                  color: Color(0xFF8B5CF6),
                ),
                title: const Text('Добавить фото из галереи'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(notifier, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFF38BDF8),
                ),
                title: const Text('Сделать снимок камерой'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(notifier, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Colors.amberAccent,
                ),
                title: const Text('Загрузить документ (PDF, DOC и др.)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDocument(notifier);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.notes_outlined,
                  color: Color(0xFF10B981),
                ),
                title: const Text('Защищенная заметка / пароль'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddTextDialog(notifier);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto(VaultNotifier notifier, ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        'vault_img_${DateTime.now().millisecondsSinceEpoch}_${image.name}';
    final savedImage = await File(image.path).copy('${appDir.path}/$fileName');

    final name = image.name.isNotEmpty
        ? image.name
        : 'Фото ${DateTime.now().hour}:${DateTime.now().minute}';

    await notifier.addDocument(
      title: name,
      category: 'image',
      payload: savedImage.path,
    );
  }

  Future<void> _pickDocument(VaultNotifier notifier) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) return;
    final pickedFile = result.files.first;
    if (pickedFile.path == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        'vault_doc_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
    final savedDoc =
        await File(pickedFile.path!).copy('${appDir.path}/$fileName');

    await notifier.addDocument(
      title: pickedFile.name,
      category: 'document',
      payload: savedDoc.path,
    );
  }

  void _openAddTextDialog(VaultNotifier notifier) {
    final titleCtrl = TextEditingController();
    final payloadCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            widget.isDarkMode ? const Color(0xFF161B22) : Colors.white,
        title: const Text('Новая защищенная заметка'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: payloadCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Текст заметки / пароль',
                  isDense: true,
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
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            onPressed: () {
              final t = titleCtrl.text.trim();
              final p = payloadCtrl.text.trim();
              if (t.isNotEmpty && p.isNotEmpty) {
                notifier.addDocument(title: t, category: 'text', payload: p);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
