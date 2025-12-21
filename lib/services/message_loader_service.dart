import 'dart:async';
import 'package:flutter/foundation.dart';
import 'media_cache_service.dart';

/// سرویس لود موازی پیام‌ها با استفاده از تردهای مختلف
class MessageLoaderService {
  static final MessageLoaderService _instance = MessageLoaderService._();
  factory MessageLoaderService() => _instance;
  MessageLoaderService._();

  // صف‌های جداگانه برای هر نوع مدیا
  final List<_MediaLoadTask> _imageQueue = [];
  final List<_MediaLoadTask> _videoQueue = [];
  final List<_MediaLoadTask> _audioQueue = [];
  
  bool _isProcessingImages = false;
  bool _isProcessingVideos = false;
  bool _isProcessingAudio = false;

  /// اضافه کردن عکس به صف دانلود
  void queueImage(String url, Function(String?) onComplete) {
    _imageQueue.add(_MediaLoadTask(url: url, onComplete: onComplete));
    _processImageQueue();
  }

  /// اضافه کردن ویدیو به صف دانلود
  void queueVideo(String url, Function(String?) onComplete) {
    _videoQueue.add(_MediaLoadTask(url: url, onComplete: onComplete));
    _processVideoQueue();
  }

  /// اضافه کردن صدا به صف دانلود
  void queueAudio(String url, Function(String?) onComplete) {
    _audioQueue.add(_MediaLoadTask(url: url, onComplete: onComplete));
    _processAudioQueue();
  }

  /// پردازش صف عکس‌ها - حداکثر 3 همزمان
  Future<void> _processImageQueue() async {
    if (_isProcessingImages || _imageQueue.isEmpty) return;
    _isProcessingImages = true;

    while (_imageQueue.isNotEmpty) {
      // 3 تا همزمان پردازش کن
      final batch = _imageQueue.take(3).toList();
      _imageQueue.removeRange(0, batch.length);

      await Future.wait(batch.map((task) async {
        try {
          // اول چک کن کش شده یا نه
          var path = await MediaCacheService.getCachedPath(task.url, type: MediaType.image);
          if (path == null) {
            path = await MediaCacheService.downloadAndCache(task.url, type: MediaType.image);
          }
          task.onComplete(path);
        } catch (e) {
          debugPrint('❌ Image load error: $e');
          task.onComplete(null);
        }
      }));
    }

    _isProcessingImages = false;
  }

  /// پردازش صف ویدیوها - حداکثر 1 همزمان (سنگین‌تره)
  Future<void> _processVideoQueue() async {
    if (_isProcessingVideos || _videoQueue.isEmpty) return;
    _isProcessingVideos = true;

    while (_videoQueue.isNotEmpty) {
      final task = _videoQueue.removeAt(0);
      
      try {
        var path = await MediaCacheService.getCachedPath(task.url, type: MediaType.video);
        if (path == null) {
          path = await MediaCacheService.downloadAndCache(task.url, type: MediaType.video);
        }
        task.onComplete(path);
      } catch (e) {
        debugPrint('❌ Video load error: $e');
        task.onComplete(null);
      }
    }

    _isProcessingVideos = false;
  }

  /// پردازش صف صداها - حداکثر 2 همزمان
  Future<void> _processAudioQueue() async {
    if (_isProcessingAudio || _audioQueue.isEmpty) return;
    _isProcessingAudio = true;

    while (_audioQueue.isNotEmpty) {
      final batch = _audioQueue.take(2).toList();
      _audioQueue.removeRange(0, batch.length);

      await Future.wait(batch.map((task) async {
        try {
          var path = await MediaCacheService.getCachedPath(task.url, type: MediaType.audio);
          if (path == null) {
            path = await MediaCacheService.downloadAndCache(task.url, type: MediaType.audio);
          }
          task.onComplete(path);
        } catch (e) {
          debugPrint('❌ Audio load error: $e');
          task.onComplete(null);
        }
      }));
    }

    _isProcessingAudio = false;
  }

  /// پاک کردن همه صف‌ها
  void clearQueues() {
    _imageQueue.clear();
    _videoQueue.clear();
    _audioQueue.clear();
  }

  /// تعداد آیتم‌های در صف
  int get pendingCount => _imageQueue.length + _videoQueue.length + _audioQueue.length;
}

class _MediaLoadTask {
  final String url;
  final Function(String?) onComplete;

  _MediaLoadTask({required this.url, required this.onComplete});
}

/// پردازش پیام‌ها در Isolate جداگانه
Future<List<Map<String, dynamic>>> processMessagesInBackground(List<Map<String, dynamic>> messages) async {
  return compute(_processMessages, messages);
}

List<Map<String, dynamic>> _processMessages(List<Map<String, dynamic>> messages) {
  // پردازش سبک پیام‌ها - مثلاً تبدیل تاریخ، فرمت کردن متن و...
  for (var msg in messages) {
    // تبدیل تاریخ به فرمت خوانا
    if (msg['createdAt'] != null) {
      try {
        final time = DateTime.parse(msg['createdAt'].toString());
        msg['_formattedTime'] = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    
    // علامت‌گذاری نوع پیام
    final type = msg['messageType'] ?? 'text';
    msg['_isMedia'] = type != 'text';
  }
  
  return messages;
}
