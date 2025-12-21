import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/review.dart';

class ReviewService {
  static const String baseUrl = 'https://bakerjobs.ir/api';

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // دریافت نظرات تایید شده یک شخص از API
  static Future<List<Review>> getReviewsForTarget(
      String targetId, ReviewTargetType type) async {
    try {
      final targetTypeStr =
          type == ReviewTargetType.jobSeeker ? 'user' : 'job_ad';
      final response = await http.get(
        Uri.parse('$baseUrl/reviews/$targetTypeStr/$targetId'),
      );
      final data = jsonDecode(response.body);

      if (data['success'] == true && data['data'] != null) {
        return (data['data'] as List)
            .map((json) => Review.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
      return [];
    }
  }

  // دریافت آمار نظرات
  static Future<ReviewStats> getReviewStats(
      String targetId, ReviewTargetType type) async {
    final reviews = await getReviewsForTarget(targetId, type);

    if (reviews.isEmpty) {
      return ReviewStats.empty();
    }

    final totalReviews = reviews.length;
    final averageRating =
        reviews.map((r) => r.rating).reduce((a, b) => a + b) / totalReviews;

    final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (var review in reviews) {
      distribution[review.rating.round()] =
          (distribution[review.rating.round()] ?? 0) + 1;
    }

    return ReviewStats(
      averageRating: averageRating,
      totalReviews: totalReviews,
      ratingDistribution: distribution,
    );
  }


  // ثبت نظر جدید (نیاز به تایید ادمین دارد)
  static Future<bool> addReview(Review review) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode(review.toJson());
      debugPrint('📝 Sending review: $body');
      debugPrint('🔑 Headers: $headers');
      
      final response = await http.post(
        Uri.parse('$baseUrl/reviews'),
        headers: headers,
        body: body,
      );
      
      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');
      
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('❌ Error adding review: $e');
      return false;
    }
  }

  // دریافت نظرات کاربر فعلی
  static Future<List<Review>> getMyReviews() async {
    try {
      final headers = await _getHeaders();
      debugPrint('🔍 Fetching my reviews...');
      debugPrint('🔑 Headers: $headers');
      
      final response = await http.get(
        Uri.parse('$baseUrl/reviews/my/list'),
        headers: headers,
      );
      
      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');
      
      final data = jsonDecode(response.body);

      if (data['success'] == true && data['data'] != null) {
        debugPrint('✅ Found ${(data['data'] as List).length} reviews');
        return (data['data'] as List)
            .map((json) => Review.fromJson(json))
            .toList();
      }
      debugPrint('⚠️ No reviews found or success=false');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching my reviews: $e');
      return [];
    }
  }

  // ویرایش نظر
  static Future<bool> updateReview(String id, Review review) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/reviews/$id'),
        headers: headers,
        body: jsonEncode(review.toJson()),
      );
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('Error updating review: $e');
      return false;
    }
  }

  // حذف نظر
  static Future<bool> deleteReview(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/reviews/$id'),
        headers: headers,
      );
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('Error deleting review: $e');
      return false;
    }
  }

  // تگ‌های پیشنهادی مثبت
  static List<String> getSuggestedTags(ReviewTargetType type) {
    if (type == ReviewTargetType.jobSeeker) {
      return [
        'حرفه‌ای',
        'باتجربه',
        'دقیق',
        'سریع',
        'قابل اعتماد',
        'مسئولیت‌پذیر',
        'خلاق',
        'صبور',
      ];
    } else {
      return [
        'قابل اعتماد',
        'پرداخت به موقع',
        'رفتار محترمانه',
        'شرایط خوب',
        'محیط کار مناسب',
        'حقوق مناسب',
      ];
    }
  }

  // تگ‌های پیشنهادی منفی
  static List<String> getNegativeTags(ReviewTargetType type) {
    if (type == ReviewTargetType.jobSeeker) {
      return [
        'بی‌دقت',
        'کم‌تجربه',
        'تأخیر در کار',
        'غیرقابل اعتماد',
        'بی‌مسئولیت',
        'کیفیت پایین',
        'عدم تعهد',
        'رفتار نامناسب',
      ];
    } else {
      return [
        'تأخیر در پرداخت',
        'رفتار نامناسب',
        'شرایط بد کاری',
        'حقوق کم',
        'عدم پایبندی به قرارداد',
        'محیط کار نامناسب',
        'غیرقابل اعتماد',
        'فشار کاری زیاد',
      ];
    }
  }
}
