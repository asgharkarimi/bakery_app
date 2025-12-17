class Review {
  final String id;
  final String reviewerId; // کسی که نظر میده
  final String reviewerName;
  final String reviewerAvatar;
  final String targetId; // کسی که نظر میگیره (کارجو یا کارفرما)
  final ReviewTargetType targetType;
  final double rating; // 1 تا 5
  final String comment;
  final DateTime createdAt;
  final List<String> tags; // مثلاً: حرفه‌ای، باتجربه، قابل اعتماد
  final bool isApproved; // تایید شده توسط ادمین

  Review({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    required this.reviewerAvatar,
    required this.targetId,
    required this.targetType,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.tags = const [],
    this.isApproved = false,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'].toString(),
      reviewerId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      reviewerName: json['user']?['name'] ?? json['reviewerName'] ?? 'کاربر',
      reviewerAvatar: json['user']?['profileImage'] ?? json['reviewerAvatar'] ?? '👤',
      targetId: json['targetId']?.toString() ?? json['target_id']?.toString() ?? '',
      targetType: _parseTargetType(json['targetType'] ?? json['target_type']),
      rating: (json['rating'] ?? 0).toDouble(),
      comment: json['comment'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      isApproved: json['isApproved'] ?? json['is_approved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetId': int.tryParse(targetId) ?? 0,
      'targetType': targetType == ReviewTargetType.jobSeeker ? 'user' : 'job_ad',
      'rating': rating.round(),
      'comment': comment,
      'tags': tags,
    };
  }

  static ReviewTargetType _parseTargetType(String? type) {
    switch (type) {
      case 'user':
      case 'jobSeeker':
        return ReviewTargetType.jobSeeker;
      case 'job_ad':
      case 'employer':
        return ReviewTargetType.employer;
      default:
        return ReviewTargetType.employer;
    }
  }
}

enum ReviewTargetType {
  jobSeeker, // کارجو
  employer, // کارفرما
}

class ReviewStats {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // تعداد هر ستاره

  ReviewStats({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  factory ReviewStats.empty() {
    return ReviewStats(
      averageRating: 0,
      totalReviews: 0,
      ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
    );
  }
}
