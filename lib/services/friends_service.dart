import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class FriendProfile {
  final String id;
  final String username;
  final String displayName;
  final String inviteCode;
  final String avatarUrl;

  FriendProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.inviteCode,
    this.avatarUrl = '',
  });

  factory FriendProfile.fromMap(Map<String, dynamic> map) {
    return FriendProfile(
      id: map['id'] as String,
      username: map['username'] as String? ?? 'user',
      displayName:
          (map['full_name'] ?? map['display_name']) as String? ??
          'Пользователь',
      inviteCode: map['invite_code'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String? ?? '',
    );
  }
}

class FriendsService {
  static final FriendsService instance = FriendsService._init();
  FriendsService._init();

  static const _uuid = Uuid();
  SupabaseClient get _client => Supabase.instance.client;

  Future<FriendProfile?> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return null;
      return FriendProfile.fromMap(data);
    } catch (e) {
      debugPrint('Ошибка получения профиля: $e');
      return null;
    }
  }

  /// Универсальный поиск: по инвайт-коду или юзернейму
  Future<List<FriendProfile>> searchUsers(String query) async {
    final user = _client.auth.currentUser;
    if (user == null || query.trim().isEmpty) return [];

    final cleanQuery = query.replaceAll('@', '').trim();
    final isCode = cleanQuery.toUpperCase().startsWith('ORB-');

    try {
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
    } catch (e) {
      debugPrint('Ошибка поиска: $e');
      return [];
    }
  }

  /// Отправка заявки в друзья (статус pending)
  Future<void> sendFriendRequest(String targetId) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id == targetId) return;

    // Проверяем, нет ли уже связи между пользователями
    final existing = await _client
        .from('friendships')
        .select('id, status')
        .or(
          'and(user_id.eq.${user.id},friend_id.eq.$targetId),and(user_id.eq.$targetId,friend_id.eq.${user.id})',
        )
        .maybeSingle();

    if (existing != null) {
      throw Exception('Запрос уже отправлен или пользователь уже в друзьях');
    }

    final newId = _uuid.v4();
    final nowIso = DateTime.now().toIso8601String();

    await _client.from('friendships').insert({
      'id': newId,
      'user_id': user.id,
      'friend_id': targetId,
      'status': 'pending',
      'created_at': nowIso,
    });
  }
}
