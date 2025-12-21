import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// سرویس کش اطلاعات کاربر
class UserCacheService {
  static const String _cacheKey = 'cached_user_data';
  static Map<String, dynamic>? _memoryCache;
  static bool _isDirty = false; // آیا تغییر کرده؟

  /// گرفتن اطلاعات کاربر (اول از کش، بعد از سرور)
  static Future<Map<String, dynamic>?> getUser({bool forceRefresh = false}) async {
    // اگه force refresh نیست و کش داریم
    if (!forceRefresh && !_isDirty && _memoryCache != null) {
      debugPrint('📦 User from memory cache');
      return _memoryCache;
    }

    // اگه force refresh نیست، از disk cache بخون
    if (!forceRefresh && !_isDirty) {
      final cached = await _loadFromDisk();
      if (cached != null) {
        _memoryCache = cached;
        debugPrint('💾 User from disk cache');
        return cached;
      }
    }

    // از سرور بگیر
    debugPrint('🌐 Fetching user from server');
    final user = await ApiService.getCurrentUser();
    if (user != null) {
      await _saveToDisk(user);
      _memoryCache = user;
      _isDirty = false;
    }
    return user;
  }

  /// علامت‌گذاری که اطلاعات تغییر کرده (بعد از ویرایش پروفایل)
  static void markDirty() {
    _isDirty = true;
    debugPrint('🔄 User cache marked as dirty');
  }

  /// آپدیت کش بعد از ویرایش پروفایل
  static Future<void> updateCache(Map<String, dynamic> user) async {
    _memoryCache = user;
    await _saveToDisk(user);
    _isDirty = false;
    debugPrint('✅ User cache updated');
  }

  /// پاک کردن کش (بعد از logout)
  static Future<void> clearCache() async {
    _memoryCache = null;
    _isDirty = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    debugPrint('🗑️ User cache cleared');
  }

  /// ذخیره در disk
  static Future<void> _saveToDisk(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(user));
    } catch (e) {
      debugPrint('❌ Error saving user to disk: $e');
    }
  }

  /// خواندن از disk
  static Future<Map<String, dynamic>?> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_cacheKey);
      if (data != null) {
        return jsonDecode(data) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('❌ Error loading user from disk: $e');
    }
    return null;
  }
}
