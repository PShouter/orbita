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
  final TextEditingController _codeController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  List<Map<String, dynamic>> _acceptedFriends = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  List<Map<String, dynamic>> _outgoingRequests = [];
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
    _codeController.dispose();
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
      final myProf = await _supabase
          .from('profiles')
          .select('invite_code')
          .eq('id', uid)
          .maybeSingle();

      if (myProf != null && myProf['invite_code'] != null) {
        _myInviteCode = myProf['invite_code'];
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
          } else {
            outgoing.add(item);
            profileIdsToFetch.add(friendId);
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

      _outgoingRequests = outgoing.map((item) {
        final otherId = item['friend_id'];
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
          .select('id, display_name, username')
          .ilike('username', '%$clean%')
          .neq('id', uid ?? '')
          .limit(10);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('Ошибка поиска пользователей: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _addFriendByCode() async {
    final code = _codeController.text.trim().toUpperCase();
    final uid = _currentUserId;
    if (code.isEmpty || uid == null) return;

    try {
      final target = await _supabase
          .from('profiles')
          .select('id, display_name, username')
          .eq('invite_code', code)
          .maybeSingle();

      if (target == null || target['id'] == uid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Неверный код или вы ввели свой собственный код'),
            ),
          );
        }
        return;
      }

      await _sendFriendRequest(target['id']);
      _codeController.clear();
    } catch (e) {
      debugPrint('Ошибка добавления по коду: $e');
    }
  }

  Future<void> _sendFriendRequest(String targetUserId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from('friendships').insert({
        'user_id': uid,
        'friend_id': targetUserId,
        'status': 'accepted',
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Друг успешно добавлен!')));
      }
      _loadMyProfileAndFriends();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Запрос уже отправлен или пользователь уже в друзьях',
            ),
          ),
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
        content: Text('Инвайт-код и ссылка скопированы в буфер:\n$code'),
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
            tooltip: 'Скопировать мой код',
            icon: const Icon(Icons.share_outlined, color: Color(0xFF38BDF8)),
            onPressed: _copyInviteLink,
          ),
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _loadMyProfileAndFriends,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: InkWell(
              onTap: _copyInviteLink,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.qr_code,
                      color: Color(0xFF38BDF8),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _myInviteCode != null
                                ? 'Мой код: $_myInviteCode'
                                : 'Загрузка кода...',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                          const Text(
                            'Нажмите, чтобы скопировать приглашение',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.copy, size: 18, color: Color(0xFF38BDF8)),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(color: textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ввести код друга (например, ORB-...)',
                        hintStyle: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _addFriendByCode,
                  child: const Text(
                    'Добавить',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Поиск по @username...',
                  hintStyle: TextStyle(color: textSecondary, fontSize: 12),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: Colors.grey,
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
                onSubmitted: _searchUsers,
                onChanged: (val) {
                  if (val.length >= 2) _searchUsers(val);
                },
              ),
            ),
          ),
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
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: borderColor),
                itemBuilder: (ctx, i) {
                  final user = _searchResults[i];
                  final isAlreadyFriend = _acceptedFriends.any(
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
                      user['display_name'] ?? 'Пользователь',
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
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
                                    'Найдите их по @username или добавьте по коду выше',
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
