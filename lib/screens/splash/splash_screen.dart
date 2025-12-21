import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/preload_service.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _loadingText = 'در حال بارگذاری...';

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // شروع پیش‌بارگذاری داده‌ها در پس‌زمینه
    final preloadFuture = PreloadService.preloadAll();
    
    // حداقل 2 ثانیه صبر کن برای نمایش splash
    final minDelay = Future.delayed(const Duration(seconds: 2));
    
    // آپدیت متن لودینگ
    if (mounted) {
      setState(() => _loadingText = 'در حال دریافت اطلاعات...');
    }
    
    // صبر کن تا هر دو تموم بشن
    await Future.wait([preloadFuture, minDelay]);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.primaryGreen,
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // لوگوی نانوایی
                  Container(
                    width: context.responsive.spacing(150),
                    height: context.responsive.spacing(150),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(context.responsive.spacing(20)),
                      child: Image.asset(
                        'assets/images/bakery_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: context.responsive.spacing(40)),
                  
                  // عنوان اصلی
                  Text(
                    'سامانه جامع نانوایی',
                    style: TextStyle(
                      fontSize: context.responsive.fontSize(32),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.responsive.spacing(16)),
                  
                  // توضیحات
                  Padding(
                    padding: context.responsive.padding(horizontal: 40),
                    child: Text(
                      'کاریابی، خرید و فروش دستگاه و رهن و اجاره نانوایی',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.responsive.fontSize(16),
                        color: AppTheme.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: context.responsive.spacing(60)),
                  
                  // لودینگ
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: context.responsive.spacing(16)),
                  Text(
                    _loadingText,
                    style: TextStyle(
                      fontSize: context.responsive.fontSize(14),
                      color: AppTheme.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
