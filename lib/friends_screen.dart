import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _FriendsScreenState extends State<FriendsScreen> {
  // Реальный список друзей без фиктивных примеров
  final List<String> _friends = [];
  final List<String> _pendingRequests = [];

  final TextEditingController _searchController = TextEditingController();

  void _sendFriendRequest() {
    final target = _searchController.text.trim().replaceAll('@', '');
    if (target.isEmpty) return;

    if (target.toLowerCase() == widget.currentUsername.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя отправить заявку самому себе')),
      );
      return;
    }

    if (_friends.contains(target) || _pendingRequests.contains(target)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заявка уже отправлена или пользователь в друзьях'),
        ),
      );
      return;
    }

    setState(() {
      _pendingRequests.add(target);
      _searchController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Запрос дружбы отправлен пользователю @$target')),
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
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : const Color(0xFFD0D7DE);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Друзья')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Поиск и добавление
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Введите ID друга (@username)',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _sendFriendRequest,
                  child: const Text('Добавить'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_pendingRequests.isNotEmpty) ...[
            const Text(
              'Исходящие запросы:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ..._pendingRequests.map(
              (req) => Card(
                color: cardBg,
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.hourglass_top)),
                  title: Text(
                    '@$req',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text('Ожидает подтверждения'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () =>
                        setState(() => _pendingRequests.remove(req)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          const Text(
            'Список друзей:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          if (_friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: const [
                    Icon(Icons.people_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'У вас пока нет добавленных друзей',
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Найдите знакомых по их @username',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._friends.map(
              (f) => Card(
                color: cardBg,
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(
                    f,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => setState(() => _friends.remove(f)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
