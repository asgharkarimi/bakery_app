import 'package:flutter/material.dart';
import '../../models/job_ad.dart';
import '../../theme/app_theme.dart';
import '../../utils/number_formatter.dart';
import '../../utils/time_ago.dart';
import '../../utils/navigation_helper.dart';
import '../../widgets/notification_badge.dart';
import '../../widgets/time_filter_bottom_sheet.dart';
import '../../widgets/add_menu_fab.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/shimmer_loading.dart';
import '../../services/api_service.dart';
import 'job_ad_detail_screen.dart';

class JobAdsListScreen extends StatefulWidget {
  const JobAdsListScreen({super.key});

  @override
  State<JobAdsListScreen> createState() => _JobAdsListScreenState();
}

class _JobAdsListScreenState extends State<JobAdsListScreen> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final List<JobAd> _ads = [];
  
  int _currentPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _selectedProvince;
  TimeFilter? _selectedTimeFilter;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadJobAds();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadJobAds() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _ads.clear();
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final ads = await ApiService.getJobAds(
        page: 1,
        location: _selectedProvince,
      );
      if (mounted) {
        setState(() {
          _ads.addAll(_filterByTime(ads));
          _currentPage = 2;
          _hasMore = ads.length >= 20;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    setState(() => _isLoadingMore = true);

    try {
      final ads = await ApiService.getJobAds(
        page: _currentPage,
        location: _selectedProvince,
      );
      if (mounted) {
        setState(() {
          _ads.addAll(_filterByTime(ads));
          _currentPage++;
          _hasMore = ads.length >= 20;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  List<JobAd> _filterByTime(List<JobAd> ads) {
    if (_selectedTimeFilter == null || _selectedTimeFilter == TimeFilter.all) {
      return ads;
    }
    
    final now = DateTime.now();
    return ads.where((ad) {
      switch (_selectedTimeFilter!) {
        case TimeFilter.today:
          return ad.createdAt.day == now.day && 
                 ad.createdAt.month == now.month && 
                 ad.createdAt.year == now.year;
        case TimeFilter.yesterday:
          final yesterday = now.subtract(const Duration(days: 1));
          return ad.createdAt.day == yesterday.day && 
                 ad.createdAt.month == yesterday.month;
        case TimeFilter.lastWeek:
          return ad.createdAt.isAfter(now.subtract(const Duration(days: 7)));
        case TimeFilter.lastMonth:
          return ad.createdAt.isAfter(now.subtract(const Duration(days: 30)));
        case TimeFilter.all:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('نیازمند همکار'),
        actions: [
          const NotificationBadge(),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_selectedProvince != null || 
                    (_selectedTimeFilter != null && _selectedTimeFilter != TimeFilter.all))
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => TimeFilterBottomSheet(
                  selectedProvince: _selectedProvince,
                  selectedTimeFilter: _selectedTimeFilter,
                  onApply: (province, timeFilter) {
                    setState(() {
                      _selectedProvince = province;
                      _selectedTimeFilter = timeFilter;
                    });
                    _loadJobAds();
                  },
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFE3F2FD),
      body: _buildBody(),
      floatingActionButton: const AddMenuFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _ads.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 5,
        itemBuilder: (_, __) => const JobAdShimmer(),
      );
    }

    if (_ads.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.work_off_outlined,
        title: 'هیچ آگهی شغلی یافت نشد',
        message: 'در حال حاضر آگهی شغلی موجود نیست.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJobAds,
      color: AppTheme.primaryGreen,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        itemCount: _ads.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // لودینگ انتهای لیست
          if (index >= _ads.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _buildJobAdCard(_ads[index], index);
        },
      ),
    );
  }

  Widget _buildJobAdCard(JobAd ad, int index) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 200 + (index.clamp(0, 5) * 50)),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Nav.toDetail(context, JobAdDetailScreen(ad: ad)),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ردیف بالا
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF26A69A), Color(0xFF4DB6AC)]),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(ad.category, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule, size: 15, color: Colors.grey.shade600),
                              const SizedBox(width: 5),
                              Text(TimeAgo.format(ad.createdAt), style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
                          child: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // عنوان
                    Text(ad.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    const SizedBox(height: 14),
                    // موقعیت و کیسه
                    Row(
                      children: [
                        _buildInfoChip(Icons.location_on, ad.location),
                        const SizedBox(width: 16),
                        _buildInfoChip(Icons.inventory_2_outlined, '${ad.dailyBags} کیسه'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // حقوق
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('حقوق هفتگی: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                          Text(NumberFormatter.formatPrice(ad.salary), style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
