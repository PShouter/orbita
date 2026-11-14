import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeState {
  final AppThemeType currentTheme;
  final bool followSystem;
  final AppTextScale textScale;

  const ThemeState({
    required this.currentTheme,
    required this.followSystem,
    required this.textScale,
  });

  ThemeState copyWith({
    AppThemeType? currentTheme,
    bool? followSystem,
    AppTextScale? textScale,
  }) {
    return ThemeState(
      currentTheme: currentTheme ?? this.currentTheme,
      followSystem: followSystem ?? this.followSystem,
      textScale: textScale ?? this.textScale,
    );
  }

  double get scaleFactor {
    switch (textScale) {
      case AppTextScale.small:
        return 0.88;
      case AppTextScale.normal:
        return 1.0;
      case AppTextScale.large:
        return 1.16;
    }
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    _loadFromPrefs();
    return const ThemeState(
      currentTheme: AppThemeType.space,
      followSystem: false,
      textScale: AppTextScale.normal,
    );
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('app_theme_type') ?? 0;
    final followSys = prefs.getBool('app_theme_system') ?? false;
    final scaleIndex = prefs.getInt('app_text_scale') ?? 1;

    state = ThemeState(
      currentTheme: AppThemeType
          .values[themeIndex.clamp(0, AppThemeType.values.length - 1)],
      followSystem: followSys,
      textScale: AppTextScale
          .values[scaleIndex.clamp(0, AppTextScale.values.length - 1)],
    );
  }

  Future<void> setTheme(AppThemeType type) async {
    state = state.copyWith(currentTheme: type, followSystem: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme_type', type.index);
    await prefs.setBool('app_theme_system', false);
  }

  Future<void> setFollowSystem(bool val) async {
    state = state.copyWith(followSystem: val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_theme_system', val);
  }

  Future<void> setTextScale(AppTextScale scale) async {
    state = state.copyWith(textScale: scale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_text_scale', scale.index);
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
