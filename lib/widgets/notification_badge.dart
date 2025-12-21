import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../screens/notifications/notifications_screen.dart';

class NotificationBadge extends StatefulWidget {
  final Color? iconColor;
  final double? iconSize;

  const NotificationBadge({
    super.key,
    this.iconColor,
    this.iconSize,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  int _unreadCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    NotificationService.addListener(_onNewNotification);
  }

  @override
  void dispose() {
    NotificationService.removeListener(_onNewNotification);
    super.dispose();
  }

  void _onNewNotification(AppNotification notification) {
    if (mounted) {
      _loadUnreadCount();
    }
  }

  Future<void> _loadUnreadCount() async {
    if (_isLoading) return;
    _isLoading = true;
    
    try {
      final count = await ApiService.getUnreadNotificationCount();
      if (mounted) {
        setState(() => _unreadCount = count);
      }
    } catch (e) {
      // استفاده از مقدار لوکال
      if (mounted) {
        setState(() => _unreadCount = NotificationService.getUnreadCount());
      }
    }
    
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(
        children: [
          Icon(
            Icons.notifications_outlined,
            color: widget.iconColor ?? AppTheme.textDark,
            size: widget.iconSize ?? 24,
          ),
          if (_unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const NotificationsScreen(),
          ),
        );
        _loadUnreadCount();
      },
    );
  }
}
