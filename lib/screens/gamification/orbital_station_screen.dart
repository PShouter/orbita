import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/gamification_provider.dart';
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

  void _showExpRulesDialog(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final bg = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final textPrimary = isDarkMode
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final textSecondary = isDarkMode
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final borderColor = isDarkMode
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      color: isDarkMode
                          ? const Color(0xFF30363D)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Color(0xFF38BDF8),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Как получить EXP',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Энергия станции пополняется за ежедневные действия и самодисциплину:',
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 18),

                _buildExpRuleGroup(
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF10B981),
                  title: 'Привычки',
                  rules: [
                    'Выполнение привычки — +15 EXP',
                    'Серия 7 дней без пропусков — бонус x1.2 к EXP',
                    'Идеальный день (закрыты все привычки) — +30 EXP',
                  ],
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  borderColor: borderColor,
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
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 12),

                _buildExpRuleGroup(
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFFF59E0B),
                  title: 'Бюджет',
                  rules: [
                    'Внесение ежедневной траты или дохода — +10 EXP (до 3 раз в день)',
                    'Пополнение копилки / сбережений — +25 EXP',
                    'Соблюдение недельного лимита трат — +40 EXP',
                    'Месяц без перерасхода бюджета — +150 EXP',
                  ],
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  borderColor: borderColor,
                ),
                const SizedBox(height: 12),

                _buildExpRuleGroup(
                  icon: Icons.task_alt,
                  color: const Color(0xFF38BDF8),
                  title: 'Задачи и Смены',
                  rules: [
                    'Выполнение обычной задачи — +10 EXP',
                    'Выполнение приоритетной задачи — +20 EXP',
                    'Закрытие смены по графику — +25 EXP',
                  ],
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  borderColor: borderColor,
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
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
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
                        fontSize: 12.5,
                        color: textSecondary,
                        height: 1.3,
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
    final gamification = ref.watch(gamificationProvider);
    final rank = gamification.rank;
    final isDarkMode = widget.isDarkMode;

    final bg = isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final cardBg = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final textPrimary = isDarkMode
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final textSecondary = isDarkMode
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final borderColor = isDarkMode
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Орбитальная станция',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Условия начисления EXP',
            icon: const Icon(
              Icons.info_outline,
              color: Color(0xFF38BDF8),
              size: 22,
            ),
            onPressed: () => _showExpRulesDialog(context),
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
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
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
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rank.echelon,
                  style: TextStyle(
                    fontSize: 13,
                    color: rank.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: gamification.progress,
                    minHeight: 10,
                    backgroundColor: isDarkMode
                        ? const Color(0xFF21262D)
                        : const Color(0xFFE2E8F0),
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
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    Text(
                      rank.level == 20
                          ? 'Макс. ранг'
                          : 'До след: ${rank.maxExp + 1 - gamification.totalExp} EXP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
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
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AchievementsScreen(isDarkMode: isDarkMode),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Color(0xFFF59E0B),
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Витрина космических наград и медалей',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Недельный импульс станции (Соревнование)
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Недельный импульс',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${gamification.weeklyExp} EXP за 7 дн.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Импульс станции обновляется каждый понедельник в 00:00.',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Энергоснабжение модулей (Разбивка по сферам)
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
                Text(
                  'Энергоснабжение модулей',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                _buildModuleStat(
                  'Привычки',
                  gamification.habitsExp,
                  const Color(0xFF10B981),
                  textPrimary,
                  textSecondary,
                ),
                const SizedBox(height: 10),
                _buildModuleStat(
                  'Дневник',
                  gamification.diaryExp,
                  const Color(0xFF8B5CF6),
                  textPrimary,
                  textSecondary,
                ),
                const SizedBox(height: 10),
                _buildModuleStat(
                  'Бюджет',
                  gamification.budgetExp,
                  const Color(0xFFF59E0B),
                  textPrimary,
                  textSecondary,
                ),
                const SizedBox(height: 10),
                _buildModuleStat(
                  'Задачи',
                  gamification.tasksExp,
                  const Color(0xFF38BDF8),
                  textPrimary,
                  textSecondary,
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
    Color color,
    Color textPrimary,
    Color textSecondary,
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
            Text(
              '$exp EXP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
