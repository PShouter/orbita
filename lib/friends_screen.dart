import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'friend_profile_screen.dart';
import 'services/friends_service.dart';

class FriendsScreen extends StatefulWidget {
  final bool isDarkMode;
  final String currentUsername;

  const FriendsScreen({
    super.key,
    required this.isDarkMode,
    required this.currentUsername,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  List<FriendProfile> _searchResults = [];
  bool _isSearching = false;

  List<Map<String, dynamic>> _acceptedFriends = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  bool _isLoading = true;

  String? _myInviteCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyProfileAndFriends();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<void> _loadMyProfileAndFriends() async {
    final uid = _currentUserId;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final myProf = await FriendsService.instance.getMyProfile();
      if (myProf != null) {
        _myInviteCode = myProf.inviteCode;
      }

      final data = await _supabase
          .from('friendships')
          .select('id, user_id, friend_id, status, created_at')
          .or('user_id.eq.$uid,friend_id.eq.$uid');

      final List accepted = [];
      final List incoming = [];
      final Set<String> profileIdsToFetch = {};

      for (final item in (data as List)) {
        final userId = item['user_id'];
        final friendId = item['friend_id'];
        final status = item['status'];

        if (status == 'accepted') {
          accepted.add(item);
          profileIdsToFetch.add(userId == uid ? friendId : userId);
        } else if (status == 'pending') {
          if (friendId == uid) {
            incoming.add(item);
            profileIdsToFetch.add(userId);
          }
        }
      }

      Map<String, Map<String, dynamic>> profilesMap = {};
      if (profileIdsToFetch.isNotEmpty) {
        final profilesData = await _supabase
            .from('profiles')
            .select('id, display_name, username')
            .filter('id', 'in', profileIdsToFetch.toList());

        for (final p in (profilesData as List)) {
          profilesMap[p['id']] = Map<String, dynamic>.from(p);
        }
      }

      _acceptedFriends = accepted.map((item) {
        final otherId = item['user_id'] == uid
            ? item['friend_id']
            : item['user_id'];
        final prof = profilesMap[otherId] ?? {};
        return {
          'friendshipId': item['id'],
          'userId': otherId,
          'name': prof['display_name'] ?? 'Пользователь',
          'username': prof['username'] ?? 'user',
          'streakDays':
              42 + (otherId.hashCode % 50).abs(), // Демо-стрик для визуала
        };
      }).toList();

      _incomingRequests = incoming.map((item) {
        final otherId = item['user_id'];
        final prof = profilesMap[otherId] ?? {};
        return {
          'friendshipId': item['id'],
          'userId': otherId,
          'name': prof['display_name'] ?? 'Пользователь',
          'username': prof['username'] ?? 'user',
        };
      }).toList();
    } catch (e) {
      debugPrint('Ошибка загрузки списка друзей: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUniversalSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await FriendsService.instance.searchUsers(clean);
      if (mounted) {
        setState(() => _searchResults = results);
      }
    } catch (e) {
      debugPrint('Ошибка поиска: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendFriendRequest(String targetUserId) async {
    try {
      await FriendsService.instance.sendFriendRequest(targetUserId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка отправлена! Ожидайте подтверждения.'),
            backgroundColor: Color(0xFF7C3AED),
          ),
        );
      }
      _loadMyProfileAndFriends();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запрос уже был отправлен ранее')),
        );
      }
    }
  }

  Future<void> _acceptFriendRequest(String friendshipId) async {
    try {
      await _supabase
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('id', friendshipId);

      _loadMyProfileAndFriends();
    } catch (e) {
      debugPrint('Ошибка принятия заявки: $e');
    }
  }

  Future<void> _removeFriendship(String friendshipId) async {
    try {
      await _supabase.from('friendships').delete().eq('id', friendshipId);
      _loadMyProfileAndFriends();
    } catch (e) {
      debugPrint('Ошибка удаления: $e');
    }
  }

