import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rental_app/models/house_model.dart';
import 'package:rental_app/services/house_service.dart';
import 'package:rental_app/models/preferences_model.dart';
import 'package:rental_app/services/preferences_service.dart';
import 'package:rental_app/services/recently_viewed_service.dart';
import 'package:rental_app/widgets/house_card.dart';
import 'package:rental_app/screens/house_detail_screen.dart';
import 'package:rental_app/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapAndListScreen extends StatefulWidget {
  const MapAndListScreen({super.key});

  @override
  State<MapAndListScreen> createState() => _MapAndListScreenState();
}

class _MapAndListScreenState extends State<MapAndListScreen> {
  final HouseService _houseService = HouseService();
  final PreferencesService _preferencesService = PreferencesService();
  final RecentlyViewedService _recentlyViewedService = RecentlyViewedService();

  String _selectedLocation = 'Zanzibar City';
  String _selectedCategory = 'All';

  final List<String> _locations = [
    'Zanzibar City',
    'Stone Town',
    'Nungwi',
    'Kendwa',
    'Paje',
    'Jambiani',
    'Matemwe',
    'Kiwengwa',
    'Chake Chake',
    'Mkoani',
    'Wete',
    'Other Zanzibar Areas'
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<String> _categories = ['All', 'Room', 'Apartment', 'House'];
  bool _isMapView = true;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Map<String, HouseModel> _housesById = {};

  String _userId = '';
  Preferences _userPreferences = Preferences(
    preferredAreas: [],
    minPrice: 0.0,
    maxPrice: 1000000.0,
    propertyType: 'Room',
  );
  bool _isLoadingPreferences = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndPreferences();
  }

  Future<void> _loadUserIdAndPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _isLoadingPreferences = false;
      });
      return;
    }
    _userId = user.uid;
    _isLoggedIn = true;
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await _preferencesService.getPreferences(_userId);
      setState(() {
        _userPreferences = preferences;
        _isLoadingPreferences = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPreferences = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load preferences: $e')),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 8),
            _buildCategoryChips(),
            const SizedBox(height: 12),
            _buildViewToggle(),
            const SizedBox(height: 8),
            Expanded(
              child: _isMapView ? _buildMapView() : _buildListView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _showLocationDialog,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _selectedLocation,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value.trim().toLowerCase());
              },
              decoration: InputDecoration(
                hintText: 'Search homes, places...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categories
              .map((category) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: FilterChip(
                      label: Text(
                        category,
                        style: TextStyle(
                          color: _selectedCategory == category
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: _selectedCategory == category
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        setState(() => _selectedCategory = category);
                      },
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _selectedCategory == category
                              ? AppColors.primary
                              : Colors.grey.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
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
          Expanded(
            child: _ToggleButton(
              icon: Icons.map_rounded,
              label: 'Map',
              isSelected: _isMapView,
              onTap: () => setState(() => _isMapView = true),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              icon: Icons.list_rounded,
              label: 'List',
              isSelected: !_isMapView,
              onTap: () => setState(() => _isMapView = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    return StreamBuilder<List<HouseModel>>(
      stream: _houseService.getHousesStream(
        locationFilter: _selectedLocation.isEmpty ? null : _selectedLocation,
        propertyTypeFilter:
            _selectedCategory == 'All' ? null : _selectedCategory,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return _buildMapError('Error loading map');
        }

        var houses = snapshot.data ?? [];
        if (_searchQuery.isNotEmpty) {
          houses = houses.where((h) {
            final title = h.title.toLowerCase();
            final location = h.location.toLowerCase();
            return title.contains(_searchQuery) ||
                location.contains(_searchQuery);
          }).toList();
        }
        _updateMarkers(houses);

        if (houses.isEmpty) {
          return _buildMapEmpty();
        }

        return GoogleMap(
          onMapCreated: (controller) => _mapController = controller,
          initialCameraPosition: const CameraPosition(
            target: LatLng(-6.1650, 39.2023),
            zoom: 10,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        );
      },
    );
  }

  Widget _buildMapError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 48, color: Colors.red[400]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.red[700], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMapEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_off_rounded,
              size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'No houses in this area',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return StreamBuilder<List<HouseModel>>(
      stream: _houseService.getHousesStream(
        locationFilter: _selectedLocation.isEmpty ? null : _selectedLocation,
        propertyTypeFilter:
            _selectedCategory == 'All' ? null : _selectedCategory,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: 4,
            itemBuilder: (context, index) => const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: HouseCardSkeleton(),
            ),
          );
        }
        if (snapshot.hasError) {
          return _buildListError(snapshot.error);
        }

        var houses = snapshot.data ?? [];
        if (_searchQuery.isNotEmpty) {
          houses = houses.where((h) {
            final title = h.title.toLowerCase();
            final location = h.location.toLowerCase();
            return title.contains(_searchQuery) ||
                location.contains(_searchQuery);
          }).toList();
        }
        if (houses.isEmpty) {
          return _buildListEmpty();
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: houses.length,
          itemBuilder: (context, index) {
            final house = houses[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
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
            );
          },
        );
      },
    );
  }

  Widget _buildListError(Object? error) {
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
                color: Colors.red.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.signal_wifi_off_rounded,
                size: 48,
                color: Colors.red.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load properties. Please try again.',
              style: const TextStyle(
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

  Widget _buildListEmpty() {
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
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No listings found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing your filters or location',
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

  void _updateMarkers(List<HouseModel> houses) {
    _markers.clear();
    _housesById.clear();
    for (final house in houses) {
      if (house.latitude != null && house.longitude != null) {
        final markerId = MarkerId(house.id);
        final marker = Marker(
          markerId: markerId,
          position: LatLng(house.latitude!, house.longitude!),
          infoWindow: InfoWindow(
            title: house.title,
            snippet: 'TSh ${house.price.toStringAsFixed(0)}/month',
          ),
          onTap: () {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HouseDetailScreen(house: house),
                ),
              );
            }
          },
        );
        _markers.add(marker);
        _housesById[house.id] = house;
      }
    }
    if (mounted) setState(() {});
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Select Location',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _locations.length,
            itemBuilder: (context, index) {
              final location = _locations[index];
              return ListTile(
                title: Text(location),
                selected: _selectedLocation == location,
                onTap: () {
                  setState(() => _selectedLocation = location);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
