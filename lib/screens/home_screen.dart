import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rental_app/screens/map_and_list_screen.dart';
import 'package:rental_app/screens/my_bookings_screen.dart';
import 'package:rental_app/screens/notifications_screen.dart';
import 'package:rental_app/screens/profile_screen.dart';
import 'package:rental_app/screens/add_house_screen.dart';
import 'package:rental_app/screens/house_detail_screen.dart';
import 'package:rental_app/screens/house_list_screen.dart';
import 'package:rental_app/screens/preferences_screen.dart';
import 'package:rental_app/screens/sheha_dashboard_screen.dart';
import 'package:rental_app/models/house_model.dart';
import 'package:rental_app/services/house_service.dart';
import 'package:rental_app/services/preferences_service.dart';
import 'package:rental_app/models/preferences_model.dart';
import 'package:rental_app/widgets/house_card.dart';
import 'package:rental_app/constants/app_colors.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Persistent screens using IndexedStack - never rebuilds
  final List<Widget> _screens = [
    const _HomeDashboard(),
    const MapAndListScreen(),
    const MyBookingsScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        height: 65,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.1),
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map/Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Dashboard home screen with welcome, quick actions, and recommendations
class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Welcome header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Zanzi Renta',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find your perfect rental in Zanzibar',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Quick action cards
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final items = [
                    _ActionItem(Icons.search_rounded, 'Browse Rentals', () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            body: MapAndListScreen(),
                          ),
                        ),
                      );
                    }),
                    _ActionItem(
                        Icons.add_circle_outline_rounded, 'Add Property', () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddHouseScreen(),
                        ),
                      );
                    }),
                    _ActionItem(Icons.favorite_outline_rounded, 'Preferences',
                        () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PreferencesScreen(),
                        ),
                      );
                    }),
                    _ActionItem(Icons.verified_user_outlined, 'Sheha Dashboard',
                        () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ShehaDashboardScreen(),
                        ),
                      );
                    }),
                  ];
                  final item = items[index];
                  return _ActionCard(item: item);
                },
                childCount: 4,
              ),
            ),
          ),
          // Recommended section (preference-scored)
          const _RecommendedSection(),
          // Houses Near Me section (GPS-based)
          const _HousesNearMeSection(),
        ],
      ),
    );
  }
}

/// Section showing houses scored by user preferences
class _RecommendedSection extends StatelessWidget {
  const _RecommendedSection();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // No user logged in – show generic recommendations
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        sliver: StreamBuilder<List<HouseModel>>(
          stream: HouseService().getHousesForRecommendationsStream(limit: 5),
          builder: (context, snapshot) {
            return _buildRecommendationsList(context, snapshot);
          },
        ),
      );
    }

    // Logged in – fetch preferences and score houses
    return FutureBuilder<Preferences>(
      future: PreferencesService().getPreferences(user.uid),
      builder: (context, prefSnapshot) {
        if (prefSnapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Recommended',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final preferences = prefSnapshot.data ??
            Preferences(
              preferredAreas: [],
              minPrice: 0.0,
              maxPrice: 1000000.0,
              propertyType: 'Room',
            );

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: StreamBuilder<List<HouseModel>>(
            stream: HouseService().getRecommendedHousesStream(
              preferences: preferences,
              limit: 5,
            ),
            builder: (context, snapshot) {
              return _buildRecommendationsList(context, snapshot);
            },
          ),
        );
      },
    );
  }

  Widget _buildRecommendationsList(
      BuildContext context, AsyncSnapshot<List<HouseModel>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: HouseCardSkeleton(),
            ),
            childCount: 3,
          ),
        ),
      );
    }
    final houses = snapshot.data ?? [];
    if (houses.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.explore_off_rounded,
                  size: 48,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'No recommendations yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Set your preferences to get personalized suggestions',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Section header
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recommended',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HouseListScreen(),
                          ),
                        );
                      },
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                HouseCard(
                  house: houses[0],
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HouseDetailScreen(house: houses[0]),
                      ),
                    );
                  },
                ),
              ],
            );
          }
          final house = houses[index];
          return Padding(
            padding: const EdgeInsets.only(top: 12),
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
        childCount: houses.length,
      ),
    );
  }
}

/// Section showing houses sorted by distance from user's current location
class _HousesNearMeSection extends StatefulWidget {
  const _HousesNearMeSection();

  @override
  State<_HousesNearMeSection> createState() => _HousesNearMeSectionState();
}

class _HousesNearMeSectionState extends State<_HousesNearMeSection> {
  Position? _currentPosition;
  bool _isLocating = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled';
          _isLocating = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permissions are denied';
            _isLocating = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permissions are permanently denied';
          _isLocating = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _isLocating = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Could not determine location';
        _isLocating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocating) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              const Text(
                'Houses Near Me',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_locationError != null || _currentPosition == null) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: StreamBuilder<List<HouseModel>>(
        stream: HouseService().getHousesNearMeStream(
          userLat: lat,
          userLng: lng,
          maxRadiusKm: 50.0,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: HouseCardSkeleton(),
                  ),
                  childCount: 3,
                ),
              ),
            );
          }
          final houses = snapshot.data ?? [];
          if (houses.isEmpty) {
            return SliverToBoxAdapter(child: SizedBox.shrink());
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Houses Near Me',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MapAndListScreen(),
                                ),
                              );
                            },
                            child: const Text('View map'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      HouseCard(
                        house: houses[0],
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  HouseDetailScreen(house: houses[0]),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                }
                final house = houses[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
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
              childCount: houses.length,
            ),
          );
        },
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionItem(this.icon, this.label, this.onTap);
}

class _ActionCard extends StatelessWidget {
  final _ActionItem item;

  const _ActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                size: 26,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
