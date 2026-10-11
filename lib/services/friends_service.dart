import 'package:supabase_flutter/supabase_flutter.dart';

class FriendProfile {
  final String id;
  final String username;
  final String displayName;
  final String inviteCode;

  FriendProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.inviteCode,
  });

  factory FriendProfile.fromMap(Map<String, dynamic> map) {
    return FriendProfile(
      id: map['id'] as String,
      username: map['username'] as String? ?? 'user',
      displayName: map['display_name'] as String? ?? 'Пользователь',
      inviteCode: map['invite_code'] as String? ?? '',
    );
  }
}

class FriendsService {
  static final FriendsService instance = FriendsService._init();
  FriendsService._init();

  SupabaseClient get _client => Supabase.instance.client;

  /// Профиль текущего пользователя (чтобы узнать свой инвайт-код)
  Future<FriendProfile?> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return FriendProfile.fromMap(data);
  }

  /// Поиск пользователей по @username (исключая самого себя)
  Future<List<FriendProfile>> searchUsers(String query) async {
    final user = _client.auth.currentUser;
    if (user == null || query.trim().isEmpty) return [];

    final cleanQuery = query.replaceAll('@', '').trim().toLowerCase();

    final List<dynamic> response = await _client
        .from('profiles')
        .select()
        .neq('id', user.id)
        .ilike('username', '%$cleanQuery%')
        .limit(10);

    return response
        .map((m) => FriendProfile.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  /// Получение списка подтвержденных друзей
  Future<List<FriendProfile>> getFriends() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final List<dynamic> response = await _client
        .from('friendships')
        .select('friend_id, profiles!friendships_friend_id_fkey(*)')
        .eq('user_id', user.id);

    final List<FriendProfile> friends = [];
    for (final row in response) {
      if (row['profiles'] != null) {
        friends.add(
          FriendProfile.fromMap(row['profiles'] as Map<String, dynamic>),
        );
      }
    }
    return friends;
  }

  /// Добавление в друзья по инвайт-коду (например, "ORB-A1B2C3")
  Future<bool> addFriendByCode(String code) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final cleanCode = code.trim().toUpperCase();

    // Находим владельца кода
    final target = await _client
        .from('profiles')
        .select()
        .eq('invite_code', cleanCode)
        .maybeSingle();

    if (target == null || target['id'] == user.id) {
      return false;
    }

    final targetId = target['id'] as String;

    // Создаем взаимную дружбу
    await _client.from('friendships').upsert([
      {'user_id': user.id, 'friend_id': targetId, 'status': 'accepted'},
      {'user_id': targetId, 'friend_id': user.id, 'status': 'accepted'},
    ]);

    return true;
  }

  /// Добавление в друзья по ID профиля (при клике из результатов поиска)
  Future<void> addFriendById(String targetId) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id == targetId) return;

    await _client.from('friendships').upsert([
      {'user_id': user.id, 'friend_id': targetId, 'status': 'accepted'},
      {'user_id': targetId, 'friend_id': user.id, 'status': 'accepted'},
    ]);
  }
}
