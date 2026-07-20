import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zanzrental/models/house_model.dart';
import 'package:zanzrental/services/house_service.dart';
import 'package:zanzrental/services/preferences_service.dart' show PreferencesService, prefChangedNotifier;
import 'package:zanzrental/screens/property/house_detail_screen.dart';
import 'package:zanzrental/constants/app_colors.dart';
import 'package:zanzrental/widgets/house_card.dart';

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
          sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

class MapAndListScreen extends StatefulWidget {
  const MapAndListScreen({super.key});

  @override
  State<MapAndListScreen> createState() => _MapAndListScreenState();
}

class _MapAndListScreenState extends State<MapAndListScreen> {
  final HouseService _houseService = HouseService();
  final _searchCtrl = TextEditingController();
  final _sheetCtrl = DraggableScrollableController();

  StreamSubscription<List<HouseModel>>? _sub;
  List<HouseModel> _allHouses = [];
  bool _loading = true;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  HouseModel? _selectedHouse;

  double _prefMinPrice = 0;
  double _prefMaxPrice = 1000000;
  List<Map<String, dynamic>> _prefAreas = [];

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  BitmapDescriptor? _availableIcon;
  BitmapDescriptor? _unavailableIcon;

  // Default camera: Dar es Salaam, Tanzania
  static const _initialCamera = CameraPosition(
    target: LatLng(-6.7924, 39.2083),
    zoom: 12,
  );


  @override
  void initState() {
    super.initState();
    // Defer marker icon loading until the first frame so context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _initMarkerIcons());
    _sub = _houseService.getHousesStream().listen((houses) {
      if (!mounted) return;
      setState(() {
        _allHouses = houses;
        _loading = false;
        _refreshMarkers();
      });
    });
    _loadPreferences();
    prefChangedNotifier.addListener(_loadPreferences);
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
    });
    _refreshMarkers();
  }

  Future<void> _initMarkerIcons() async {
    try {
      // Use the device pixel ratio so the image is crisp on high-DPI screens
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final imageConfig = ImageConfiguration(
        devicePixelRatio: dpr,
        size: const Size(72.0, 40.0),
      );
      final icon = await BitmapDescriptor.asset(
        imageConfig,
        'assets/images/marker.png',
      );
      if (!mounted) return;
      setState(() {
        _availableIcon = icon;
        _unavailableIcon = icon;
        _refreshMarkers();
      });
    } catch (_) {
      // If asset fails to load, markers fall back to default red pins
    }
  }

  @override
  void dispose() {
    prefChangedNotifier.removeListener(_loadPreferences);
    _sub?.cancel();
    _searchCtrl.dispose();
    _sheetCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  List<HouseModel> get _filtered {
    return _allHouses.where((h) {
      // Category chip filter
      if (_selectedCategory != 'All') {
        if ((h.propertyType ?? '').toLowerCase() !=
            _selectedCategory.toLowerCase()) {
          return false;
        }
      }
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!h.title.toLowerCase().contains(q) &&
            !h.location.toLowerCase().contains(q) &&
            !(h.propertyType?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
      }
      // Preference: price range
      if (h.price < _prefMinPrice) return false;
      if (_prefMaxPrice < 1000000 && h.price > _prefMaxPrice) return false;
      // Preference: areas — coordinate distance first, name match as fallback
      if (_prefAreas.isNotEmpty) {
        final matches = _prefAreas.any((area) {
          final aLat = (area['lat'] as num?)?.toDouble();
          final aLng = (area['lng'] as num?)?.toDouble();
          if (aLat != null && aLng != null &&
              h.latitude != null && h.longitude != null) {
            return _haversineKm(aLat, aLng, h.latitude!, h.longitude!) <= 5.0;
          }
          final name = (area['name'] as String? ?? '').toLowerCase();
          return name.isNotEmpty && h.location.toLowerCase().contains(name);
        });
        if (!matches) return false;
      }
      return true;
    }).toList();
  }

  String? get _prefsLabel {
    final parts = <String>[];
    if (_prefMinPrice > 0 || _prefMaxPrice < 1000000) {
      final min = _prefMinPrice > 0 ? 'TSh ${_fmtPref(_prefMinPrice)}' : null;
      final max = _prefMaxPrice < 1000000 ? 'TSh ${_fmtPref(_prefMaxPrice)}' : null;
      if (min != null && max != null) {
        parts.add('$min – $max');
      } else if (max != null) {
        parts.add('max $max');
      } else if (min != null) {
        parts.add('min $min');
      }
    }
    if (_prefAreas.isNotEmpty) {
      parts.add(_prefAreas.map((a) => a['name'] as String? ?? '').join(', '));
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _fmtPref(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  void _refreshMarkers() {
    final newMarkers = <Marker>{};
    for (final h in _filtered) {
      if (h.latitude == null || h.longitude == null) continue;
      final icon = h.isAvailable
          ? (_availableIcon ?? BitmapDescriptor.defaultMarker)
          : (_unavailableIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueViolet));
      newMarkers.add(Marker(
        markerId: MarkerId(h.id),
        position: LatLng(h.latitude!, h.longitude!),
        icon: icon,
        onTap: () {
          setState(() => _selectedHouse = h);
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(h.latitude!, h.longitude!), 14),
          );
        },
      ));
    }
    _markers = newMarkers;
  }

  void _updateFilter({String? query, String? category}) {
    setState(() {
      if (query != null) _searchQuery = query;
      if (category != null) _selectedCategory = category;
      _refreshMarkers();
    });
    // Show/hide the bottom sheet based on whether there is an active search
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetCtrl.isAttached) return;
      _sheetCtrl.animateTo(
        _searchQuery.isNotEmpty ? 0.45 : 0.0,
        duration: const Duration(milliseconds: 350),
        curve: _searchQuery.isNotEmpty ? Curves.easeOut : Curves.easeIn,
      );
    });
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = 'All';
      _refreshMarkers();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheetCtrl.isAttached) return;
      _sheetCtrl.animateTo(0.0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeIn);
    });
  }

  @override
  Widget build(BuildContext context) {
    final houses = _filtered;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Full-screen Google Map ───────────────────────────────────
          // RepaintBoundary isolates the map's render layer so that
          // setState calls elsewhere don't trigger a map repaint,
          // preventing the platform-thread stalls that cause ANR.
          RepaintBoundary(
            child: GoogleMap(
              onMapCreated: (c) => _mapController = c,
              initialCameraPosition: _initialCamera,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              mapType: MapType.normal,
              onTap: (_) {
                if (_selectedHouse != null) {
                  setState(() => _selectedHouse = null);
                }
              },
            ),
          ),

          // ── Search bar (floating on map) ──────────────────────────
          SafeArea(
            bottom: false,
            child: _buildSearchBar(),
          ),

          // ── Mini card when marker is tapped ─────────────────────────
          if (_selectedHouse != null)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: _MiniPropertyCard(
                house: _selectedHouse!,
                onTap: () {
                  final h = _selectedHouse!;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => HouseDetailScreen(house: h),
                  ));
                },
                onClose: () => setState(() => _selectedHouse = null),
              ),
            ),

          // ── Draggable sheet with listing grid ───────────────────────
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.0,
            minChildSize: 0.0,
            maxChildSize: 0.90,
            snap: true,
            snapSizes: const [0.0, 0.45, 0.90],
            builder: (ctx, scrollCtrl) => _ListSheet(
              houses: houses,
              scrollController: scrollCtrl,
              isLoading: _loading,
              hasQuery: _searchQuery.isNotEmpty,
              onClearFilters: _clearFilters,
              onHouseTap: (h) => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => HouseDetailScreen(house: h)),
              ),
              prefsLabel: _prefsLabel,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar — matches home screen height & style ───────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _searchQuery.isNotEmpty
                ? AppColors.primary
                : const Color(0xFFCCCCCC),
            width: _searchQuery.isNotEmpty ? 1.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
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
                  : Colors.grey[500],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => _updateFilter(query: v),
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: 'Search properties, cities...',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[500]?.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  _updateFilter(query: '');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.close_rounded,
                      size: 20, color: Colors.grey[500]),
                ),
              )
            else
              const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }

}

