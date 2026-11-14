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
import '../../theme/app_theme.dart';
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

  Future<void> _handleUnlockAttempt(
    String pin,
    VaultNotifier notifier,
    AppColorsExtension colors,
  ) async {
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
              SnackBar(
                content: const Text(
                  'Превышен лимит попыток. Данные сейфа очищены.',
                  style: TextStyle(fontFamily: 'Onest'),
                ),
                backgroundColor: colors.error,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Превышен лимит попыток ($_maxAttempts). Ввод временно ограничен.',
                  style: const TextStyle(fontFamily: 'Onest'),
                ),
                backgroundColor: colors.error,
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
    final colors = context.colors;
    final vault = ref.watch(vaultProvider);
    final notifier = ref.read(vaultProvider.notifier);

    if (!vault.isUnlocked && vault.hasPin && !_hasAutoTriggeredBio) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tryBiometricUnlockAuto(),
      );
    }

    final sortedDocs = _applySorting(vault.documents);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Сейф',
          style: TextStyle(
            fontFamily: 'Unbounded',
            color: colors.text,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: vault.isUnlocked ? 'Заблокировать сейф' : 'Разблокировать',
            icon: Icon(
              vault.isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: vault.isUnlocked ? colors.accent : colors.warning,
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
            icon: Icon(Icons.settings_outlined, color: colors.text),
            tooltip: 'Настройки сейфа',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      VaultSettingsScreen(isDarkMode: colors.isDark),
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
              backgroundColor: colors.accent,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add, size: 28),
              onPressed: () => _showAddOptions(notifier, colors),
            )
          : null,
      body: vault.isUnlocked
          ? _buildUnlockedGrid(sortedDocs, notifier, colors)
          : _buildLockedView(vault, notifier, colors),
    );
  }

  Widget _buildLockedView(
    VaultState vault,
    VaultNotifier notifier,
    AppColorsExtension colors,
  ) {
    final needsSetup = !vault.hasPin;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.nested),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: colors.accent,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                needsSetup ? 'Создание мастер-PIN' : 'Сейф заблокирован',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                needsSetup
                    ? 'Придумайте PIN для шифрования документов и включения биометрии'
                    : 'Введите PIN или подтвердите вход отпечатком / Face ID',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontSize: 13,
                  color: colors.text.withValues(alpha: 0.6),
                ),
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
                        fontFamily: 'Unbounded',
                        fontSize: 20,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        hintStyle: TextStyle(
                          color: colors.text.withValues(alpha: 0.3),
                          letterSpacing: 4,
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
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  if (!needsSetup) ...[
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: colors.accent.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(12),
                        minimumSize: const Size(48, 48),
                      ),
                      icon: Icon(
                        Icons.fingerprint,
                        color: colors.accent,
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
                    fontFamily: 'Unbounded',
                    fontSize: 20,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Повторите PIN',
                    hintStyle: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.35),
                      fontSize: 14,
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
              if (vault.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  vault.errorMessage!,
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor:
                        colors.isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    final pin = _pinController.text.trim();
                    if (pin.length < 4) return;

                    if (needsSetup) {
                      final confirm = _confirmPinController.text.trim();
                      if (pin != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'PIN-коды не совпадают',
                              style: TextStyle(fontFamily: 'Onest'),
                            ),
                            backgroundColor: colors.error,
                          ),
                        );
                        return;
                      }
                      await notifier.setupPin(pin);
                    } else {
                      await _handleUnlockAttempt(pin, notifier, colors);
                    }
                  },
                  child: Text(
                    needsSetup ? 'Создать сейф' : 'Разблокировать',
                    style: const TextStyle(
                      fontFamily: 'Onest',
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
    AppColorsExtension colors,
  ) {
    if (documents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 64,
                color: colors.text.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 14),
              Text(
                'В сейфе пока пусто',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Нажмите «+», чтобы зашифровать файл, фото или заметку',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: colors.text.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 84),
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
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  Icons.broken_image,
                  color: colors.text.withValues(alpha: 0.4),
                  size: 36,
                ),
              ),
            ),
          );
        } else if (isImage && !fileExists) {
          previewWidget = Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: colors.text.withValues(alpha: 0.4),
                  size: 32,
                ),
                const SizedBox(height: 4),
                Text(
                  'Файл не найден',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
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
                    color: colors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.insert_drive_file_outlined,
                    color: colors.accent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ext.length <= 4 ? ext : 'DOC',
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      color: colors.accent,
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
                          color: colors.text.withValues(alpha: 0.4),
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Текст скрыт',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontSize: 11,
                            color: colors.text.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(
                    payload,
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 12,
                      color: colors.text.withValues(alpha: 0.7),
                      height: 1.35,
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.fade,
                  ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.nested),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                if (isImage) {
                  if (fileExists) {
                    _openImageFullscreen(file, title, doc['id'].toString(), colors);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Файл изображения недоступен на устройстве',
                          style: TextStyle(fontFamily: 'Onest'),
                        ),
                        backgroundColor: colors.error,
                      ),
                    );
                  }
                } else if (isDocument) {
                  if (fileExists) {
                    OpenFilex.open(file.path);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Файл документа не найден на устройстве',
                          style: TextStyle(fontFamily: 'Onest'),
                        ),
                        backgroundColor: colors.error,
                      ),
                    );
                  }
                } else {
                  _openTextDocFullscreen(title, payload, colors);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: colors.nested.withValues(alpha: 0.3),
                      child: previewWidget,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
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
                                  fontFamily: 'Onest',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: colors.text,
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
                                  fontFamily: 'Onest',
                                  fontSize: 11,
                                  color: colors.text.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: colors.error,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
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

  void _openImageFullscreen(
    File file,
    String title,
    String tagId,
    AppColorsExtension colors,
  ) {
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
              style: const TextStyle(
                fontFamily: 'Onest',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
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

  void _openTextDocFullscreen(
    String title,
    String content,
    AppColorsExtension colors,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: colors.text,
          ),
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
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontSize: 14,
                  height: 1.5,
                  color: colors.text,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.copy, size: 16, color: colors.accent),
            label: Text(
              'Скопировать',
              style: TextStyle(
                fontFamily: 'Onest',
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Скопировано в буфер',
                    style: TextStyle(fontFamily: 'Onest'),
                  ),
                  backgroundColor: colors.accent,
                ),
              );
            },
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Закрыть',
              style: TextStyle(
                fontFamily: 'Onest',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddOptions(VaultNotifier notifier, AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_camera_back_outlined,
                  color: colors.accent,
                ),
                title: Text(
                  'Добавить фото из галереи',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(notifier, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: colors.accent,
                ),
                title: Text(
                  'Сделать снимок камерой',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(notifier, ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.picture_as_pdf_outlined,
                  color: colors.warning,
                ),
                title: Text(
                  'Загрузить документ (PDF, DOC и др.)',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDocument(notifier);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.notes_outlined,
                  color: colors.success,
                ),
                title: Text(
                  'Защищенная заметка / пароль',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddTextDialog(notifier, colors);
                },
              ),
              const SizedBox(height: 8),
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
    final savedDoc = await File(pickedFile.path!)
        .copy('${appDir.path}/$fileName');

    await notifier.addDocument(
      title: pickedFile.name,
      category: 'document',
      payload: savedDoc.path,
    );
  }

  void _openAddTextDialog(VaultNotifier notifier, AppColorsExtension colors) {
    final titleCtrl = TextEditingController();
    final payloadCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Новая защищенная заметка',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
                decoration: InputDecoration(
                  labelText: 'Название',
                  labelStyle: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: colors.nested.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.nested),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: payloadCtrl,
                maxLines: 4,
                style: TextStyle(fontFamily: 'Onest', color: colors.text),
                decoration: InputDecoration(
                  labelText: 'Текст заметки / пароль',
                  labelStyle: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: colors.nested.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.nested),
                  ),
                  isDense: true,
                ),
              ),
            ],
          ),
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
            ),
            onPressed: () {
              final t = titleCtrl.text.trim();
              final p = payloadCtrl.text.trim();
              if (t.isNotEmpty && p.isNotEmpty) {
                notifier.addDocument(title: t, category: 'text', payload: p);
                Navigator.pop(ctx);
              }
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
      ),
    );
  }
}