  void _copyInviteLink() {
    final code = _myInviteCode ?? 'ORB-USER';
    final shareText =
        'Привет! Добавляйся ко мне в приложении Орбита. Мой код: $code\nСсылка: orbita://invite?code=$code';
    Clipboard.setData(ClipboardData(text: shareText));
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Инвайт-код скопирован: $code ✨'),
        backgroundColor: const Color(0xFF7C3AED),
      ),
    );
  }

  void _openFriendProfile(Map<String, dynamic> friend) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendProfileScreen(
          isDarkMode: widget.isDarkMode,
          friendshipId: friend['friendshipId'],
          friendUserId: friend['userId'],
          friendName: friend['name'],
          friendUsername: friend['username'],
          onFriendRemoved: _loadMyProfileAndFriends,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF07090E) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF131826) : Colors.white;
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
        titleSpacing: 16,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              'Друзья',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '${_acceptedFriends.length}',
                style: const TextStyle(
                  color: Color(0xFFC4B5FD),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Поделиться кодом',
            icon: const Icon(Icons.qr_code_2, color: Color(0xFF8B5CF6)),
            onPressed: _copyInviteLink,
          ),
          IconButton(
            tooltip: 'Перезагрузить',
            icon: Icon(Icons.refresh, color: textPrimary),
            onPressed: _loadMyProfileAndFriends,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF8B5CF6),
          indicatorWeight: 3,
          labelColor: const Color(0xFF8B5CF6),
          unselectedLabelColor: textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: 'Мои друзья (${_acceptedFriends.length})'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Заявки'),
                  if (_incomingRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_incomingRequests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ЕДИНАЯ СТРОКА ПОИСКА (по коду ИЛИ по username)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF101422) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Поиск по @username или коду инвайта...',
                  hintStyle: TextStyle(color: textSecondary, fontSize: 12),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: Color(0xFF8B5CF6),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchResults = []);
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: _handleUniversalSearch,
                onChanged: (val) {
                  if (val.length >= 2) _handleUniversalSearch(val);
                },
              ),
            ),
          ),

          // Результаты глобального поиска
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: borderColor),
                itemBuilder: (ctx, i) {
                  final user = _searchResults[i];
                  final isAlreadyFriend = _acceptedFriends.any(
                    (f) => f['userId'] == user.id,
                  );

                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF7C3AED),
                      child: Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      user.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '@${user.username}',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                    trailing: isAlreadyFriend
                        ? const Text(
                            'В друзьях',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              _sendFriendRequest(user.id);
                              setState(() => _searchResults = []);
                              _searchController.clear();
                            },
                            child: const Text(
                              'Заявка',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  );
                },
              ),
            ),

          // Вкладки: Мои друзья / Заявки
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Вкладка 1: Мои друзья
                      _acceptedFriends.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '🛸',
                                    style: TextStyle(fontSize: 42),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'На вашей орбите пока пусто',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Найдите друзей в поиске выше или поделитесь кодом',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: _acceptedFriends.length,
                              itemBuilder: (ctx, i) {
                                final f = _acceptedFriends[i];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _openFriendProfile(f),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            // Аватарка со статусом
                                            Stack(
                                              alignment: Alignment.bottomRight,
                                              children: [
                                                CircleAvatar(
                                                  radius: 22,
                                                  backgroundColor: const Color(
                                                    0xFF1E293B,
                                                  ),
                                                  child: Text(
                                                    f['name'].isNotEmpty
                                                        ? f['name'][0]
                                                              .toUpperCase()
                                                        : '?',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF10B981,
                                                    ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: cardBg,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    f['name'],
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '@${f['username']}',
                                                    style: TextStyle(
                                                      color: textSecondary,
                                                      fontSize: 11,
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Бейдж стрика
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF59E0B)
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: const Color(0xFFF59E0B)
                                                      .withValues(alpha: 0.25),
                                                ),
                                              ),
                                              child: Text(
                                                '🔥 ${f['streakDays']} дн.',
                                                style: const TextStyle(
                                                  color: Color(0xFFF59E0B),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        // Кнопки действий прямо в карточке
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF7C3AED,
                                                  ).withValues(alpha: 0.2),
                                                  foregroundColor: const Color(
                                                    0xFFC4B5FD,
                                                  ),
                                                  elevation: 0,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.chat_bubble_outline,
                                                  size: 14,
                                                ),
                                                label: const Text(
                                                  'Чат',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _openFriendProfile(f),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              tooltip: 'Удалить из друзей',
                                              icon: const Icon(
                                                Icons.person_remove_outlined,
                                                color: Colors.redAccent,
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  _removeFriendship(
                                                    f['friendshipId'],
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                      // Вкладка 2: Входящие заявки
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_incomingRequests.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36),
                              child: Center(
                                child: Text(
                                  'Новых входящих заявок нет',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._incomingRequests.map((req) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFF8B5CF6)
                                          .withValues(alpha: 0.2),
                                      child: const Icon(
                                        Icons.person_add,
                                        color: Color(0xFF8B5CF6),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            req['name'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            '@${req['username']}',
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF10B981),
                                        size: 24,
                                      ),
                                      tooltip: 'Принять',
                                      onPressed: () => _acceptFriendRequest(
                                        req['friendshipId'],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.cancel,
                                        color: Colors.redAccent,
                                        size: 24,
                                      ),
                                      tooltip: 'Отклонить',
                                      onPressed: () => _removeFriendship(
                                        req['friendshipId'],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
