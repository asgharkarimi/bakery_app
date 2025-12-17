import 'package:flutter/material.dart';
import '../models/review.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';
import '../screens/reviews/reviews_screen.dart';

class RatingBadge extends StatelessWidget {
  final String targetId;
  final ReviewTargetType targetType;
  final String targetName;
  final bool showReviewCount;
  final bool isClickable;

  const RatingBadge({
    super.key,
    required this.targetId,
    required this.targetType,
    required this.targetName,
    this.showReviewCount = true,
    this.isClickable = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReviewStats>(
      future: ReviewService.getReviewStats(targetId, targetType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        final stats = snapshot.data;
        if (stats == null || stats.totalReviews == 0) {
          return _buildNoRating(context);
        }

        return _buildRating(context, stats);
      },
    );
  }

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildRating(BuildContext context, ReviewStats stats) {
    return InkWell(
      onTap: isClickable ? () => _navigateToReviews(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            Text(
              stats.averageRating.toStringAsFixed(1),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
                fontSize: 14,
              ),
            ),
            if (showReviewCount) ...[
              const SizedBox(width: 4),
              Text(
                '(${stats.totalReviews})',
                style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoRating(BuildContext context) {
    return InkWell(
      onTap: isClickable ? () => _navigateToReviews(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border, color: AppTheme.textGrey, size: 18),
            const SizedBox(width: 4),
            Text(
              'بدون نظر',
              style: TextStyle(
                color: AppTheme.textGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToReviews(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewsScreen(
          targetId: targetId,
          targetType: targetType,
          targetName: targetName,
        ),
      ),
    );
  }
}
