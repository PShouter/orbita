import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  List<Map<String, dynamic>> _acceptedFriends = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> _outgoingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFriendships();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // Загрузка всех связей пользователя
  Future<void> _loadFriendships() async {
    final uid = _currentUserId;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Загружаем все дружбы, где текущий пользователь либо отправитель, либо получатель
      final data = await _supabase
          .from('friendships')
          .select('id, sender_id, receiver_id, status, created_at')
          .or('sender_id.eq.$uid,receiver_id.eq.$uid');

      final List accepted = [];
      final List incoming = [];
      final List outgoing = [];

      final Set<String> profileIdsToFetch = {};

      for (final item in (data as List)) {
        final senderId = item['sender_id'];
        final receiverId = item['receiver_id'];
        final status = item['status'];

        if (status == 'accepted') {
          accepted.add(item);
          profileIdsToFetch.add(senderId == uid ? receiverId : senderId);
        } else if (status == 'pending') {
          if (receiverId == uid) {
            incoming.add(item);
            profileIdsToFetch.add(senderId);
          } else {
            outgoing.add(item);
            profileIdsToFetch.add(receiverId);
          }
        }
      }

      // 2. Подгружаем профили этих людей
      Map<String, Map<String, dynamic>> profilesMap = {};
      if (profileIdsToFetch.isNotEmpty) {
        final profilesData = await _supabase
            .from('profiles')
            .select('id, full_name, username, avatar_url')
            .filter('id', 'in', profileIdsToFetch.toList());

        for (final p in (profilesData as List)) {
          profilesMap[p['id']] = Map<String, dynamic>.from(p);
        }
      }

      // 3. Собираем итоговые списки
      _acceptedFriends = accepted.map((item) {
        final otherId = item['sender_id'] == uid
            ? item['receiver_id']
            : item['sender_id'];
        final prof = profilesMap[otherId] ?? {};
        return {
          'friendshipId': item['id'],
          'userId': otherId,
          'name': prof['full_name'] ?? 'Пользователь',
          'username': prof['username'] ?? 'user',
        };
      }).toList();

      _incomingRequests = incoming.map((item) {
        final otherId = item['sender_id'];
        final prof = profilesMap[otherId] ?? {};
        return {
          'friendshipId': item['id'],
          'userId': otherId,
          'name': prof['full_name'] ?? 'Пользователь',
          'username': prof['username'] ?? 'user',
        };
      }).toList();

      _outgoingRequests = outgoing.map((item) {
        final otherId = item['receiver_id'];
        final prof = profilesMap[otherId] ?? {};
        return {
          'friendshipId': item['id'],
          'userId': otherId,
          'name': prof['full_name'] ?? 'Пользователь',
          'username': prof['username'] ?? 'user',
        };
      }).toList();
    } catch (e) {
      debugPrint('Ошибка загрузки списка друзей: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Поиск пользователей в Supabase
  Future<void> _searchUsers(String query) async {
    final clean = query.trim().replaceAll('@', '');
    if (clean.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final uid = _currentUserId;
      final res = await _supabase
          .from('profiles')
          .select('id, full_name, username')
          .ilike('username', '%$clean%')
          .neq('id', uid ?? '')
          .limit(10);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('Ошибка поиска пользователей: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // Отправка заявки в друзья
  Future<void> _sendFriendRequest(String targetUserId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from('friendships').insert({
        'sender_id': uid,
        'receiver_id': targetUserId,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка в друзья отправлена')),
        );
      }
      _loadFriendships();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка уже отправлена или существует')),
        );
      }
    }
  }

  // Принятие заявки
  Future<void> _acceptFriendRequest(String friendshipId) async {
    try {
      await _supabase
          .from('friendships')
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', friendshipId);

      _loadFriendships();
    } catch (e) {
      debugPrint('Ошибка принятия заявки: $e');
    }
  }

  // Отклонение / Удаление дружбы
  Future<void> _removeFriendship(String friendshipId) async {
    try {
      await _supabase.from('friendships').delete().eq('id', friendshipId);
      _loadFriendships();
    } catch (e) {
      debugPrint('Ошибка удаления: $e');
    }
  }

  // Копирование персональной ссылки-приглашения
  void _copyInviteLink() {
    final link = 'https://orbita.app/invite?user=${widget.currentUsername}';
    Clipboard.setData(ClipboardData(text: link));
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ссылка-приглашение скопирована:\n$link'),
        backgroundColor: const Color(0xFF2C69D1),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF0F6FC)
        : const Color(0xFF24292F);
    final textSecondary = isDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF57606A);
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Друзья',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Пригласить по ссылке',
            icon: const Icon(Icons.share_outlined, color: Color(0xFF38BDF8)),
            onPressed: _copyInviteLink,
          ),
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _loadFriendships,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: textSecondary,
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
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_incomingRequests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
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
          // Поле глобального поиска по @username
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Поиск человека по @username...',
                  hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: Colors.grey,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
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
                onSubmitted: _searchUsers,
                onChanged: (val) {
                  if (val.length >= 2) _searchUsers(val);
                },
              ),
            ),
          ),

          // Результаты поиска
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
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
                    (f) => f['userId'] == user['id'],
                  );
                  final isOutgoing = _outgoingRequests.any(
                    (f) => f['userId'] == user['id'],
                  );

                  return ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFF2C69D1),
                      child: Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                    title: Text(
                      user['full_name'] ?? 'Пользователь',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '@${user['username']}',
                      style: TextStyle(color: textSecondary),
                    ),
                    trailing: isAlreadyFriend
                        ? const Text(
                            'В друзьях',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          )
                        : isOutgoing
                        ? const Text(
                            'Запрос отправлен',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                            ),
                          )
                        : FilledButton.tonal(
                            onPressed: () {
                              _sendFriendRequest(user['id']);
                              setState(() => _searchResults = []);
                              _searchController.clear();
                            },
                            child: const Text(
                              'Добавить',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                  );
                },
              ),
            ),

          // Баннер быстрой инвайт-ссылки
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: InkWell(
              onTap: _copyInviteLink,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.link, color: Color(0xFF38BDF8), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Пригласить друга по ссылке',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                          Text(
                            'Нажмите, чтобы скопировать персональную ссылку',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.copy, size: 18, color: Color(0xFF38BDF8)),
                  ],
                ),
              ),
            ),
          ),

          // Вкладки: Друзья и Заявки
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Вкладка 1: Список принятых друзей
                      _acceptedFriends.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 48,
                                    color: Colors.grey.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'У вас пока нет друзей',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Найдите их по @username или отправьте ссылку',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _acceptedFriends.length,
                              itemBuilder: (ctx, i) {
                                final f = _acceptedFriends[i];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      const CircleAvatar(
                                        backgroundColor: Color(0xFF2C69D1),
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        ),
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
                                                fontWeight: FontWeight.bold,
                                                color: textPrimary,
                                              ),
                                            ),
                                            Text(
                                              '@${f['username']}',
                                              style: TextStyle(
                                                color: textSecondary,
                                                fontSize: 12,
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
                                          size: 20,
                                        ),
                                        onPressed: () => _removeFriendship(
                                          f['friendshipId'],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                      // Вкладка 2: Входящие и исходящие заявки
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            'Входящие заявки (${_incomingRequests.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_incomingRequests.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Новых заявок нет',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            ..._incomingRequests.map((req) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Colors.orangeAccent,
                                      child: Icon(
                                        Icons.person_add,
                                        color: Colors.white,
                                        size: 20,
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
                                            ),
                                          ),
                                          Text(
                                            '@${req['username']}',
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                      onPressed: () => _acceptFriendRequest(
                                        req['friendshipId'],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.cancel,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _removeFriendship(
                                        req['friendshipId'],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                          const SizedBox(height: 16),
                          Text(
                            'Отправленные запросы (${_outgoingRequests.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_outgoingRequests.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Нет ожидающих запросов',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            ..._outgoingRequests.map((req) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Colors.grey,
                                      child: Icon(
                                        Icons.hourglass_top,
                                        color: Colors.white,
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
                                            ),
                                          ),
                                          Text(
                                            '@${req['username']}',
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _removeFriendship(
                                        req['friendshipId'],
                                      ),
                                      child: const Text(
                                        'Отменить',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                        ),
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
