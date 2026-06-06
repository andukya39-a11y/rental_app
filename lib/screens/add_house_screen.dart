import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rental_app/models/house_model.dart';
import 'package:rental_app/services/house_service.dart';
import 'package:rental_app/constants/app_colors.dart';

class AddHouseScreen extends StatefulWidget {
  const AddHouseScreen({Key? key}) : super(key: key);

  @override
  State<AddHouseScreen> createState() => _AddHouseScreenState();
}

class _AddHouseScreenState extends State<AddHouseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  bool _isLoading = false;
  bool _isAvailable = true;
  bool _isVerified = false;
  String? _selectedPropertyType;
  XFile? _imageFile;

  final List<String> _propertyTypes = [
    'Room',
    'Apartment',
    'House',
    'Villa',
    'Studio'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
    }
  }

  Future<void> _removeImage() async {
    setState(() => _imageFile = null);
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final file = File(imageFile.path);
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance
          .ref()
          .child('house_images')
          .child('$fileName.jpg');

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
        if (imageUrl == null && !mounted) return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to add a house')),
        );
        return;
      }

      final house = HouseModel(
        id: '',
        userId: user.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        location: _locationController.text.trim(),
        bedrooms: int.parse(_bedroomsController.text),
        bathrooms: int.parse(_bathroomsController.text),
        isAvailable: _isAvailable,
        imageUrl: imageUrl,
        isVerified: _isVerified,
        propertyType: _selectedPropertyType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await HouseService().addHouse(house);
      if (!mounted) return;

      _formKey.currentState!.reset();
      setState(() {
        _isAvailable = true;
        _isVerified = false;
        _selectedPropertyType = null;
        _imageFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('House added successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding house: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Add New Listing',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSection(),
              const SizedBox(height: 24),
              _buildSectionHeader(
                icon: Icons.edit_note_rounded,
                title: 'Basic Information',
                subtitle: 'Tell us about your property',
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _titleController,
                label: 'Property Title',
                hint: 'e.g. Sunny Studio in Stone Town',
                icon: Icons.title_rounded,
                validator: (v) => v == null || v.isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Describe the property, amenities, and neighborhood...',
                icon: Icons.description_rounded,
                maxLines: 4,
                validator: (v) => v == null || v.isEmpty ? 'Enter a description' : null,
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(
                icon: Icons.attach_money_rounded,
                title: 'Pricing & Location',
                subtitle: 'Set your rental details',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      controller: _priceController,
                      label: 'Price (TSh/mo)',
                      hint: '150000',
                      icon: Icons.payments_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefix: 'TSh ',
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter price';
                        if (double.tryParse(v) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextFormField(
                      controller: _locationController,
                      label: 'Location',
                      hint: 'Stone Town',
                      icon: Icons.location_on_rounded,
                      validator: (v) => v == null || v.isEmpty ? 'Enter location' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPropertyTypeDropdown(),
              const SizedBox(height: 24),
              _buildSectionHeader(
                icon: Icons.bed_rounded,
                title: 'Property Details',
                subtitle: 'Rooms and availability',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextFormField(
                      controller: _bedroomsController,
                      label: 'Bedrooms',
                      hint: '2',
                      icon: Icons.bed_rounded,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (int.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextFormField(
                      controller: _bathroomsController,
                      label: 'Bathrooms',
                      hint: '1',
                      icon: Icons.bathtub_rounded,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (int.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTogglesSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _imageFile != null
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
          width: _imageFile != null ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _imageFile != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(_imageFile!.path),
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    children: [
                      _ImageActionButton(
                        icon: Icons.edit_rounded,
                        color: Colors.white,
                        backgroundColor: Colors.black.withValues(alpha: 0.4),
                        onTap: _pickImage,
                      ),
                      const SizedBox(width: 8),
                      _ImageActionButton(
                        icon: Icons.close_rounded,
                        color: Colors.white,
                        backgroundColor: Colors.red.withValues(alpha: 0.7),
                        onTap: _removeImage,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: const Text(
                      'Tap edit to change photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            )
          : GestureDetector(
              onTap: _pickImage,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_a_photo_rounded,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap to add photo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recommended: 1200x800px',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? prefix,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary.withValues(alpha: 0.6)),
        prefixText: prefix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red[400]!, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red[400]!, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildPropertyTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Property Type',
          prefixIcon: Icon(Icons.category_rounded, size: 20, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        value: _selectedPropertyType,
        items: _propertyTypes
            .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(
                    type,
                    style: const TextStyle(fontSize: 15),
                  ),
                ))
            .toList(),
        onChanged: (value) {
          setState(() => _selectedPropertyType = value);
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a type';
          }
          return null;
        },
        isExpanded: true,
      ),
    );
  }

  Widget _buildTogglesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text(
              'Available for Rent',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _isAvailable ? 'Visible to renters' : 'Hidden from search',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            value: _isAvailable,
            onChanged: (v) => setState(() => _isAvailable = v),
            secondary: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _isAvailable
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.home_rounded,
                size: 20,
                color: _isAvailable ? Colors.green[700] : Colors.grey,
              ),
            ),
            activeColor: AppColors.primary,
          ),
          const Divider(height: 1, indent: 72),
          SwitchListTile(
            title: const Text(
              'Verified Listing',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _isVerified ? 'Marked as verified' : 'Not verified yet',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            value: _isVerified,
            onChanged: (v) => setState(() => _isVerified = v),
            secondary: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _isVerified
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.verified_rounded,
                size: 20,
                color: _isVerified ? AppColors.primary : Colors.grey,
              ),
            ),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Publish Listing',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _ImageActionButton({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
