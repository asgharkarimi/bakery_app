import 'package:flutter/material.dart';
import '../../models/bakery_ad.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import '../map/bakeries_map_screen.dart';
import 'bakery_detail_screen.dart';
import 'add_bakery_ad_screen.dart';

class BakeryListScreen extends StatefulWidget {
  const BakeryListScreen({super.key});

  @override
  State<BakeryListScreen> createState() => _BakeryListScreenState();
}

class _BakeryListScreenState extends State<BakeryListScreen> {
  List<BakeryAd> _ads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() => _isLoading = true);
    try {
      final ads = await ApiService.getBakeryAds();
      if (mounted) {
        setState(() {
          _ads = ads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('خرید و فروش نانوایی'),
          actions: [
            IconButton(
              icon: const Icon(Icons.map),
              tooltip: 'نمایش روی نقشه',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BakeriesMapScreen()),
                );
              },
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _ads.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.store_outlined,
                    title: 'آگهی نانوایی یافت نشد',
                    message: 'اولین آگهی نانوایی را ثبت کنید!',
                    buttonText: 'ثبت آگهی',
                    onButtonPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AddBakeryAdScreen()),
                      );
                      if (result == true) _loadAds();
                    },
                  )
                : RefreshIndicator(
                    onRefresh: _loadAds,
                    child: ListView.builder(
          itemCount: _ads.length,
          itemBuilder: (context, index) {
            final ad = _ads[index];
            return Card(
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BakeryDetailScreen(ad: ad),
                    ),
                  );
                },
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.store, color: AppTheme.primaryGreen),
                ),
                title: Text(ad.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad.location),
                    if (ad.type == BakeryAdType.sale)
                      Text(
                        'فروش: ${ad.salePrice! ~/ 1000000} میلیون',
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Text(
                        'رهن: ${ad.rentDeposit! ~/ 1000000}م - اجاره: ${ad.monthlyRent! ~/ 1000000}م',
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
              ),
            );
          },
        ),
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddBakeryAdScreen()),
            );
            if (result == true) _loadAds();
          },
          backgroundColor: AppTheme.primaryGreen,
          icon: Icon(Icons.add, color: AppTheme.white),
          label: Text(
            'افزودن آگهی',
            style: TextStyle(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
