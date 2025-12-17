import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/bakery_ad.dart';
import '../../theme/app_theme.dart';
import '../../utils/number_formatter.dart';
import '../../services/bookmark_service.dart';
import '../../services/api_service.dart';
import '../chat/chat_screen.dart';
import '../map/map_screen.dart';
import 'add_bakery_ad_screen.dart';

class BakeryDetailScreen extends StatefulWidget {
  final BakeryAd ad;

  const BakeryDetailScreen({super.key, required this.ad});

  @override
  State<BakeryDetailScreen> createState() => _BakeryDetailScreenState();
}

class _BakeryDetailScreenState extends State<BakeryDetailScreen> {
  bool _isBookmarked = false;
  bool _isOwner = false;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  late BakeryAd _ad;

  @override
  void initState() {
    super.initState();
    _ad = widget.ad;
    _checkBookmark();
    _checkOwnership();
  }
  
  Future<void> _checkOwnership() async {
    final userId = await ApiService.getCurrentUserId();
    if (mounted && userId != null) {
      setState(() => _isOwner = _ad.userId == userId);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkBookmark() async {
    final isBookmarked = await BookmarkService.isBookmarked(widget.ad.id, 'bakery');
    if (mounted) setState(() => _isBookmarked = isBookmarked);
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      await BookmarkService.removeBookmark(widget.ad.id, 'bakery');
    } else {
      await BookmarkService.addBookmark(widget.ad.id, 'bakery');
    }
    if (mounted) {
      setState(() => _isBookmarked = !_isBookmarked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBookmarked ? 'به نشانک‌ها اضافه شد' : 'از نشانک‌ها حذف شد'),
          backgroundColor: _isBookmarked ? AppTheme.primaryGreen : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: CustomScrollView(
          slivers: [
            // App Bar with Image Slider
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: ad.type == BakeryAdType.sale ? Colors.blue : Colors.purple,
              flexibleSpace: FlexibleSpaceBar(
                background: ad.images.isNotEmpty
                    ? _buildImageSlider(ad)
                    : _buildDefaultHeader(ad),
              ),
              actions: [
                if (_isOwner)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddBakeryAdScreen(adToEdit: _ad),
                        ),
                      );
                      if (result == true && mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                  ),
                IconButton(
                  icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: Colors.white),
                  onPressed: _toggleBookmark,
                ),
              ],
            ),

            // Content
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Title Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Text(
                          ad.title,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        if (ad.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            ad.description,
                            style: TextStyle(fontSize: 15, color: AppTheme.textGrey, height: 1.6),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Price Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.monetization_on, color: AppTheme.primaryGreen),
                            const SizedBox(width: 8),
                            const Text('اطلاعات قیمت', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 24),
                        if (ad.type == BakeryAdType.sale)
                          _buildPriceRow('قیمت فروش', NumberFormatter.formatPrice(ad.salePrice ?? 0), Colors.blue)
                        else ...[
                          _buildPriceRow('رهن', NumberFormatter.formatPrice(ad.rentDeposit ?? 0), Colors.purple),
                          const SizedBox(height: 12),
                          _buildPriceRow('اجاره ماهانه', NumberFormatter.formatPrice(ad.monthlyRent ?? 0), Colors.orange),
                        ],
                      ],
                    ),
                  ),

                  // Bakery Info Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text('مشخصات نانوایی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 24),
                        if (ad.flourQuota != null && ad.flourQuota! > 0)
                          _buildInfoItem(Icons.inventory_2, 'سهمیه آرد', '${ad.flourQuota} کیسه در ماه', Colors.amber),
                        if (ad.breadPrice != null && ad.breadPrice! > 0)
                          _buildInfoItem(Icons.bakery_dining, 'قیمت نان', NumberFormatter.formatPrice(ad.breadPrice!), Colors.brown),
                        _buildInfoItem(Icons.visibility, 'بازدید', '${ad.views} بار', Colors.grey),
                      ],
                    ),
                  ),

                  // Location Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('موقعیت مکانی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 24),
                        Text(
                          ad.location,
                          style: TextStyle(fontSize: 14, color: AppTheme.textGrey, height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                        if (ad.lat != null && ad.lng != null) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MapScreen(lat: ad.lat, lng: ad.lng, title: ad.title),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map),
                              label: const Text('نمایش روی نقشه'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Contact Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.contact_phone, color: AppTheme.primaryGreen),
                            const SizedBox(width: 8),
                            const Text('اطلاعات تماس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: ad.phoneNumber));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: const Text('شماره کپی شد'), backgroundColor: AppTheme.primaryGreen),
                                  );
                                },
                                icon: const Icon(Icons.phone),
                                label: Text(ad.phoneNumber),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      recipientId: '1',
                                      recipientName: 'فروشنده',
                                      recipientAvatar: 'ف',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('پیام'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildImageSlider(BakeryAd ad) {
    return Stack(
      children: [
        // Image PageView
        PageView.builder(
          controller: _pageController,
          itemCount: ad.images.length,
          onPageChanged: (index) => setState(() => _currentImageIndex = index),
          itemBuilder: (context, index) {
            final imageUrl = ad.images[index].startsWith('http')
                ? ad.images[index]
                : 'http://10.0.2.2:3000${ad.images[index]}';
            return GestureDetector(
              onTap: () => _showFullImage(context, imageUrl),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Center(child: CircularProgressIndicator(color: Colors.white));
                },
              ),
            );
          },
        ),
        // Gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 100,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
              ),
            ),
          ),
        ),
        // Type badge
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: ad.type == BakeryAdType.sale ? Colors.blue : Colors.purple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ad.type == BakeryAdType.sale ? '🏷️ فروش' : '🔑 رهن و اجاره',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        // Page indicator
        if (ad.images.length > 1)
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImageIndex + 1} / ${ad.images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        // Dots indicator
        if (ad.images.length > 1)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                ad.images.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentImageIndex == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentImageIndex == index ? Colors.white : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultHeader(BakeryAd ad) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: ad.type == BakeryAdType.sale
              ? [Colors.blue.shade400, Colors.blue.shade700]
              : [Colors.purple.shade400, Colors.purple.shade700],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                ad.type == BakeryAdType.sale ? '🏷️ فروش' : '🔑 رهن و اجاره',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'بدون تصویر',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: color)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textGrey)),
          ),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
