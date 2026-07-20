import 'package:flutter/material.dart';
import 'package:zanzrental/models/house_model.dart';
import 'package:zanzrental/widgets/verification_badge.dart';
import 'package:zanzrental/constants/app_colors.dart';

class HouseCard extends StatelessWidget {
  final HouseModel house;
  final VoidCallback onTap;
  final bool compact;

  const HouseCard({
    Key? key,
    required this.house,
    required this.onTap,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhoto(),
              const SizedBox(height: 10),
              _buildInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompact() {
    final isVerified = house.verificationStatus == 'verified';
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image expands to fill all space above the text ────
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo
                  house.imageUrl != null && house.imageUrl!.isNotEmpty
                      ? Image.network(
                          house.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: const Color(0xFFF0F0F0),
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(),
                        )
                      : _buildPhotoPlaceholder(),
                  // Verified badge — top left
                  if (isVerified)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 11, color: Colors.green),
                            SizedBox(width: 3),
                            Text('Verified',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green)),
                          ],
                        ),
                      ),
                    ),
                  // Rented badge — top left (below verified if both)
                  if (!house.isAvailable)
                    Positioned(
                      top: isVerified ? 42 : 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Rented',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  // Heart button — top right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_border_rounded,
                          size: 16, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ── Title + rating ───────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  house.title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 12, color: AppColors.textPrimary),
                  SizedBox(width: 2),
                  Text('4.5',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          // ── Location ─────────────────────────────────────────
          Text(
            house.location,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          // ── Price ────────────────────────────────────────────
          RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.textPrimary),
              children: [
                TextSpan(
                  text: 'TSh ${_formatPrice(house.price)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const TextSpan(
                  text: ' /mo',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Photo with heart & availability badge ──────────────────────
  Widget _buildPhoto() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 1.2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            house.imageUrl != null && house.imageUrl!.isNotEmpty
                ? Image.network(
                    house.imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: const Color(0xFFF0F0F0),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(),
                  )
                : _buildPhotoPlaceholder(),
            // Heart (wishlist) button — top right
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  size: 17,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Availability pill — top left
            if (!house.isAvailable)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Rented',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 6),
          Text('No image',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ── Text info (Airbnb layout) ──────────────────────────────────
  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: title + rating
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                house.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: 13, color: AppColors.textPrimary),
                SizedBox(width: 3),
                Text(
                  '4.5',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Row 2: location
        Text(
          house.location,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        // Row 3: type · beds · baths
        Text(
          _buildSubtitle(),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        // Row 4: price + verification badge
        Row(
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(color: AppColors.textPrimary),
                children: [
                  TextSpan(
                    text: 'TSh ${_formatPrice(house.price)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(
                    text: ' /month',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            VerificationBadge(
                verificationStatus: house.verificationStatus),
          ],
        ),
      ],
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (house.propertyType != null && house.propertyType!.isNotEmpty) {
      parts.add(house.propertyType!);
    }
    parts.add('${house.bedrooms} ${house.bedrooms == 1 ? "bed" : "beds"}');
    parts.add('${house.bathrooms} ${house.bathrooms == 1 ? "bath" : "baths"}');
    return parts.join(' · ');
  }

  String _formatPrice(double price) {
    if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(1)}M';
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
    return price.toStringAsFixed(0);
  }
}

// ─── Skeleton shimmer card ────────────────────────────────────────
class HouseCardSkeleton extends StatelessWidget {
  final bool compact;
  const HouseCardSkeleton({Key? key, this.compact = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(color: const Color(0xFFEEEEEE)),
            ),
          ),
          const SizedBox(height: 8),
          _box(double.infinity, 13),
          const SizedBox(height: 4),
          _box(80, 12),
          const SizedBox(height: 4),
          _box(90, 13),
        ],
      );
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo skeleton
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1.2,
              child: Container(color: const Color(0xFFEEEEEE)),
            ),
          ),
          const SizedBox(height: 10),
          // Text skeletons
          _box(180, 14),
          const SizedBox(height: 6),
          _box(120, 12),
          const SizedBox(height: 6),
          _box(150, 12),
          const SizedBox(height: 8),
          _box(100, 14),
        ],
      ),
    );
  }

  Widget _box(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}
