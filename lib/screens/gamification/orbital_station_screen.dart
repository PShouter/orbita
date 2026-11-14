import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/gamification_provider.dart';
import '../../theme/app_theme.dart';
import 'achievements_screen.dart';

class OrbitalStationScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const OrbitalStationScreen({super.key, required this.isDarkMode});

  @override
  ConsumerState<OrbitalStationScreen> createState() =>
      _OrbitalStationScreenState();
}

class _OrbitalStationScreenState extends ConsumerState<OrbitalStationScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(gamificationProvider.notifier).loadData());
  }

  void _showExpRulesDialog(BuildContext context, AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.nested,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: colors.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Как получить EXP',
                      style: TextStyle(
                        fontFamily: 'Unbounded',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Энергия станции пополняется за ежедневные действия и самодисциплину:',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 13,
                    color: colors.text.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 18),
                _buildExpRuleGroup(
                  icon: Icons.check_circle_outline,
                  color: colors.success,
                  title: 'Привычки',
                  rules: [
                    'Выполнение привычки — +15 EXP',
                    'Серия 7 дней без пропусков — бонус x1.2 к EXP',
                    'Идеальный день (закрыты все привычки) — +30 EXP',
                  ],
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _buildExpRuleGroup(
                  icon: Icons.book_outlined,
                  color: const Color(0xFF8B5CF6),
                  title: 'Дневник',
                  rules: [
                    'Запись от 50 символов с настроением — +25 EXP (раз в сутки)',
                    'Прикрепление фото или тегов — +5 EXP',
                    'Серия 7 дней ведения дневника — +100 EXP',
                  ],
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _buildExpRuleGroup(
                  icon: Icons.account_balance_wallet_outlined,
                  color: colors.warning,
                  title: 'Бюджет',
                  rules: [
                    'Внесение ежедневной траты или дохода — +10 EXP (до 3 раз в день)',
                    'Пополнение копилки / сбережений — +25 EXP',
                    'Соблюдение недельного лимита трат — +40 EXP',
                    'Месяц без перерасхода бюджета — +150 EXP',
                  ],
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _buildExpRuleGroup(
                  icon: Icons.task_alt,
                  color: colors.accent,
                  title: 'Задачи и Смены',
                  rules: [
                    'Выполнение обычной задачи — +10 EXP',
                    'Выполнение приоритетной задачи — +20 EXP',
                    'Закрытие смены по графику — +25 EXP',
                  ],
                  colors: colors,
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildExpRuleGroup({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> rules,
    required AppColorsExtension colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rules.map(
            (rule) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rule,
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 12.5,
                        color: colors.text.withValues(alpha: 0.7),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
        iconTheme: IconThemeData(color: colors.text),
        title: Text(
          'Орбитальная станция',
          style: TextStyle(
            fontFamily: 'Unbounded',
            color: colors.text,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Условия начисления EXP',
            icon: Icon(
              Icons.info_outline,
              color: colors.accent,
              size: 22,
            ),
            onPressed: () => _showExpRulesDialog(context, colors),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Блок Реактора / Ранг пилота
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: rank.primaryColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: rank.primaryColor.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: gamification.progress,
                        strokeWidth: 8,
                        backgroundColor: rank.primaryColor.withValues(
                          alpha: 0.15,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          rank.primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: rank.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${rank.level}',
                          style: TextStyle(
                            fontFamily: 'Unbounded',
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: rank.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  rank.title,
                  style: TextStyle(
                    fontFamily: 'Unbounded',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rank.echelon,
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 13,
                    color: rank.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: LinearProgressIndicator(
                    value: gamification.progress,
                    minHeight: 10,
                    backgroundColor: colors.nested.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rank.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${gamification.totalExp} EXP',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 12,
                        color: colors.text.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      rank.level == 20
                          ? 'Макс. ранг'
                          : 'До след: ${rank.maxExp + 1 - gamification.totalExp} EXP',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.text.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Кнопка «Достижения»
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AchievementsScreen(isDarkMode: colors.isDark),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.nested),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: colors.warning,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Достижения',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Витрина космических наград и медалей',
                          style: TextStyle(
                            fontFamily: 'Onest',
                            fontSize: 12,
                            color: colors.text.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: colors.text.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Недельный импульс станции
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Недельный импульс',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        '${gamification.weeklyExp} EXP за 7 дн.',
                        style: TextStyle(
                          fontFamily: 'Unbounded',
                          fontSize: 11,
                          color: colors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Импульс станции обновляется каждый понедельник в 00:00.',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 12,
                    color: colors.text.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Энергоснабжение модулей
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
                  'Энергоснабжение модулей',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 14),
                _buildModuleStat(
                  'Привычки',
                  gamification.habitsExp,
                  colors.success,
                  colors,
                ),
                const SizedBox(height: 10),
                _buildModuleStat(
                  'Дневник',
                  gamification.diaryExp,
                  const Color(0xFF8B5CF6),
                  colors,
                ),
                const SizedBox(height: 10),
                _buildModuleStat(
                  'Бюджет',
                  gamification.budgetExp,
                  colors.warning,
                  colors,
                ),
                const SizedBox(height: 10),
                _buildModuleStat(
                  'Задачи',
                  gamification.tasksExp,
                  colors.accent,
                  colors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleStat(
    String title,
    int exp,
    Color accentColor,
    AppColorsExtension colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Onest',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.text,
              ),
            ),
            Text(
              '$exp EXP',
              style: TextStyle(
                fontFamily: 'Unbounded',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
