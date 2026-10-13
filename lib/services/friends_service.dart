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

  /// Универсальный поиск: по коду инвайта ИЛИ по username
  Future<List<FriendProfile>> searchUsers(String query) async {
    final user = _client.auth.currentUser;
    if (user == null || query.trim().isEmpty) return [];

    final cleanQuery = query.replaceAll('@', '').trim();
    final isCode = cleanQuery.toUpperCase().startsWith('ORB-');

    if (isCode) {
      final codeRes = await _client
          .from('profiles')
          .select()
          .neq('id', user.id)
          .eq('invite_code', cleanQuery.toUpperCase())
          .limit(5);

      if ((codeRes as List).isNotEmpty) {
        return codeRes.map((m) => FriendProfile.fromMap(m)).toList();
      }
    }

    final List<dynamic> response = await _client
        .from('profiles')
        .select()
        .neq('id', user.id)
        .ilike('username', '%${cleanQuery.toLowerCase()}%')
        .limit(10);

    return response
        .map((m) => FriendProfile.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  /// Отправка заявки в друзья (в статусе 'pending')
  Future<void> sendFriendRequest(String targetId) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id == targetId) return;

    await _client.from('friendships').insert({
      'user_id': user.id,
      'friend_id': targetId,
      'status': 'pending',
    });
  }
}
