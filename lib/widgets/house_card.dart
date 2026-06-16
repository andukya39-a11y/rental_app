import 'package:flutter/material.dart';
import 'package:rental_app/models/house_model.dart';
import 'package:rental_app/widgets/verification_badge.dart';
import 'package:rental_app/constants/app_colors.dart';

/// Modern M3-styled house card with glassmorphism elements and smooth animations
class HouseCard extends StatelessWidget {
  final HouseModel house;
  final VoidCallback onTap;

  const HouseCard({
    Key? key,
    required this.house,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        surfaceTintColor: colorScheme.surfaceTint,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image section with modern overlays
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      // House image
                      SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: house.imageUrl != null &&
                                house.imageUrl!.isNotEmpty
                            ? Image.network(
                                house.imageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return _buildShimmerPlaceholder();
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPlaceholderImage(colorScheme),
                              )
                            : _buildPlaceholderImage(colorScheme),
                      ),
                      // Gradient overla for readability
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                colorScheme.onSurface.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Price badge - M3 elevated chip style
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                size: 14,
                                color: colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'TSh ${_formatPrice(house.price)}/mo',
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Location badge - frosted glass style
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colorScheme.shadow.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                house.location,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Verification status badge top-right
                      if (house.verificationStatus == 'verified')
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer
                                  .withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: 12,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Content section with improved typography
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and rating row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              house.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                                height: 1.3,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Rating badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  '4.5',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Property features row
                      Row(
                        children: [
                          _buildFeatureChip(
                            icon: Icons.bed_rounded,
                            label: '${house.bedrooms} BR',
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          _buildFeatureChip(
                            icon: Icons.bathtub_rounded,
                            label: '${house.bathrooms} BA',
                            color: colorScheme.primary,
                          ),
                          if (house.propertyType != null) ...[
                            const SizedBox(width: 8),
                            _buildFeatureChip(
                              icon: Icons.home_work_rounded,
                              label: house.propertyType!,
                              color: colorScheme.tertiary,
                            ),
                          ],
                          if (house.price > 0) ...[
                            const Spacer(),
                            Text(
                              '${_formatPrice(house.price)} TSh',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Status and verification row
                      Row(
                        children: [
                          // Availability tag - M3 chip style
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: house.isAvailable
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: house.isAvailable
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: house.isAvailable
                                        ? Colors.green
                                        : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  house.isAvailable ? 'Available' : 'Rented',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: house.isAvailable
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Verification badge
                          VerificationBadge(
                            verificationStatus: house.verificationStatus,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip({
    required IconData icon,
    required String label,
    required Color color,
    ColorScheme? scheme,
  }) {
    final cs = scheme ?? ColorScheme.light();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(ColorScheme colorScheme) {
    return Container(
      height: 200,
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.house_rounded,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'No Image',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toStringAsFixed(0);
  }
}

/// Skeleton shimmer placeholder for loading state
class HouseCardSkeleton extends StatelessWidget {
  const HouseCardSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image skeleton
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                height: 180,
                width: double.infinity,
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              ),
            ),
            // Details skeleton
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBox(200, 16, colorScheme),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _skeletonBox(60, 12, colorScheme),
                      const SizedBox(width: 12),
                      _skeletonBox(60, 12, colorScheme),
                      const SizedBox(width: 12),
                      _skeletonBox(70, 12, colorScheme),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _skeletonBox(80, 10, colorScheme),
                      const SizedBox(width: 8),
                      _skeletonBox(90, 10, colorScheme),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox(double width, double height, ColorScheme colorScheme) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
