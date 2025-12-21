import 'dart:convert';
import 'package:flutter/foundation.dart';

List<String> _parseImages(dynamic images) {
  if (images == null) return [];
  if (images is List) return List<String>.from(images);
  if (images is String) {
    if (images.isEmpty || images == '[]') return [];
    try {
      final parsed = jsonDecode(images);
      if (parsed is List) return List<String>.from(parsed);
    } catch (_) {}
  }
  return [];
}

class JobAd {
  final String id;
  final String userId;
  final String userName;
  final String title;
  final String category;
  final int dailyBags;
  final int salary;
  final String location;
  final String phoneNumber;
  final String description;
  final List<String> images;
  final bool hasInsurance;
  final bool hasAccommodation;
  final bool hasVacation;
  final int vacationDays;
  final bool isApproved;
  final int views;
  final DateTime createdAt;

  JobAd({
    required this.id,
    this.userId = '',
    this.userName = '',
    required this.title,
    required this.category,
    required this.dailyBags,
    required this.salary,
    required this.location,
    required this.phoneNumber,
    required this.description,
    this.images = const [],
    this.hasInsurance = false,
    this.hasAccommodation = false,
    this.hasVacation = false,
    this.vacationDays = 0,
    this.isApproved = false,
    this.views = 0,
    required this.createdAt,
  });

  factory JobAd.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    // اول از user.id بخون، بعد از userId مستقیم
    String finalUserId = '';
    if (user != null && user['id'] != null) {
      finalUserId = user['id'].toString();
    } else if (json['userId'] != null) {
      finalUserId = json['userId'].toString();
    } else if (json['user_id'] != null) {
      finalUserId = json['user_id'].toString();
    }
    debugPrint('📋 JobAd.fromJson - userId: $finalUserId, user: $user');
    return JobAd(
      id: json['id']?.toString() ?? '',
      userId: finalUserId,
      userName: user?['name'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      dailyBags: json['dailyBags'] ?? json['daily_bags'] ?? 0,
      salary: json['salary'] ?? 0,
      location: json['location'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone_number'] ?? '',
      description: json['description'] ?? '',
      images: _parseImages(json['images']),
      hasInsurance: json['hasInsurance'] ?? json['has_insurance'] ?? false,
      hasAccommodation: json['hasAccommodation'] ?? json['has_accommodation'] ?? false,
      hasVacation: json['hasVacation'] ?? json['has_vacation'] ?? false,
      vacationDays: json['vacationDays'] ?? json['vacation_days'] ?? 0,
      isApproved: json['isApproved'] ?? json['is_approved'] ?? false,
      views: json['views'] ?? 0,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'category': category,
      'dailyBags': dailyBags,
      'salary': salary,
      'location': location,
      'phoneNumber': phoneNumber,
      'description': description,
      'images': images,
      'hasInsurance': hasInsurance,
      'hasAccommodation': hasAccommodation,
      'hasVacation': hasVacation,
      'vacationDays': vacationDays,
    };
  }
}
