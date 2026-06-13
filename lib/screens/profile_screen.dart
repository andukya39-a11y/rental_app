import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rental_app/services/house_service.dart';
import 'package:rental_app/services/booking_service.dart';
import 'package:rental_app/services/review_service.dart';
import 'package:rental_app/screens/add_house_screen.dart';
import 'package:rental_app/screens/edit_house_screen.dart';
import 'package:rental_app/screens/my_bookings_screen.dart';
import 'package:rental_app/screens/landlord_bookings_screen.dart';
import 'package:rental_app/screens/house_detail_screen.dart';
import 'package:rental_app/screens/preferences_screen.dart';
import 'package:rental_app/screens/sheha_dashboard_screen.dart';
import 'package:rental_app/models/house_model.dart';
import 'package:rental_app/widgets/house_card.dart';
import 'package:rental_app/constants/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final HouseService _houseService = HouseService();
  final BookingService _bookingService = BookingService();
  final ReviewService _reviewService = ReviewService();
  User? _user;
  bool _isLoading = true;
  List<HouseModel> _myListings = [];
  int _bookingsCount = 0;
  int _reviewsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _user = user;
        });
        final listings = await _houseService.getHousesByUserId(user.uid);
        if (!mounted) return;
        setState(() {
          _myListings = listings;
        });
        final tenantBookings = await _bookingService.getTenantBookingRequests(user.uid).first;
        final userReviews = await _reviewService.getReviewsByUser(user.uid);
        if (!mounted) return;
        setState(() {
          _bookingsCount = tenantBookings.length;
          _reviewsCount = userReviews.length;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: $e')),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _LogoutConfirmDialog(),
    );
    if (confirmed != true) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  void _navigateToMyListings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyListingsScreen(listings: _myListings),
      ),
    );
  }

  void _navigateToMyBookings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MyBookingsScreen(),
      ),
    );
  }

  void _navigateToManageBookings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LandlordBookingsScreen(),
      ),
    );
  }

  void _navigateToPreferences() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PreferencesScreen(),
      ),
    );
  }

  void _navigateToShehaDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ShehaDashboardScreen(),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            )
          : _user == null
              ? _buildLoggedOutState()
              : CustomScrollView(
                  slivers: [
                    _buildProfileHeader(),
                    _buildQuickActions(),
                    _buildListingsSection(),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
    );
  }

  Widget _buildLoggedOutState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_off_rounded,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Not logged in',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please log in to view your profile',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user?.displayName ?? 'No Name',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _user?.email ?? 'No Email',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      _buildVerificationBadge(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final photoUrl = _user?.photoURL;
    final isVerified = _user?.emailVerified ?? false;

    return Stack(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 3,
            ),
          ),
          child: CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withValues(alpha: 0.06),
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  )
                : null,
          ),
        ),
        if (isVerified)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVerificationBadge() {
    final isVerified = _user?.emailVerified ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isVerified
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isVerified
              ? Colors.green.withValues(alpha: 0.25)
              : Colors.red.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified
                ? Icons.verified_user_rounded
                : Icons.error_outline_rounded,
            size: 14,
            color: isVerified ? Colors.green[700] : Colors.red[700],
          ),
          const SizedBox(width: 6),
          Text(
            isVerified ? 'Verified Email' : 'Unverified Email',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isVerified ? Colors.green[700] : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final listingsCount = _myListings.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.home_work_rounded,
              label: 'Listings',
              value: listingsCount.toString(),
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.calendar_month_rounded,
              label: 'Bookings',
              value: _bookingsCount.toString(),
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.star_rounded,
              label: 'Reviews',
              value: _reviewsCount.toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _ProfileAction(
        icon: Icons.list_alt_rounded,
        label: 'My Listings',
        subtitle: 'View and manage your properties',
        onTap: _navigateToMyListings,
      ),
      _ProfileAction(
        icon: Icons.calendar_today_rounded,
        label: 'My Bookings',
        subtitle: 'Track rental requests',
        onTap: _navigateToMyBookings,
      ),
      _ProfileAction(
        icon: Icons.assignment_rounded,
        label: 'Manage Bookings',
        subtitle: 'Accept or reject tenant requests',
        onTap: _navigateToManageBookings,
      ),
      _ProfileAction(
        icon: Icons.tune_rounded,
        label: 'Preferences',
        subtitle: 'Customize recommendations',
        onTap: _navigateToPreferences,
      ),
      _ProfileAction(
        icon: Icons.verified_rounded,
        label: 'Sheha Dashboard',
        subtitle: 'Verify properties',
        onTap: _navigateToShehaDashboard,
      ),
      _ProfileAction(
        icon: Icons.settings_rounded,
        label: 'Settings',
        subtitle: 'Account and app settings',
        onTap: _navigateToSettings,
      ),
      _ProfileAction(
        icon: Icons.logout_rounded,
        label: 'Logout',
        subtitle: 'Sign out of your account',
        onTap: _logout,
        isDestructive: true,
      ),
    ];

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final action = actions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProfileActionCard(action: action),
            );
          },
          childCount: actions.length,
        ),
      ),
    );
  }

  Widget _buildListingsSection() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Listings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_myListings.isNotEmpty)
                  TextButton(
                    onPressed: _navigateToMyListings,
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_myListings.isEmpty)
              _buildEmptyListings()
            else
              _buildListingsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyListings() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.home_work_outlined,
              size: 28,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No listings yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start earning by adding your first property',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AddHouseScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Listing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingsList() {
    final visibleListings = _myListings.take(3).toList();
    return Column(
      children: [
        for (final house in visibleListings)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: HouseCard(
              house: house,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HouseDetailScreen(house: house),
                  ),
                );
              },
            ),
          ),
        if (_myListings.length > 3)
          Center(
            child: TextButton(
              onPressed: _navigateToMyListings,
              child: Text(
                'View all ${_myListings.length} listings',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ProfileAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });
}

