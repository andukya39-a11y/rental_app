import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zanzrental/services/property_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:zanzrental/constants/app_colors.dart';

const _kMapsApiKey = 'AIzaSyA5D5H-3lTkMIuJM4kTLO_anIExo11GLyA';

// ── Data classes ──────────────────────────────────────────────────────────────

class _PlaceSuggestion {
  final String placeId;
  final String description;
  const _PlaceSuggestion({required this.placeId, required this.description});
}

class _PlaceDetails {
  final String address;
  final double lat;
  final double lng;
  const _PlaceDetails({
    required this.address,
    required this.lat,
    required this.lng,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AddHouseScreen extends StatefulWidget {
  final Map<String, dynamic>? property;
  const AddHouseScreen({Key? key, this.property}) : super(key: key);

  @override
  State<AddHouseScreen> createState() => _AddHouseScreenState();
}

class _AddHouseScreenState extends State<AddHouseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();

  // Location
  String _pickedAddress = '';
  double? _pickedLat;
  double? _pickedLng;
  bool _locationError = false;

  int _minRentalMonths = 1;
  bool _isLoading = false;
  bool _isAvailable = true;
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  XFile? _imageFile;
  String? _existingImageUrl;
  bool _categoryError = false;

  String? _editId;

  final _propertyService = PropertyService();
  List<Map<String, dynamic>> _categories = [];
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    final p = widget.property;
    if (p != null) {
      _editId = p['id']?.toString();
      _titleController.text =
          p['title'] as String? ?? p['property_name'] as String? ?? '';
      _descriptionController.text = p['description'] as String? ?? '';
      _priceController.text = '${p['price'] ?? ''}';
      _bedroomsController.text =
          '${p['bedrooms'] ?? p['number_of_rooms'] ?? ''}';
      _bathroomsController.text = '${p['bathrooms'] ?? 0}';
      _pickedAddress = p['location'] as String? ?? '';
      _pickedLat = (p['latitude'] as num?)?.toDouble();
      _pickedLng = (p['longitude'] as num?)?.toDouble();
      _isAvailable =
          p['isAvailable'] ?? p['availability_status'] == 'available';
      _minRentalMonths =
          int.tryParse((p['minRentalMonths'] ?? 1).toString()) ?? 1;
      _selectedCategoryId =
          p['propertyType']?.toString() ?? p['category_id']?.toString();
      _selectedCategoryName = _selectedCategoryId;
      // Existing image URL (already a full Firebase Storage URL)
      _existingImageUrl =
          p['imageUrl'] as String? ?? p['primary_image'] as String?;
    }
  }

  Future<void> _loadCategories() async {
    try {
      final res = await _propertyService.getCategories();
      if (!mounted) return;
      setState(() {
        _loadingCategories = false;
        if (res.success && res.data != null) {
          final data = res.data;
          List<dynamic>? list;
          if (data is List) {
            list = data;
          } else if (data is Map) {
            final inner = data['data'] ?? data['categories'];
            if (inner is List) list = inner;
          }
          if (list != null) {
            _categories = list.whereType<Map<String, dynamic>>().toList();
            if (_selectedCategoryId != null && _selectedCategoryName == null) {
              final match = _categories.firstWhere(
                (c) => c['id'] == _selectedCategoryId,
                orElse: () => <String, dynamic>{},
              );
              _selectedCategoryName = match['category_name'] as String?;
            }
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    super.dispose();
  }

  // ── Places API ─────────────────────────────────────────────────────────────

  // Returns (suggestions, errorMessage). errorMessage is non-null on API error.
  Future<(List<_PlaceSuggestion>, String?)> _fetchSuggestions(
      String input) async {
    if (input.trim().length < 2) return (<_PlaceSuggestion>[], null);
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': input,
          'key': _kMapsApiKey,
          'language': 'en',
          // Bias toward Zanzibar without hard-restricting to Tanzania,
          // so partial names like "Nungwi" or "Stone Town" still resolve.
          'location': '-6.1650,39.2023',
          'radius': '100000',
        },
      );
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        return (<_PlaceSuggestion>[], 'Server error (${res.statusCode})');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      if (status == 'ZERO_RESULTS') return (<_PlaceSuggestion>[], null);
      if (status != 'OK') {
        final msg = data['error_message'] as String? ?? status;
        return (<_PlaceSuggestion>[], msg);
      }
      final predictions = data['predictions'] as List<dynamic>? ?? [];
      return (
        predictions
            .map((p) => _PlaceSuggestion(
                  placeId: p['place_id'] as String,
                  description: p['description'] as String,
                ))
            .toList(),
        null,
      );
    } catch (e) {
      return (<_PlaceSuggestion>[], 'Network error: $e');
    }
  }

  Future<_PlaceDetails?> _fetchDetails(String placeId) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'fields': 'geometry,formatted_address',
          'key': _kMapsApiKey,
        },
      );
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) return null;
      final loc = result['geometry']['location'] as Map<String, dynamic>;
      return _PlaceDetails(
        address: result['formatted_address'] as String,
        lat: (loc['lat'] as num).toDouble(),
        lng: (loc['lng'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _openLocationSearch() async {
    final result = await showModalBottomSheet<_PlaceDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LocationSearchSheet(
        fetchSuggestions: _fetchSuggestions,
        fetchDetails: _fetchDetails,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _pickedAddress = result.address;
        _pickedLat = result.lat;
        _pickedLng = result.lng;
        _locationError = false;
      });
    }
  }

  // ── Image ──────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = picked);
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submitForm() async {
    bool valid = _formKey.currentState!.validate();
    if (_selectedCategoryId == null) {
      setState(() => _categoryError = true);
      valid = false;
    }
    if (_pickedAddress.isEmpty) {
      setState(() => _locationError = true);
      valid = false;
    }
    if (!valid) return;

    setState(() => _isLoading = true);
    try {
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _pickedAddress,
        'propertyType': _selectedCategoryName ?? _selectedCategoryId,
        'price': double.parse(_priceController.text),
        'bedrooms': int.tryParse(_bedroomsController.text) ?? 1,
        'bathrooms': int.tryParse(_bathroomsController.text) ?? 0,
        'isAvailable': _isAvailable,
        'minRentalMonths': _minRentalMonths,
        if (_pickedLat != null) 'latitude': _pickedLat,
        if (_pickedLng != null) 'longitude': _pickedLng,
      };

      final res = _editId != null
          ? await _propertyService.updateProperty(_editId!, data)
          : await _propertyService.createProperty(data);

      if (!mounted) return;

      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: Colors.red),
        );
        return;
      }

      // Upload image if a new one was selected
      if (_imageFile != null) {
        final propertyId = _editId ?? (res.data as Map?)?['id']?.toString();
        if (propertyId != null) {
          final uploadRes = await _propertyService.uploadPropertyImage(
              propertyId, _imageFile!.path);
          if (!mounted) return;
          if (!uploadRes.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image upload failed: ${uploadRes.message}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editId != null
              ? 'Listing updated successfully!'
              : 'Listing submitted for approval!'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: Text(_editId != null ? 'Edit Listing' : 'Add New Listing')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoSection(),
              const SizedBox(height: 28),

              // ── Basic info ─────────────────────────────────────
              const _SectionLabel(label: 'Basic Information'),
              const SizedBox(height: 14),
              _buildCard(children: [
                _LabeledField(
                  label: 'Property title',
                  child: TextFormField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Sunny Studio in Stone Town',
                      prefixIcon: Icon(Icons.title_rounded,
                          size: 20, color: AppColors.textSecondary),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Title is required' : null,
                  ),
                ),
                const SizedBox(height: 16),
                _LabeledField(
                  label: 'Description',
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText:
                          'Describe the property, amenities, neighborhood...',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 56),
                        child: Icon(Icons.description_rounded,
                            size: 20, color: AppColors.textSecondary),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Description is required'
                        : null,
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              // ── Pricing ────────────────────────────────────────
              const _SectionLabel(label: 'Pricing'),
              const SizedBox(height: 14),
              _buildCard(children: [
                _LabeledField(
                  label: 'Price (TSh / month)',
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: '150,000',
                      prefixIcon: Icon(Icons.payments_rounded,
                          size: 20, color: AppColors.textSecondary),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Price is required';
                      if (double.tryParse(v) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              // ── Rental Duration ────────────────────────────────
              const _SectionLabel(label: 'Minimum Rental Duration'),
              const SizedBox(height: 4),
              const SizedBox(height: 12),
              _buildCard(children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Settlement Period',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          Text(
                            '$_minRentalMonths month${_minRentalMonths == 1 ? '' : 's'} per settlement',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    // Stepper
                    Row(
                      children: [
                        _StepperBtn(
                          icon: Icons.remove_rounded,
                          enabled: _minRentalMonths > 1,
                          onTap: () => setState(
                              () => _minRentalMonths = _minRentalMonths - 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '$_minRentalMonths',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _StepperBtn(
                          icon: Icons.add_rounded,
                          enabled: _minRentalMonths < 24,
                          onTap: () => setState(
                              () => _minRentalMonths = _minRentalMonths + 1),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 15, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Example: if set to $_minRentalMonths month${_minRentalMonths == 1 ? '' : 's'}, a tenant who chooses 2 settlements pays for ${_minRentalMonths * 2} months.',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              // ── Location ───────────────────────────────────────
              const _SectionLabel(label: 'Location'),
              const SizedBox(height: 4),
              const Text(
                'Search and pin your property on the map',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              _buildLocationSection(),

              const SizedBox(height: 24),

              // ── Property type ──────────────────────────────────
              const _SectionLabel(label: 'Property Type'),
              const SizedBox(height: 4),
              const Text(
                'Select the type that best describes your property',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _loadingCategories
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final id = cat['id']?.toString();
                        final name = cat['category_name'] as String? ?? '';
                        final selected = _selectedCategoryId == id;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedCategoryId = id;
                            _selectedCategoryName = name;
                            _categoryError = false;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color:
                                  selected ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
              if (_categoryError) ...[
                const SizedBox(height: 6),
                const Text(
                  'Please select a property category',
                  style: TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ],

              const SizedBox(height: 24),

              // ── Property details ───────────────────────────────
              const _SectionLabel(label: 'Property Details'),
              const SizedBox(height: 14),
              _buildCard(children: [
                Row(
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'Bedrooms',
                        child: TextFormField(
                          controller: _bedroomsController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: '2',
                            prefixIcon: Icon(Icons.bed_rounded,
                                size: 20, color: AppColors.textSecondary),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (int.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LabeledField(
                        label: 'Bathrooms',
                        child: TextFormField(
                          controller: _bathroomsController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            hintText: '1',
                            prefixIcon: Icon(Icons.bathtub_rounded,
                                size: 20, color: AppColors.textSecondary),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (int.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ]),

              const SizedBox(height: 24),

              // ── Status toggles ─────────────────────────────────
              const _SectionLabel(label: 'Status'),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: _ToggleRow(
                  icon: Icons.home_rounded,
                  iconColor: _isAvailable
                      ? Colors.green[700]!
                      : AppColors.textSecondary,
                  iconBg: _isAvailable
                      ? Colors.green.withValues(alpha: 0.1)
                      : AppColors.background,
                  title: 'Available for rent',
                  subtitle: _isAvailable
                      ? 'Visible to renters'
                      : 'Hidden from search',
                  value: _isAvailable,
                  onChanged: (v) => setState(() => _isAvailable = v),
                ),
              ),
            ],
          ),
        ),
      ),
      // ── Sticky publish button ──────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.divider)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _editId != null ? 'Save Changes' : 'Publish Listing',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Location section ───────────────────────────────────────────────────────

  Widget _buildLocationSection() {
    final hasPick = _pickedAddress.isNotEmpty && _pickedLat != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search tap target
        GestureDetector(
          onTap: _openLocationSearch,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _locationError ? AppColors.error : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasPick ? Icons.location_on_rounded : Icons.search_rounded,
                  size: 20,
                  color: hasPick ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasPick
                        ? _pickedAddress
                        : 'Search location or place name...',
                    style: TextStyle(
                      fontSize: 15,
                      color: hasPick
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (hasPick)
                  GestureDetector(
                    onTap: () => setState(() {
                      _pickedAddress = '';
                      _pickedLat = null;
                      _pickedLng = null;
                    }),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textSecondary),
                  )
                else
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        if (_locationError)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 2),
            child: Text(
              'Please select a location',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),

        // Mini map preview after selection
        if (hasPick) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                SizedBox(
                  height: 180,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_pickedLat!, _pickedLng!),
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('picked'),
                        position: LatLng(_pickedLat!, _pickedLng!),
                      ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: _openLocationSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_location_alt_rounded,
                              size: 14, color: AppColors.textPrimary),
                          SizedBox(width: 4),
                          Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Photo section ──────────────────────────────────────────────────────────

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Property Photo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Add a high-quality photo to attract more renters',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _imageFile != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(_imageFile!.path), fit: BoxFit.cover),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.5),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Row(
                          children: [
                            _PhotoBtn(
                              icon: Icons.edit_rounded,
                              onTap: _pickImage,
                            ),
                            const SizedBox(width: 8),
                            _PhotoBtn(
                              icon: Icons.delete_rounded,
                              color: Colors.red,
                              onTap: () => setState(() => _imageFile = null),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : _existingImageUrl != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            _existingImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF0F0F0),
                              child: const Icon(Icons.home_rounded,
                                  size: 40, color: AppColors.border),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: _PhotoBtn(
                              icon: Icons.edit_rounded,
                              onTap: _pickImage,
                            ),
                          ),
                        ],
                      )
                    : GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          color: const Color(0xFFF0F0F0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_a_photo_rounded,
                                  size: 28,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Tap to add a photo',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'JPG or PNG · Recommended 1200×800',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ── Location search bottom sheet ──────────────────────────────────────────────

class _LocationSearchSheet extends StatefulWidget {
  final Future<(List<_PlaceSuggestion>, String?)> Function(String)
      fetchSuggestions;
  final Future<_PlaceDetails?> Function(String) fetchDetails;

  const _LocationSearchSheet({
    required this.fetchSuggestions,
    required this.fetchDetails,
  });

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final _searchController = TextEditingController();
  List<_PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _isLoadingDetails = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String value) async {
    if (value.trim().length < 2) {
      setState(() {
        _suggestions = [];
      });
      return;
    }
    setState(() => _isSearching = true);
    final (results, _) = await widget.fetchSuggestions(value);
    if (mounted)
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
  }

  Future<void> _onSelect(_PlaceSuggestion s) async {
    setState(() => _isLoadingDetails = true);
    final details = await widget.fetchDetails(s.placeId);
    if (!mounted) return;
    if (details != null) {
      Navigator.of(context).pop(details);
    } else {
      setState(() => _isLoadingDetails = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not fetch place details. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Search Location',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded,
                        size: 22, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'e.g. Stone Town, Nungwi Beach...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _suggestions = []);
                          },
                        )
                      : null,
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            // Results
            if (_isLoadingDetails)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 12),
                      Text('Fetching location...',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else if (_isSearching)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2),
                ),
              )
            else if (_suggestions.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.search_rounded,
                            size: 28, color: AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Start typing to search',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Results are filtered to Tanzania',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, i) {
                    final s = _suggestions[i];
                    // Split into main name and sub-address
                    final parts = s.description.split(',');
                    final mainName = parts.first.trim();
                    final subAddress =
                        parts.length > 1 ? parts.skip(1).join(',').trim() : '';
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            size: 18, color: AppColors.primary),
                      ),
                      title: Text(
                        mainName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: subAddress.isNotEmpty
                          ? Text(
                              subAddress,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () => _onSelect(s),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

class _PhotoBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _PhotoBtn({required this.icon, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color ?? AppColors.textPrimary),
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepperBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.border.withValues(alpha: 0.4),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
