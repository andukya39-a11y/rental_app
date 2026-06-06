import 'package:flutter/material.dart';
import 'package:rental_app/models/house_model.dart';
import 'package:rental_app/services/house_service.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({Key? key}) : super(key: key);

  @override
  State<AdminVerificationScreen> createState() => _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  final HouseService _houseService = HouseService();
  bool _isLoading = true;
  List<HouseModel> _unverifiedHouses = [];
  List<HouseModel> _verifiedHouses = [];

  @override
  void initState() {
    super.initState();
    _loadHouses();
  }

  Future<void> _loadHouses() async {
    setState(() => _isLoading = true);
    try {
      final allHouses = await _houseService.getHouses();
      setState(() {
        _unverifiedHouses = allHouses.where((house) => !house.isVerified).toList();
        _verifiedHouses = allHouses.where((house) => house.isVerified).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading houses: $e')),
      );
    }
  }

  Future<void> _verifyHouse(HouseModel house, bool verify) async {
    try {
      await _houseService.verifyHouse(house.id, verify);
      await _loadHouses(); // Reload to update lists
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            house.isVerified ? 'House verified successfully!' : 'House unverified successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying house: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('House Verification'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHouses,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Unverified Houses'),
                      Tab(text: 'Verified Houses'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildHouseList(_unverifiedHouses, false),
                        _buildHouseList(_verifiedHouses, true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHouseList(List<HouseModel> houses, bool showVerifyButtons) {
    if (houses.isEmpty) {
      return Center(
        child: Text(
          showVerifyButtons ? 'No verified houses yet.' : 'No unverified houses.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: houses.length,
      itemBuilder: (context, index) {
        final house = houses[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: house.imageUrl != null && house.imageUrl!.isNotEmpty
                ? Image.network(
                    house.imageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  )
                : const Icon(
                    Icons.house,
                    size: 40,
                    color: Colors.grey,
                  ),
            title: Text(house.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('\$${house.price.toStringAsFixed(2)}/month'),
                Text('${house.location} • ${house.bedrooms}BR/${house.bathrooms}BA'),
                if (!showVerifyButtons && house.isVerified)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: showVerifyButtons
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        onPressed: () => _verifyHouse(house, true),
                        tooltip: 'Verify House',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.red,
                        ),
                        onPressed: () => _verifyHouse(house, false),
                        tooltip: 'Unverify House',
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}