class _ProfileActionCard extends StatelessWidget {
  final _ProfileAction action;

  const _ProfileActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: action.isDestructive
                    ? Colors.red.withValues(alpha: 0.08)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                action.icon,
                size: 20,
                color:
                    action.isDestructive ? Colors.red[600] : AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: action.isDestructive
                          ? Colors.red[600]
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutConfirmDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Logout?',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'Are you sure you want to sign out of your account?',
        style: TextStyle(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Logout'),
        ),
      ],
    );
  }
}

// Placeholder screens for navigation
class MyListingsScreen extends StatelessWidget {
  final List<HouseModel> listings;

  const MyListingsScreen({super.key, required this.listings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: listings.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: listings.length,
              itemBuilder: (context, index) {
                final house = listings[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: house.imageUrl != null &&
                            house.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              house.imageUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.home_work_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                    title: Text(
                      house.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'TSh ${house.price.toStringAsFixed(0)}/mo',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => EditHouseScreen(house: house),
                            ),
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        } else if (value == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text(
                                'Delete Listing?',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              content: Text(
                                'Are you sure you want to permanently delete "${house.title}"? This action cannot be undone.',
                                style: const TextStyle(fontSize: 14),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            try {
                              await HouseService().deleteHouse(house.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Listing deleted successfully'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                Navigator.of(context).pop(true);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete: $e'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded,
                                  size: 18, color: AppColors.primary),
                              SizedBox(width: 10),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 10),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => HouseDetailScreen(house: house),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.home_work_outlined,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No listings yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start earning by adding your first property',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _isDeletingAccount = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed to change password')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Account?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This action cannot be undone. All your listings, bookings, and reviews will be permanently deleted.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeletingAccount = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.delete();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed to delete account')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    const url = 'https://yourapp.com/privacy-policy';
    if (!await launchUrl(Uri.parse(url))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open privacy policy')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                  title: const Text('Change Password'),
                  subtitle: const Text('Update your account password'),
                  onTap: _showChangePasswordDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                  title: const Text('Delete Account'),
                  subtitle: const Text('Permanently remove your account'),
                  onTap: _deleteAccount,
                  trailing: _isDeletingAccount
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                  title: const Text('App Version'),
                  subtitle: const Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_rounded, color: AppColors.primary),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('View our privacy policy'),
                  onTap: _launchPrivacyPolicy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Change Password',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isChangingPassword ? null : () async {
              await _changePassword();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
