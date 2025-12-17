import 'package:flutter/material.dart';
import '../../models/review.dart';
import '../../services/review_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_buttons_style.dart';
import '../../utils/responsive.dart';
import 'add_review_screen.dart';
import 'review_detail_screen.dart';

class ReviewsScreen extends StatefulWidget {
  final String targetId;
  final ReviewTargetType targetType;
  final String targetName;

  const ReviewsScreen({
    super.key,
    required this.targetId,
    required this.targetType,
    required this.targetName,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  ReviewStats? _stats;
  List<Review> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final stats = await ReviewService.getReviewStats(widget.targetId, widget.targetType);
    final reviews = await ReviewService.getReviewsForTarget(widget.targetId, widget.targetType);
    
    if (mounted) {
      setState(() {
        _stats = stats;
        _reviews = reviews;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('نظرات و امتیازها'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: context.responsive.padding(all: 16),
                children: [
                  _buildStatsCard(),
                  SizedBox(height: context.responsive.spacing(16)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddReviewScreen(
                              targetId: widget.targetId,
                              targetType: widget.targetType,
                              targetName: widget.targetName,
                            ),
                          ),
                        );
                        if (result == true && mounted) {
                          _loadData();
                        }
                      },
                      icon: const Icon(Icons.rate_review),
                      label: const Text('ثبت نظر جدید'),
                      style: AppButtonsStyle.elevatedIconButton(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_reviews.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.rate_review_outlined, size: 64, color: AppTheme.textGrey),
                            const SizedBox(height: 16),
                            Text(
                              'هنوز نظری ثبت نشده',
                              style: TextStyle(color: AppTheme.textGrey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._reviews.map((review) => _buildReviewCard(review)),
                ],
              ),
      ),
    );
  }


  Widget _buildStatsCard() {
    final stats = _stats ?? ReviewStats.empty();
    
    return Card(
      child: Padding(
        padding: context.responsive.padding(all: 20),
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  stats.averageRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: context.responsive.fontSize(48),
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < stats.averageRating.round()
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  '${stats.totalReviews} نظر',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                children: List.generate(5, (index) {
                  final star = 5 - index;
                  final count = stats.ratingDistribution[star] ?? 0;
                  final percentage = stats.totalReviews > 0
                      ? (count / stats.totalReviews)
                      : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text('$star', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: AppTheme.background,
                            valueColor: AlwaysStoppedAnimation(AppTheme.primaryGreen),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$count',
                          style: TextStyle(fontSize: 12, color: AppTheme.textGrey),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    // تشخیص تگ‌های منفی
    final negativeTags = ReviewService.getNegativeTags(widget.targetType);
    
    return Card(
      margin: EdgeInsets.only(bottom: context.responsive.spacing(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReviewDetailScreen(
                review: review,
                targetType: widget.targetType,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: context.responsive.padding(all: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: context.responsive.spacing(20),
                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  backgroundImage: _hasProfileImage(review)
                      ? NetworkImage('http://10.0.2.2:3000${review.reviewerAvatar}')
                      : null,
                  child: !_hasProfileImage(review)
                      ? Text(
                          review.reviewerName.isNotEmpty ? review.reviewerName[0] : '؟',
                          style: TextStyle(
                            fontSize: context.responsive.fontSize(18),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: context.responsive.spacing(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.reviewerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < review.rating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                          const SizedBox(width: 8),
                          Text(
                            _getTimeAgo(review.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.comment,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textDark,
                  height: 1.5,
                ),
              ),
            ],
            if (review.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: review.tags.map((tag) {
                  final isNegative = negativeTags.contains(tag);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isNegative
                          ? Colors.red.withValues(alpha: 0.1)
                          : AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12,
                        color: isNegative ? Colors.red : AppTheme.primaryGreen,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()} ماه پیش';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} روز پیش';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ساعت پیش';
    } else {
      return 'همین الان';
    }
  }

  bool _hasProfileImage(Review review) {
    return review.reviewerAvatar.isNotEmpty &&
        review.reviewerAvatar.startsWith('/') &&
        !review.reviewerAvatar.contains('👤');
  }
}
