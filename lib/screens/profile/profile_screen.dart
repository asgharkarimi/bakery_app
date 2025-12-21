import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/media_cache_service.dart';
import '../../services/user_cache_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_image.dart';
import '../auth/login_screen.dart';
import '../bookmarks/bookmarks_screen.dart';
import '../reviews/my_reviews_screen.dart';
import 'about_screen.dart';
import 'my_ads_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginAndLoadData();
  }

  Future<void> _checkLoginAndLoadData() async {
    final isLoggedIn = await ApiService.isLoggedIn();
    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });
      if (isLoggedIn) {
        _loadUserData();
      }
    }
  }

  Future<void> _loadUserData({bool forceRefresh = false}) async {
    final user = await UserCacheService.getUser(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() => _user = user);
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    await UserCacheService.clearCache();
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _user = null;
      });
    }
  }

  // برای refresh دستی (pull to refresh)
  Future<void> _refreshUserData() async {
    await _loadUserData(forceRefresh: true);
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'تنظیمات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_sweep, color: Colors.red.shade400),
                ),
                title: const Text('پاک کردن کش'),
                subtitle: FutureBuilder<int>(
                  future: MediaCacheService.getCacheSize(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text(
                        'حجم کش: ${MediaCacheService.formatSize(snapshot.data!)}',
                        style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                      );
                    }
                    return Text(
                      'در حال محاسبه...',
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                    );
                  },
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  _showClearCacheDialog();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.notifications_outlined, color: Colors.blue.shade400),
                ),
                title: const Text('اعلان‌ها'),
                subtitle: Text(
                  'تنظیمات اعلان‌ها',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: صفحه تنظیمات اعلان
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.delete_sweep, color: Colors.red),
              SizedBox(width: 8),
              Text('پاک کردن کش'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('کدام کش را می‌خواهید پاک کنید؟'),
              const SizedBox(height: 16),
              _buildCacheOption(
                icon: Icons.image,
                title: 'تصاویر',
                color: Colors.blue,
                onTap: () async {
                  Navigator.pop(ctx);
                  await MediaCacheService.clearCacheByType(MediaType.image);
                  await ImageCacheService.clearDiskCache();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('کش تصاویر پاک شد'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              _buildCacheOption(
                icon: Icons.videocam,
                title: 'ویدیوها',
                color: Colors.red,
                onTap: () async {
                  Navigator.pop(ctx);
                  await MediaCacheService.clearCacheByType(MediaType.video);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('کش ویدیوها پاک شد'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              _buildCacheOption(
                icon: Icons.audiotrack,
                title: 'صداها',
                color: Colors.orange,
                onTap: () async {
                  Navigator.pop(ctx);
                  await MediaCacheService.clearCacheByType(MediaType.audio);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('کش صداها پاک شد'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              const Divider(),
              _buildCacheOption(
                icon: Icons.delete_forever,
                title: 'پاک کردن همه',
                color: Colors.red,
                onTap: () async {
                  Navigator.pop(ctx);
                  await MediaCacheService.clearAllCache();
                  await ImageCacheService.clearDiskCache();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('همه کش‌ها پاک شدند'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('انصراف'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 15)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textGrey),
          ],
        ),
      ),
    );
  }

  void _goToLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (result == true) {
      _checkLoginAndLoadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isLoggedIn) {
      return _buildLoginPrompt();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refreshUserData,
          color: AppTheme.primaryGreen,
          child: CustomScrollView(
            slivers: [
            SliverAppBar(
              expandedHeight: 240,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryGreen,
                        AppTheme.primaryGreen.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 800),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: CachedAvatar(
                            imageUrl: _user?['profileImage'] != null
                                ? '${ApiService.serverUrl}${_user!['profileImage']}'
                                : null,
                            radius: 50,
                            name: _user?['name'] ?? _user?['phone'],
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _user?['name'] ?? _user?['phone'] ?? 'کاربر',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (_user?['bio'] != null && _user!['bio'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                          child: Text(
                            _user!['bio'],
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (_user?['city'] != null || _user?['province'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on, color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                [_user?['city'], _user?['province']].where((e) => e != null).join('، '),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfileScreen(user: _user),
                            ),
                          );
                          if (result == true) _loadUserData();
                        },
                        icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                        label: const Text(
                          'ویرایش پروفایل',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white24,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildMenuCard(
                    icon: Icons.work,
                    title: 'آگهی‌های من',
                    subtitle: 'مشاهده و مدیریت آگهی‌ها',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyAdsScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    icon: Icons.bookmark,
                    title: 'نشانک‌ها',
                    subtitle: 'آگهی‌های ذخیره شده',
                    color: Colors.amber,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    icon: Icons.rate_review,
                    title: 'نظرات من',
                    subtitle: 'مشاهده و مدیریت نظرات',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyReviewsScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    icon: Icons.settings,
                    title: 'تنظیمات',
                    subtitle: 'تنظیمات حساب کاربری',
                    color: Colors.grey,
                    onTap: () => _showSettingsDialog(),
                  ),
                  _buildMenuCard(
                    icon: Icons.info,
                    title: 'درباره ما',
                    subtitle: 'اطلاعات تماس و پشتیبانی',
                    color: AppTheme.primaryGreen,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'خروج از حساب کاربری',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryGreen,
                AppTheme.primaryGreen.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'به حساب کاربری خود وارد شوید',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'برای دسترسی به پروفایل، آگهی‌ها و امکانات بیشتر وارد شوید',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _goToLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryGreen,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'ورود / ثبت‌نام',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
                        );
                      },
                      child: const Text(
                        'درباره ما',
                        style: TextStyle(color: Colors.white70),
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

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
