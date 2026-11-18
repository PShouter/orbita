import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/theme_provider.dart';
import '../../../theme/app_theme.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.nested),
            ),
            child: IconButton(
              icon: Icon(Icons.chevron_left, color: colors.text, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Оформление',
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            'ТЕМА ПРИЛОЖЕНИЯ',
            style: TextStyle(
              fontFamily: 'Onest',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: colors.text.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),

          // Сетка тем 2x2 + 1 внизу
          Row(
            children: [
              Expanded(
                child: _buildThemeCard(
                  title: 'Космос',
                  palette: AppColorsExtension.space,
                  isSelected: themeState.currentTheme == AppThemeType.space &&
                      !themeState.followSystem,
                  onTap: () => notifier.setTheme(AppThemeType.space),
                  colors: colors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeCard(
                  title: 'Рассвет',
                  palette: AppColorsExtension.dawn,
                  isSelected: themeState.currentTheme == AppThemeType.dawn &&
                      !themeState.followSystem,
                  onTap: () => notifier.setTheme(AppThemeType.dawn),
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildThemeCard(
                  title: 'Аврора',
                  palette: AppColorsExtension.aurora,
                  isSelected: themeState.currentTheme == AppThemeType.aurora &&
                      !themeState.followSystem,
                  onTap: () => notifier.setTheme(AppThemeType.aurora),
                  colors: colors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeCard(
                  title: 'Закат',
                  palette: AppColorsExtension.sunset,
                  isSelected: themeState.currentTheme == AppThemeType.sunset &&
                      !themeState.followSystem,
                  onTap: () => notifier.setTheme(AppThemeType.sunset),
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildThemeCard(
                  title: 'Шалфей',
                  palette: AppColorsExtension.sage,
                  isSelected: themeState.currentTheme == AppThemeType.sage &&
                      !themeState.followSystem,
                  onTap: () => notifier.setTheme(AppThemeType.sage),
                  colors: colors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeCard(
                  title: 'Клубника',
                  palette: AppColorsExtension.strawberry,
                  isSelected:
                      themeState.currentTheme == AppThemeType.strawberry &&
                          !themeState.followSystem,
                  onTap: () => notifier.setTheme(AppThemeType.strawberry),
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildThemeCard(
                  title: 'AMOLED',
                  palette: AppColorsExtension.amoled,
                  isSelected: themeState.currentTheme == AppThemeType.amoled &&
                      !themeState.followSystem,
                  onTap: () => notifier.setTheme(AppThemeType.amoled),
                  colors: colors,
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),

          const SizedBox(height: 20),

          // Переключатель «Как в системе»
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.nested),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Как в системе',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Светлая днём, тёмная ночью',
                        style: TextStyle(
                          fontFamily: 'Onest',
                          fontSize: 13,
                          color: colors.text.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: themeState.followSystem,
                  activeThumbColor: colors.accent,
                  activeTrackColor: colors.accent.withValues(alpha: 0.3),
                  onChanged: (val) => notifier.setFollowSystem(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'РАЗМЕР ТЕКСТА',
            style: TextStyle(
              fontFamily: 'Onest',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: colors.text.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),

          // Сегментированный переключатель размера шрифта
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.nested),
            ),
            child: Row(
              children: [
                _buildScaleOption(
                  title: 'Мелкий',
                  isSelected: themeState.textScale == AppTextScale.small,
                  onTap: () => notifier.setTextScale(AppTextScale.small),
                  colors: colors,
                ),
                _buildScaleOption(
                  title: 'Обычный',
                  isSelected: themeState.textScale == AppTextScale.normal,
                  onTap: () => notifier.setTextScale(AppTextScale.normal),
                  colors: colors,
                ),
                _buildScaleOption(
                  title: 'Крупный',
                  isSelected: themeState.textScale == AppTextScale.large,
                  onTap: () => notifier.setTextScale(AppTextScale.large),
                  colors: colors,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required String title,
    required AppColorsExtension palette,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColorsExtension colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? colors.accent : colors.nested,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 70,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.nested),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 6,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: palette.card,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 50,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.nested,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: palette.isDark ? Colors.black : Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScaleOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColorsExtension colors,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.nested : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Onest',
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color:
                  isSelected ? colors.text : colors.text.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
