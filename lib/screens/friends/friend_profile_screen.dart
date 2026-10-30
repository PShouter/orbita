import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  int _cheersCount = 0;
  bool _canCheerToday = true;

  @override
  void initState() {
    super.initState();
    _loadCheerState();
  }

  Future<void> _loadCheerState() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastCheerDate = prefs.getString('last_cheer_${widget.friendUserId}');
    final count = prefs.getInt('cheers_count_${widget.friendUserId}') ?? 0;

    setState(() {
      _cheersCount = count;
      _canCheerToday = lastCheerDate != today;
    });
  }

  Future<void> _cheerFriend() async {
    if (!_canCheerToday) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Вы уже поддержали этого друга сегодня! Приходите завтра 🙌',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final newCount = _cheersCount + 1;
    await prefs.setString('last_cheer_${widget.friendUserId}', today);
    await prefs.setInt('cheers_count_${widget.friendUserId}', newCount);

    setState(() {
      _cheersCount = newCount;
      _canCheerToday = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Вы поддержали ${widget.friendName}! 🔥'),
          backgroundColor: const Color(0xFFF59E0B),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Профиль друга',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
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
          // Карточка друга: аватарка слева, имя и ID в центре, Чат справа
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                // Аватарка слева
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF1E293B),
                    child: Text(
                      widget.friendName.isNotEmpty
                          ? widget.friendName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Имя и ID в центре
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.friendName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@${widget.friendUsername}',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: const Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Иконка чата справа
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Чат с другом откроется в следующем обновлении 🚀',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: Color(0xFFC4B5FD),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3 Блока счетчиков
          Row(
            children: [
              _buildCounterTile(
                '0',
                'Дней в орбите',
                const Color(0xFF06B6D4),
                cardBg,
                textSecondary,
              ),
              const SizedBox(width: 8),
              _buildCounterTile(
                '0',
                'Общий стрик',
                const Color(0xFFF59E0B),
                cardBg,
                textSecondary,
              ),
              const SizedBox(width: 8),
              _buildCounterTile(
                '0',
                'Совместных событий',
                const Color(0xFF10B981),
                cardBg,
                textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Кнопка «Поддержать» с суточным лимитом
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _canCheerToday
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                foregroundColor: _canCheerToday ? Colors.black : Colors.white70,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Text('🙌', style: TextStyle(fontSize: 18)),
              label: Text(
                _canCheerToday
                    ? 'Поддержать ($_cheersCount)'
                    : 'Поддержано сегодня ($_cheersCount)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _cheerFriend,
            ),
          ),
          const SizedBox(height: 20),

          // Блок «Общая синергия привычек» (в разработке)
          Container(
            padding: const EdgeInsets.all(18),
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
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Скоро',
                        style: TextStyle(
                          color: Color(0xFFC4B5FD),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: innerBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF8B5CF6),
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'В разработке 🚀',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Здесь будут отображаться общие цели и взаимные привычки',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),
                ),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
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
