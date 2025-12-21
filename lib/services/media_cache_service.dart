import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// سرویس کش مدیا (عکس، ویدیو، صدا)
class MediaCacheService {
  static final Map<String, String> _memoryCache = {};
  static Directory? _imageCacheDir;
  static Directory? _videoCacheDir;
  static Directory? _audioCacheDir;
  static bool _initialized = false;

  /// مقداردهی اولیه
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getTemporaryDirectory();
      
      _imageCacheDir = Directory('${dir.path}/media_cache/images');
      _videoCacheDir = Directory('${dir.path}/media_cache/videos');
      _audioCacheDir = Directory('${dir.path}/media_cache/audio');
      
      if (!await _imageCacheDir!.exists()) {
        await _imageCacheDir!.create(recursive: true);
      }
      if (!await _videoCacheDir!.exists()) {
        await _videoCacheDir!.create(recursive: true);
      }
      if (!await _audioCacheDir!.exists()) {
        await _audioCacheDir!.create(recursive: true);
      }
      
      _initialized = true;
      debugPrint('✅ MediaCacheService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing media cache: $e');
    }
  }

  /// هش ساده برای نام فایل
  static String _getHash(String url) {
    int hash = 0;
    for (int i = 0; i < url.length; i++) {
      hash = ((hash << 5) - hash) + url.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  /// تشخیص نوع مدیا از URL
  static MediaType _getMediaType(String url) {
    final ext = p.extension(url).toLowerCase().split('?').first;
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext)) {
      return MediaType.image;
    } else if (['.mp4', '.mov', '.avi', '.webm', '.3gp', '.mkv'].contains(ext)) {
      return MediaType.video;
    } else if (['.mp3', '.wav', '.ogg', '.m4a', '.aac', '.flac'].contains(ext)) {
      return MediaType.audio;
    }
    return MediaType.image; // پیش‌فرض
  }

  /// دریافت دایرکتوری کش بر اساس نوع
  static Directory? _getCacheDir(MediaType type) {
    switch (type) {
      case MediaType.image:
        return _imageCacheDir;
      case MediaType.video:
        return _videoCacheDir;
      case MediaType.audio:
        return _audioCacheDir;
    }
  }

  /// دریافت مسیر فایل کش شده
  static Future<String?> getCachedPath(String url, {MediaType? type}) async {
    await init();
    
    // چک کردن memory cache
    if (_memoryCache.containsKey(url)) {
      final cachedPath = _memoryCache[url]!;
      if (await File(cachedPath).exists()) {
        return cachedPath;
      }
    }

    // تشخیص نوع
    type ??= _getMediaType(url);
    final cacheDir = _getCacheDir(type);
    if (cacheDir == null) return null;

    // چک کردن disk cache
    final hash = _getHash(url);
    final ext = p.extension(url).split('?').first;
    final filePath = '${cacheDir.path}/$hash${ext.isEmpty ? _getDefaultExt(type) : ext}';
    
    if (await File(filePath).exists()) {
      _memoryCache[url] = filePath;
      return filePath;
    }

    return null;
  }

  /// پسوند پیش‌فرض
  static String _getDefaultExt(MediaType type) {
    switch (type) {
      case MediaType.image:
        return '.jpg';
      case MediaType.video:
        return '.mp4';
      case MediaType.audio:
        return '.mp3';
    }
  }

  /// دانلود و کش کردن با نمایش پیشرفت
  static Future<String?> downloadAndCache(
    String url, {
    MediaType? type,
    void Function(double progress)? onProgress,
  }) async {
    await init();
    
    try {
      debugPrint('📥 Downloading: $url');
      
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send().timeout(
        const Duration(seconds: 120),
      );
      
      if (response.statusCode == 200) {
        type ??= _getMediaType(url);
        final cacheDir = _getCacheDir(type);
        if (cacheDir == null) return null;

        final hash = _getHash(url);
        final ext = p.extension(url).split('?').first;
        final filePath = '${cacheDir.path}/$hash${ext.isEmpty ? _getDefaultExt(type) : ext}';
        
        final file = File(filePath);
        final sink = file.openWrite();
        
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;
        
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          
          if (onProgress != null && totalBytes > 0) {
            onProgress(receivedBytes / totalBytes);
          }
        }
        
        await sink.close();
        
        _memoryCache[url] = filePath;
        debugPrint('✅ Cached: $filePath ($receivedBytes bytes)');
        return filePath;
      }
    } catch (e) {
      debugPrint('❌ Error downloading media: $e');
    }
    
    return null;
  }

  /// پاک کردن memory cache
  static void clearMemoryCache() {
    _memoryCache.clear();
    debugPrint('🗑️ Memory cache cleared');
  }

  /// پاک کردن کش یک نوع خاص
  static Future<void> clearCacheByType(MediaType type) async {
    await init();
    try {
      final cacheDir = _getCacheDir(type);
      if (cacheDir != null && await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }
      // پاک کردن از memory cache
      _memoryCache.removeWhere((url, _) => _getMediaType(url) == type);
      debugPrint('🗑️ ${type.name} cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing ${type.name} cache: $e');
    }
  }

  /// پاک کردن همه کش‌ها
  static Future<void> clearAllCache() async {
    await init();
    try {
      if (_imageCacheDir != null && await _imageCacheDir!.exists()) {
        await _imageCacheDir!.delete(recursive: true);
        await _imageCacheDir!.create();
      }
      if (_videoCacheDir != null && await _videoCacheDir!.exists()) {
        await _videoCacheDir!.delete(recursive: true);
        await _videoCacheDir!.create();
      }
      if (_audioCacheDir != null && await _audioCacheDir!.exists()) {
        await _audioCacheDir!.delete(recursive: true);
        await _audioCacheDir!.create();
      }
      _memoryCache.clear();
      debugPrint('🗑️ All media cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing all cache: $e');
    }
  }

  /// محاسبه حجم کش
  static Future<int> getCacheSize() async {
    await init();
    int totalSize = 0;
    
    try {
      for (final dir in [_imageCacheDir, _videoCacheDir, _audioCacheDir]) {
        if (dir != null && await dir.exists()) {
          await for (final entity in dir.list(recursive: true)) {
            if (entity is File) {
              totalSize += await entity.length();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error calculating cache size: $e');
    }
    
    return totalSize;
  }

  /// فرمت حجم به صورت خوانا
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

enum MediaType { image, video, audio }
