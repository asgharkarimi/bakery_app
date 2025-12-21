import 'package:flutter/material.dart';
import 'api_service.dart';

class NotificationService {
  static final List<AppNotification> _notifications = [];
  static final List<Function(AppNotification)> _listeners = [];
  static int _unreadCount = 0;

  // دریافت تمام نوتیفیکیشن‌ها
  static List<AppNotification> getAll() {
    return List.from(_notifications);
  }

  // دریافت نوتیفیکیشن‌های خوانده نشده
  static List<AppNotification> getUnread() {
    return _notifications.where((n) => !n.isRead).toList();
  }

  // تعداد نوتیفیکیشن‌های خوانده نشده
  static int getUnreadCount() {
    return _unreadCount;
  }

  // بارگذاری نوتیفیکیشن‌ها از سرور
  static Future<void> loadFromServer() async {
    try {
      final response = await ApiService.getNotifications();
      if (response['success'] == true) {
        _notifications.clear();
        final data = response['data'] as List? ?? [];
        for (var item in data) {
          _notifications.add(AppNotification.fromJson(item));
        }
        _unreadCount = response['unreadCount'] ?? 0;
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  // اضافه کردن نوتیفیکیشن جدید (لوکال)
  static void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    if (!notification.isRead) _unreadCount++;
    _notifyListeners(notification);
  }

  // علامت‌گذاری به عنوان خوانده شده
  static Future<void> markAsRead(String id) async {
    try {
      await ApiService.markNotificationAsRead(id);
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // علامت‌گذاری همه به عنوان خوانده شده
  static Future<void> markAllAsRead() async {
    try {
      await ApiService.markAllNotificationsAsRead();
      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
      _unreadCount = 0;
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  // حذف نوتیفیکیشن
  static Future<void> remove(String id) async {
    try {
      await ApiService.deleteNotification(id);
      final notification = _notifications.firstWhere((n) => n.id == id, orElse: () => AppNotification.empty());
      if (!notification.isRead) _unreadCount = (_unreadCount - 1).clamp(0, 999);
      _notifications.removeWhere((n) => n.id == id);
    } catch (e) {
      debugPrint('Error removing notification: $e');
    }
  }

  // پاک کردن همه
  static Future<void> clearAll() async {
    try {
      await ApiService.deleteAllNotifications();
      _notifications.clear();
      _unreadCount = 0;
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  // ثبت listener
  static void addListener(Function(AppNotification) listener) {
    _listeners.add(listener);
  }

  // حذف listener
  static void removeListener(Function(AppNotification) listener) {
    _listeners.remove(listener);
  }

  // اطلاع‌رسانی به listeners
  static void _notifyListeners(AppNotification notification) {
    for (var listener in _listeners) {
      listener(notification);
    }
  }

  // رفرش تعداد خوانده نشده
  static Future<void> refreshUnreadCount() async {
    try {
      final response = await ApiService.getNotifications(limit: 1);
      if (response['success'] == true) {
        _unreadCount = response['unreadCount'] ?? 0;
      }
    } catch (e) {
      debugPrint('Error refreshing unread count: $e');
    }
  }
}

// مدل نوتیفیکیشن
class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotification.empty() => AppNotification(
    id: '',
    title: '',
    body: '',
    type: NotificationType.general,
    createdAt: DateTime.now(),
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? json['message'] ?? '',
      type: _parseType(json['type']),
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] == true || json['is_read'] == true,
    );
  }

  static NotificationType _parseType(dynamic type) {
    if (type == null) return NotificationType.general;
    final typeStr = type.toString().toLowerCase();
    if (typeStr.contains('job')) return NotificationType.newJobAd;
    if (typeStr.contains('bakery')) return NotificationType.newBakeryAd;
    if (typeStr.contains('message') || typeStr.contains('chat')) return NotificationType.newMessage;
    if (typeStr.contains('review')) return NotificationType.newReview;
    return NotificationType.general;
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  IconData get icon {
    switch (type) {
      case NotificationType.newJobAd:
        return Icons.work;
      case NotificationType.newBakeryAd:
        return Icons.store;
      case NotificationType.newMessage:
        return Icons.message;
      case NotificationType.newReview:
        return Icons.star;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.newJobAd:
        return Colors.blue;
      case NotificationType.newBakeryAd:
        return Colors.orange;
      case NotificationType.newMessage:
        return Colors.green;
      case NotificationType.newReview:
        return Colors.amber;
      case NotificationType.general:
        return Colors.grey;
    }
  }
}

enum NotificationType {
  newJobAd,
  newBakeryAd,
  newMessage,
  newReview,
  general,
}
