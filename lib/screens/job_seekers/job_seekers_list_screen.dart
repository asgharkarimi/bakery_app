import 'package:flutter/material.dart';
import '../../models/job_seeker.dart';
import '../../theme/app_theme.dart';
import '../../utils/number_formatter.dart';
import '../../utils/time_ago.dart';
import '../../widgets/time_filter_bottom_sheet.dart';
import '../../widgets/add_menu_fab.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/cached_image.dart';
import '../../services/api_service.dart';
import 'job_seeker_detail_screen.dart';

class JobSeekersListScreen extends StatefulWidget {
  const JobSeekersListScreen({super.key});

  @override
  State<JobSeekersListScreen> createState() => _JobSeekersListScreenState();
}

class _JobSeekersListScreenState extends State<JobSeekersListScreen> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final List<JobSeeker> _seekers = [];
  
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
    _loadSeekers();
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

  Future<void> _loadSeekers() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _seekers.clear();
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final seekers = await ApiService.getJobSeekers(
        page: 1,
        location: _selectedProvince,
      );
      if (mounted) {
        setState(() {
          _seekers.addAll(_filterByTime(seekers));
          _currentPage = 2;
          _hasMore = seekers.length >= 20;
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
      final seekers = await ApiService.getJobSeekers(
        page: _currentPage,
        location: _selectedProvince,
      );
      if (mounted) {
        setState(() {
          _seekers.addAll(_filterByTime(seekers));
          _currentPage++;
          _hasMore = seekers.length >= 20;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  List<JobSeeker> _filterByTime(List<JobSeeker> seekers) {
    if (_selectedTimeFilter == null || _selectedTimeFilter == TimeFilter.all) {
      return seekers;
    }
    
    final now = DateTime.now();
    return seekers.where((seeker) {
      switch (_selectedTimeFilter!) {
        case TimeFilter.today:
          return seeker.createdAt.day == now.day && 
                 seeker.createdAt.month == now.month && 
                 seeker.createdAt.year == now.year;
        case TimeFilter.yesterday:
          final yesterday = now.subtract(const Duration(days: 1));
          return seeker.createdAt.day == yesterday.day && 
                 seeker.createdAt.month == yesterday.month;
        case TimeFilter.lastWeek:
          return seeker.createdAt.isAfter(now.subtract(const Duration(days: 7)));
        case TimeFilter.lastMonth:
          return seeker.createdAt.isAfter(now.subtract(const Duration(days: 30)));
        case TimeFilter.all:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFE3F2FD),
        appBar: AppBar(
          title: const Text('جویندگان کار'),
          actions: [
            IconButton(
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
                      _loadSeekers();
                    },
                  ),
                );
              },
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
            ),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: const AddMenuFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _seekers.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => const JobSeekerShimmer(),
      );
    }

    if (_seekers.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.person_search_outlined,
        title: 'هیچ کارجویی یافت نشد',
        message: 'در حال حاضر کارجویی ثبت نشده است.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSeekers,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        itemCount: _seekers.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _seekers.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _buildSeekerCard(_seekers[index], index);
        },
      ),
    );
  }

  Widget _buildSeekerCard(JobSeeker seeker, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 200 + (index.clamp(0, 5) * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 30 * (1 - value)), child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobSeekerDetailScreen(seeker: seeker))),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CachedAvatar(
                      imageUrl: seeker.profileImage != null
                          ? '${ApiService.serverUrl}${seeker.profileImage}'
                          : null,
                      radius: 30,
                      name: seeker.name,
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(seeker.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text('${seeker.rating}', style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
                              const SizedBox(width: 12),
                              Icon(Icons.schedule, size: 14, color: AppTheme.textGrey),
                              const SizedBox(width: 4),
                              Text(TimeAgo.format(seeker.createdAt), style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textGrey),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: seeker.skills.map((skill) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF64B5F6)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(skill, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textGrey),
                    const SizedBox(width: 4),
                    Text(seeker.location, style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Flexible(
                        child: RichText(
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: TextStyle(color: AppTheme.textGrey, fontSize: 14, fontFamily: 'Vazir'),
                            children: [
                              const TextSpan(text: 'حقوق هفتگی درخواستی: '),
                              TextSpan(
                                text: NumberFormatter.formatPrice(seeker.expectedSalary),
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
