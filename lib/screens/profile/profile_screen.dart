import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/gamification_provider.dart';
import '../../theme/app_theme.dart';
import '../gamification/orbital_station_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
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

  Future<void> _saveProfile(AppColorsExtension colors) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Профиль успешно обновлен',
            style: TextStyle(fontFamily: 'Onest'),
          ),
          backgroundColor: colors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _confirmDeleteAccount(AppColorsExtension colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: colors.error,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Удаление аккаунта',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Вы уверены, что хотите удалить свой аккаунт? '
          'Все ваши задачи, события календаря, привычки и заметки будут безвозвратно удалены с устройства и серверов Орбиты.',
          style: TextStyle(
            fontFamily: 'Onest',
            fontSize: 14,
            color: colors.text.withValues(alpha: 0.8),
            height: 1.45,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              minimumSize: const Size(120, 44),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeDeleteAccount();
            },
            child: const Text(
              'Удалить навсегда',
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

  Future<void> _executeDeleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

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
      Navigator.pop(context);
      if (widget.onDeleteAccount != null) {
        widget.onDeleteAccount!();
      } else {
        widget.onLogout();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gamification = ref.watch(gamificationProvider);
    final rank = gamification.rank;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        title: Text(
          'Мой профиль',
          style: TextStyle(
            fontFamily: 'Unbounded',
            color: colors.text,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: colors.text),
        actions: [
          if (_isSaving)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.accent,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: () => _saveProfile(colors),
              child: Text(
                'Сохранить',
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: colors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          rank.primaryColor.withValues(alpha: 0.25),
                      backgroundImage:
                          _avatarPath != null && File(_avatarPath!).existsSync()
                              ? FileImage(File(_avatarPath!))
                              : null,
                      child: _avatarPath == null ||
                              !File(_avatarPath!).existsSync()
                          ? Icon(
                              Icons.person,
                              size: 52,
                              color: colors.text,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickAvatar,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.bg, width: 2),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: colors.isDark ? Colors.black : Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.rocket_launch,
                        size: 16,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.daysWithOrbita}-й день на Орбите',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Интерактивная плашка ранга
                InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OrbitalStationScreen(isDarkMode: colors.isDark),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: rank.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: rank.primaryColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: rank.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ранг ${rank.level}: ${rank.title}',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            color: rank.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: rank.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.nested),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Личные данные',
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Ваше имя',
                    labelStyle: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                    ),
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      color: colors.text.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: colors.nested.withValues(alpha: 0.3),
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
                      borderSide: BorderSide(color: colors.accent, width: 1.5),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _usernameController,
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colors.text,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Имя пользователя',
                    labelStyle: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                    ),
                    prefixText: '@',
                    prefixStyle: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                    prefixIcon: Icon(
                      Icons.alternate_email,
                      color: colors.text.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: colors.nested.withValues(alpha: 0.3),
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
                      borderSide: BorderSide(color: colors.accent, width: 1.5),
                    ),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.error.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Управление аккаунтом',
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.error,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.logout,
                    color: colors.text.withValues(alpha: 0.6),
                  ),
                  title: Text(
                    'Выйти из аккаунта',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colors.text.withValues(alpha: 0.4),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onLogout();
                  },
                ),
                Divider(color: colors.nested),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_forever,
                    color: colors.error,
                  ),
                  title: Text(
                    'Удалить аккаунт',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.error,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Удалит все данные без возможности восстановления',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 12,
                      color: colors.text.withValues(alpha: 0.5),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colors.error,
                  ),
                  onTap: () => _confirmDeleteAccount(colors),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
