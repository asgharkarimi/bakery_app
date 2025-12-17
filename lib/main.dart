import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/cache_service.dart';
import 'services/notification_manager.dart';
import 'services/api_service.dart';

// کلید گلوبال برای Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // مقداردهی اولیه کش
  await CacheService.init();
  
  // بارگذاری نوتیفیکیشن‌های نمونه
  NotificationService.loadSampleNotifications();
  
  // تنظیم callback برای نمایش پیام سرور در دسترس نیست
  ApiService.onServerUnavailable = _showServerUnavailableMessage;
  
  runApp(const MyApp());
}

// نمایش پیام سرور در دسترس نیست
void _showServerUnavailableMessage(String message) {
  final context = navigatorKey.currentContext;
  if (context != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // مقداردهی مدیر اعلان
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationManager.init(navigatorKey);
    });
    
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'سامانه جامع نانوایی',
      theme: AppTheme.lightTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CustomPageTransitionBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: CustomPageTransitionBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: CustomPageTransitionBuilder(),
          },
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

/// انیمیشن سفارشی برای انتقال صفحات
class CustomPageTransitionBuilder extends PageTransitionsBuilder {
  const CustomPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // انیمیشن Fade + Slide
    final tween = Tween(begin: const Offset(-0.15, 0.0), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic));
    
    final fadeTween = Tween(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOut));

    return FadeTransition(
      opacity: animation.drive(fadeTween),
      child: SlideTransition(
        position: animation.drive(tween),
        child: child,
      ),
    );
  }
}
