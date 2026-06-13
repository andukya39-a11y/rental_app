import 'package:flutter/material.dart';
import 'package:rental_app/models/review_model.dart';
import 'package:rental_app/constants/app_colors.dart';

class ReviewsScreen extends StatelessWidget {
  final String houseId;
  final String houseTitle;
  final Stream<List<ReviewModel>> reviewsStream;
  final Future<double> averageRating;
  final Future<int> reviewCount;

  const ReviewsScreen({
    Key? key,
    required this.houseId,
    required this.houseTitle,
    required this.reviewsStream,
    required this.averageRating,
    required this.reviewCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Reviews',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: StreamBuilder<List<ReviewModel>>(
        stream: reviewsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            );
          }

          final reviews = snapshot.data ?? [];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: FutureBuilder<double>(
                  future: averageRating,
                  builder: (context, ratingSnapshot) {
                    final avgRating = ratingSnapshot.data ?? 0.0;
                    return FutureBuilder<int>(
                      future: reviewCount,
                      builder: (context, countSnapshot) {
                        final count = countSnapshot.data ?? 0;
                        return Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    avgRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: List.generate(5, (index) {
                                          return Icon(
                                            index < avgRating.round()
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            size: 20,
                                            color: Colors.amber,
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$count review${count != 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (reviews.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.star_border_rounded,
                          size: 48,
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No reviews yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to review this property',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final review = reviews[index];
                      return _ReviewCard(review: review);
                    },
                    childCount: reviews.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage:
                    review.userPhotoUrl != null ? NetworkImage(review.userPhotoUrl!) : null,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: review.userPhotoUrl == null
                    ? Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: AppColors.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating.round()
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 16,
                    color: Colors.amber,
                  );
                }),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.comment!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}