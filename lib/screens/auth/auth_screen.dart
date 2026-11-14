import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onAuthenticated;

  const AuthScreen({
    super.key,
    required this.isDarkMode,
    required this.onAuthenticated,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit(AppColorsExtension colors) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Пожалуйста, заполните email и пароль', colors.error);
      return;
    }

    if (password.length < 6) {
      _showMessage('Пароль должен содержать минимум 6 символов', colors.error);
      return;
    }

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();

    try {
      if (_isSignUp) {
        final name = _nameController.text.trim();
        final username = _usernameController.text.trim().replaceAll('@', '');

        final response = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'full_name': name.isEmpty ? 'Пользователь' : name,
            'username': username.isEmpty ? email.split('@').first : username,
          },
        );

        if (response.user != null) {
          final effectiveName = name.isEmpty ? 'Пользователь' : name;
          final effectiveUsername =
              username.isEmpty ? email.split('@').first : username;

          await prefs.setString('user_full_name', effectiveName);
          await prefs.setString('user_custom_username', effectiveUsername);
          await prefs.setBool('is_guest_mode', false);

          try {
            await supabase.from('profiles').upsert({
              'id': response.user!.id,
              'full_name': effectiveName,
              'username': effectiveUsername,
              'updated_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {}

          _showMessage('Регистрация успешна!', colors.success);
          widget.onAuthenticated();
        }
      } else {
        final response = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (response.user != null) {
          await prefs.setBool('is_guest_mode', false);

          try {
            final data = await supabase
                .from('profiles')
                .select()
                .eq('id', response.user!.id)
                .maybeSingle();

            if (data != null) {
              if (data['full_name'] != null) {
                await prefs.setString('user_full_name', data['full_name']);
              }
              if (data['username'] != null) {
                await prefs.setString('user_custom_username', data['username']);
              }
            }
          } catch (_) {}

          widget.onAuthenticated();
        }
      }
    } on AuthException catch (e) {
      _showMessage(e.message, colors.error);
    } catch (e) {
      _showMessage('Ошибка подключения: $e', colors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog(AppColorsExtension colors) {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_reset,
                      color: colors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Сброс пароля',
                    style: TextStyle(
                      fontFamily: 'Unbounded',
                      color: colors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Укажите email вашей учетной записи. Мы отправим ссылку для восстановления доступа.',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 13,
                      color: colors.text.withValues(alpha: 0.65),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontFamily: 'Onest', color: colors.text),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(
                        fontFamily: 'Onest',
                        color: colors.text.withValues(alpha: 0.6),
                      ),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        size: 20,
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
                        borderSide:
                            BorderSide(color: colors.accent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(dialogCtx),
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
                    backgroundColor: colors.accent,
                    foregroundColor:
                        colors.isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size(100, 44),
                  ),
                  onPressed: isSending
                      ? null
                      : () async {
                          final email = resetEmailController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            _showMessage(
                                'Введите корректный email', colors.error);
                            return;
                          }

                          setDialogState(() => isSending = true);

                          try {
                            await Supabase.instance.client.auth
                                .resetPasswordForEmail(
                              email,
                              redirectTo: 'https://apporbita.ru',
                            );
                            if (mounted) {
                              Navigator.pop(dialogCtx);
                              _showMessage(
                                'Письмо со ссылкой для сброса пароля отправлено на $email',
                                colors.success,
                              );
                            }
                          } on AuthException catch (e) {
                            _showMessage(e.message, colors.error);
                          } catch (e) {
                            _showMessage('Не удалось отправить письмо: $e',
                                colors.error);
                          } finally {
                            if (dialogCtx.mounted) {
                              setDialogState(() => isSending = false);
                            }
                          }
                        },
                  child: isSending
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.isDark ? Colors.black : Colors.white,
                          ),
                        )
                      : const Text(
                          'Отправить',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest_mode', true);
    widget.onAuthenticated();
  }

  void _showMessage(String text, [Color? backgroundColor]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontFamily: 'Onest')),
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Логотип и брендинг
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.rocket_launch,
                    size: 48,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Орбита',
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Твой персональный второй мозг',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 14,
                    color: colors.text.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 28),

                // Форма авторизации
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: colors.nested),
                    boxShadow: [
                      BoxShadow(
                        color: colors.nested.withValues(
                          alpha: colors.isDark ? 0.3 : 0.08,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Переключатель "Вход / Регистрация"
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.nested.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isSignUp = false),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_isSignUp
                                        ? colors.accent
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Вход',
                                    style: TextStyle(
                                      fontFamily: 'Onest',
                                      color: !_isSignUp
                                          ? (colors.isDark
                                              ? Colors.black
                                              : Colors.white)
                                          : colors.text.withValues(alpha: 0.6),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isSignUp = true),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isSignUp
                                        ? colors.accent
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Регистрация',
                                    style: TextStyle(
                                      fontFamily: 'Onest',
                                      color: _isSignUp
                                          ? (colors.isDark
                                              ? Colors.black
                                              : Colors.white)
                                          : colors.text.withValues(alpha: 0.6),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Поля регистрации
                      if (_isSignUp) ...[
                        TextField(
                          controller: _nameController,
                          style: TextStyle(
                            fontFamily: 'Onest',
                            color: colors.text,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Ваше имя',
                            labelStyle: TextStyle(
                              fontFamily: 'Onest',
                              color: colors.text.withValues(alpha: 0.6),
                            ),
                            prefixIcon: Icon(
                              Icons.badge_outlined,
                              size: 20,
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
                              borderSide: BorderSide(
                                color: colors.accent,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _usernameController,
                          style: TextStyle(
                            fontFamily: 'Onest',
                            color: colors.text,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Юзернейм (ID)',
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
                              size: 20,
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
                              borderSide: BorderSide(
                                color: colors.accent,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.text,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(
                            fontFamily: 'Onest',
                            color: colors.text.withValues(alpha: 0.6),
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            size: 20,
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
                            borderSide: BorderSide(
                              color: colors.accent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Пароль
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(
                          fontFamily: 'Onest',
                          color: colors.text,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          labelStyle: TextStyle(
                            fontFamily: 'Onest',
                            color: colors.text.withValues(alpha: 0.6),
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            size: 20,
                            color: colors.text.withValues(alpha: 0.5),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: colors.text.withValues(alpha: 0.5),
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
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
                            borderSide: BorderSide(
                              color: colors.accent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      // Кнопка "Забыли пароль?" в режиме входа
                      if (!_isSignUp) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _showForgotPasswordDialog(colors),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              minimumSize: const Size(44, 44),
                            ),
                            child: Text(
                              'Забыли пароль?',
                              style: TextStyle(
                                fontFamily: 'Onest',
                                color: colors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Кнопка подтверждения
                      FilledButton(
                        onPressed: _isLoading ? null : () => _submit(colors),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor:
                              colors.isDark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.isDark
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              )
                            : Text(
                                _isSignUp ? 'Зарегистрироваться' : 'Войти',
                                style: const TextStyle(
                                  fontFamily: 'Onest',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Вход как гость
                TextButton(
                  onPressed: _continueAsGuest,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(
                    'Продолжить без аккаунта (локально)',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      color: colors.text.withValues(alpha: 0.6),
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
