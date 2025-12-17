import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/unread_messages_service.dart';
import '../job_ads/job_ads_list_screen.dart';
import '../job_seekers/job_seekers_list_screen.dart';
import '../marketplace/marketplace_screen.dart';
import '../chat/chat_list_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;
  late AnimationController _fabAnimationController;

  final List<Widget> _screens = [
    const JobAdsListScreen(),
    const JobSeekersListScreen(),
    const MarketplaceScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // بارگذاری تعداد پیام‌های خوانده نشده
    UnreadMessagesService().loadUnreadCount();
    UnreadMessagesService().addListener(_onUnreadCountChanged);
  }

  void _onUnreadCountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    UnreadMessagesService().removeListener(_onUnreadCountChanged);
    _pageController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppTheme.primaryGreen,
            unselectedItemColor: AppTheme.textGrey,
            selectedFontSize: 10,
            unselectedFontSize: 9,
            iconSize: 24,
            elevation: 0,
            backgroundColor: Colors.white,
            items: [
              _buildNavItem(Icons.work_outline, Icons.work, 'نیازمند همکار', 0),
              _buildNavItem(Icons.person_search_outlined, Icons.person_search, 'جویندگان کار', 1),
              _buildNavItem(Icons.shopping_bag_outlined, Icons.shopping_bag, 'بازار', 2),
              _buildNavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'چت', 3),
              _buildNavItem(Icons.person_outline, Icons.person, 'پروفایل', 4),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
    final unreadCount = UnreadMessagesService().unreadCount;
    final showBadge = index == 3 && unreadCount > 0;
    
    return BottomNavigationBarItem(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(_selectedIndex == index ? 8 : 4),
            decoration: BoxDecoration(
              color: _selectedIndex == index 
                  ? AppTheme.primaryGreen.withValues(alpha: 0.1) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_selectedIndex == index ? activeIcon : icon),
          ),
          if (showBadge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      label: label,
    );
  }
}
