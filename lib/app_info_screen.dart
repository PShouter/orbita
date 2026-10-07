import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppInfoScreen extends StatelessWidget {
  final bool isDarkMode;

  const AppInfoScreen({super.key, required this.isDarkMode});

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color textPrimary = isDarkMode
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final Color textSecondary = isDarkMode
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final Color cardBg = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDarkMode
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF0D1117)
          : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('О приложении'),
        backgroundColor: cardBg,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        children: [
          // Логотип и общая информация
          Center(
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDarkMode
                        ? const Color(0xFF21262D)
                        : const Color(0xFFE2E8F0),
                    border: Border.all(
                      color: const Color(0xFF38BDF8),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.rocket_launch,
                      size: 36,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Орбита',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Версия: Demo 0.2.9',
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Разработчик: Pavel Krikun',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Блок "О нас"
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
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF38BDF8),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'О нас',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '«Орбита» — это персональный цифровой центр управления продуктивностью («второй мозг»). '
                  'Приложение объединяет в единую экосистему управление задачами, календарное планирование, '
                  'графики смен, трекинг привычек, заметки Obsidian Live, шифрованный сейф и совместную работу с друзьями.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Блок "Связаться с нами"
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
                Row(
                  children: [
                    const Icon(
                      Icons.contact_support_outlined,
                      color: Color(0xFF4ADE80),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Связаться с нами',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Нажмите на контакт, чтобы скопировать его в буфер обмена:',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const Divider(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF2C69D1),
                    child: Icon(
                      Icons.mail_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Электронная почта',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  // Укажи здесь свою почту:
                  subtitle: const Text(
                    'support@orbita.app',
                    style: TextStyle(fontSize: 12, color: Color(0xFF38BDF8)),
                  ),
                  trailing: const Icon(Icons.copy, size: 18),
                  onTap: () => _copyToClipboard(
                    context,
                    'support@orbita.app',
                    'Email скопирован в буфер обмена',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF0284C7),
                    child: Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                  title: Text(
                    'Telegram',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  // Укажи здесь свой Telegram-аккаунт:
                  subtitle: const Text(
                    '@pavel_krikun',
                    style: TextStyle(fontSize: 12, color: Color(0xFF38BDF8)),
                  ),
                  trailing: const Icon(Icons.copy, size: 18),
                  onTap: () => _copyToClipboard(
                    context,
                    '@pavel_krikun',
                    'Telegram скопирован в буфер обмена',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF0EA5E9),
                    child: Icon(Icons.campaign, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    'Telegram-канал',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  // Укажи здесь ссылку на свой Telegram-канал:
                  subtitle: const Text(
                    'https://t.me/orbita_official',
                    style: TextStyle(fontSize: 12, color: Color(0xFF38BDF8)),
                  ),
                  trailing: const Icon(Icons.copy, size: 18),
                  onTap: () => _copyToClipboard(
                    context,
                    'https://t.me/orbita_official',
                    'Ссылка на канал скопирована',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Блок "Политика конфиденциальности"
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
                Row(
                  children: [
                    const Icon(
                      Icons.privacy_tip_outlined,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Политика конфиденциальности',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // =====================================================================
                // МЕСТО ДЛЯ ТВОЕГО ТЕКСТА ПОЛИТИКИ КОНФИДЕНЦИАЛЬНОСТИ:
                // Замени текст внутри этой строковой переменной на свой юридический текст.
                // =====================================================================
                Text(
                  '1. Общие положения:\n'
                  'Мы уважаем конфиденциальность ваших данных. Настоящий раздел определяет порядок сбора, хранения и использования информации в приложении «Орбита».\n\n'
                  '2. Безопасность файлов:\n'
                  'Все файлы и изображения в разделе Сейф шифруются сквозным шифрованием (E2E) с использованием индивидуального PIN-кода пользователя на устройстве.\n\n'
                  '3. Облачная синхронизация:\n'
                  'Персональные записи синхронизируются через изолированные учётные записи Supabase. Доступ к вашим данным третьим лицам не предоставляется.\n\n'
                  '/* НАПИШИ СВОИ ПУНКТЫ ЗДЕСЬ ПРИ НЕОБХОДИМОСТИ */',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: textSecondary,
                  ),
                ),
                // =====================================================================
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
