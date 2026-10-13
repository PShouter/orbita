import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendProfileScreen extends StatefulWidget {
  final bool isDarkMode;
  final String friendshipId;
  final String friendUserId;
  final String friendName;
  final String friendUsername;
  final VoidCallback onFriendRemoved;

  const FriendProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.friendshipId,
    required this.friendUserId,
    required this.friendName,
    required this.friendUsername,
    required this.onFriendRemoved,
  });

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  int _cheersCount = 12;
  bool _isCloseCircle = true;

  // Демо-привычки для синергии (синхронизируются с общим стилем)
  final List<Map<String, dynamic>> _habits = [
    {
      'title': 'Figma UI Daily',
      'subtitle': 'Совместный спринт по будням',
      'icon': '🎨',
      'streak': 84,
      'isDone': true,
    },
    {
      'title': 'Утренняя пробежка 5 км',
      'subtitle': 'Синхронизация привычки',
      'icon': '🏃',
      'streak': 29,
      'isDone': false,
    },
    {
      'title': 'Чтение книг 30 мин',
      'subtitle': 'Глава каждый вечер',
      'icon': '📚',
      'streak': 41,
      'isDone': true,
    },
  ];

  void _cheerFriend() {
    HapticFeedback.heavyImpact();
    setState(() => _cheersCount++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Вы поддержали стрик ${widget.friendName}! 🔥'),
        backgroundColor: const Color(0xFFF59E0B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleHabit(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _habits[index]['isDone'] = !_habits[index]['isDone'];
    });
  }

  Future<void> _confirmRemoveFriend() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF161B22)
            : Colors.white,
        title: const Text('Удалить из друзей?'),
        content: Text(
          'Вы действительно хотите удалить ${widget.friendName} из своей орбиты?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase
            .from('friendships')
            .delete()
            .eq('id', widget.friendshipId);
        widget.onFriendRemoved();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        debugPrint('Ошибка удаления: $e');
      }
    }
  }

  void _copyLink() {
    Clipboard.setData(
      ClipboardData(text: 'orbita://user/${widget.friendUsername}'),
    );
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка на орбиту друга скопирована! 🔗')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF080B14) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF121626) : Colors.white;
    final innerBg = isDark ? const Color(0xFF181E32) : const Color(0xFFEEF2F6);
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              'ПРОФИЛЬ ДРУГА',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B5CF6),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⭐ ', style: TextStyle(fontSize: 10)),
                  Text(
                    'Взаимная орбита',
                    style: TextStyle(
                      color: Color(0xFFFCD34D),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textPrimary),
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (val) {
              if (val == 'copy') _copyLink();
              if (val == 'remove') _confirmRemoveFriend();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 18, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Text(
                      'Поделиться орбитой',
                      style: TextStyle(color: textPrimary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(
                      Icons.person_remove_outlined,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Удалить из друзей',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Переключатель режима видимости
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Режим видимости:',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _isCloseCircle = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isCloseCircle
                                ? const Color(0xFF7C3AED)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Близкий круг',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isCloseCircle
                                  ? Colors.white
                                  : textSecondary,
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _isCloseCircle = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: !_isCloseCircle
                                ? const Color(0xFF7C3AED)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Знакомый',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: !_isCloseCircle
                                  ? Colors.white
                                  : textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Карточка Героя (Аватар, Имя, Статус, 3 счётчика)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                // Аватарка со статусом
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: const Color(0xFF1E293B),
                        child: Text(
                          widget.friendName.isNotEmpty
                              ? widget.friendName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0E17),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF8B5CF6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Color(0xFF8B5CF6), size: 6),
                          SizedBox(width: 4),
                          Text(
                            'Фокус',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.friendName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${widget.friendUsername} • На Орбите',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 14),

                // Статус / цитата
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('⏳ ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(
                          _isCloseCircle
                              ? '«Глубокий спринт над задачами Орбиты до 16:30»'
                              : '«Занят до 16:30 (Глубокий фокус)»',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFDDD6FE),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3 Счетчика (Дней, Стрик, Слоты)
                Row(
                  children: [
                    _buildCounterTile(
                      '142',
                      'Дней в синергии',
                      const Color(0xFF06B6D4),
                      innerBg,
                      textSecondary,
                    ),
                    const SizedBox(width: 8),
                    _buildCounterTile(
                      '🔥 38',
                      'Общий стрик',
                      const Color(0xFFF59E0B),
                      innerBg,
                      textSecondary,
                    ),
                    const SizedBox(width: 8),
                    _buildCounterTile(
                      '19',
                      'Совместных слотов',
                      const Color(0xFF10B981),
                      innerBg,
                      textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Быстрые действия (Написать, Слот, Поддержать)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text(
                    'Чат',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Чат с другом откроется в следующем обновлении 🚀',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF06B6D4),
                    side: const BorderSide(color: Color(0xFF06B6D4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: const Text(
                    'Слот',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Свободное окно для встречи с ${widget.friendName}: 17:00 - 18:30 ☕',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B)
                        .withValues(alpha: 0.2),
                    foregroundColor: const Color(0xFFF59E0B),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Text('🙌', style: TextStyle(fontSize: 16)),
                  label: Text(
                    '+$_cheersCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _cheerFriend,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4. Синергия привычек
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🤝 ', style: TextStyle(fontSize: 16)),
                        Text(
                          'Общая синергия привычек',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '3 цели',
                        style: TextStyle(
                          color: Color(0xFF06B6D4),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._habits.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final h = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: innerBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Text(h['icon'], style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h['title'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                h['subtitle'],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '🔥 ${h['streak']} дн',
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _toggleHabit(idx),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: h['isDone']
                                  ? const Color(0xFF10B981)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: h['isDone']
                                    ? const Color(0xFF10B981)
                                    : textSecondary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: h['isDone']
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterTile(
    String val,
    String label,
    Color color,
    Color bg,
    Color textSecondary,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
