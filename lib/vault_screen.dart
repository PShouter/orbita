import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final bool _isCreatingPin = false;

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
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Сейф (AES-256)',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (vault.isUnlocked)
            IconButton(
              tooltip: 'Заблокировать сейф',
              icon: const Icon(Icons.lock, color: Colors.orangeAccent),
              onPressed: () {
                notifier.lock();
                _pinController.clear();
              },
            ),
        ],
      ),
      body: vault.isUnlocked
          ? _buildUnlockedView(
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

  /// 1. Экран ввода или создания PIN-кода
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
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF38BDF8),
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
                    ? 'Придумайте 4-6 значный PIN для шифрования документов алгоритмом AES-256'
                    : 'Введите ваш мастер-PIN для расшифровки файлов',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 20),

              // Поле ввода PIN
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: const TextStyle(letterSpacing: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              if (needsSetup) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Повторите PIN',
                    hintStyle: const TextStyle(fontSize: 14, letterSpacing: 2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],

              if (vault.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  vault.errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                      if (!ok) {
                        HapticFeedback.heavyImpact();
                      }
                    }
                  },
                  child: Text(
                    needsSetup ? 'Зашифровать и создать' : 'Разблокировать',
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

  /// 2. Экран расшифрованного содержимого
  Widget _buildUnlockedView(
    VaultState vault,
    VaultNotifier notifier,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Инфо-баннер шифрования
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, color: Color(0xFF38BDF8), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Сейф разблокирован. Данные хранятся в зашифрованном виде AES-256.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Защищенные документы (${vault.documents.length})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.add_circle,
                color: Color(0xFF38BDF8),
                size: 28,
              ),
              onPressed: () => _openAddDocumentDialog(notifier),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (vault.documents.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 48,
                    color: Colors.grey.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'В сейфе пока пусто',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Нажмите «+», чтобы зашифровать пароль, документ или заметку',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          )
        else
          ...vault.documents.map((doc) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.vpn_key_outlined,
                      color: Color(0xFF38BDF8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc['title'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          doc['payload'] ?? '',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      size: 18,
                      color: Color(0xFF38BDF8),
                    ),
                    tooltip: 'Скопировать',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: doc['payload'] ?? ''),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Скопировано в буфер обмена'),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    onPressed: () =>
                        notifier.deleteDocument(doc['id'].toString()),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _openAddDocumentDialog(VaultNotifier notifier) {
    final titleCtrl = TextEditingController();
    final payloadCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Зашифровать запись',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название (например: Пароль от почты)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: payloadCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Секретные данные (пароль, токен, пин-код)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                    ),
                    onPressed: () {
                      final t = titleCtrl.text.trim();
                      final p = payloadCtrl.text.trim();
                      if (t.isEmpty || p.isEmpty) return;

                      notifier.addDocument(
                        title: t,
                        category: 'password',
                        payload: p,
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Зашифровать и сохранить',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
