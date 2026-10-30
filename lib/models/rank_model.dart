import 'package:flutter/material.dart';

class RankTierInfo {
  final int level;
  final String title;
  final int minExp;
  final int maxExp;
  final Color primaryColor;
  final Color secondaryColor;
  final String echelon;

  const RankTierInfo({
    required this.level,
    required this.title,
    required this.minExp,
    required this.maxExp,
    required this.primaryColor,
    required this.secondaryColor,
    required this.echelon,
  });
}

class RankCalculator {
  static const List<RankTierInfo> ranks = [
    // I Эшелон: Стажеры и Младший состав
    RankTierInfo(
      level: 1,
      title: 'Стажер станции',
      minExp: 0,
      maxExp: 250,
      primaryColor: Color(0xFF94A3B8),
      secondaryColor: Color(0xFF64748B),
      echelon: 'Младший состав',
    ),
    RankTierInfo(
      level: 2,
      title: 'Кадет орбиты',
      minExp: 251,
      maxExp: 650,
      primaryColor: Color(0xFFCBD5E1),
      secondaryColor: Color(0xFF94A3B8),
      echelon: 'Младший состав',
    ),
    RankTierInfo(
      level: 3,
      title: 'Младший техник',
      minExp: 651,
      maxExp: 1200,
      primaryColor: Color(0xFF60A5FA),
      secondaryColor: Color(0xFF3B82F6),
      echelon: 'Младший состав',
    ),
    RankTierInfo(
      level: 4,
      title: 'Бортовой техник',
      minExp: 1201,
      maxExp: 2000,
      primaryColor: Color(0xFF2C69D1),
      secondaryColor: Color(0xFF1D4ED8),
      echelon: 'Младший состав',
    ),
    RankTierInfo(
      level: 5,
      title: 'Оператор систем',
      minExp: 2001,
      maxExp: 3000,
      primaryColor: Color(0xFF2563EB),
      secondaryColor: Color(0xFF1E40AF),
      echelon: 'Младший состав',
    ),

    // II Эшелон: Офицеры и Специалисты
    RankTierInfo(
      level: 6,
      title: 'Младший навигатор',
      minExp: 3001,
      maxExp: 4300,
      primaryColor: Color(0xFF38BDF8),
      secondaryColor: Color(0xFF0284C7),
      echelon: 'Офицерский корпус',
    ),
    RankTierInfo(
      level: 7,
      title: 'Штурман орбиты',
      minExp: 4301,
      maxExp: 6000,
      primaryColor: Color(0xFF06B6D4),
      secondaryColor: Color(0xFF0891B2),
      echelon: 'Офицерский корпус',
    ),
    RankTierInfo(
      level: 8,
      title: 'Офицер связи',
      minExp: 6001,
      maxExp: 8200,
      primaryColor: Color(0xFF0EA5E9),
      secondaryColor: Color(0xFF0369A1),
      echelon: 'Офицерский корпус',
    ),
    RankTierInfo(
      level: 9,
      title: 'Инженер модулей',
      minExp: 8201,
      maxExp: 11000,
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF059669),
      echelon: 'Офицерский корпус',
    ),
    RankTierInfo(
      level: 10,
      title: 'Специалист миссий',
      minExp: 11001,
      maxExp: 14500,
      primaryColor: Color(0xFF14B8A6),
      secondaryColor: Color(0xFF0F766E),
      echelon: 'Офицерский корпус',
    ),

    // III Эшелон: Командный состав
    RankTierInfo(
      level: 11,
      title: 'Лейтенант флота',
      minExp: 14501,
      maxExp: 19000,
      primaryColor: Color(0xFF818CF8),
      secondaryColor: Color(0xFF6366F1),
      echelon: 'Командный состав',
    ),
    RankTierInfo(
      level: 12,
      title: 'Старший лейтенант',
      minExp: 19001,
      maxExp: 24500,
      primaryColor: Color(0xFFA855F7),
      secondaryColor: Color(0xFF7E22CE),
      echelon: 'Командный состав',
    ),
    RankTierInfo(
      level: 13,
      title: 'Капитан III ранга',
      minExp: 24501,
      maxExp: 31000,
      primaryColor: Color(0xFFC084FC),
      secondaryColor: Color(0xFF9333EA),
      echelon: 'Командный состав',
    ),
    RankTierInfo(
      level: 14,
      title: 'Капитан II ранга',
      minExp: 31001,
      maxExp: 39000,
      primaryColor: Color(0xFFD946EF),
      secondaryColor: Color(0xFFA21CAF),
      echelon: 'Командный состав',
    ),
    RankTierInfo(
      level: 15,
      title: 'Капитан I ранга',
      minExp: 39001,
      maxExp: 48500,
      primaryColor: Color(0xFF7C3AED),
      secondaryColor: Color(0xFF5B21B6),
      echelon: 'Командный состав',
    ),

    // IV Эшелон: Высшее командование
    RankTierInfo(
      level: 16,
      title: 'Командор сектора',
      minExp: 48501,
      maxExp: 60000,
      primaryColor: Color(0xFFF59E0B),
      secondaryColor: Color(0xFFD97706),
      echelon: 'Высшее командование',
    ),
    RankTierInfo(
      level: 17,
      title: 'Капитан флагмана',
      minExp: 60001,
      maxExp: 74000,
      primaryColor: Color(0xFFFBBF24),
      secondaryColor: Color(0xFFB45309),
      echelon: 'Высшее командование',
    ),
    RankTierInfo(
      level: 18,
      title: 'Адмирал орбиты',
      minExp: 74001,
      maxExp: 91000,
      primaryColor: Color(0xFFF97316),
      secondaryColor: Color(0xFFC2410C),
      echelon: 'Высшее командование',
    ),
    RankTierInfo(
      level: 19,
      title: 'Верховный маршал',
      minExp: 91001,
      maxExp: 112000,
      primaryColor: Color(0xFFEF4444),
      secondaryColor: Color(0xFFB91C1C),
      echelon: 'Высшее командование',
    ),
    RankTierInfo(
      level: 20,
      title: 'Архитектор созвездий',
      minExp: 112001,
      maxExp: 9999999,
      primaryColor: Color(0xFFE2E8F0),
      secondaryColor: Color(0xFF38BDF8),
      echelon: 'Легендарный ранг',
    ),
  ];

  static RankTierInfo getRankByExp(int exp) {
    if (exp <= 0) return ranks.first;
    for (final r in ranks) {
      if (exp >= r.minExp && exp <= r.maxExp) {
        return r;
      }
    }
    return ranks.last;
  }

  static double getProgress(int exp) {
    final rank = getRankByExp(exp);
    if (rank.level == 20) return 1.0;
    final totalInRank = rank.maxExp - rank.minExp;
    final gainedInRank = exp - rank.minExp;
    if (totalInRank <= 0) return 1.0;
    return (gainedInRank / totalInRank).clamp(0.0, 1.0);
  }
}
