import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  final bool isDarkMode;
  final String userName;
  final String customUsername;
  final String? userAvatarPath;
  final int daysWithOrbita;
  final VoidCallback onLogout;
  final Function(String, String, String?) onProfileUpdated;
  final VoidCallback? onDeleteAccount;

  const ProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.userName,
    required this.customUsername,
    required this.userAvatarPath,
    required this.daysWithOrbita,
    required this.onLogout,
    required this.onProfileUpdated,
    this.onDeleteAccount,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  String? _avatarPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _usernameController = TextEditingController(text: widget.customUsername);
    _avatarPath = widget.userAvatarPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _avatarPath = pickedFile.path;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_avatar_path', pickedFile.path);
      widget.onProfileUpdated(
        _nameController.text.trim(),
        _usernameController.text.trim(),
        _avatarPath,
      );
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().replaceAll('@', '');

    if (name.isEmpty) return;

    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_full_name', name);
    await prefs.setString('user_custom_username', username);
    if (_avatarPath != null) {
      await prefs.setString('user_avatar_path', _avatarPath!);
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'full_name': name,
          'username': username,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    setState(() => _isSaving = false);
    widget.onProfileUpdated(name, username, _avatarPath);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Профиль успешно обновлен')));
      Navigator.pop(context);
    }
  }

  // Диалог удаления аккаунта
  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 28,
            ),
            SizedBox(width: 8),
            Text('Удаление аккаунта'),
          ],
        ),
        content: const Text(
          'Вы уверены, что хотите удалить свой аккаунт? '
          'Все ваши задачи, события календаря, привычки и заметки будут безвозвратно удалены с устройства и серверов Орбиты.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeDeleteAccount();
            },
            child: const Text('Удалить навсегда'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeleteAccount() async {
    // 1. Очищаем все локальные данные в SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 2. Очищаем профиль в Supabase (если авторизован)
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('profiles')
            .delete()
            .eq('id', user.id);
        await Supabase.instance.client
            .from('calendar_events')
            .delete()
            .eq('user_id', user.id);
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context); // Закрываем экран профиля
      if (widget.onDeleteAccount != null) {
        widget.onDeleteAccount!();
      } else {
        widget.onLogout();
      }
    }
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
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Мой профиль',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Сохранить',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Аватарка и дни с Орбитой
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFF2C69D1),
                      backgroundImage:
                          _avatarPath != null && File(_avatarPath!).existsSync()
                          ? FileImage(File(_avatarPath!))
                          : null,
                      child:
                          _avatarPath == null ||
                              !File(_avatarPath!).existsSync()
                          ? const Icon(
                              Icons.person,
                              size: 54,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                            color: Color(0xFF38BDF8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.rocket_launch,
                        size: 16,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.daysWithOrbita}-й день на Орбите',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Поля ввода
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Личные данные',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Ваше имя',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _usernameController,
                  style: TextStyle(color: textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Имя пользователя',
                    prefixText: '@',
                    prefixIcon: Icon(Icons.alternate_email),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Опасная зона: Выход и Удаление аккаунта
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Управление аккаунтом',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: Colors.grey),
                  title: Text(
                    'Выйти из аккаунта',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onLogout();
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_forever,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Удалить аккаунт',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Удалит все данные без возможности восстановления',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Colors.redAccent,
                  ),
                  onTap: _confirmDeleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
