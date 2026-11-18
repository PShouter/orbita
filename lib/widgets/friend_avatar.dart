import 'package:flutter/material.dart';

/// Аватар друга с fallback: при отсутствии URL или ошибке загрузки
/// изображения показывает инициалы имени (или иконку), а не пустой круг.
class FriendAvatar extends StatefulWidget {
  final String? url;
  final String name;
  final double radius;
  final Color fallbackColor;
  final IconData? fallbackIcon;

  const FriendAvatar({
    super.key,
    required this.url,
    required this.name,
    this.radius = 22,
    this.fallbackColor = const Color(0xFF1E293B),
    this.fallbackIcon,
  });

  @override
  State<FriendAvatar> createState() => _FriendAvatarState();
}

class _FriendAvatarState extends State<FriendAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(FriendAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _failed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    final hasUrl = !_failed && url != null && url.isNotEmpty;
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.fallbackColor,
      backgroundImage: hasUrl ? NetworkImage(url) : null,
      onBackgroundImageError: hasUrl
          ? (_, __) {
              if (mounted) setState(() => _failed = true);
            }
          : null,
      child: hasUrl
          ? null
          : widget.fallbackIcon != null
              ? Icon(
                  widget.fallbackIcon,
                  color: Colors.white,
                  size: widget.radius,
                )
              : Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: widget.radius * 0.7,
                  ),
                ),
    );
  }
}