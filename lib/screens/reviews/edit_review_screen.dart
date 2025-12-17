import 'package:flutter/material.dart';
import '../../models/review.dart';
import '../../services/review_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_buttons_style.dart';

class EditReviewScreen extends StatefulWidget {
  final Review review;

  const EditReviewScreen({super.key, required this.review});

  @override
  State<EditReviewScreen> createState() => _EditReviewScreenState();
}

class _EditReviewScreenState extends State<EditReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  late double _rating;
  late Set<String> _selectedPositiveTags;
  late Set<String> _selectedNegativeTags;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.review.rating;
    _commentController.text = widget.review.comment;
    
    final negativeTags = ReviewService.getNegativeTags(widget.review.targetType);
    _selectedPositiveTags = widget.review.tags
        .where((tag) => !negativeTags.contains(tag))
        .toSet();
    _selectedNegativeTags = widget.review.tags
        .where((tag) => negativeTags.contains(tag))
        .toSet();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final allTags = [..._selectedPositiveTags, ..._selectedNegativeTags];
    final updatedReview = Review(
      id: widget.review.id,
      reviewerId: widget.review.reviewerId,
      reviewerName: widget.review.reviewerName,
      reviewerAvatar: widget.review.reviewerAvatar,
      targetId: widget.review.targetId,
      targetType: widget.review.targetType,
      rating: _rating,
      comment: _commentController.text.trim(),
      createdAt: widget.review.createdAt,
      tags: allTags,
    );

    final success = await ReviewService.updateReview(widget.review.id, updatedReview);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('نظر ویرایش شد و پس از تایید نمایش داده می‌شود'),
            backgroundColor: AppTheme.primaryGreen,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در ویرایش نظر'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final positiveTags = ReviewService.getSuggestedTags(widget.review.targetType);
    final negativeTags = ReviewService.getNegativeTags(widget.review.targetType);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('ویرایش نظر'),
          centerTitle: true,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // امتیاز
              const Text(
                'امتیاز شما',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            onPressed: () {
                              setState(() => _rating = (index + 1).toDouble());
                            },
                            icon: Icon(
                              index < _rating.round() ? Icons.star : Icons.star_border,
                              size: 40,
                              color: Colors.amber,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // تگ‌های مثبت
              const Text(
                'ویژگی‌های مثبت (اختیاری)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: positiveTags.map((tag) {
                  final isSelected = _selectedPositiveTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedPositiveTags.add(tag);
                        } else {
                          _selectedPositiveTags.remove(tag);
                        }
                      });
                    },
                    selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primaryGreen,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primaryGreen : AppTheme.textDark,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // تگ‌های منفی
              const Text(
                'ویژگی‌های منفی (اختیاری)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: negativeTags.map((tag) {
                  final isSelected = _selectedNegativeTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedNegativeTags.add(tag);
                        } else {
                          _selectedNegativeTags.remove(tag);
                        }
                      });
                    },
                    selectedColor: Colors.red.withValues(alpha: 0.2),
                    checkmarkColor: Colors.red,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.red : AppTheme.textDark,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // نظر
              const Text(
                'نظر شما',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _commentController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'تجربه خود را با دیگران به اشتراک بگذارید...',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: Icon(Icons.comment, color: AppTheme.primaryGreen),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),

              // دکمه ثبت
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: AppButtonsStyle.primaryButton(verticalPadding: 18),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('ذخیره تغییرات'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
