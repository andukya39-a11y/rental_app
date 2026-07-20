import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zanzrental/constants/app_colors.dart';
import 'package:zanzrental/models/user_model.dart';
import 'package:zanzrental/screens/auth/auth_screen.dart';
import 'package:zanzrental/services/auth_service.dart';

// ── Location helpers (file-level so both home tab and verification list share them) ──

/// Returns true if [property] is in or near the Sheha's registered area.
/// Priority: Haversine distance (≤15 km) when both sides have coordinates;
/// falls back to keyword matching against the property location text.
bool _propertyMatchesSheha(
    Map<String, dynamic> property, Map<String, dynamic>? shehaExtra) {
  if (shehaExtra == null) return true;

  final shehaLat = (shehaExtra['shehiaLat'] as num?)?.toDouble();
  final shehaLng = (shehaExtra['shehiaLng'] as num?)?.toDouble();

  // Rule 1: Sheha has no saved coordinates → cannot filter by proximity → show all.
  if (shehaLat == null || shehaLng == null) return true;

  final propLat = _toDouble(property['lat'] ?? property['latitude']);
  final propLng = _toDouble(property['lng'] ?? property['longitude']);

  // Rule 2: Property has no coordinates → cannot confirm distance → include it.
  if (propLat == null || propLng == null) return true;

  // Rule 3: Both sides have coordinates → distance-based filter.
  // 30 km covers the breadth of Zanzibar island comfortably.
  final distKm = _haversineKm(shehaLat, shehaLng, propLat, propLng);
  return distKm <= 30.0;
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
          sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse('$v');
}

class ShehaPortalScreen extends StatefulWidget {
  const ShehaPortalScreen({super.key});

  @override
  State<ShehaPortalScreen> createState() => _ShehaPortalScreenState();
}

class _ShehaPortalScreenState extends State<ShehaPortalScreen> {
  int _currentIndex = 0;
  UserModel? _sheha;
  Map<String, dynamic>? _shehaExtra; // shehia, shehaId from Firestore
  final List<bool> _visited = [true, false, false, false];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = await AuthService().getStoredUser();
    if (!mounted) return;
    setState(() => _sheha = user);

    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .get();
      if (!mounted) return;
      setState(() => _shehaExtra = doc.data());
    }
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
      _visited[index] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _ShehaHomeTab(sheha: _sheha, shehaExtra: _shehaExtra),
      _visited[1]
          ? _ShehaPropertiesTab(shehaExtra: _shehaExtra)
          : const SizedBox(),
      _visited[2]
          ? _ShehaNotificationsTab(userId: _sheha?.id)
          : const SizedBox(),
      _visited[3]
          ? _ShehaProfileTab(sheha: _sheha, shehaExtra: _shehaExtra)
          : const SizedBox(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
        ),
        child: NavigationBar(
          height: 64,
          backgroundColor: Colors.white,
          selectedIndex: _currentIndex,
          onDestinationSelected: _onNavTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.verified_outlined),
              selectedIcon: Icon(Icons.verified_rounded),
              label: 'Properties',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Notifications',
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

// ═══════════════════════════════════════════════════════════════════════════════
// HOME TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _ShehaHomeTab extends StatefulWidget {
  final UserModel? sheha;
  final Map<String, dynamic>? shehaExtra;

  const _ShehaHomeTab({this.sheha, this.shehaExtra});

  @override
  State<_ShehaHomeTab> createState() => _ShehaHomeTabState();
}

class _ShehaHomeTabState extends State<_ShehaHomeTab> {
  int _pending = 0;
  int _approved = 0;
  int _rejected = 0;
  bool _loadingStats = true;

