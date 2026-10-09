import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/notes_provider.dart';

class NotesScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const NotesScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final notifier = ref.read(notesProvider.notifier);

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

    final filteredNotes = notes.where((n) {
      final title = (n['title'] ?? '').toString().toLowerCase();
      final body = (n['body'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return title.contains(q) || body.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF38BDF8),
        onPressed: () => _openNoteEditor(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Заметки',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${notes.length} шт.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Поисковая строка
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  style: TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Поиск по заметкам...',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 12),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.grey,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: filteredNotes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 48,
                            color: Colors.grey.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Заметок пока нет',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Нажмите «+», чтобы создать первую заметку',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: filteredNotes.length,
                      itemBuilder: (ctx, i) {
                        final note = filteredNotes[i];
                        final isPinned = note['is_pinned'] == true;
                        final imagePath = note['image_path'] as String?;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isPinned
                                  ? const Color(0xFF38BDF8)
                                        .withValues(alpha: 0.6)
                                  : borderColor,
                              width: isPinned ? 1.5 : 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _openNoteEditor(existingNote: note),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isPinned)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(
                                            Icons.push_pin,
                                            size: 16,
                                            color: Color(0xFF38BDF8),
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          note['title'] ?? 'Без названия',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          isPinned
                                              ? Icons.push_pin
                                              : Icons.push_pin_outlined,
                                          size: 18,
                                          color: isPinned
                                              ? const Color(0xFF38BDF8)
                                              : Colors.grey,
                                        ),
                                        onPressed: () => notifier.togglePin(
                                          note['id'].toString(),
                                          isPinned,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () => notifier.deleteNote(
                                          note['id'].toString(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (note['body'] != null &&
                                      (note['body'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      note['body'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textSecondary,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (imagePath != null &&
                                      File(imagePath).existsSync()) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(imagePath),
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNoteEditor({Map<String, dynamic>? existingNote}) {
    final titleCtrl = TextEditingController(text: existingNote?['title'] ?? '');
    final bodyCtrl = TextEditingController(text: existingNote?['body'] ?? '');
    String? imagePath = existingNote?['image_path'] ?? existingNote?['image'];
    bool isPinned = existingNote?['is_pinned'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => Padding(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      existingNote == null ? 'Новая заметка' : 'Редактировать',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        color: isPinned ? const Color(0xFF38BDF8) : Colors.grey,
                      ),
                      onPressed: () => setDState(() => isPinned = !isPinned),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Заголовок',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Текст заметки...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                if (imagePath != null && File(imagePath!).existsSync()) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(imagePath!),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                            onPressed: () => setDState(() => imagePath = null),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Фото'),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final img = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (img != null) {
                          setDState(() => imagePath = img.path);
                        }
                      },
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                      ),
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        final body = bodyCtrl.text.trim();
                        if (title.isEmpty && body.isEmpty) return;

                        ref
                            .read(notesProvider.notifier)
                            .saveNote(
                              existingId: existingNote?['id']?.toString(),
                              title: title.isEmpty ? 'Без названия' : title,
                              body: body,
                              imagePath: imagePath,
                              isPinned: isPinned,
                            );

                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Сохранить',
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
      ),
    );
  }
}
