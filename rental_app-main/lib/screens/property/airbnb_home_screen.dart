import 'package:flutter/material.dart';
import 'package:zanzrental/models/house_model.dart';
import 'package:zanzrental/services/house_service.dart';
import 'package:zanzrental/widgets/house_card.dart';
import 'package:zanzrental/screens/property/add_house_screen.dart';
import 'package:zanzrental/screens/property/house_detail_screen.dart';
import 'package:zanzrental/constants/app_colors.dart';

class AirbnbHomeScreen extends StatefulWidget {
  const AirbnbHomeScreen({super.key});

  @override
  State<AirbnbHomeScreen> createState() => _AirbnbHomeScreenState();
}

class _AirbnbHomeScreenState extends State<AirbnbHomeScreen> {
  final HouseService _houseService = HouseService();
  
  // Filter states
  String _selectedLocation = 'Zanzibar City'; // Placeholder
  String _selectedCategory = 'All'; // All, Room, Apartment, House
  
  // Available locations for dropdown (Zanzibar island areas only)
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
  
  // Property categories
  final List<String> _categories = ['All', 'Room', 'Apartment', 'House'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // App bar with search and location
          SliverAppBar(
            pinned: true,
            floating: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location selector
                GestureDetector(
                  onTap: _showLocationDialog,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedLocation,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search for homes, places, and more',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Category buttons
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((category) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ChoiceChip(
                      label: Text(
                        category,
                        style: TextStyle(
                          color: _selectedCategory == category
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      selected: _selectedCategory == category,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    ),
                  )).toList(),
                ),
              ),
            ),
          ),
          
          // Recommended Houses section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recommended for you',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: StreamBuilder<List<HouseModel>>(
                      stream: _houseService.getHousesStream(
                        locationFilter: _selectedLocation.isEmpty ? null : _selectedLocation,
                        propertyTypeFilter: _selectedCategory == 'All' ? null : _selectedCategory,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          );
                        }
                        
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          );
                        }
                        
                        final houses = snapshot.data ?? [];
                        
                        if (houses.isEmpty) {
                          return const Center(
                            child: Text(
                              'No recommended houses',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          );
                        }
                        
                        // Take first 3 houses for recommendations
                        final recommended = houses.take(3).toList();
                        
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: recommended.length,
                          itemBuilder: (context, index) {
                            final house = recommended[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => HouseDetailScreen(house: house),
                                  ),
                                );
                              },
                              child: Container(
                                width: 160,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: house.imageUrl != null && house.imageUrl!.isNotEmpty
                                          ? Image.network(
                                              house.imageUrl!,
                                              height: 120,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              height: 120,
                                              width: double.infinity,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.house,
                                                size: 40,
                                                color: Colors.grey,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Title
                                    Text(
                                      house.title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    // Price and rating
                                    Row(
                                      children: [
                                        Text(
                                          'TSh ${house.price.toStringAsFixed(0)}/night',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(
                                          Icons.star,
                                          size: 14,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 2),
                                        const Text(
                                          '4.8',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Popular Areas section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Popular Areas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _locations.length,
                      itemBuilder: (context, index) {
                        final area = _locations[index];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLocation = area;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedLocation == area
                                    ? AppColors.primary
                                    : AppColors.textSecondary.withValues(alpha: 0.2),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              area,
                              style: TextStyle(
                                color: _selectedLocation == area
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: _selectedLocation == area
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Main houses list
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: StreamBuilder<List<HouseModel>>(
              stream: _houseService.getHousesStream(
                locationFilter: _selectedLocation.isEmpty ? null : _selectedLocation,
                propertyTypeFilter: _selectedCategory == 'All' ? null : _selectedCategory,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }
                
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  );
                }
                
                final houses = snapshot.data ?? [];
                
                if (houses.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No houses found',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try changing your search or filters',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                return SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final house = houses[index];
                      return HouseCard(
                        house: house,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HouseDetailScreen(house: house),
                            ),
                          );
                        },
                      );
                    },
                    childCount: houses.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddHouseScreen()),
          );
        },
        label: const Text('Add Listing'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
  
  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Select Location',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
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
                  setState(() {
                    _selectedLocation = location;
                  });
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