import 'package:flutter/material.dart';
import 'package:zanzrental/constants/app_colors.dart';
import 'package:zanzrental/models/house_model.dart';
import 'package:zanzrental/models/user_model.dart';
import 'package:zanzrental/screens/owner/owner_analytics_screen.dart';
import 'package:zanzrental/screens/profile/profile_screen.dart';
import 'package:zanzrental/screens/property/add_house_screen.dart';
import 'package:zanzrental/screens/property/house_detail_screen.dart';
import 'package:zanzrental/models/booking_model.dart';
import 'package:zanzrental/services/auth_service.dart';
import 'package:zanzrental/services/property_service.dart';
import 'package:zanzrental/services/booking_service.dart';
import 'package:zanzrental/widgets/house_card.dart';
import 'package:zanzrental/widgets/notification_bell.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  int _selectedIndex = 0;
  UserModel? _user;
  Key _listingsKey = const ValueKey('listings-0');
  int _listingsVersion = 0;

  @override
  void initState() {
    super.initState();
    AuthService().getStoredUser().then((u) {
      if (mounted) setState(() => _user = u);
    });
  }

  void _onPropertyAdded() {
    _listingsVersion++;
    setState(() {
      _listingsKey = ValueKey('listings-$_listingsVersion');
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _OwnerOverviewTab(
        user: _user,
        onPropertyAdded: _onPropertyAdded,
        onSeeAllListings: () => setState(() => _selectedIndex = 1),
      ),
      _OwnerListingsTab(key: _listingsKey),
      const _OwnerBookingsTab(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
        ),
        child: NavigationBar(
          height: 64,
          backgroundColor: Colors.white,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Listings',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overview Tab ───────────────────────────────────────────────────────────────

class _OwnerOverviewTab extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onPropertyAdded;
  final VoidCallback? onSeeAllListings;
  const _OwnerOverviewTab({this.user, this.onPropertyAdded, this.onSeeAllListings});

  @override
  State<_OwnerOverviewTab> createState() => _OwnerOverviewTabState();
}

class _OwnerOverviewTabState extends State<_OwnerOverviewTab> {
  final _propertyService = PropertyService();
  Map<String, dynamic> _stats = {};
  List<HouseModel> _recentListings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final listingsRes = await _propertyService.getMyListings();
    if (!mounted) return;

    List<HouseModel> allListings = [];
    if (listingsRes.success && listingsRes.data is List) {
      allListings = List<HouseModel>.from(listingsRes.data as List);
    }

    setState(() {
      _isLoading = false;
      _stats = {
        'total_listings': allListings.length,
        'available': allListings.where((h) => h.isAvailable).length,
        'verified': allListings.where((h) => h.isVerified).length,
      };
      _recentListings = allListings.take(3).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user?.name.split(' ').first ?? 'Owner';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 16,
                    20,
                    12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        _getInitials(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.user?.roleName ?? 'Property Owner',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const NotificationBell(),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('PROPERTY STATS'),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.4,
                        children: [
                          _StatCard(
                            label: 'Total Listings',
                            value: '${_stats['total_listings'] ?? 0}',
                            icon: Icons.home_rounded,
                            color: AppColors.primary,
                          ),
                          _StatCard(
                            label: 'Active Listings',
                            value: '${_stats['active_listings'] ?? 0}',
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF2E7D32),
                          ),
                          _StatCard(
                            label: 'Total Bookings',
                            value: '${_stats['total_bookings'] ?? 0}',
                            icon: Icons.calendar_month_rounded,
                            color: const Color(0xFF1565C0),
                          ),
                          _StatCard(
                            label: 'Revenue',
                            value: _formatAmount(_stats['total_revenue']),
                            icon: Icons.payments_rounded,
                            color: const Color(0xFFE65100),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _sectionLabel('QUICK ACTIONS'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.add_home_rounded,
                              label: 'Add Property',
                              color: AppColors.primary,
                              onTap: () async {
                                final added = await Navigator.of(context)
                                    .push<bool>(MaterialPageRoute(
                                        builder: (_) =>
                                            const AddHouseScreen()));
                                if (added == true) {
                                  widget.onPropertyAdded?.call();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickAction(
                              icon: Icons.bar_chart_rounded,
                              label: 'Analytics',
                              color: const Color(0xFF1565C0),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const OwnerAnalyticsScreen(),
                                ));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // ── Recent Properties ──────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionLabel('RECENT PROPERTIES'),
                          if (_recentListings.isNotEmpty)
                            GestureDetector(
                              onTap: widget.onSeeAllListings,
                              child: const Text(
                                'See all',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_recentListings.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.home_outlined,
                                  size: 36,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.4)),
                              const SizedBox(height: 8),
                              const Text(
                                'No properties yet',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          height: 230,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.zero,
                            itemCount: _recentListings.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (ctx, i) {
                              final house = _recentListings[i];
                              return SizedBox(
                                width: 155,
                                child: _OwnerPropertyCard(
                                  house: house,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          HouseDetailScreen(house: house),
                                    ),
                                  ),
                                  onEdit: () async {
                                    await Navigator.of(context).push<bool>(
                                      MaterialPageRoute(
                                        builder: (_) => AddHouseScreen(
                                          property: house.toMap()
                                            ..['id'] = house.id,
                                        ),
                                      ),
                                    );
                                    _load();
                                  },
                                  onDelete: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Delete Listing'),
                                        content: const Text('Are you sure?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: TextButton.styleFrom(
                                                foregroundColor: Colors.red),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true && mounted) {
                                      await PropertyService()
                                          .deleteProperty(house.id);
                                      _load();
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  String _formatAmount(dynamic value) {
    if (value == null) return 'TSh 0';
    final num = double.tryParse(value.toString()) ?? 0;
    if (num >= 1000000) return 'TSh ${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return 'TSh ${(num / 1000).toStringAsFixed(0)}K';
    return 'TSh ${num.toStringAsFixed(0)}';
  }

  String _getInitials() {
    final name = widget.user?.name ?? 'O';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'O';
    return trimmed[0].toUpperCase();
  }
}

// ── Listings Tab ───────────────────────────────────────────────────────────────

class _OwnerListingsTab extends StatefulWidget {
  const _OwnerListingsTab({super.key});

  @override
  State<_OwnerListingsTab> createState() => _OwnerListingsTabState();
}

class _OwnerListingsTabState extends State<_OwnerListingsTab> {
  final _propertyService = PropertyService();
  List<HouseModel> _listings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final res = await _propertyService.getMyListings();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.success) {
        final data = res.data;
        if (data is List) {
          _listings = data.whereType<HouseModel>().toList();
        } else {
          _listings = [];
        }
      } else {
        _error = res.message;
      }
    });
  }

  Future<void> _edit(HouseModel house) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => AddHouseScreen(property: house.toMap()..['id'] = house.id)),
    );
    if (updated == true) _load();
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Listing'),
        content: const Text(
            'Are you sure you want to delete this property? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final res = await _propertyService.deleteProperty(id);
    if (!mounted) return;
    if (res.success) {
      setState(() => _listings.removeWhere((p) => p.id == id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property deleted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Listings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(
                    builder: (_) => const AddHouseScreen()))
                .then((_) => _load()),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _listings.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.74,
                        ),
                        itemCount: _listings.length,
                        itemBuilder: (context, i) {
                          final house = _listings[i];
                          return _OwnerPropertyCard(
                            house: house,
                            onDelete: () => _delete(house.id),
                            onEdit: () => _edit(house),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HouseDetailScreen(house: house),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.home_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'No listings yet',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your first property to get started',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(
                    builder: (_) => const AddHouseScreen()))
                .then((_) => _load()),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Property'),
          ),
        ],
      ),
    );
  }
}

// ── Bookings Tab ───────────────────────────────────────────────────────────────

class _OwnerBookingsTab extends StatefulWidget {
  const _OwnerBookingsTab();

  @override
  State<_OwnerBookingsTab> createState() => _OwnerBookingsTabState();
}

class _OwnerBookingsTabState extends State<_OwnerBookingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BookingModel> _pending = [];
  List<BookingModel> _confirmed = [];
  List<BookingModel> _all = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final res = await BookingService().getOwnerBookings();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.success && res.data is List) {
        _all = List<BookingModel>.from(res.data as List);
        _pending = _all.where((b) => b.status == 'pending').toList();
        _confirmed = _all.where((b) => b.status == 'confirmed').toList();
      }
    });
  }

  Future<void> _confirm(String id) async {
    final res = await BookingService().confirmBooking(id);
    if (!mounted) return;
    if (res.success) {
      _load();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Booking confirmed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bookings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              text: 'Pending',
              icon: Badge(
                isLabelVisible: _pending.isNotEmpty,
                label: Text('${_pending.length}'),
                child: const Icon(Icons.pending_rounded, size: 18),
              ),
            ),
            const Tab(
              text: 'Confirmed',
              icon: Icon(Icons.check_circle_rounded, size: 18),
            ),
            const Tab(
              text: 'All',
              icon: Icon(Icons.list_rounded, size: 18),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookingList(_pending, showConfirm: true),
                _buildBookingList(_confirmed),
                _buildBookingList(_all),
              ],
            ),
    );
  }

  Widget _buildBookingList(List<BookingModel> bookings,
      {bool showConfirm = false}) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('No bookings here',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final b = bookings[i];
          return _BookingCard(
            booking: b,
            onConfirm: showConfirm ? () => _confirm(b.id) : null,
          );
        },
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps [HouseCard] (compact/Airbnb style) with an owner-only popup menu
/// for edit and delete actions. Used in both the overview and listings tab.
class _OwnerPropertyCard extends StatelessWidget {
  final HouseModel house;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OwnerPropertyCard({
    required this.house,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: HouseCard(house: house, compact: true, onTap: onTap),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.white.withValues(alpha: 0.88),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') onEdit();
                if (val == 'delete') onDelete();
              },
              icon: const Icon(Icons.more_vert_rounded,
                  size: 16, color: AppColors.textPrimary),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onConfirm;

  const _BookingCard({required this.booking, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final status = booking.status;

    Color statusColor;
    switch (status) {
      case 'confirmed':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      case 'completed':
        statusColor = AppColors.primary;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property image banner
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: booking.houseImageUrl.isNotEmpty
                ? Image.network(
                    booking.houseImageUrl,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            height: 130,
                            color: Colors.grey[100],
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                    errorBuilder: (_, __, ___) => _placeholderImage(),
                  )
                : _placeholderImage(),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        booking.houseTitle.isNotEmpty ? booking.houseTitle : 'Property',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(label: status, color: statusColor),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      booking.tenantName.isNotEmpty ? booking.tenantName : 'Unknown Tenant',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.date_range_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _fmt(booking.moveInDate),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.schedule_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${booking.rentalDurationMonths} month(s)',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
                  ],
                ),
                if (onConfirm != null && status == 'pending') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Confirm Booking'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  Widget _placeholderImage() {
    return Container(
      height: 130,
      width: double.infinity,
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.house_rounded, size: 36, color: Colors.grey[400]),
          const SizedBox(height: 6),
          Text('No image', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