  // _allProps holds the full unfiltered snapshot; _applyFilter() derives the two lists.
  List<Map<String, dynamic>> _allProps = [];
  List<Map<String, dynamic>> _pendingProps = [];
  List<Map<String, dynamic>> _approvedProps = [];
  bool _loadingProperties = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didUpdateWidget(_ShehaHomeTab old) {
    super.didUpdateWidget(old);
    // shehaExtra arrives async after first build. If properties are already
    // loaded with a null shehaExtra (no filter applied), re-fetch once the
    // Sheha's location is known so the filter runs with real coordinates.
    final hadLocation = old.shehaExtra?['shehiaLat'] != null;
    final hasLocation = widget.shehaExtra?['shehiaLat'] != null;
    if (!hadLocation && hasLocation) {
      _fetchProperties(); // one-time reload with real coordinates
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadStats(), _fetchProperties()]);
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('properties')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('properties')
            .where('status', isEqualTo: 'approved')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('properties')
            .where('status', isEqualTo: 'rejected')
            .count()
            .get(),
      ]);
      if (!mounted) return;
      setState(() {
        _pending = results[0].count ?? 0;
        _approved = results[1].count ?? 0;
        _rejected = results[2].count ?? 0;
        _loadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _fetchProperties() async {
    setState(() => _loadingProperties = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('properties')
          .orderBy('createdAt', descending: true)
          .get();
      if (!mounted) return;
      _allProps = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      _applyFilter();
    } catch (_) {
      if (mounted) setState(() => _loadingProperties = false);
    }
  }

  // Split _allProps into pending/approved using the Sheha's location.
  void _applyFilter() {
    final pending = <Map<String, dynamic>>[];
    final approved = <Map<String, dynamic>>[];

    for (final p in _allProps) {
      if (!_propertyMatchesSheha(p, widget.shehaExtra)) continue;
      final status = p['status'] as String?;
      final vs = p['verificationStatus'] as String?;
      if (status == 'approved' || vs == 'verified') {
        approved.add(p);
      } else if (status != 'rejected' && vs != 'rejected') {
        pending.add(p);
      }
    }

    setState(() {
      _pendingProps = pending;
      _approvedProps = approved;
      _loadingProperties = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.sheha?.name ?? '';
    final shehia = widget.shehaExtra?['shehia'] as String? ??
        widget.shehaExtra?['shehiaArea'] as String? ??
        'Zanzibar';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(28)),
                ),
                padding: EdgeInsets.fromLTRB(
                    20, MediaQuery.of(context).padding.top + 20, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting,',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                name.isNotEmpty ? name : 'Sheha',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_user_rounded,
                              color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Shehia badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            shehia,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Stats ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verification Summary',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _loadingStats
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                  color: AppColors.primary),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  count: _pending,
                                  label: 'Pending',
                                  icon: Icons.pending_outlined,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCard(
                                  count: _approved,
                                  label: 'Approved',
                                  icon:
                                      Icons.check_circle_outline_rounded,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCard(
                                  count: _rejected,
                                  label: 'Rejected',
                                  icon: Icons.cancel_outlined,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),

            // ── Quick action ────────────────────────────────────────
            if (!_loadingStats && _pending > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Action Required',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.home_work_rounded,
                                  color: Colors.orange[700], size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_pending propert${_pending == 1 ? 'y' : 'ies'} awaiting verification',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tap Properties to review them',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: Colors.orange[400]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Pending in this area ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pending Verification',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!_loadingProperties)
                      Text(
                        '${_pendingProps.length} found',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),

            if (_loadingProperties)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              )
            else if (_pendingProps.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _EmptyArea(
                    icon: Icons.pending_outlined,
                    message: 'No properties pending verification',
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 260,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    itemCount: _pendingProps.length,
                    itemBuilder: (_, i) => Padding(
                      padding: EdgeInsets.only(
                          right: i < _pendingProps.length - 1 ? 12 : 0),
                      child: SizedBox(
                        width: 220,
                        child: _LocalPropertyCard(property: _pendingProps[i]),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Recently Approved in this area ──────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recently Approved',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!_loadingProperties)
                      Text(
                        '${_approvedProps.length} found',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),

            if (!_loadingProperties && _approvedProps.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _EmptyArea(
                    icon: Icons.check_circle_outline_rounded,
                    message: 'No approved properties yet in your area',
                  ),
                ),
              )
            else if (!_loadingProperties)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 260,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    itemCount: _approvedProps.length,
                    itemBuilder: (_, i) => Padding(
                      padding: EdgeInsets.only(
                          right: i < _approvedProps.length - 1 ? 12 : 0),
                      child: SizedBox(
                        width: 220,
                        child: _LocalPropertyCard(property: _approvedProps[i]),
                      ),
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.count,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty-area placeholder ───────────────────────────────────────────────────

class _EmptyArea extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyArea({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Local property card (home tab – Airbnb style) ────────────────────────────

class _LocalPropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  const _LocalPropertyCard({required this.property});

  @override
  Widget build(BuildContext context) {
    final imageUrls = property['imageUrls'] as List<dynamic>? ?? [];
    final imageUrl = (imageUrls.isNotEmpty ? imageUrls.first as String? : null) ??
        property['imageUrl'] as String?;
    final title = property['title'] as String? ?? 'Untitled';
    final location = property['location'] as String? ?? '—';
    final price = property['price'];
    final propertyType = property['propertyType'] as String? ?? '';
    final bedrooms = property['bedrooms'];
    final bathrooms = property['bathrooms'];
    final status = property['status'] as String? ?? 'pending';
    final isApproved = status == 'approved';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Photo ──────────────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: const Color(0xFFF0F0F0),
                              child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primary),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => _photoPlaceholder(),
                        )
                      : _photoPlaceholder(),
                  // Status badge – top right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isApproved ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isApproved ? 'Approved' : 'Pending',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Photo count – top left
                  if (imageUrls.length > 1)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.photo_library_rounded,
                              size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('${imageUrls.length}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ── Info ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Location
                Text(
                  location,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Type · beds · baths
                Text(
                  _subtitle(propertyType, bedrooms, bathrooms),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                // Price
                if (price != null)
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: AppColors.textPrimary),
                      children: [
                        TextSpan(
                          text: 'TSh ${_formatPrice(price)}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(
                          text: ' /mo',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(String type, dynamic beds, dynamic baths) {
    final parts = <String>[];
    if (type.isNotEmpty) parts.add(type);
    if (beds != null) parts.add('$beds ${beds == 1 ? "bed" : "beds"}');
    if (baths != null) parts.add('$baths ${baths == 1 ? "bath" : "baths"}');
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  String _formatPrice(dynamic price) {
    final p = (price is num) ? price.toDouble() : double.tryParse('$price') ?? 0;
    if (p >= 1000000) return '${(p / 1000000).toStringAsFixed(1)}M';
    if (p >= 1000) return '${(p / 1000).toStringAsFixed(0)}K';
    return p.toStringAsFixed(0);
  }

  Widget _photoPlaceholder() => Container(
        color: const Color(0xFFF0F0F0),
        child: const Icon(Icons.home_rounded, size: 32, color: AppColors.border),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTIES TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _ShehaPropertiesTab extends StatefulWidget {
  final Map<String, dynamic>? shehaExtra;
  const _ShehaPropertiesTab({this.shehaExtra});

  @override
  State<_ShehaPropertiesTab> createState() => _ShehaPropertiesTabState();
}

class _ShehaPropertiesTabState extends State<_ShehaPropertiesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Property Verification'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _VerificationList(status: 'pending', showActions: true, shehaExtra: widget.shehaExtra),
          _VerificationList(status: 'approved', shehaExtra: widget.shehaExtra),
          _VerificationList(status: 'rejected', shehaExtra: widget.shehaExtra),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFICATIONS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _ShehaNotificationsTab extends StatefulWidget {
  final String? userId;
  const _ShehaNotificationsTab({this.userId});

  @override
  State<_ShehaNotificationsTab> createState() =>
      _ShehaNotificationsTabState();
}

class _ShehaNotificationsTabState extends State<_ShehaNotificationsTab> {
  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .doc(widget.userId)
            .collection('items')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.notifications_none_rounded,
                    size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text('No notifications yet',
                    style: TextStyle(color: AppColors.textSecondary)),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final n = docs[i].data() as Map<String, dynamic>;
              final isRead = n['isRead'] == true;
              final ts = n['createdAt'] as Timestamp?;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isRead
                      ? Colors.white
                      : AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isRead
                        ? AppColors.border
                        : AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_rounded,
                          size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n['title'] as String? ?? 'Notification',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if ((n['message'] as String?)?.isNotEmpty ?? false)
                            ...[
                            const SizedBox(height: 3),
                            Text(
                              n['message'] as String,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                          if (ts != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatTs(ts.toDate()),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTs(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _ShehaProfileTab extends StatelessWidget {
  final UserModel? sheha;
  final Map<String, dynamic>? shehaExtra;

  const _ShehaProfileTab({this.sheha, this.shehaExtra});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Sign out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read from UserModel first; fall back to raw Firestore doc
    final name = (sheha?.name.isNotEmpty == true ? sheha!.name : null) ??
        shehaExtra?['name'] as String? ??
        '—';
    final email = (sheha?.email.isNotEmpty == true ? sheha!.email : null) ??
        shehaExtra?['email'] as String? ??
        '—';
    final phone = sheha?.phoneNumber ??
        shehaExtra?['phoneNumber'] as String? ??
        '—';
    final nationalId = sheha?.nationalId ??
        shehaExtra?['nationalId'] as String?;
    final shehia = shehaExtra?['shehia'] as String? ??
        shehaExtra?['shehiaArea'] as String? ??
        '—';
    final shehaId = shehaExtra?['shehaId'] as String? ?? '—';
    final shehiaFullAddress = shehaExtra?['shehiaFullAddress'] as String?;
    final shehiaLat = (shehaExtra?['shehiaLat'] as num?)?.toDouble();
    final shehiaLng = (shehaExtra?['shehiaLng'] as num?)?.toDouble();
    // Show coordinates only when no full address was captured
    final coordsLabel = (shehiaFullAddress == null || shehiaFullAddress.isEmpty) &&
            shehiaLat != null &&
            shehiaLng != null
        ? '${shehiaLat.toStringAsFixed(5)}, ${shehiaLng.toStringAsFixed(5)}'
        : null;
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'S';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Sign out',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Avatar + name ────────────────────────────────────
            const SizedBox(height: 8),
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: sheha?.profilePhoto != null
                  ? NetworkImage(sheha!.profilePhoto!)
                  : null,
              child: sheha?.profilePhoto == null
                  ? Text(initials,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary))
                  : null,
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_rounded,
                      size: 13, color: AppColors.primary),
                  SizedBox(width: 5),
                  Text('Sheha',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Info section ─────────────────────────────────────
            const _SectionHeader('Contact Information'),
            const SizedBox(height: 10),
            _ProfileTile(Icons.email_outlined, 'Email', email),
            _ProfileTile(Icons.phone_outlined, 'Phone', phone),
            if (nationalId != null && nationalId.isNotEmpty)
              _ProfileTile(Icons.badge_outlined, 'National ID', nationalId),

            const SizedBox(height: 20),
            const _SectionHeader('Sheha Details'),
            const SizedBox(height: 10),
            _ProfileTile(Icons.location_city_rounded, 'Shehia Area', shehia),
            if (shehiaFullAddress != null && shehiaFullAddress.isNotEmpty)
              _ProfileTile(Icons.location_on_rounded, 'Location Address',
                  shehiaFullAddress),
            if (coordsLabel != null)
              _ProfileTile(Icons.my_location_rounded, 'GPS Coordinates',
                  coordsLabel),
            if (shehaId != '—')
              _ProfileTile(
                  Icons.numbers_rounded, 'Badge / Registration No.', shehaId),

            const SizedBox(height: 20),
            const _SectionHeader('Account'),
            const SizedBox(height: 10),
            _ProfileTile(
              Icons.shield_outlined,
              'Account Status',
              sheha?.isVerified == true ? 'Verified' : 'Pending verification',
              trailingColor: sheha?.isVerified == true
                  ? Colors.green
                  : Colors.orange,
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red[300]!),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
      );
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? trailingColor;

  const _ProfileTile(this.icon, this.label, this.value,
      {this.trailingColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: trailingColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VERIFICATION LIST (Properties tab internals)
// ═══════════════════════════════════════════════════════════════════════════════

class _VerificationList extends StatefulWidget {
  final String status;
  final bool showActions;
  final Map<String, dynamic>? shehaExtra;

  const _VerificationList({
    required this.status,
    this.showActions = false,
    this.shehaExtra,
  });

  @override
  State<_VerificationList> createState() => _VerificationListState();
}

class _VerificationListState extends State<_VerificationList>
    with AutomaticKeepAliveClientMixin {
  List<QueryDocumentSnapshot> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      List<QueryDocumentSnapshot> docs;

      if (widget.status == 'pending') {
        final snap = await FirebaseFirestore.instance
            .collection('properties')
            .orderBy('createdAt', descending: true)
            .get();
        docs = snap.docs.where((d) {
          final p = d.data();
          final status = p['status'] as String?;
          final vs = p['verificationStatus'] as String?;
          if (status == 'approved' || status == 'rejected') return false;
          if (vs == 'verified' || vs == 'rejected') return false;
          return _propertyMatchesSheha(p, widget.shehaExtra);
        }).toList();
      } else {
        final snap = await FirebaseFirestore.instance
            .collection('properties')
            .where('status', isEqualTo: widget.status)
            .orderBy('createdAt', descending: true)
            .get();
        docs = snap.docs
            .where((d) => _propertyMatchesSheha(d.data(), widget.shehaExtra))
            .toList();
      }

      if (!mounted) return;
      setState(() { _isLoading = false; _items = docs; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _approve(String id) async {
    try {
      await FirebaseFirestore.instance.collection('properties').doc(id).update({
        'status': 'approved',
        'verificationStatus': 'verified',
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (!mounted) return;
      setState(() => _items.removeWhere((d) => d.id == id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Property approved and verified'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to approve: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _reject(String id) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(),
    );
    if (reason == null) return;
    try {
      await FirebaseFirestore.instance.collection('properties').doc(id).update({
        'status': 'rejected',
        'verificationStatus': 'rejected',
        'isVerified': false,
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (!mounted) return;
      setState(() => _items.removeWhere((d) => d.id == id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Property rejected'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to reject: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
            ),
          ]),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            widget.status == 'pending'
                ? Icons.check_circle_outline_rounded
                : Icons.home_outlined,
            size: 56,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            widget.status == 'pending'
                ? 'All caught up — no pending properties'
                : 'No ${widget.status} properties yet',
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final doc = _items[i];
          final p = doc.data() as Map<String, dynamic>;
          return _PropertyVerificationCard(
            property: p,
            onApprove:
                widget.showActions ? () => _approve(doc.id) : null,
            onReject: widget.showActions ? () => _reject(doc.id) : null,
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROPERTY CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _PropertyVerificationCard extends StatefulWidget {
  final Map<String, dynamic> property;
  final Future<void> Function()? onApprove;
  final Future<void> Function()? onReject;

  const _PropertyVerificationCard({
    required this.property,
    this.onApprove,
    this.onReject,
  });

  @override
  State<_PropertyVerificationCard> createState() =>
      _PropertyVerificationCardState();
}

class _PropertyVerificationCardState
    extends State<_PropertyVerificationCard> {
  bool _expanded = false;
  bool _isActing = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final imageUrls = p['imageUrls'] as List<dynamic>? ?? [];
    final imageUrl = (imageUrls.isNotEmpty ? imageUrls.first as String? : null) ??
        p['imageUrl'] as String?;
    final status = p['status'] as String? ?? 'pending';
    final desc = p['description'] as String?;

    Color statusColor;
    switch (status) {
      case 'approved': statusColor = Colors.green; break;
      case 'rejected': statusColor = Colors.red; break;
      default: statusColor = Colors.orange;
    }

    // Build subtitle: type · beds · baths
    final parts = <String>[];
    final type = p['propertyType'] as String? ?? '';
    final beds = p['bedrooms'];
    final baths = p['bathrooms'];
    if (type.isNotEmpty) parts.add(type);
    if (beds != null) parts.add('$beds ${beds == 1 ? "bed" : "beds"}');
    if (baths != null) parts.add('$baths ${baths == 1 ? "bath" : "baths"}');
    final subtitle = parts.isEmpty ? '' : parts.join(' · ');

    // Price formatted
    String? priceLabel;
    if (p['price'] != null) {
      final raw = p['price'];
      final d = (raw is num) ? raw.toDouble() : double.tryParse('$raw') ?? 0;
      final fmt = d >= 1000000
          ? '${(d / 1000000).toStringAsFixed(1)}M'
          : d >= 1000
              ? '${(d / 1000).toStringAsFixed(0)}K'
              : d.toStringAsFixed(0);
      priceLabel = 'TSh $fmt / month';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Photo ─────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: const Color(0xFFF0F0F0),
                              child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primary),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => _photoPlaceholder(),
                        )
                      : _photoPlaceholder(),
                  // Status pill – top right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  // Photo count – top left
                  if (imageUrls.length > 1)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.photo_library_rounded,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('${imageUrls.length}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Details ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + rating row (matching HouseCard style)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        p['title'] as String? ?? 'Untitled property',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 13, color: AppColors.textPrimary),
                        SizedBox(width: 3),
                        Text('New',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Location
                Row(children: [
                  const Icon(Icons.location_on_rounded,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      p['location'] as String? ?? '—',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 2),
                // Type · beds · baths
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                // Owner
                Row(children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Owner: ${p['ownerName'] as String? ?? '—'}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                // Price
                if (priceLabel != null)
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: priceLabel.split(' / ').first,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        const TextSpan(
                          text: ' / month',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                // Description toggle
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Row(children: [
                      Text(
                        _expanded ? 'Hide description' : 'Show description',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ]),
                  ),
                  if (_expanded)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(desc,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5)),
                    ),
                ],
              ],
            ),
          ),

          // ── Actions ───────────────────────────────────────────
          if (widget.onApprove != null && widget.onReject != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isActing
                        ? null
                        : () async {
                            setState(() => _isActing = true);
                            await widget.onReject?.call();
                            if (mounted) setState(() => _isActing = false);
                          },
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isActing
                        ? null
                        : () async {
                            setState(() => _isActing = true);
                            await widget.onApprove?.call();
                            if (mounted) setState(() => _isActing = false);
                          },
                    icon: _isActing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ]),
            ),
          ] else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() => Container(
        color: const Color(0xFFF0F0F0),
        child: const Icon(Icons.home_rounded, size: 48, color: AppColors.border),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// REJECT DIALOG
// ═══════════════════════════════════════════════════════════════════════════════

class _RejectDialog extends StatefulWidget {
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject property'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Provide a reason so the owner can correct their listing:',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Incomplete information, suspicious listing…',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final reason = _ctrl.text.trim();
            if (reason.isEmpty) return;
            Navigator.pop(context, reason);
          },
          style:
              ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Reject',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
