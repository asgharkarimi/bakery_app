import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'unread_messages_service.dart';

/// سرویس WebSocket برای چت realtime
class SocketService {
  static io.Socket? _socket;
  static bool _isConnected = false;
  static int? _currentUserId;
  
  // Callbacks
  static Function(Map<String, dynamic>)? onNewMessage;
  static Function(int)? onUserTyping;
  static Function()? onConnected;
  static Function()? onDisconnected;
  
  // Callback برای نمایش اعلان (از بیرون تنظیم میشه)
  static Function(Map<String, dynamic>)? onShowNotification;

  static const String _serverUrl = 'http://10.0.2.2:3000';

  /// اتصال به سرور
  static void connect(int userId) {
    if (_isConnected && _currentUserId == userId) return;
    
    _currentUserId = userId;
    
    _socket = io.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      debugPrint('🔌 WebSocket connected');
      _isConnected = true;
      _socket!.emit('register', userId);
      onConnected?.call();
    });

    _socket!.on('newMessage', (data) {
      debugPrint('📨 New message received via WebSocket');
      final message = data is Map<String, dynamic> 
          ? data 
          : Map<String, dynamic>.from(data);
      
      onNewMessage?.call(message);
      
      // افزایش تعداد پیام‌های خوانده نشده
      UnreadMessagesService().increment();
      
      // نمایش اعلان
      onShowNotification?.call(message);
    });

    _socket!.on('userTyping', (data) {
      final senderId = data['senderId'];
      if (senderId != null) {
        onUserTyping?.call(senderId);
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('🔌 WebSocket disconnected');
      _isConnected = false;
      onDisconnected?.call();
    });

    _socket!.onError((error) {
      debugPrint('❌ WebSocket error: $error');
    });

    _socket!.connect();
  }

  /// ارسال پیام
  static void sendMessage({
    required int receiverId,
    required String message,
    String messageType = 'text',
    String? mediaUrl,
    bool isEncrypted = false,
  }) {
    if (_socket == null || !_isConnected) {
      debugPrint('⚠️ WebSocket not connected');
      return;
    }

    _socket!.emit('sendMessage', {
      'senderId': _currentUserId,
      'receiverId': receiverId,
      'message': message,
      'messageType': messageType,
      'mediaUrl': mediaUrl,
      'isEncrypted': isEncrypted,
    });
  }

  /// ارسال وضعیت تایپ
  static void sendTyping(int receiverId) {
    if (_socket == null || !_isConnected) return;
    
    _socket!.emit('typing', {
      'senderId': _currentUserId,
      'receiverId': receiverId,
    });
  }

  /// قطع اتصال
  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
    _currentUserId = null;
  }

  /// وضعیت اتصال
  static bool get isConnected => _isConnected;
}
