import 'dart:io';
import 'package:flutter/material.dart';
import '../services/media_cache_service.dart';

/// ویجت تصویر کش شده با نمایش پیشرفت
class CachedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CachedNetworkImage({
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
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  String? _cachedPath;
  bool _isLoading = true;
  bool _hasError = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _progress = 0;
    });

    // اول از کش بخون
    String? path = await MediaCacheService.getCachedPath(
      widget.imageUrl,
      type: MediaType.image,
    );
    
    if (path != null) {
      if (mounted) {
        setState(() {
          _cachedPath = path;
          _isLoading = false;
        });
      }
      return;
    }

    // دانلود و کش کن با نمایش پیشرفت
    path = await MediaCacheService.downloadAndCache(
      widget.imageUrl,
      type: MediaType.image,
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      },
    );
    
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
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                value: _progress > 0 ? _progress : null,
              ),
            ),
            if (_progress > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${(_progress * 100).toInt()}%',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
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

/// ویجت ویدیو کش شده با نمایش پیشرفت دانلود
class CachedVideo extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const CachedVideo({
    super.key,
    required this.videoUrl,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  State<CachedVideo> createState() => _CachedVideoState();
}

class _CachedVideoState extends State<CachedVideo> {
  String? _cachedPath;
  bool _isLoading = false;
  bool _isCached = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  Future<void> _checkCache() async {
    final path = await MediaCacheService.getCachedPath(
      widget.videoUrl,
      type: MediaType.video,
    );
    if (mounted) {
      setState(() {
        _cachedPath = path;
        _isCached = path != null;
      });
    }
  }

  Future<void> _downloadVideo() async {
    setState(() {
      _isLoading = true;
      _progress = 0;
    });
    
    final path = await MediaCacheService.downloadAndCache(
      widget.videoUrl,
      type: MediaType.video,
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      },
    );
    
    if (mounted) {
      setState(() {
        _cachedPath = path;
        _isCached = path != null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isCached && widget.onTap != null) {
          widget.onTap!();
        } else if (!_isLoading) {
          _downloadVideo();
        }
      },
      child: Container(
        width: widget.width ?? 200,
        height: widget.height ?? 150,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isLoading)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                      value: _progress > 0 ? _progress : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _progress > 0 ? '${(_progress * 100).toInt()}%' : 'در حال دانلود...',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              )
            else
              Icon(
                _isCached ? Icons.play_circle_fill : Icons.download,
                color: Colors.white,
                size: 50,
              ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isCached ? Icons.check_circle : Icons.videocam,
                      color: _isCached ? Colors.green : Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isCached ? 'کش شده' : 'ویدیو',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ویجت صدای کش شده با نمایش پیشرفت
class CachedAudio extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const CachedAudio({
    super.key,
    required this.audioUrl,
    this.isMe = false,
  });

  @override
  State<CachedAudio> createState() => _CachedAudioState();
}

class _CachedAudioState extends State<CachedAudio> {
  String? _cachedPath;
  bool _isLoading = false;
  bool _isCached = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _checkAndDownload();
  }

  Future<void> _checkAndDownload() async {
    // اول چک کن کش شده یا نه
    var path = await MediaCacheService.getCachedPath(
      widget.audioUrl,
      type: MediaType.audio,
    );
    
    if (path != null) {
      if (mounted) {
        setState(() {
          _cachedPath = path;
          _isCached = true;
        });
      }
      return;
    }

    // اگه کش نشده، دانلود کن
    setState(() {
      _isLoading = true;
      _progress = 0;
    });
    
    path = await MediaCacheService.downloadAndCache(
      widget.audioUrl,
      type: MediaType.audio,
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      },
    );
    
    if (mounted) {
      setState(() {
        _cachedPath = path;
        _isCached = path != null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.isMe ? Colors.white : Colors.teal,
              value: _progress > 0 ? _progress : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _progress > 0 ? '${(_progress * 100).toInt()}%' : 'در حال دانلود...',
            style: TextStyle(
              color: widget.isMe ? Colors.white70 : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  String? get cachedPath => _cachedPath;
  bool get isCached => _isCached;
}
