import 'package:flutter/material.dart';
import '../widgets/in_app_notification.dart';
import '../screens/chat/chat_screen.dart';
import 'socket_service.dart';
import 'encryption_service.dart';

/// مدیریت اعلان‌های درون برنامه‌ای
class NotificationManager {
  static GlobalKey<NavigatorState>? navigatorKey;
  static String? _currentChatRecipientId;

  /// مقداردهی اولیه
  static void init(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
    
    // تنظیم callback برای نمایش اعلان
    SocketService.onShowNotification = _handleNewMessage;
  }

  /// تنظیم recipientId چت فعلی (برای جلوگیری از نمایش اعلان در همون چت)
  static void setCurrentChat(String? recipientId) {
    _currentChatRecipientId = recipientId;
  }

  /// هندل کردن پیام جدید
  static Future<void> _handleNewMessage(Map<String, dynamic> message) async {
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    final senderId = message['senderId']?.toString();
    
    // اگه توی همون چت هستیم، اعلان نشون نده
    if (senderId == _currentChatRecipientId) return;

    // رمزگشایی پیام
    String messageText = message['message'] ?? '';
    if (message['isEncrypted'] == true && senderId != null) {
      try {
        messageText = await EncryptionService.decryptMessage(
          messageText,
          int.parse(senderId),
        );
      } catch (e) {
        messageText = 'پیام جدید';
      }
    }

    // نمایش اعلان
    InAppNotification.showMessageNotification(
      context: context,
      senderName: message['senderName'] ?? 'کاربر',
      message: messageText,
      senderAvatar: message['senderAvatar'],
      onTap: () {
        // رفتن به صفحه چت
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              recipientId: senderId ?? '0',
              recipientName: message['senderName'] ?? 'کاربر',
              recipientAvatar: message['senderAvatar'] ?? 'ک',
            ),
          ),
        );
      },
    );
  }
}
