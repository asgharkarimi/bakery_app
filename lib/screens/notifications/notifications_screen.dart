import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/time_ago.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    await NotificationService.loadFromServer();
    
    if (mounted) {
      setState(() {
        _notifications = NotificationService.getAll();
        _unreadCount = NotificationService.getUnreadCount();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('اعلان‌ها'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_unreadCount > 0)
              TextButton(
                onPressed: () async {
                  await NotificationService.markAllAsRead();
                  _loadNotifications();
                },
                child: Text(
                  'خواندن همه',
                  style: TextStyle(color: AppTheme.primaryGreen),
                ),
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  _showClearDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('پاک کردن همه'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    child: ListView.builder(
                      padding: context.responsive.padding(all: 16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationItem(_notifications[index]);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: context.responsive.iconSize(80),
            color: AppTheme.textGrey,
          ),
          SizedBox(height: context.responsive.spacing(16)),
          Text(
            'اعلانی وجود ندارد',
            style: TextStyle(
              fontSize: context.responsive.fontSize(18),
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(
            context.responsive.borderRadius(12),
          ),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        await NotificationService.remove(notification.id);
        _loadNotifications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اعلان حذف شد')),
          );
        }
      },
      child: Card(
        margin: EdgeInsets.only(bottom: context.responsive.spacing(12)),
        color: notification.isRead ? Colors.white : AppTheme.primaryGreen.withValues(alpha: 0.05),
        child: InkWell(
          onTap: () async {
            if (!notification.isRead) {
              await NotificationService.markAsRead(notification.id);
              _loadNotifications();
            }
            _handleNotificationTap(notification);
          },
          borderRadius: BorderRadius.circular(
            context.responsive.borderRadius(12),
          ),
          child: Padding(
            padding: context.responsive.padding(all: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(context.responsive.spacing(12)),
                  decoration: BoxDecoration(
                    color: notification.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      context.responsive.borderRadius(12),
                    ),
                  ),
                  child: Icon(
                    notification.icon,
                    color: notification.color,
                    size: context.responsive.iconSize(24),
                  ),
                ),
                SizedBox(width: context.responsive.spacing(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: context.responsive.fontSize(16),
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: context.responsive.spacing(4)),
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: context.responsive.fontSize(14),
                          color: AppTheme.textGrey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: context.responsive.spacing(8)),
                      Text(
                        TimeAgo.format(notification.createdAt),
                        style: TextStyle(
                          fontSize: context.responsive.fontSize(12),
                          color: AppTheme.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(AppNotification notification) {
    // اینجا می‌تونی به صفحه مربوطه هدایت کنی
    switch (notification.type) {
      case NotificationType.newJobAd:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('باز کردن آگهی شغلی...')),
        );
        break;
      case NotificationType.newBakeryAd:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('باز کردن آگهی نانوایی...')),
        );
        break;
      case NotificationType.newMessage:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('باز کردن پیام...')),
        );
        break;
      default:
        break;
    }
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('پاک کردن همه اعلان‌ها'),
          content: const Text('آیا مطمئن هستید که می‌خواهید همه اعلان‌ها را پاک کنید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف'),
            ),
            TextButton(
              onPressed: () async {
                await NotificationService.clearAll();
                _loadNotifications();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('پاک کردن', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
