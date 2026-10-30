import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'friend_profile_screen.dart';
import '../../services/friends_service.dart';
import '../../services/notification_service.dart';

typedef JsonMap = Map<String, dynamic>;

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

  List<JsonMap> _acceptedFriends = [];
  List<JsonMap> _incomingRequests = [];
  List<JsonMap> _outgoingRequests = [];
  bool _isLoading = true;

  String? _myInviteCode;
  RealtimeChannel? _friendshipsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyProfileAndFriends();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _friendshipsSubscription?.unsubscribe();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  void _setupRealtimeSubscription() {
    final uid = _currentUserId;
    if (uid == null) return;

    _friendshipsSubscription = _supabase
        .channel('public:friendships_user_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (payload) async {
            final newRecord = payload.newRecord;
            final eventType = payload.eventType;

            if (eventType == PostgresChangeEvent.insert &&
                newRecord['friend_id'] == uid &&
                newRecord['status'] == 'pending') {
              NotificationService.instance.showNotification(
                id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                title: 'Новая заявка в друзья! 🛸',
                body: 'Кто-то хочет добавиться на вашу Орбиту.',
                payload: 'screen_friends',
              );
            }

            if (eventType == PostgresChangeEvent.update &&
                newRecord['user_id'] == uid &&
                newRecord['status'] == 'accepted') {
              NotificationService.instance.showNotification(
                id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                title: 'Заявка принята! ✨',
                body: 'Пользователь принял ваше приглашение на Орбиту.',
                payload: 'screen_friends',
              );
            }

            await _loadMyProfileAndFriends(showLoading: false);
          },
        )
        .subscribe();
  }

  Future<void> _loadMyProfileAndFriends({bool showLoading = true}) async {
    final uid = _currentUserId;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

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
      final List outgoing = [];
      final Set<String> profileIdsToFetch = {};

      for (final item in (data as List)) {
        final userId = item['user_id'] as String;
        final friendId = item['friend_id'] as String;
        final status = item['status'] as String;

        if (status == 'accepted') {
          accepted.add(item);
          profileIdsToFetch.add(userId == uid ? friendId : userId);
        } else if (status == 'pending') {
          if (friendId == uid) {
            incoming.add(item);
            profileIdsToFetch.add(userId);
          } else if (userId == uid) {
            outgoing.add(item);
            profileIdsToFetch.add(friendId);
          }
        }
      }

      Map<String, Map<String, dynamic>> profilesMap = {};
      if (profileIdsToFetch.isNotEmpty) {
        final profilesData = await _supabase
            .from('profiles')
            .select('id, full_name, username')
            .filter('id', 'in', profileIdsToFetch.toList());

        for (final p in (profilesData as List)) {
          profilesMap[p['id'] as String] = Map<String, dynamic>.from(p);
        }
      }

      _acceptedFriends = accepted.map((item) {
        final otherId =
            item['user_id'] == uid ? item['friend_id'] : item['user_id'];
        final prof = profilesMap[otherId] ?? {};
        return <String, dynamic>{
          'friendshipId': item['id'],
          'userId': otherId,
          'name': prof['full_name'] ?? prof['username'] ?? 'Пользователь',
          'username': prof['username'] ?? 'user',
        };
      }).toList();

      _incomingRequests = incoming.map((item) {
        final otherId = item['user_id'];
        final prof = profilesMap[otherId] ?? {};
        return <String, dynamic>{
          'friendshipId': item['id'],
          'userId': otherId,
          'name': prof['full_name'] ?? prof['username'] ?? 'Пользователь',
          'username': prof['username'] ?? 'user',
        };
      }).toList();

      _outgoingRequests = outgoing.map((item) {
        final otherId = item['friend_id'];
        final prof = profilesMap[otherId] ?? {};
        return <String, dynamic>{
          'friendshipId': item['id'],
          'userId': otherId,
          'name': prof['full_name'] ?? prof['username'] ?? 'Пользователь',
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
            content: Text('Заявка отправлена и появилась в ваших исходящих!'),
            backgroundColor: Color(0xFF7C3AED),
          ),
        );
      }
      await _loadMyProfileAndFriends(showLoading: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _acceptFriendRequest(String friendshipId) async {
    try {
      final res = await _supabase
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('id', friendshipId)
          .select();

      if ((res as List).isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ошибка доступа: проверьте RLS политики таблицы friendships в Supabase',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка принята! Друг добавлен на вашу Орбиту.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }

      await _loadMyProfileAndFriends(showLoading: false);
    } catch (e) {
      debugPrint('Ошибка принятия заявки: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось принять заявку: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _cancelOrRemoveFriendship(
    String friendshipId, {
    bool isOutgoing = false,
  }) async {
    try {
      await _supabase.from('friendships').delete().eq('id', friendshipId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOutgoing ? 'Заявка отменена' : 'Удалено из списка'),
          ),
        );
      }

      await _loadMyProfileAndFriends(showLoading: false);
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

  void _openFriendProfile(JsonMap friend) {
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
    final textPrimary =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    final int totalRequestsCount =
        _incomingRequests.length + _outgoingRequests.length;

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
            tooltip: 'Обновить',
            icon: Icon(Icons.refresh, color: textPrimary),
            onPressed: () => _loadMyProfileAndFriends(showLoading: true),
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
                  if (totalRequestsCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _incomingRequests.isNotEmpty
                            ? const Color(0xFFEC4899)
                            : Colors.grey.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalRequestsCount',
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
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ),
            ),
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
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: borderColor),
                itemBuilder: (ctx, i) {
                  final user = _searchResults[i];
                  final isAlreadyFriend = _acceptedFriends.any(
                    (f) => f['userId'] == user.id,
                  );
                  final isPendingOut = _outgoingRequests.any(
                    (f) => f['userId'] == user.id,
                  );
                  final isPendingIn = _incomingRequests.any(
                    (f) => f['userId'] == user.id,
                  );

                  Widget actionWidget;
                  if (isAlreadyFriend) {
                    actionWidget = const Text(
                      'В друзьях',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  } else if (isPendingOut) {
                    actionWidget = const Text(
                      'Заявка отправлена',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  } else if (isPendingIn) {
                    actionWidget = const Text(
                      'Ждёт ответа',
                      style: TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  } else {
                    actionWidget = ElevatedButton(
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
                        'Пригласить',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }

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
                    trailing: actionWidget,
                  );
                },
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Вкладка 1: Принятые друзья
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
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: const Color(
                                            0xFF1E293B,
                                          ),
                                          child: Text(
                                            f['name'].isNotEmpty
                                                ? f['name'][0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                f['name'],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '@${f['username']}',
                                                style: TextStyle(
                                                  color: textSecondary,
                                                  fontSize: 12,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Удалить из друзей',
                                          icon: const Icon(
                                            Icons.person_remove_outlined,
                                            color: Colors.redAccent,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _cancelOrRemoveFriendship(
                                            f['friendshipId'],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                      // Вкладка 2: Входящие и Исходящие заявки
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            children: [
                              Text(
                                'Входящие заявки',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${_incomingRequests.length})',
                                style: const TextStyle(
                                  color: Color(0xFFEC4899),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_incomingRequests.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Новых входящих заявок нет',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
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
                                        size: 26,
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
                                        size: 26,
                                      ),
                                      tooltip: 'Отклонить',
                                      onPressed: () =>
                                          _cancelOrRemoveFriendship(
                                        req['friendshipId'],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                'Исходящие заявки',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${_outgoingRequests.length})',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_outgoingRequests.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'У вас нет активных отправленных заявок',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            ..._outgoingRequests.map((out) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.grey.withValues(
                                        alpha: 0.15,
                                      ),
                                      child: const Icon(
                                        Icons.outgoing_mail,
                                        color: Colors.amber,
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
                                            out['name'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            '@${out['username']} • Ждет ответа',
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                      ),
                                      onPressed: () =>
                                          _cancelOrRemoveFriendship(
                                        out['friendshipId'],
                                        isOutgoing: true,
                                      ),
                                      child: const Text(
                                        'Отменить',
                                        style: TextStyle(fontSize: 12),
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
