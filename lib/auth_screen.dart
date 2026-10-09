import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Пожалуйста, заполните email и пароль');
      return;
    }

    if (password.length < 6) {
      _showMessage('Пароль должен содержать минимум 6 символов');
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
          final effectiveUsername = username.isEmpty
              ? email.split('@').first
              : username;

          await prefs.setString('user_full_name', effectiveName);
          await prefs.setString('user_custom_username', effectiveUsername);
          await prefs.setBool('is_guest_mode', false);

          // Запись в таблицу profiles в Supabase
          try {
            await supabase.from('profiles').upsert({
              'id': response.user!.id,
              'full_name': effectiveName,
              'username': effectiveUsername,
              'updated_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {}

          _showMessage('Регистрация успешна!');
          widget.onAuthenticated();
        }
      } else {
        final response = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (response.user != null) {
          await prefs.setBool('is_guest_mode', false);

          // Подтягивание профиля из Supabase
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
      _showMessage(e.message);
    } catch (e) {
      _showMessage('Ошибка подключения: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest_mode', true);
    widget.onAuthenticated();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final Color textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final Color textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFF6F8FA),
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
                    color: const Color(0xFF2C69D1).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.rocket_launch,
                    size: 48,
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Орбита',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Твой персональный второй мозг',
                  style: TextStyle(fontSize: 14, color: textSecondary),
                ),
                const SizedBox(height: 28),

                // Форма авторизации
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.3 : 0.05,
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
                          color: isDark
                              ? const Color(0xFF0D1117)
                              : const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(12),
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
                                        ? const Color(0xFF2C69D1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Вход',
                                    style: TextStyle(
                                      color: !_isSignUp
                                          ? Colors.white
                                          : textSecondary,
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
                                        ? const Color(0xFF2C69D1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Регистрация',
                                    style: TextStyle(
                                      color: _isSignUp
                                          ? Colors.white
                                          : textSecondary,
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

                      // Дополнительные поля при регистрации
                      if (_isSignUp) ...[
                        TextField(
                          controller: _nameController,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Ваше имя',
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _usernameController,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Юзернейм (ID)',
                            prefixText: '@',
                            prefixIcon: const Icon(
                              Icons.alternate_email,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Пароль
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Кнопка подтверждения
                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2C69D1),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isSignUp ? 'Зарегистрироваться' : 'Войти',
                                style: const TextStyle(
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
                  child: Text(
                    'Продолжить без аккаунта (локально)',
                    style: TextStyle(
                      color: textSecondary,
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
