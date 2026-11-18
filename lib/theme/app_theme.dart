import 'package:flutter/material.dart';

enum AppThemeType { space, dawn, aurora, sunset, amoled, sage, strawberry }

enum AppTextScale { small, normal, large }

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color bg;
  final Color card;
  final Color nested;
  final Color text;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final bool isDark;

  const AppColorsExtension({
    required this.bg,
    required this.card,
    required this.nested,
    required this.text,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.isDark,
  });

  // Палитры согласно дизайн-системе Орбиты
  static const space = AppColorsExtension(
    bg: Color(0xFF0A0E17),
    card: Color(0xFF121826),
    nested: Color(0xFF1B2438),
    text: Color(0xFFEEF2FA),
    accent: Color(0xFF6AB0FF),
    success: Color(0xFF4ADE9A),
    warning: Color(0xFFFFC163),
    error: Color(0xFFFF7A7A),
    isDark: true,
  );

  static const dawn = AppColorsExtension(
    bg: Color(0xFFF3F5FA),
    card: Color(0xFFFFFFFF),
    nested: Color(0xFFECEFF7),
    text: Color(0xFF10172A),
    accent: Color(0xFF2F62F0),
    success: Color(0xFF0F7F59),
    warning: Color(0xFF9A5A00),
    error: Color(0xFFC5303A),
    isDark: false,
  );

  static const aurora = AppColorsExtension(
    bg: Color(0xFF07110E),
    card: Color(0xFF0F1C17),
    nested: Color(0xFF16281F),
    text: Color(0xFFEAF7F1),
    accent: Color(0xFF3DDC97),
    success: Color(0xFF3DDC97),
    warning: Color(0xFFF5C451),
    error: Color(0xFFFF8484),
    isDark: true,
  );

  static const sunset = AppColorsExtension(
    bg: Color(0xFF130E0C),
    card: Color(0xFF1E1613),
    nested: Color(0xFF2A1E19),
    text: Color(0xFFFBF0EA),
    accent: Color(0xFFFF8F5A),
    success: Color(0xFF7BDB9A),
    warning: Color(0xFFFFD066),
    error: Color(0xFFFF7C7C),
    isDark: true,
  );

  static const amoled = AppColorsExtension(
    bg: Color(0xFF000000),
    card: Color(0xFF0D0D12),
    nested: Color(0xFF17171F),
    text: Color(0xFFFFFFFF),
    accent: Color(0xFF9A8CFF),
    success: Color(0xFF5BE3A4),
    warning: Color(0xFFFFC869),
    error: Color(0xFFFF8080),
    isDark: true,
  );

  // Шалфей — мягкая светлая тема в свежих травяных тонах
  static const sage = AppColorsExtension(
    bg: Color(0xFFF1F6F1),
    card: Color(0xFFFFFFFF),
    nested: Color(0xFFE2EBE3),
    text: Color(0xFF1A2420),
    accent: Color(0xFF5E9E6B),
    success: Color(0xFF2E7D4F),
    warning: Color(0xFF9A6B00),
    error: Color(0xFFB53A3A),
    isDark: false,
  );

  // Клубника — тёплая светлая тема с розово-персиковыми акцентами
  static const strawberry = AppColorsExtension(
    bg: Color(0xFFFFF4F4),
    card: Color(0xFFFFFFFF),
    nested: Color(0xFFFFE3E3),
    text: Color(0xFF2A1518),
    accent: Color(0xFFE8617C),
    success: Color(0xFF3C9D77),
    warning: Color(0xFFC07A22),
    error: Color(0xFFD64545),
    isDark: false,
  );

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? bg,
    Color? card,
    Color? nested,
    Color? text,
    Color? accent,
    Color? success,
    Color? warning,
    Color? error,
    bool? isDark,
  }) {
    return AppColorsExtension(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      nested: nested ?? this.nested,
      text: text ?? this.text,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(
    ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      nested: Color.lerp(nested, other.nested, t)!,
      text: Color.lerp(text, other.text, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      isDark: other.isDark,
    );
  }
}

// Быстрый доступ к цветам в любом виджете через context.colors
extension ThemeContextExt on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>() ??
      AppColorsExtension.space;
}

// Генератор ThemeData со шрифтами, отступами и скруглениями дизайн-системы
ThemeData buildThemeData(AppColorsExtension palette) {
  final base = palette.isDark ? ThemeData.dark() : ThemeData.light();

  return base.copyWith(
    scaffoldBackgroundColor: palette.bg,
    colorScheme: ColorScheme(
      brightness: palette.isDark ? Brightness.dark : Brightness.light,
      primary: palette.accent,
      onPrimary: palette.isDark ? Colors.black : Colors.white,
      secondary: palette.accent,
      onSecondary: Colors.white,
      error: palette.error,
      onError: Colors.white,
      surface: palette.card,
      onSurface: palette.text,
    ),
    extensions: [palette],
    // Радиусы дизайн-системы: карточка 22, кнопка 16, чип 13, минимальная зона нажатия 44px
    cardTheme: CardThemeData(
      color: palette.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: palette.nested, width: 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size(44, 44),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size(44, 44),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
    textTheme: TextTheme(
      // Unbounded 600 · 26 — заголовок экрана, числа
      headlineMedium: const TextStyle(
        fontFamily: 'Unbounded',
        fontWeight: FontWeight.w600,
        fontSize: 26,
        letterSpacing: -0.5,
      ),
      // Onest 600 · 15-17 — заголовок карточки
      titleMedium: const TextStyle(
        fontFamily: 'Onest',
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      // Onest 400 · 15 — основной текст и поля ввода
      bodyMedium: const TextStyle(
        fontFamily: 'Onest',
        fontWeight: FontWeight.w400,
        fontSize: 15,
      ),
      // Onest 400 · 13 — подписи и вторичные данные
      bodySmall: const TextStyle(
        fontFamily: 'Onest',
        fontWeight: FontWeight.w400,
        fontSize: 13,
      ),
      // Onest 600 · 12 · капс — метка раздела
      labelSmall: const TextStyle(
        fontFamily: 'Onest',
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.8,
      ),
    ).apply(
      fontFamily: 'Onest',
      bodyColor: palette.text,
      displayColor: palette.text,
    ),
  );
}
