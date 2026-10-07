import 'dart:io';

import 'package:flutter/material.dart';

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
  bool _isUnlocked = false;
  final TextEditingController _pinController = TextEditingController();

  void _checkPin() {
    if (widget.savedVaultPin == null) {
      if (_pinController.text.length == 4) {
        widget.onPinCreated(_pinController.text);
        setState(() => _isUnlocked = true);
      }
    } else {
      if (_pinController.text == widget.savedVaultPin) {
        setState(() => _isUnlocked = true);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Неверный PIN-код')));
      }
    }
  }

  void _addNewDoc() {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String docType = 'Паспорт / ID';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить в Сейф'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Название документа',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Номер / Данные документа',
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
            onPressed: () {
              if (titleCtrl.text.isNotEmpty) {
                setState(() {
                  widget.documents.add({
                    'title': titleCtrl.text.trim(),
                    'type': docType,
                    'note': noteCtrl.text.trim(),
                    'imagePath': null,
                    'date': 'Добавлено сегодня',
                  });
                });
                widget.onSaveDocuments();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _previewDocument(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(doc['title'] ?? 'Документ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  doc['imagePath'] != null &&
                      File(doc['imagePath']).existsSync()
                  ? Image.file(File(doc['imagePath']), fit: BoxFit.cover)
                  : const Center(
                      child: Icon(
                        Icons.security,
                        size: 64,
                        color: Colors.white70,
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              'Данные: ${doc['note'] ?? 'Без заметок'}',
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
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

    if (!_isUnlocked) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: const Text('Защищенный сейф')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Color(0xFF38BDF8),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.savedVaultPin == null
                      ? 'Установите 4-значный PIN сейфа'
                      : 'Введите PIN сейфа',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 12),
                    decoration: const InputDecoration(counterText: ''),
                    onChanged: (v) {
                      if (v.length == 4) _checkPin();
                    },
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _checkPin,
                  child: const Text('Войти в сейф'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Сейф документов'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addNewDoc),
        ],
      ),
      body: widget.documents.isEmpty
          ? const Center(
              child: Text('Сейф пуст. Добавьте первый защищенный документ'),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: widget.documents.length,
              itemBuilder: (ctx, i) {
                final doc = widget.documents[i];
                return GestureDetector(
                  onTap: () => _previewDocument(doc),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 4. Реальная миниатюра предпросмотра
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child:
                                doc['imagePath'] != null &&
                                    File(doc['imagePath']).existsSync()
                                ? ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                    child: Image.file(
                                      File(doc['imagePath']),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.description,
                                      size: 44,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc['title'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                              ),
                              Text(
                                doc['type'] ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
