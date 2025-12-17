import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// سرویس رمزنگاری برای چت
class EncryptionService {
  static const String _keyStoragePrefix = 'chat_key_';
  static int? _myUserId;

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

  /// تولید کلید مشترک برای هر مکالمه
  static Future<String> _getOrCreateChatKey(int recipientId) async {
    final prefs = await SharedPreferences.getInstance();
    final keyName = _generateChatKeyName(recipientId);

    String? key = prefs.getString(keyName);
    if (key == null) {
      // کلید ثابت بر اساس ترکیب userIds (برای هر دو طرف یکسان)
      final minId = _myUserId != null && _myUserId! < recipientId ? _myUserId! : recipientId;
      final maxId = _myUserId != null && _myUserId! > recipientId ? _myUserId! : recipientId;
      key = _generateDeterministicKey(minId, maxId);
      await prefs.setString(keyName, key);
      debugPrint('🔐 Chat key generated for conversation $minId-$maxId');
    }
    return key;
  }

  /// تولید کلید قطعی بر اساس دو userId (همیشه یکسان برای هر دو طرف)
  static String _generateDeterministicKey(int id1, int id2) {
    // ترکیب دو ID برای ساخت seed
    final seed = '$id1-bakery-chat-$id2-secure-key';
    final bytes = utf8.encode(seed);
    
    // تولید کلید 32 بایتی از seed
    final key = List<int>.generate(32, (i) {
      return (bytes[i % bytes.length] + i * 7) % 256;
    });
    
    return base64Encode(key);
  }

  /// رمزنگاری پیام با XOR + Base64
  static Future<String> encryptMessage(String message, int recipientId) async {
    try {
      final key = await _getOrCreateChatKey(recipientId);
      final keyBytes = utf8.encode(key);
      final messageBytes = utf8.encode(message);

      // XOR encryption
      final encrypted = List<int>.generate(
        messageBytes.length,
        (i) => messageBytes[i] ^ keyBytes[i % keyBytes.length],
      );

      final result = base64Encode(encrypted);
      debugPrint('🔐 Message encrypted');
      return result;
    } catch (e) {
      debugPrint('❌ Encryption error: $e');
      rethrow;
    }
  }

  /// رمزگشایی پیام
  static Future<String> decryptMessage(String encryptedMessage, int recipientId) async {
    try {
      if (encryptedMessage.isEmpty) return encryptedMessage;

      final key = await _getOrCreateChatKey(recipientId);
      final keyBytes = utf8.encode(key);

      final encryptedBytes = base64Decode(encryptedMessage);

      // XOR decryption
      final decrypted = List<int>.generate(
        encryptedBytes.length,
        (i) => encryptedBytes[i] ^ keyBytes[i % keyBytes.length],
      );

      final result = utf8.decode(decrypted);
      debugPrint('🔓 Message decrypted');
      return result;
    } catch (e) {
      debugPrint('❌ Decryption error: $e');
      return encryptedMessage;
    }
  }

  /// پاک کردن همه کلیدها
  static Future<void> clearAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyStoragePrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
    debugPrint('🔐 All chat keys cleared');
  }
}
