import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/bakery_ad.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/number_formatter.dart';
import '../bakery/bakery_detail_screen.dart';

class BakeriesMapScreen extends StatefulWidget {
  const BakeriesMapScreen({super.key});

  @override
  State<BakeriesMapScreen> createState() => _BakeriesMapScreenState();
}

class _BakeriesMapScreenState extends State<BakeriesMapScreen> {
  final MapController _mapController = MapController();
  List<BakeryAd> _bakeries = [];
  bool _isLoading = true;
  BakeryAd? _selectedBakery;
  
  // مرکز ایران
  final LatLng _iranCenter = const LatLng(32.4279, 53.6880);

  @override
  void initState() {
    super.initState();
    _loadBakeries();
  }

  Future<void> _loadBakeries() async {
    setState(() => _isLoading = true);
    try {
      final bakeries = await ApiService.getBakeryAds();
      if (mounted) {
        setState(() {
          // فقط آگهی‌هایی که موقعیت دارن
          _bakeries = bakeries.where((b) => b.lat != null && b.lng != null).toList();
          _isLoading = false;
        });
        
        // اگه آگهی داریم، روی اولین آگهی زوم کن
        if (_bakeries.isNotEmpty) {
          final first = _bakeries.first;
          _mapController.move(LatLng(first.lat!, first.lng!), 10);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نقشه نانوایی‌ها'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadBakeries,
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showLegend,
            ),
          ],
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _iranCenter,
                initialZoom: 5.5,
                minZoom: 4.0,
                maxZoom: 18.0,
                onTap: (_, __) => setState(() => _selectedBakery = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.my_bakers_jobapp',
                ),
                MarkerLayer(
                  markers: _bakeries.map((bakery) => _buildMarker(bakery)).toList(),
                ),
              ],
            ),
            
            // Loading
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            
            // تعداد آگهی‌ها
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.store, color: AppTheme.primaryGreen, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${_bakeries.length} نانوایی',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // کارت آگهی انتخاب شده
            if (_selectedBakery != null)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _buildBakeryCard(_selectedBakery!),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _mapController.move(_iranCenter, 5.5),
          backgroundColor: AppTheme.primaryGreen,
          child: const Icon(Icons.my_location, color: Colors.white),
        ),
      ),
    );
  }


  Marker _buildMarker(BakeryAd bakery) {
    final isSale = bakery.type == BakeryAdType.sale;
    final isSelected = _selectedBakery?.id == bakery.id;
    
    return Marker(
      point: LatLng(bakery.lat!, bakery.lng!),
      width: isSelected ? 50 : 40,
      height: isSelected ? 50 : 40,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedBakery = bakery);
          _mapController.move(LatLng(bakery.lat!, bakery.lng!), 14);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSale ? Colors.red : Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.yellow : Colors.white,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isSale ? Colors.red : Colors.blue).withValues(alpha: 0.4),
                blurRadius: isSelected ? 12 : 6,
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Icon(
            Icons.store,
            color: Colors.white,
            size: isSelected ? 26 : 20,
          ),
        ),
      ),
    );
  }

  Widget _buildBakeryCard(BakeryAd bakery) {
    final isSale = bakery.type == BakeryAdType.sale;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // عکس یا آیکون
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: (isSale ? Colors.red : Colors.blue).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  image: bakery.images.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage('${ApiService.serverUrl}${bakery.images.first}'),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: bakery.images.isEmpty
                    ? Icon(Icons.store, color: isSale ? Colors.red : Colors.blue, size: 30)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bakery.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: AppTheme.textGrey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            bakery.location,
                            style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSale ? Colors.red : Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isSale ? 'فروش' : 'اجاره',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // قیمت
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSale ? 'قیمت فروش:' : 'اجاره ماهیانه:',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                ),
                Text(
                  NumberFormatter.formatPrice(
                    isSale ? (bakery.salePrice ?? 0) : (bakery.monthlyRent ?? 0),
                  ),
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // دکمه مشاهده
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BakeryDetailScreen(ad: bakery)),
                );
              },
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('مشاهده جزئیات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLegend() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('راهنمای نقشه'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLegendItem(Colors.red, 'نانوایی برای فروش'),
              const SizedBox(height: 12),
              _buildLegendItem(Colors.blue, 'نانوایی برای اجاره'),
              const SizedBox(height: 16),
              Text(
                'روی هر نشانگر کلیک کنید تا جزئیات آگهی را ببینید',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('متوجه شدم'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.store, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
