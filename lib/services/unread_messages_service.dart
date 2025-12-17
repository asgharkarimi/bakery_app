import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// سرویس مدیریت پیام‌های خوانده نشده
class UnreadMessagesService extends ChangeNotifier {
  static final UnreadMessagesService _instance = UnreadMessagesService._internal();
  factory UnreadMessagesService() => _instance;
  UnreadMessagesService._internal();

  int _unreadCount = 0;
  
  int get unreadCount => _unreadCount;

  /// بارگذاری تعداد پیام‌های خوانده نشده از سرور
  Future<void> loadUnreadCount() async {
    try {
      final conversations = await ApiService.getConversations();
      int total = 0;
      for (final conv in conversations) {
        total += (conv['unreadCount'] ?? 0) as int;
      }
      _unreadCount = total;
      notifyListeners();
      debugPrint('📬 Unread messages: $_unreadCount');
    } catch (e) {
      debugPrint('❌ Error loading unread count: $e');
    }
  }

  /// افزایش تعداد پیام‌های خوانده نشده
  void increment() {
    _unreadCount++;
    notifyListeners();
  }

  /// کاهش تعداد پیام‌های خوانده نشده
  void decrement([int count = 1]) {
    _unreadCount = (_unreadCount - count).clamp(0, 999);
    notifyListeners();
  }

  /// ریست کردن تعداد
  void reset() {
    _unreadCount = 0;
    notifyListeners();
  }

  /// تنظیم مستقیم تعداد
  void setCount(int count) {
    _unreadCount = count;
    notifyListeners();
  }
}
