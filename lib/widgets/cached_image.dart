import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// سرویس کش تصاویر
class ImageCacheService {
  static final Map<String, String> _memoryCache = {};
  static Directory? _cacheDir;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getTemporaryDirectory();
      _cacheDir = Directory('${dir.path}/image_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      
      // پر کردن memory cache از فایل‌های موجود در disk
      final files = _cacheDir!.listSync();
      for (final file in files) {
        if (file is File) {
          // نمیتونیم URL رو از hash بازیابی کنیم، ولی حداقل فایل‌ها آماده‌ان
        }
      }
      debugPrint('📦 Image cache initialized with ${files.length} files');
      
      _initialized = true;
    } catch (e) {
      debugPrint('❌ Error initializing image cache: $e');
    }
  }

  /// گرفتن از memory cache (sync - بدون await)
  static String? getFromMemoryCache(String url) {
    return _memoryCache[url];
  }

  static String _getHash(String url) {
    // هش ساده بدون پکیج اضافی
    int hash = 0;
    for (int i = 0; i < url.length; i++) {
      hash = ((hash << 5) - hash) + url.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  static Future<String?> getCachedImagePath(String url) async {
    await init();
    
    // چک کردن memory cache
    if (_memoryCache.containsKey(url)) {
      final cachedPath = _memoryCache[url]!;
      if (await File(cachedPath).exists()) {
        return cachedPath;
      }
    }

    // چک کردن disk cache
    final hash = _getHash(url);
    final ext = p.extension(url).split('?').first;
    final filePath = '${_cacheDir!.path}/$hash$ext';
    
    if (await File(filePath).exists()) {
      _memoryCache[url] = filePath;
      return filePath;
    }

    return null;
  }

  static Future<String?> downloadAndCache(String url) async {
    await init();
    
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
      );
      
      if (response.statusCode == 200) {
        final hash = _getHash(url);
        final ext = p.extension(url).split('?').first;
        final filePath = '${_cacheDir!.path}/$hash${ext.isEmpty ? '.jpg' : ext}';
        
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        _memoryCache[url] = filePath;
        return filePath;
      }
    } catch (e) {
      debugPrint('❌ Error downloading image: $e');
    }
    
    return null;
  }

  static void clearMemoryCache() {
    _memoryCache.clear();
  }

  static Future<void> clearDiskCache() async {
    await init();
    try {
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create();
      }
      _memoryCache.clear();
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }
}

/// ویجت نمایش تصویر با کش
class CachedImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  String? _cachedPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _cachedPath = null;
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
      return;
    }

    // 1. اول چک کن memory cache داره یا نه (سریع و sync)
    final memoryCached = ImageCacheService.getFromMemoryCache(widget.imageUrl);
    if (memoryCached != null && await File(memoryCached).exists()) {
      if (mounted) {
        setState(() {
          _cachedPath = memoryCached;
          _isLoading = false;
          _hasError = false;
        });
      }
      debugPrint('🎯 Memory cache hit: ${widget.imageUrl.split('/').last}');
      return;
    }

    // 2. بعد از disk cache بخون
    String? path = await ImageCacheService.getCachedImagePath(widget.imageUrl);
    
    if (path != null && await File(path).exists()) {
      if (mounted) {
        setState(() {
          _cachedPath = path;
          _isLoading = false;
          _hasError = false;
        });
      }
      debugPrint('💾 Disk cache hit: ${widget.imageUrl.split('/').last}');
      return;
    }

    // 3. نمایش loading فقط اگه باید دانلود کنیم
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    // 4. دانلود و کش کن
    debugPrint('⬇️ Downloading: ${widget.imageUrl.split('/').last}');
    path = await ImageCacheService.downloadAndCache(widget.imageUrl);
    
    if (mounted) {
      setState(() {
        _cachedPath = path;
        _isLoading = false;
        _hasError = path == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (_isLoading) {
      child = widget.placeholder ?? _buildPlaceholder();
    } else if (_hasError || _cachedPath == null) {
      child = widget.errorWidget ?? _buildError();
    } else {
      child = Image.file(
        File(_cachedPath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => widget.errorWidget ?? _buildError(),
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: child,
      );
    }

    return child;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey.shade200,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey.shade200,
      child: Icon(
        Icons.broken_image_outlined,
        color: Colors.grey.shade400,
        size: 40,
      ),
    );
  }
}

/// ویجت آواتار با کش
class CachedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? name;
  final Color? backgroundColor;

  const CachedAvatar({
    super.key,
    this.imageUrl,
    this.radius = 24,
    this.name,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: CachedImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: _buildFallback(),
          errorWidget: _buildFallback(),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.teal,
      child: Text(
        name?.isNotEmpty == true ? name![0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
