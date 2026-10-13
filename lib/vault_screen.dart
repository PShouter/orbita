import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'providers/vault_provider.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricUnlock();
    });
  }

  Future<void> _tryBiometricUnlock() async {
    final vault = ref.read(vaultProvider);
    if (!vault.isUnlocked && vault.hasPin) {
      await ref.read(vaultProvider.notifier).unlockWithBiometrics();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultProvider);
    final notifier = ref.read(vaultProvider.notifier);

    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF07090E) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF131826) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

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
              } else {
                _tryBiometricUnlock();
              }
            },
          ),
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
              vault,
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
                        backgroundColor: const Color(0xFF7C3AED)
                            .withValues(alpha: 0.2),
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
                      final ok = await notifier.unlock(pin);
                      if (!ok) HapticFeedback.heavyImpact();
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
    VaultState vault,
    VaultNotifier notifier,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (vault.documents.isEmpty) {
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
        childAspectRatio: 0.85,
      ),
      itemCount: vault.documents.length,
      itemBuilder: (ctx, i) {
        final doc = vault.documents[i];
        final category = doc['category'] ?? 'text';
        final payload = doc['payload'] ?? '';
        final title = doc['title'] ?? 'Без названия';

        Widget previewWidget;
        if (category == 'image' && File(payload).existsSync()) {
          previewWidget = Image.file(
            File(payload),
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, color: Colors.grey),
          );
        } else {
          previewWidget = Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              payload,
              style: TextStyle(fontSize: 11, color: textSecondary),
              maxLines: 5,
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
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            category == 'image' ? 'Фото' : 'Заметка',
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
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          notifier.deleteDocument(doc['id'].toString()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddOptions(VaultNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF131826)
          : Colors.white,
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

    final name = image.name.isNotEmpty
        ? image.name
        : 'Фото ${DateTime.now().hour}:${DateTime.now().minute}';
    await notifier.addDocument(
      title: name,
      category: 'image',
      payload: image.path,
    );
  }

  void _openAddTextDialog(VaultNotifier notifier) {
    final titleCtrl = TextEditingController();
    final payloadCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF161B22)
            : Colors.white,
        title: const Text('Новая защищенная заметка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: payloadCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Текст заметки / пароль',
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
