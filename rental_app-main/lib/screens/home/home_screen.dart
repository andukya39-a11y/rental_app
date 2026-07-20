import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zanzrental/screens/property/map_and_list_screen.dart';
import 'package:zanzrental/screens/bookings/my_bookings_screen.dart';
import 'package:zanzrental/screens/profile/notifications_screen.dart';
import 'package:zanzrental/screens/profile/profile_screen.dart';
import 'package:zanzrental/screens/property/house_detail_screen.dart';
import 'package:zanzrental/screens/profile/preferences_screen.dart';
import 'package:zanzrental/models/house_model.dart';
import 'package:zanzrental/services/house_service.dart';
import 'package:zanzrental/services/preferences_service.dart' show PreferencesService, prefChangedNotifier;
import 'package:zanzrental/widgets/house_card.dart';
import 'package:zanzrental/constants/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // Lazily created: null until a tab is first visited, preventing Google Maps
  // and other heavy screens from initialising before the user opens them.
  late final List<Widget?> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = List.filled(5, null);
    _tabs[0] = const _HomeDashboard(); // home tab is always the first
  }

  Widget _makeTab(int i) {
    switch (i) {
      case 1: return const MapAndListScreen();
      case 2: return const MyBookingsScreen();
      case 3: return const NotificationsScreen();
      case 4: return const ProfileScreen();
      default: return const _HomeDashboard();
    }
  }

  void _onTabSelected(int i) {
    setState(() {
      _tabs[i] ??= _makeTab(i);
      _selectedIndex = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(5, (i) => _tabs[i] ?? const SizedBox.shrink()),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: NavigationBar(
          height: 64,
          backgroundColor: Colors.white,
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onTabSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today_rounded),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Inbox',
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

// ─── Haversine distance (km) between two lat/lng points ──────────
double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
          sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

// ─── Home Dashboard ───────────────────────────────────────────────
class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard();

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  String _selectedCategory = 'All';
  late final Stream<List<HouseModel>> _listingsStream;

  // Saved preferences (from profile → Rental Preferences page)
  double _prefMinPrice = 0;
  double _prefMaxPrice = 1000000;
  List<Map<String, dynamic>> _prefAreas = [];
  String _prefPropertyType = '';

  // Inline search + quick filters (set inside the filter sheet)
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  double _qMinPrice = 0;
  double _qMaxPrice = 1000000;
  bool _qVerifiedOnly = false;
  bool _qAvailableOnly = false;
  String _qPropertyType = '';

  bool get _hasActiveFilters =>
      _qMinPrice > 0 ||
      _qMaxPrice < 1000000 ||
      _qVerifiedOnly ||
      _qAvailableOnly ||
      _qPropertyType.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _listingsStream =
        HouseService().getHousesForRecommendationsStream(limit: 20);
    _loadPreferences();
    prefChangedNotifier.addListener(_loadPreferences);
    _searchCtrl.addListener(
      () => setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    prefChangedNotifier.removeListener(_loadPreferences);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await PreferencesService().getPreferences(uid);
    if (!mounted) return;
    setState(() {
      _prefMinPrice = prefs.minPrice;
      _prefMaxPrice = prefs.maxPrice;
      _prefAreas = prefs.preferredAreas;
      _prefPropertyType = prefs.propertyType;
    });
  }

  static const _categories = [
    _Category('All', Icons.home_rounded),
    _Category('Apartment', Icons.apartment_rounded),
    _Category('Villa', Icons.villa_rounded),
    _Category('Studio', Icons.single_bed_rounded),
    _Category('Beach', Icons.beach_access_rounded),
    _Category('Office', Icons.business_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(),
          _buildPreferencesStrip(),
          _buildFeaturedSection(),
          _buildListingsFeed(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── Single sticky header: greeting + search + categories ─────────
  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      toolbarHeight: 0,
      flexibleSpace: const SizedBox.shrink(),
      bottom: PreferredSize(
        // greeting(56) + search(86) + chips(48) + divider(1) = 191
        preferredSize: const Size.fromHeight(191),
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Greeting row ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Text(
                            'Find your home',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeaderAction(
                      icon: Icons.notifications_outlined,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Search field (tall, prominent) ──────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _searchQuery.isNotEmpty
                          ? AppColors.primary
                          : AppColors.border,
                      width: _searchQuery.isNotEmpty ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(
                        Icons.search_rounded,
                        size: 28,
                        color: _searchQuery.isNotEmpty
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by name, location…',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.6),
                            ),
                            border: InputBorder.none,
                            isDense: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () => _searchCtrl.clear(),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.close_rounded,
                                size: 20, color: AppColors.textSecondary),
                          ),
                        ),
                      GestureDetector(
                        onTap: _showFilterSheet,
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: _hasActiveFilters
                                ? AppColors.primary
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 16,
                                color: _hasActiveFilters
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Filter',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _hasActiveFilters
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Category chips ───────────────────────────────────
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final sel = _selectedCategory == cat.label;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedCategory = cat.label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                sel ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon,
                                size: 13,
                                color: sel
                                    ? Colors.white
                                    : AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Text(
                              cat.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: sel
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.divider),
            ],
          ),
        ),
      ),
    );
  }

  // ── Saved-preferences strip (non-sticky) ─────────────────────────
  Widget _buildPreferencesStrip() {
    final hasAreaPref = _prefAreas.isNotEmpty;
    final hasPricePref = _prefMinPrice > 0 || _prefMaxPrice < 1000000;
    if (!hasAreaPref && !hasPricePref) return const SliverToBoxAdapter(child: SizedBox.shrink());

    String priceLabel() {
      if (_prefMinPrice > 0 && _prefMaxPrice < 1000000) {
        return 'TSh ${_fmtK(_prefMinPrice)}–${_fmtK(_prefMaxPrice)}';
      }
      if (_prefMaxPrice < 1000000) return 'Max TSh ${_fmtK(_prefMaxPrice)}';
      return 'Min TSh ${_fmtK(_prefMinPrice)}';
    }

    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bookmark_rounded,
                    size: 13, color: AppColors.primary),
                const SizedBox(width: 5),
                const Text(
                  'My Favourite',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PreferencesScreen()),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (hasPricePref)
                  _PrefChip(
                    label: priceLabel(),
                    icon: Icons.payments_rounded,
                    onRemove: () => setState(() {
                      _prefMinPrice = 0;
                      _prefMaxPrice = 1000000;
                    }),
                  ),
                ..._prefAreas.map((a) => _PrefChip(
                      label: a['name'] as String? ?? '',
                      icon: Icons.location_on_rounded,
                      onRemove: () => setState(
                          () => _prefAreas.remove(a)),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtK(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  // ── Ad banner carousel ───────────────────────────────────────────
  Widget _buildFeaturedSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: _AdBannerCarousel(
          ads: [
            _AdData(
              title: 'Tafuta Nyumba Yako',
              subtitle: 'Nyumba za kukodi kwa bei\nnafuu hapa Zanzibar',
              cta: 'Tafuta Sasa',
              icon: Icons.search_rounded,
              decorIcon: Icons.home_rounded,
              gradientColors: const [Color(0xFF00897B), Color(0xFF00BFA5)],
              onTap: (ctx) => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const MapAndListScreen()),
              ),
            ),
            _AdData(
              title: 'Pata Arifa za\nNyumba Mpya',
              subtitle: 'Usikose nyumba mpya —\npata taarifa mara moja',
              cta: 'Angalia Arifa',
              icon: Icons.notifications_rounded,
              decorIcon: Icons.notification_important_rounded,
              gradientColors: const [Color(0xFFE65100), Color(0xFFFF8F00)],
              onTap: (ctx) => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            _AdData(
              title: 'Angalia Kwenye Ramani',
              subtitle: 'Gundua maeneo mazuri\nkaribu nawe kwa urahisi',
              cta: 'Fungua Ramani',
              icon: Icons.map_rounded,
              decorIcon: Icons.location_on_rounded,
              gradientColors: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
              onTap: (ctx) => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const MapAndListScreen()),
              ),
            ),
            _AdData(
              title: 'Hifadhi Matakwa Yako',
              subtitle: 'Weka bei na eneo unalotaka\ntupate chaguo bora kwako',
              cta: 'Weka Matakwa',
              icon: Icons.tune_rounded,
              decorIcon: Icons.favorite_rounded,
              gradientColors: const [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
              onTap: (ctx) => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const PreferencesScreen()),
              ),
            ),
            _AdData(
              title: 'Angalia Miadi Yako',
              subtitle: 'Fuatilia maombi ya kukodi\nna historia yako yote',
              cta: 'Angalia Miadi',
              icon: Icons.calendar_month_rounded,
              decorIcon: Icons.event_available_rounded,
              gradientColors: const [Color(0xFF283593), Color(0xFF5C6BC0)],
              onTap: (ctx) => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Listings feed ────────────────────────────────────────────────
  Widget _buildListingsFeed() {
    return StreamBuilder<List<HouseModel>>(
      stream: _listingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 16,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, __) => const HouseCardSkeleton(compact: true),
                childCount: 4,
              ),
            ),
          );
        }

        final all = snapshot.data ?? [];
        var houses = _selectedCategory == 'All'
            ? all
            : all
                .where((h) =>
                    (h.propertyType ?? '').toLowerCase() ==
                    _selectedCategory.toLowerCase())
                .toList();

        // Preference: price range
        if (_prefMinPrice > 0) {
          houses = houses.where((h) => h.price >= _prefMinPrice).toList();
        }
        if (_prefMaxPrice < 1000000) {
          houses = houses.where((h) => h.price <= _prefMaxPrice).toList();
        }
        // Preference: areas
        if (_prefAreas.isNotEmpty) {
          houses = houses.where((h) {
            return _prefAreas.any((area) {
              final aLat = (area['lat'] as num?)?.toDouble();
              final aLng = (area['lng'] as num?)?.toDouble();
              if (aLat != null && aLng != null &&
                  h.latitude != null && h.longitude != null) {
                return _haversineKm(aLat, aLng, h.latitude!, h.longitude!) <= 5.0;
              }
              final name = (area['name'] as String? ?? '').toLowerCase();
              return name.isNotEmpty && h.location.toLowerCase().contains(name);
            });
          }).toList();
        }

        // Quick search
        if (_searchQuery.isNotEmpty) {
          houses = houses.where((h) {
            final q = _searchQuery;
            return h.title.toLowerCase().contains(q) ||
                h.location.toLowerCase().contains(q) ||
                (h.propertyType?.toLowerCase().contains(q) ?? false) ||
                (h.description.toLowerCase().contains(q));
          }).toList();
        }

        // Quick filters from filter sheet
        if (_qMinPrice > 0) {
          houses = houses.where((h) => h.price >= _qMinPrice).toList();
        }
        if (_qMaxPrice < 1000000) {
          houses = houses.where((h) => h.price <= _qMaxPrice).toList();
        }
        if (_qVerifiedOnly) {
          houses = houses.where((h) => h.verificationStatus == 'verified').toList();
        }
        if (_qAvailableOnly) {
          houses = houses.where((h) => h.isAvailable).toList();
        }
        if (_qPropertyType.isNotEmpty) {
          houses = houses
              .where((h) =>
                  (h.propertyType ?? '').toLowerCase() ==
                  _qPropertyType.toLowerCase())
              .toList();
        }

        if (houses.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmpty());
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.74,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => HouseCard(
                house: houses[i],
                compact: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => HouseDetailScreen(house: houses[i])),
                ),
              ),
              childCount: houses.length,
            ),
          ),
        );
      },
    );
  }

  // ── Filter bottom sheet ──────────────────────────────────────────
  void _showFilterSheet() {
    double tmpMin = _qMinPrice;
    double tmpMax = _qMaxPrice;
    bool tmpVerified = _qVerifiedOnly;
    bool tmpAvailable = _qAvailableOnly;
    String tmpPropertyType = _qPropertyType;

    final hasSavedPref = _prefAreas.isNotEmpty ||
        _prefMinPrice > 0 ||
        _prefMaxPrice < 1000000 ||
        _prefPropertyType.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          String fmt(double v) {
            if (v >= 1000000) return 'TSh ${(v / 1000000).toStringAsFixed(1)}M';
            if (v >= 1000) return 'TSh ${(v / 1000).toStringAsFixed(0)}K';
            return 'TSh ${v.toStringAsFixed(0)}';
          }

          void applyAllSaved() {
            setSt(() {
              tmpMin = _prefMinPrice;
              tmpMax = _prefMaxPrice;
              tmpPropertyType = _prefPropertyType;
            });
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (_, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 24 + MediaQuery.of(ctx).viewInsets.bottom),
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title row
                Row(
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setSt(() {
                        tmpMin = 0;
                        tmpMax = 1000000;
                        tmpVerified = false;
                        tmpAvailable = false;
                        tmpPropertyType = '';
                      }),
                      child: const Text('Reset all',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Saved Preferences section ──────────────────────
                if (hasSavedPref) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bookmark_rounded,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'My Favourite',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        const PreferencesScreen()));
                              },
                              child: const Text('Edit',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (_prefMinPrice > 0 || _prefMaxPrice < 1000000)
                              _SheetPrefChip(
                                label: _prefMinPrice > 0 && _prefMaxPrice < 1000000
                                    ? '${fmt(_prefMinPrice)} – ${fmt(_prefMaxPrice)}'
                                    : _prefMaxPrice < 1000000
                                        ? 'Max ${fmt(_prefMaxPrice)}'
                                        : 'Min ${fmt(_prefMinPrice)}',
                                icon: Icons.payments_rounded,
                              ),
                            if (_prefPropertyType.isNotEmpty)
                              _SheetPrefChip(
                                label: _prefPropertyType,
                                icon: Icons.home_work_rounded,
                              ),
                            ..._prefAreas.map((a) => _SheetPrefChip(
                                  label: a['name'] as String? ?? '',
                                  icon: Icons.location_on_rounded,
                                )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: applyAllSaved,
                            icon: const Icon(Icons.done_all_rounded, size: 16),
                            label: const Text('Apply All Saved Preferences'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Price Range ────────────────────────────────────
                const Text('Price Range',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fmt(tmpMin),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    Text(tmpMax >= 1000000 ? 'No limit' : fmt(tmpMax),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                RangeSlider(
                  values: RangeValues(tmpMin, tmpMax),
                  min: 0,
                  max: 1000000,
                  divisions: 20,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.primary.withValues(alpha: 0.15),
                  onChanged: (v) =>
                      setSt(() { tmpMin = v.start; tmpMax = v.end; }),
                ),
                const SizedBox(height: 16),

                // ── Property Type ──────────────────────────────────
                const Text('Property Type',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['', 'Room', 'Apartment', 'House', 'Studio', 'Villa']
                      .map((type) {
                    final label = type.isEmpty ? 'Any' : type;
                    final sel = tmpPropertyType == type;
                    return GestureDetector(
                      onTap: () => setSt(() => tmpPropertyType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: sel
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // ── Property Status ────────────────────────────────
                const Text('Property Status',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                _FilterToggle(
                  label: 'Verified properties only',
                  icon: Icons.verified_rounded,
                  color: Colors.green,
                  value: tmpVerified,
                  onChanged: (v) => setSt(() => tmpVerified = v),
                ),
                const SizedBox(height: 8),
                _FilterToggle(
                  label: 'Available for rent only',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.primary,
                  value: tmpAvailable,
                  onChanged: (v) => setSt(() => tmpAvailable = v),
                ),
                const SizedBox(height: 24),

                // Apply button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _qMinPrice = tmpMin;
                        _qMaxPrice = tmpMax;
                        _qVerifiedOnly = tmpVerified;
                        _qAvailableOnly = tmpAvailable;
                        _qPropertyType = tmpPropertyType;
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Apply Filters',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        children: [
          Icon(Icons.explore_off_rounded,
              size: 56, color: AppColors.textSecondary.withValues(alpha: 0.35)),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == 'All'
                ? 'No listings yet'
                : 'No $_selectedCategory listings',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Check back soon',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning ☀️';
    if (h < 17) return 'Good afternoon 🌤️';
    return 'Good evening 🌙';
  }
}

// ─── Category model ───────────────────────────────────────────────
class _Category {
  final String label;
  final IconData icon;

  const _Category(this.label, this.icon);
}

// ─── Header action button ─────────────────────────────────────────
class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

// ─── Ad data model ────────────────────────────────────────────────
class _AdData {
  final String title;
  final String subtitle;
  final String cta;
  final IconData icon;
  final IconData decorIcon;
  final List<Color> gradientColors;
  final void Function(BuildContext ctx) onTap;

  const _AdData({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.icon,
    required this.decorIcon,
    required this.gradientColors,
    required this.onTap,
  });
}

// ─── Ad banner carousel ───────────────────────────────────────────
class _AdBannerCarousel extends StatefulWidget {
  final List<_AdData> ads;
  const _AdBannerCarousel({required this.ads});

  @override
  State<_AdBannerCarousel> createState() => _AdBannerCarouselState();
}

class _AdBannerCarouselState extends State<_AdBannerCarousel> {
  late final PageController _pageCtrl;
  late final Timer _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.96);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_current + 1) % widget.ads.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.ads.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (ctx, i) {
              final ad = widget.ads[i];
              return _AdBannerCard(ad: ad);
            },
          ),
        ),
      ],
    );
  }
}

// ─── Single ad banner card ────────────────────────────────────────
class _AdBannerCard extends StatelessWidget {
  final _AdData ad;
  const _AdBannerCard({required this.ad});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ad.onTap(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: ad.gradientColors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: ad.gradientColors.first.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Large decorative circle — back right
            Positioned(
              right: -28,
              top: -28,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Medium decorative circle — mid right
            Positioned(
              right: 30,
              bottom: -40,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            // Big icon — right side visual
            Positioned(
              right: 14,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(
                  ad.decorIcon,
                  size: 70,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ),
            // Content — left side
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 11, 100, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Small icon badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(ad.icon, size: 15, color: Colors.white),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    ad.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ad.subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.35,
                    ),
                  ),
                  const Spacer(),
                  // CTA button
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ad.cta,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ad.gradientColors.first,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter toggle row ────────────────────────────────────────────
class _FilterToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FilterToggle({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? color.withValues(alpha: 0.4) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: value ? color : AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: value ? color : AppColors.textPrimary,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? color : Colors.transparent,
                border: Border.all(
                  color: value ? color : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Display-only chip used inside the filter sheet ──────────────
class _SheetPrefChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SheetPrefChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Saved-preference removable chip ─────────────────────────────
class _PrefChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onRemove;

  const _PrefChip({
    required this.label,
    required this.icon,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 13, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
