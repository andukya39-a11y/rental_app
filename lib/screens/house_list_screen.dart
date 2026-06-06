import 'package:flutter/material.dart';
import 'package:rental_app/models/house_model.dart';
import 'package:rental_app/services/house_service.dart';
import 'package:rental_app/widgets/house_card.dart';
import 'package:rental_app/screens/house_detail_screen.dart';
import 'package:rental_app/screens/add_house_screen.dart';
import 'package:rental_app/constants/app_colors.dart';

class HouseListScreen extends StatefulWidget {
  const HouseListScreen({Key? key}) : super(key: key);

  @override
  State<HouseListScreen> createState() => _HouseListScreenState();
}

class _HouseListScreenState extends State<HouseListScreen> {
  final HouseService _houseService = HouseService();
  bool _isLoading = true;
  List<HouseModel> _houses = [];
  String? _loadError;

  // Filter states
  String _selectedLocation = '';
  double _minPrice = 0;
  double _maxPrice = 1000000;
  int _minRooms = 0;

  // Available locations for dropdown (Zanzibar island areas only)
  final List<String> _locations = [
    '',
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

  @override
  void initState() {
    super.initState();
    _loadHouses();
  }

  Future<void> _loadHouses() async {
    setState(() => _isLoading = true);
    try {
      final houses = await _houseService.getHouses(
        locationFilter: _selectedLocation.isEmpty ? null : _selectedLocation,
        minPrice: _minPrice > 0 ? _minPrice : null,
        maxPrice: _maxPrice < 1000000 ? _maxPrice : null,
        minRooms: _minRooms > 0 ? _minRooms : null,
      );
      setState(() {
        _houses = houses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading houses: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _applyFilters() {
    _loadHouses();
  }

  void _resetFilters() {
    setState(() {
      _selectedLocation = '';
      _minPrice = 0;
      _maxPrice = 1000000;
      _minRooms = 0;
    });
    _loadHouses();
  }

  void _navigateToHouseDetail(HouseModel house) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HouseDetailScreen(house: house),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Explore Zanzibar Rentals',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadHouses,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddHouseScreen()),
          );
        },
        label: const Text('Add Property'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBody() {
    // Loading state: skeleton placeholders
    if (_isLoading) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 0, vertical: 6),
          child: HouseCardSkeleton(),
        ),
      );
    }

    // Error state after loading attempt
    if (_houses.isEmpty && _loadError != null) {
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
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadHouses,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state: illustration with helpful message
    if (_houses.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Empty illustration
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 56,
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No listings found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedLocation.isNotEmpty
                    ? 'No properties in "$_selectedLocation" match\nyour current filters.'
                    : 'No properties are available yet.\nBe the first to add one!',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Quick action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_selectedLocation.isNotEmpty ||
                      _minPrice > 0 ||
                      _minRooms > 0) ...[
                    OutlinedButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear Filters'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddHouseScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Listing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Data state: scrollable list with pull-to-refresh
    return RefreshIndicator(
      onRefresh: _loadHouses,
      color: AppColors.primary,
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: _houses.length,
        itemBuilder: (context, index) {
          return HouseCard(
            house: _houses[index],
            onTap: () => _navigateToHouseDetail(_houses[index]),
          );
        },
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Filter Houses (Zanzibar Only)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Location filter
              DropdownButtonFormField<String>(
                value: _selectedLocation.isEmpty ? null : _selectedLocation,
                decoration: InputDecoration(
                  labelText: 'Location (Zanzibar Areas)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _locations
                    .map((location) => DropdownMenuItem(
                          value: location,
                          child: Text(
                            location.isEmpty ? 'All Zanzibar Areas' : location,
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLocation = value ?? '';
                  });
                },
              ),
              const SizedBox(height: 20),

              // Price range in TZS
              Text(
                'Price Range (TZS)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Min Price',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixText: 'TSh ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          _minPrice = double.tryParse(value) ?? 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Max Price',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixText: 'TSh ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          _maxPrice = double.tryParse(value) ?? 1000000;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Minimum rooms
              Text(
                'Minimum Rooms',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Bedrooms + Bathrooms',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _minRooms = int.tryParse(value) ?? 0;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _resetFilters,
            child: Text(
              'Reset',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _applyFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }
}