// ── Mini property card ────────────────────────────────────────────────────────
class _MiniPropertyCard extends StatelessWidget {
  final HouseModel house;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _MiniPropertyCard({
    required this.house,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80,
                height: 72,
                child: house.imageUrl != null && house.imageUrl!.isNotEmpty
                    ? Image.network(house.imageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _ph())
                    : _ph(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(house.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.location_on_rounded,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(house.location,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(
                            text: 'TSh ${_fmt(house.price)}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary),
                          ),
                          const TextSpan(
                            text: '/mo',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('View',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close_rounded,
                  size: 18, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ph() => Container(
      color: const Color(0xFFF0F0F0),
      child: Icon(Icons.home_rounded, color: Colors.grey[400]));

  String _fmt(double price) {
    if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(1)}M';
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
    return price.toStringAsFixed(0);
  }
}

// ── Bottom sheet with 2-column property grid ──────────────────────────────────
class _ListSheet extends StatelessWidget {
  final List<HouseModel> houses;
  final ScrollController scrollController;
  final bool isLoading;
  final bool hasQuery;
  final VoidCallback onClearFilters;
  final ValueChanged<HouseModel> onHouseTap;
  final String? prefsLabel;

  const _ListSheet({
    required this.houses,
    required this.scrollController,
    required this.isLoading,
    required this.hasQuery,
    required this.onClearFilters,
    required this.onHouseTap,
    this.prefsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
              color: Color(0x22000000),
              blurRadius: 20,
              offset: Offset(0, -4)),
        ],
      ),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          // Drag handle + result count
          SliverToBoxAdapter(
            child: Column(children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isLoading
                          ? 'Loading...'
                          : '${houses.length} ${houses.length == 1 ? 'property' : 'properties'} found',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    if (hasQuery)
                      GestureDetector(
                        onTap: onClearFilters,
                        child: const Text('Clear filters',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              if (prefsLabel != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.bookmark_rounded,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'My Favourite: $prefsLabel',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 4),
            ]),
          ),

          if (isLoading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
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
            )
          else if (houses.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 48),
                child: Column(children: [
                  Icon(Icons.search_off_rounded,
                      size: 56,
                      color:
                          AppColors.textSecondary.withValues(alpha: 0.35)),
                  const SizedBox(height: 16),
                  const Text('No properties found',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Try a different search or clear your filters',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.68,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => HouseCard(
                    house: houses[i],
                    compact: true,
                    onTap: () => onHouseTap(houses[i]),
                  ),
                  childCount: houses.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

