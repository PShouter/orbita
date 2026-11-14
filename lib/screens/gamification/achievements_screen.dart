import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/achievements_provider.dart';
import '../../theme/app_theme.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const AchievementsScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  AchievementCategory _selectedCategory = AchievementCategory.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(achievementsProvider.notifier).checkAllProgress(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final achievements = ref.watch(achievementsProvider);

    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final totalCount = achievements.length;

    final filtered = achievements.where((a) {
      if (_selectedCategory == AchievementCategory.all) return true;
      return a.category == _selectedCategory;
    }).toList();

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.text),
        title: Text(
          'Достижения',
          style: TextStyle(
            fontFamily: 'Unbounded',
            color: colors.text,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Шапка прогресса
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.nested),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: colors.warning,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Открыто: $unlockedCount из $totalCount',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: LinearProgressIndicator(
                            value: totalCount > 0
                                ? unlockedCount / totalCount
                                : 0.0,
                            minHeight: 8,
                            backgroundColor:
                                colors.nested.withValues(alpha: 0.5),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Фильтры категорий
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _buildFilterChip('Все', AchievementCategory.all, colors),
                _buildFilterChip(
                    'Привычки', AchievementCategory.habits, colors),
                _buildFilterChip('Задачи', AchievementCategory.tasks, colors),
                _buildFilterChip('Дневник', AchievementCategory.diary, colors),
                _buildFilterChip('Бюджет', AchievementCategory.budget, colors),
                _buildFilterChip(
                    'Станция', AchievementCategory.station, colors),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Список наград
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: filtered.length,
              itemBuilder: (ctx, idx) {
                final item = filtered[idx];
                final isUnlocked = item.isUnlocked;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? item.color
                            .withValues(alpha: colors.isDark ? 0.08 : 0.04)
                        : colors.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isUnlocked
                          ? item.color.withValues(alpha: 0.4)
                          : colors.nested,
                      width: isUnlocked ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Иконка
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isUnlocked
                              ? item.color.withValues(alpha: 0.15)
                              : colors.nested.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isUnlocked ? item.icon : Icons.lock_outline,
                          color: isUnlocked
                              ? item.color
                              : colors.text.withValues(alpha: 0.4),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Название, описание и прогресс
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontFamily: 'Onest',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isUnlocked
                                          ? colors.text
                                          : colors.text.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        colors.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Text(
                                    '+${item.expReward} EXP',
                                    style: TextStyle(
                                      fontFamily: 'Unbounded',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: colors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              style: TextStyle(
                                fontFamily: 'Onest',
                                fontSize: 12,
                                color: colors.text.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Прогресс-бар
                            if (!isUnlocked) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: LinearProgressIndicator(
                                  value: item.progress,
                                  minHeight: 6,
                                  backgroundColor:
                                      colors.nested.withValues(alpha: 0.5),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    item.color,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.currentValue.clamp(0, item.targetValue)} / ${item.targetValue}',
                                style: TextStyle(
                                  fontFamily: 'Onest',
                                  fontSize: 11,
                                  color: colors.text.withValues(alpha: 0.5),
                                ),
                              ),
                            ] else
                              Row(
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 14,
                                    color: colors.success,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Получено',
                                    style: TextStyle(
                                      fontFamily: 'Onest',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: colors.success,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    AchievementCategory category,
    AppColorsExtension colors,
  ) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'Onest',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? (colors.isDark ? Colors.black : Colors.white)
                : colors.text,
          ),
        ),
        selected: isSelected,
        selectedColor: colors.accent,
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(color: isSelected ? colors.accent : colors.nested),
        ),
        onSelected: (_) => setState(() => _selectedCategory = category),
      ),
    );
  }
}
