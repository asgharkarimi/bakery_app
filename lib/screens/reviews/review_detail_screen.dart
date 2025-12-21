import 'package:flutter/material.dart';
import '../../models/review.dart';
import '../../services/review_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_ago.dart';

class ReviewDetailScreen extends StatelessWidget {
  final Review review;
  final ReviewTargetType targetType;

  const ReviewDetailScreen({
    super.key,
    required this.review,
    required this.targetType,
  });

  @override
  Widget build(BuildContext context) {
    final negativeTags = ReviewService.getNegativeTags(targetType);
    final positiveTags = _getPositiveTags(negativeTags);
    final negTags = _getNegativeTags(negativeTags);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back, color: AppTheme.textDark, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'جزییات نظر',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // کارت پروفایل و امتیاز
              _buildProfileRatingCard(),
              const SizedBox(height: 20),

              // ویژگی‌های مثبت
              if (positiveTags.isNotEmpty) ...[
                _buildTagsCard(
                  title: 'ویژگی‌های مثبت',
                  icon: Icons.thumb_up_rounded,
                  color: AppTheme.primaryGreen,
                  tags: positiveTags,
                  isPositive: true,
                ),
                const SizedBox(height: 16),
              ],

              // ویژگی‌های منفی
              if (negTags.isNotEmpty) ...[
                _buildTagsCard(
                  title: 'ویژگی‌های منفی',
                  icon: Icons.thumb_down_rounded,
                  color: Colors.red,
                  tags: negTags,
                  isPositive: false,
                ),
                const SizedBox(height: 16),
              ],

              // نظر متنی
              if (review.comment.isNotEmpty) _buildCommentCard(),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getPositiveTags(List<String> negativeTags) {
    return review.tags.where((tag) => !negativeTags.contains(tag)).toList();
  }

  List<String> _getNegativeTags(List<String> negativeTags) {
    return review.tags.where((tag) => negativeTags.contains(tag)).toList();
  }

  bool _hasProfileImage() {
    return review.reviewerAvatar.isNotEmpty &&
        review.reviewerAvatar.startsWith('/') &&
        !review.reviewerAvatar.contains('👤');
  }

  Widget _buildProfileRatingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withValues(alpha: 0.8),
            const Color(0xFF2E7D32),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // آواتار
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              backgroundImage: _hasProfileImage()
                  ? NetworkImage('${ApiService.serverUrl}${review.reviewerAvatar}')
                  : null,
              child: !_hasProfileImage()
                  ? Text(
                      review.reviewerName.isNotEmpty ? review.reviewerName[0] : '؟',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          
          // نام
          Text(
            review.reviewerName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          
          // زمان
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  TimeAgo.format(review.createdAt),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // خط جداکننده
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.white.withValues(alpha: 0.2),
          ),
          
          const SizedBox(height: 20),
          
          // امتیاز
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    review.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          index < review.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 28,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagsCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> tags,
    required bool isPositive,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPositive
                        ? [AppTheme.primaryGreen, AppTheme.primaryGreen.withValues(alpha: 0.7)]
                        : [Colors.red, Colors.red.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tags.length}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: color,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tag,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.blue.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.format_quote_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Text(
                'نظر کاربر',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              review.comment,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textDark,
                height: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
