import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// سرویس رمزنگاری برای چت
class EncryptionService {
  static const String _keyStoragePrefix = 'chat_key_';
  static int? _myUserId;
  
  // کش کلیدها در حافظه برای سرعت بیشتر
  static final Map<int, String> _keyCache = {};

  /// تنظیم userId کاربر فعلی
  static void setMyUserId(int userId) {
    _myUserId = userId;
  }

  /// تولید کلید یکتا برای مکالمه (بر اساس هر دو userId)
  static String _generateChatKeyName(int recipientId) {
    if (_myUserId == null) return '$_keyStoragePrefix$recipientId';
    
    // کلید یکسان برای هر دو طرف: min_max
    final minId = _myUserId! < recipientId ? _myUserId! : recipientId;
    final maxId = _myUserId! > recipientId ? _myUserId! : recipientId;
    return '${_keyStoragePrefix}${minId}_$maxId';
  }

  /// تولید کلید مشترک برای هر مکالمه - با کش
  static Future<String> _getOrCreateChatKey(int recipientId) async {
    // اول از کش بخون
    if (_keyCache.containsKey(recipientId)) {
      return _keyCache[recipientId]!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final keyName = _generateChatKeyName(recipientId);

    String? key = prefs.getString(keyName);
    if (key == null) {
      final minId = _myUserId != null && _myUserId! < recipientId ? _myUserId! : recipientId;
      final maxId = _myUserId != null && _myUserId! > recipientId ? _myUserId! : recipientId;
      key = _generateDeterministicKey(minId, maxId);
      await prefs.setString(keyName, key);
    }
    
    // کش کن
    _keyCache[recipientId] = key;
    return key;
  }
  
  /// گرفتن کلید از کش (sync) - برای استفاده در Isolate
  static String? getCachedKey(int recipientId) {
    return _keyCache[recipientId];
  }
  
  /// پیش‌بارگذاری کلید برای یک مکالمه
  static Future<void> preloadKey(int recipientId) async {
    await _getOrCreateChatKey(recipientId);
  }

  /// تولید کلید قطعی بر اساس دو userId (همیشه یکسان برای هر دو طرف)
  static String _generateDeterministicKey(int id1, int id2) {
    final seed = '$id1-bakery-chat-$id2-secure-key';
    final bytes = utf8.encode(seed);
    
    final key = List<int>.generate(32, (i) {
      return (bytes[i % bytes.length] + i * 7) % 256;
    });
    
    return base64Encode(key);
  }

  /// رمزنگاری پیام با XOR + Base64
  static Future<String> encryptMessage(String message, int recipientId) async {
    try {
      final key = await _getOrCreateChatKey(recipientId);
      return _encryptWithKey(message, key);
    } catch (e) {
      debugPrint('❌ Encryption error: $e');
      rethrow;
    }
  }
  
  /// رمزنگاری sync با کلید آماده
  static String _encryptWithKey(String message, String key) {
    final keyBytes = utf8.encode(key);
    final messageBytes = utf8.encode(message);

    final encrypted = List<int>.generate(
      messageBytes.length,
      (i) => messageBytes[i] ^ keyBytes[i % keyBytes.length],
    );

    return base64Encode(encrypted);
  }

  /// رمزگشایی پیام
  static Future<String> decryptMessage(String encryptedMessage, int recipientId) async {
    try {
      if (encryptedMessage.isEmpty) return encryptedMessage;
      final key = await _getOrCreateChatKey(recipientId);
      return _decryptWithKey(encryptedMessage, key);
    } catch (e) {
      debugPrint('❌ Decryption error: $e');
      return encryptedMessage;
    }
  }
  
  /// رمزگشایی sync با کلید آماده
  static String _decryptWithKey(String encryptedMessage, String key) {
    try {
      final keyBytes = utf8.encode(key);
      final encryptedBytes = base64Decode(encryptedMessage);

      final decrypted = List<int>.generate(
        encryptedBytes.length,
        (i) => encryptedBytes[i] ^ keyBytes[i % keyBytes.length],
      );

      return utf8.decode(decrypted);
    } catch (e) {
      return encryptedMessage;
    }
  }
  
  /// رمزگشایی لیست پیام‌ها در Isolate
  static Future<List<Map<String, dynamic>>> decryptMessagesInBackground(
    List<Map<String, dynamic>> messages,
    int recipientId,
  ) async {
    // اول کلید رو آماده کن
    final key = await _getOrCreateChatKey(recipientId);
    
    // رمزگشایی در Isolate
    return compute(_decryptMessagesIsolate, _DecryptParams(messages, key));
  }

  /// پاک کردن همه کلیدها
  static Future<void> clearAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyStoragePrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
    _keyCache.clear();
    debugPrint('🔐 All chat keys cleared');
  }
}

/// پارامترهای رمزگشایی برای Isolate
class _DecryptParams {
  final List<Map<String, dynamic>> messages;
  final String key;
  
  _DecryptParams(this.messages, this.key);
}

/// تابع رمزگشایی در Isolate
List<Map<String, dynamic>> _decryptMessagesIsolate(_DecryptParams params) {
  for (var msg in params.messages) {
    if (msg['message'] != null && msg['isEncrypted'] == true) {
      try {
        final encryptedMessage = msg['message'] as String;
        final keyBytes = utf8.encode(params.key);
        final encryptedBytes = base64Decode(encryptedMessage);

        final decrypted = List<int>.generate(
          encryptedBytes.length,
          (i) => encryptedBytes[i] ^ keyBytes[i % keyBytes.length],
        );

        msg['message'] = utf8.decode(decrypted);
      } catch (e) {
        // اگه رمزگشایی نشد، همون متن رو نگه دار
      }
    }
  }
  return params.messages;
}
