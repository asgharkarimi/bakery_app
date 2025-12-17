import 'package:flutter/material.dart';
import 'page_transitions.dart';

/// کلاس کمکی برای ناوبری با انیمیشن
class Nav {
  /// رفتن به صفحه با انیمیشن Slide
  static Future<T?> to<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      PageTransitions.sharedAxisX(page) as Route<T>,
    );
  }

  /// رفتن به صفحه جزئیات با انیمیشن Scale
  static Future<T?> toDetail<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      PageTransitions.fadeScale(page) as Route<T>,
    );
  }

  /// باز کردن صفحه از پایین (مثل فرم‌ها)
  static Future<T?> toForm<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      PageTransitions.slideFromBottom(page) as Route<T>,
    );
  }

  /// باز کردن Modal
  static Future<T?> toModal<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      PageTransitions.modal(page) as Route<T>,
    );
  }

  /// جایگزین کردن صفحه فعلی
  static Future<T?> replace<T>(BuildContext context, Widget page) {
    return Navigator.pushReplacement<T, dynamic>(
      context,
      PageTransitions.fadeScale(page) as Route<T>,
    );
  }

  /// برگشت به صفحه قبل
  static void back<T>(BuildContext context, [T? result]) {
    Navigator.pop(context, result);
  }

  /// برگشت به صفحه اصلی.
  static void toHome(BuildContext context, Widget home) {
    Navigator.pushAndRemoveUntil(
      context,
      PageTransitions.fadeScale(home),
      (route) => false,
    );
  }
}
