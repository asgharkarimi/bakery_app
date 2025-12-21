import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class ImagePickerWidget extends StatefulWidget {
  final List<String> existingImages;
  final Function(List<String>) onImagesChanged;
  final int maxImages;
  final String title;

  const ImagePickerWidget({
    super.key,
    this.existingImages = const [],
    required this.onImagesChanged,
    this.maxImages = 5,
    this.title = 'تصاویر آگهی',
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _newImages = [];
  late List<String> _existingImages;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _existingImages = List.from(widget.existingImages);
  }

  int get _totalImages => _existingImages.length + _newImages.length;

  Future<void> _pickImage(ImageSource source) async {
    if (_totalImages >= widget.maxImages) {
      _showMessage('حداکثر ${widget.maxImages} تصویر مجاز است', Colors.orange);
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _newImages.add(File(image.path)));
        _uploadNewImage(File(image.path));
      }
    } catch (e) {
      _showMessage('خطا در انتخاب تصویر', Colors.red);
    }
  }


  Future<void> _uploadNewImage(File file) async {
    setState(() => _isUploading = true);
    
    try {
      final url = await ApiService.uploadImage(file);
      if (url != null) {
        setState(() {
          _newImages.remove(file);
          _existingImages.add(url);
        });
        widget.onImagesChanged(_existingImages);
        _showMessage('تصویر آپلود شد', AppTheme.primaryGreen);
      } else {
        setState(() => _newImages.remove(file));
        _showMessage('خطا در آپلود تصویر', Colors.red);
      }
    } catch (e) {
      setState(() => _newImages.remove(file));
      _showMessage('خطا: $e', Colors.red);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImages.removeAt(index));
    widget.onImagesChanged(_existingImages);
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'انتخاب تصویر',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildPickerOption(
                    icon: Icons.camera_alt,
                    label: 'دوربین',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPickerOption(
                    icon: Icons.photo_library,
                    label: 'گالری',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _totalImages >= widget.maxImages
                      ? Colors.orange.withValues(alpha: 0.1)
                      : AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_totalImages / ${widget.maxImages}',
                  style: TextStyle(
                    color: _totalImages >= widget.maxImages ? Colors.orange : AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // نمایش تصاویر
          if (_existingImages.isNotEmpty || _newImages.isNotEmpty) ...[
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // تصاویر موجود (آپلود شده)
                  ..._existingImages.asMap().entries.map((entry) => _buildImageItem(
                    imageUrl: entry.value.startsWith('http') ? entry.value : '${ApiService.serverUrl}${entry.value}',
                    onRemove: () => _removeExistingImage(entry.key),
                    isUploaded: true,
                  )),
                  // تصاویر جدید (در حال آپلود)
                  ..._newImages.asMap().entries.map((entry) => _buildImageItem(
                    file: entry.value,
                    onRemove: () => _removeNewImage(entry.key),
                    isUploading: true,
                  )),
                  // دکمه افزودن
                  if (_totalImages < widget.maxImages) _buildAddButton(),
                ],
              ),
            ),
          ] else ...[
            // حالت خالی
            _buildEmptyState(),
          ],
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'در حال آپلود...',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildImageItem({
    String? imageUrl,
    File? file,
    required VoidCallback onRemove,
    bool isUploaded = false,
    bool isUploading = false,
  }) {
    return Container(
      width: 110,
      height: 110,
      margin: const EdgeInsets.only(left: 10),
      child: Stack(
        children: [
          // تصویر
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildErrorPlaceholder(),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return _buildLoadingPlaceholder();
                      },
                    )
                  : Image.file(
                      file!,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          // اندیکاتور آپلود
          if (isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
            ),
          // بج آپلود شده
          if (isUploaded)
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
            ),
          // دکمه حذف
          Positioned(
            top: 6,
            left: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _showPickerOptions,
      child: Container(
        width: 110,
        height: 110,
        margin: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, color: AppTheme.primaryGreen, size: 32),
            const SizedBox(height: 4),
            Text(
              'افزودن',
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return GestureDetector(
      onTap: _showPickerOptions,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryGreen.withValues(alpha: 0.2),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_a_photo, color: AppTheme.primaryGreen, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              'برای افزودن تصویر کلیک کنید',
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'حداکثر ${widget.maxImages} تصویر',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: 110,
      height: 110,
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: 110,
      height: 110,
      color: Colors.grey.shade200,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
