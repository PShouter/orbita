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
  final Function(String newName, String newUsername, String? newAvatarPath)
  onProfileUpdated;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.userName,
    required this.customUsername,
    this.userAvatarPath,
    required this.daysWithOrbita,
    required this.onProfileUpdated,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _userCtrl;
  late TextEditingController _telegramCtrl;

  String? _avatarPath;
  DateTime? _birthDate;
  bool _isEditing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.userName);
    _userCtrl = TextEditingController(text: widget.customUsername);
    _telegramCtrl = TextEditingController();
    _avatarPath = widget.userAvatarPath;
    _loadExtraProfileData();
  }

  Future<void> _loadExtraProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _avatarPath =
          prefs.getString('user_avatar_path') ?? widget.userAvatarPath;
      final tg = prefs.getString('user_telegram_handle');
      if (tg != null) _telegramCtrl.text = tg;

      final bDateIso = prefs.getString('user_birth_date');
      if (bDateIso != null) {
        _birthDate = DateTime.tryParse(bDateIso);
      }
    });
  }

  // Выбор фото из Галереи или с Камеры
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_avatar_path', pickedFile.path);

        setState(() {
          _avatarPath = pickedFile.path;
        });

        widget.onProfileUpdated(
          _nameCtrl.text.trim(),
          _userCtrl.text.trim().replaceAll('@', ''),
          pickedFile.path,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Фото профиля обновлено')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить фото: $e')),
        );
      }
    }
  }

  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF161B22)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF38BDF8),
              ),
              title: const Text('Выбрать из Галереи'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2C69D1)),
              title: const Text('Сделать снимок'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_avatarPath != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Удалить аватар',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('user_avatar_path');
                  setState(() => _avatarPath = null);
                  widget.onProfileUpdated(
                    _nameCtrl.text.trim(),
                    _userCtrl.text.trim().replaceAll('@', ''),
                    null,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      locale: const Locale('ru', 'RU'),
    );

    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _saveChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final newName = _nameCtrl.text.trim().isEmpty
        ? widget.userName
        : _nameCtrl.text.trim();
    final newUsername = _userCtrl.text.trim().isEmpty
        ? widget.customUsername
        : _userCtrl.text.trim().replaceAll('@', '');
    final tg = _telegramCtrl.text.trim().replaceAll('@', '');

    await prefs.setString('user_full_name', newName);
    await prefs.setString('user_custom_username', newUsername);
    await prefs.setString('user_telegram_handle', tg);

    if (_birthDate != null) {
      await prefs.setString('user_birth_date', _birthDate!.toIso8601String());
    } else {
      await prefs.remove('user_birth_date');
    }

    // Сохранение в Supabase (если авторизован)
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'full_name': newName,
          'username': newUsername,
          'telegram_handle': tg,
          'birth_date': _birthDate?.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    widget.onProfileUpdated(newName, newUsername, _avatarPath);
    setState(() => _isEditing = false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Профиль успешно сохранен')));
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
        title: const Text(
          'Мой профиль',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _isEditing ? 'Сохранить' : 'Редактировать',
            icon: Icon(_isEditing ? Icons.check : Icons.edit_outlined),
            onPressed: () {
              if (_isEditing) {
                _saveChanges();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Аватарка с кнопкой выбора фото
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _showImageSourceModal,
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2C69D1),
                      border: Border.all(
                        color: const Color(0xFF38BDF8),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(54),
                      child:
                          _avatarPath != null && File(_avatarPath!).existsSync()
                          ? Image.file(File(_avatarPath!), fit: BoxFit.cover)
                          : const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _showImageSourceModal,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Color(0xFF38BDF8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _showImageSourceModal,
              child: const Text(
                'Изменить фото профиля',
                style: TextStyle(fontSize: 13, color: Color(0xFF38BDF8)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Основная карточка информации
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isEditing) ...[
                  Text(
                    _nameCtrl.text,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${_userCtrl.text}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _nameCtrl,
                    style: TextStyle(color: textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userCtrl,
                    style: TextStyle(color: textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Никнейм (@id)',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                ],

                const Divider(height: 28),

                // Дата рождения
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.cake_outlined,
                    color: Colors.pinkAccent,
                  ),
                  title: const Text(
                    'Дата рождения',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  subtitle: Text(
                    _birthDate != null
                        ? '${_birthDate!.day.toString().padLeft(2, '0')}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.year}'
                        : 'Не указана',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  trailing: _isEditing
                      ? const Icon(Icons.edit_calendar, size: 20)
                      : null,
                  onTap: _isEditing ? _pickBirthDate : null,
                ),

                const Divider(height: 16),

                // Telegram
                if (!_isEditing)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFF0088CC),
                    ),
                    title: const Text(
                      'Telegram',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    subtitle: Text(
                      _telegramCtrl.text.isNotEmpty
                          ? '@${_telegramCtrl.text}'
                          : 'Не привязан',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  )
                else
                  TextField(
                    controller: _telegramCtrl,
                    style: TextStyle(color: textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Telegram (@username)',
                      prefixText: '@',
                      prefixIcon: Icon(
                        Icons.send_rounded,
                        color: Color(0xFF0088CC),
                      ),
                    ),
                  ),

                const Divider(height: 28),

                // Статистика
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'В системе «Орбита»:',
                      style: TextStyle(color: textSecondary),
                    ),
                    Text(
                      '${widget.daysWithOrbita} дн.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Статус аккаунта:',
                      style: TextStyle(color: textSecondary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Активен',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Кнопка выхода
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.14),
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.logout),
            label: const Text(
              'Выйти из аккаунта',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
          ),
        ],
      ),
    );
  }
}
