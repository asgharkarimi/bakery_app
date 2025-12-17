import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// سرویس کش برای ذخیره داده‌ها و پشتیبانی آفلاین
class CacheService {
  static SharedPreferences? _prefs;
  static const Duration _defaultExpiry = Duration(hours: 1);

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// ذخیره داده با زمان انقضا
  static Future<bool> set(String key, dynamic data, {Duration? expiry}) async {
    await init();
    try {
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'expiry': (expiry ?? _defaultExpiry).inMilliseconds,
      };
      return await _prefs!.setString('cache_$key', jsonEncode(cacheData));
    } catch (e) {
      debugPrint('❌ Cache set error: $e');
      return false;
    }
  }

  /// دریافت داده از کش
  static Future<T?> get<T>(String key, {bool ignoreExpiry = false}) async {
    await init();
    try {
      final cached = _prefs!.getString('cache_$key');
      if (cached == null) return null;

      final cacheData = jsonDecode(cached);
      final timestamp = DateTime.parse(cacheData['timestamp']);
      final expiry = Duration(milliseconds: cacheData['expiry']);

      // چک کردن انقضا
      if (!ignoreExpiry && DateTime.now().difference(timestamp) > expiry) {
        await remove(key);
        return null;
      }

      return cacheData['data'] as T?;
    } catch (e) {
      debugPrint('❌ Cache get error: $e');
      return null;
    }
  }

  /// حذف یک کلید
  static Future<bool> remove(String key) async {
    await init();
    return await _prefs!.remove('cache_$key');
  }

  /// پاک کردن همه کش‌ها
  static Future<void> clearAll() async {
    await init();
    final keys = _prefs!.getKeys().where((k) => k.startsWith('cache_'));
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }

  /// چک کردن وجود کش معتبر
  static Future<bool> has(String key) async {
    final data = await get(key);
    return data != null;
  }

  // ============ متدهای کمکی برای انواع داده ============

  /// کش کردن لیست آگهی‌ها
  static Future<bool> cacheJobAds(List<Map<String, dynamic>> ads) async {
    return await set('job_ads', ads, expiry: const Duration(minutes: 30));
  }

  static Future<List<Map<String, dynamic>>?> getJobAds() async {
    final data = await get<List>('job_ads', ignoreExpiry: true);
    return data?.cast<Map<String, dynamic>>();
  }

  /// کش کردن کارجویان
  static Future<bool> cacheJobSeekers(List<Map<String, dynamic>> seekers) async {
    return await set('job_seekers', seekers, expiry: const Duration(minutes: 30));
  }

  static Future<List<Map<String, dynamic>>?> getJobSeekers() async {
    final data = await get<List>('job_seekers', ignoreExpiry: true);
    return data?.cast<Map<String, dynamic>>();
  }

  /// کش کردن تجهیزات
  static Future<bool> cacheEquipment(List<Map<String, dynamic>> items) async {
    return await set('equipment', items, expiry: const Duration(minutes: 30));
  }

  static Future<List<Map<String, dynamic>>?> getEquipment() async {
    final data = await get<List>('equipment', ignoreExpiry: true);
    return data?.cast<Map<String, dynamic>>();
  }

  /// کش کردن نانوایی‌ها
  static Future<bool> cacheBakeries(List<Map<String, dynamic>> bakeries) async {
    return await set('bakeries', bakeries, expiry: const Duration(minutes: 30));
  }

  static Future<List<Map<String, dynamic>>?> getBakeries() async {
    final data = await get<List>('bakeries', ignoreExpiry: true);
    return data?.cast<Map<String, dynamic>>();
  }

  /// کش کردن پروفایل کاربر
  static Future<bool> cacheUserProfile(Map<String, dynamic> profile) async {
    return await set('user_profile', profile, expiry: const Duration(hours: 24));
  }

  static Future<Map<String, dynamic>?> getUserProfile() async {
    final data = await get<Map<String, dynamic>>('user_profile', ignoreExpiry: true);
    return data;
  }

  /// کش کردن مکالمات
  static Future<bool> cacheConversations(List<Map<String, dynamic>> convs) async {
    return await set('conversations', convs, expiry: const Duration(minutes: 5));
  }

  static Future<List<Map<String, dynamic>>?> getConversations() async {
    final data = await get<List>('conversations', ignoreExpiry: true);
    return data?.cast<Map<String, dynamic>>();
  }

  /// گرفتن سایز کش
  static Future<String> getCacheSize() async {
    await init();
    int totalBytes = 0;
    final keys = _prefs!.getKeys().where((k) => k.startsWith('cache_'));
    for (final key in keys) {
      final value = _prefs!.getString(key);
      if (value != null) totalBytes += value.length;
    }
    
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
