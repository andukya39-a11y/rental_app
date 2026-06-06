import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rental_app/services/preferences_service.dart';
import 'package:rental_app/models/preferences_model.dart';
import 'package:rental_app/constants/app_colors.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final PreferencesService _preferencesService = PreferencesService();
  late final String _userId;
  bool _isLoading = true;
  Preferences _preferences = Preferences(
    preferredAreas: [],
    minPrice: 0.0,
    maxPrice: 1000000.0,
    propertyType: 'Room',
  );

  // Controllers for text fields
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  // List of available areas
  final List<String> _availableAreas = [
    'Stone Town',
    'Mbweni',
    'Mpendae',
    'Kiembe Samaki',
    'Fuoni',
  ];

  // Property type options
  final List<String> _propertyTypes = ['Room', 'Apartment', 'House'];

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
        _isLoading = false;
      });
      return;
    }
    _userId = user.uid;
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await _preferencesService.getPreferences(_userId);
      setState(() {
        _preferences = preferences;
        // Update controllers
        _minPriceController.text = _preferences.minPrice.toString();
        _maxPriceController.text = _preferences.maxPrice.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load preferences: $e')),
      );
    }
  }

  Future<void> _savePreferences() async {
    // Validate input
    final minPrice = double.tryParse(_minPriceController.text);
    final maxPrice = double.tryParse(_maxPriceController.text);
    if (minPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid minimum price')),
      );
      return;
    }
    if (maxPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid maximum price')),
      );
      return;
    }
    if (minPrice > maxPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum price cannot be greater than maximum price')),
      );
      return;
    }

    // Update preferences object
    final updatedPreferences = Preferences(
      preferredAreas: _preferences.preferredAreas,
      minPrice: minPrice,
      maxPrice: maxPrice,
      propertyType: _preferences.propertyType,
    );

    try {
      await _preferencesService.savePreferences(_userId, updatedPreferences);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save preferences: $e')),
      );
    }
  }

  void _toggleArea(String area) {
    setState(() {
      if (_preferences.preferredAreas.contains(area)) {
        _preferences.preferredAreas.remove(area);
      } else {
        _preferences.preferredAreas.add(area);
      }
    });
  }

  void _setPropertyType(String type) {
    setState(() {
      _preferences.propertyType = type;
    });
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental Preferences'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : FirebaseAuth.instance.currentUser == null
              ? const Center(
                  child: Text('Please log in to set preferences'),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preferred Areas
                      const Text(
                        'Preferred Areas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _availableAreas.map((area) => FilterChip(
                              label: Text(area),
                              selected: _preferences.preferredAreas.contains(area),
                              onSelected: (selected) {
                                _toggleArea(area);
                              },
                              backgroundColor: Colors.grey[200],
                              selectedColor: AppColors.primary,
                            )).toList(),
                      ),
                      const SizedBox(height: 24),
                      // Budget Range
                      const Text(
                        'Budget Range (per month)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Minimum Price',
                                prefixText: 'TSh ',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _maxPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Maximum Price',
                                prefixText: 'TSh ',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Property Type
                      const Text(
                        'Property Type',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._propertyTypes.map((type) => ListTile(
                            title: Text(type),
                            leading: Radio<String>(
                              value: type,
                              groupValue: _preferences.propertyType,
                              onChanged: (value) {
                                _setPropertyType(value!);
                              },
                            ),
                          )).toList(),
                      const SizedBox(height: 32),
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _savePreferences,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Preferences',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}