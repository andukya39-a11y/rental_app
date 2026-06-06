import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rental_app/services/booking_service.dart';
import 'package:rental_app/constants/app_colors.dart';

class BookingRequestDialog extends StatefulWidget {
  final String houseId;
  final String houseTitle;
  final String houseImageUrl;
  final String houseLocation;
  final String landlordId;
  final String verificationStatus; // Added verification status

  const BookingRequestDialog({
    Key? key,
    required this.houseId,
    required this.houseTitle,
    required this.houseImageUrl,
    required this.houseLocation,
    required this.landlordId,
    required this.verificationStatus, // required
  }) : super(key: key);

  @override
  State<BookingRequestDialog> createState() => _BookingRequestDialogState();
}

class _BookingRequestDialogState extends State<BookingRequestDialog> {
  final BookingService _bookingService = BookingService();
  DateTime? _selectedMoveInDate;
  int _selectedRentalDuration = 1; // default 1 month
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Request Booking for ${widget.houseTitle}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // House image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.houseImageUrl.isNotEmpty
                  ? Image.network(
                      widget.houseImageUrl,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 100,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.house, size: 40, color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.houseLocation,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Verification status info card
            _buildVerificationInfo(),
            const SizedBox(height: 12),
            // Disclaimer
            _buildDisclaimer(),
            const SizedBox(height: 24),
            // Move-in date picker
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _selectedMoveInDate == null
                    ? 'Select Move-in Date'
                    : 'Move-in Date: ${_selectedMoveInDate!.toLocal().toString().split(' ')[0]}',
              ),
              onTap: _selectMoveInDate,
            ),
            const Divider(),
            // Rental duration picker
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                'Rental Duration: $_selectedRentalDuration month${_selectedRentalDuration > 1 ? 's' : ''}',
              ),
              onTap: _selectRentalDuration,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                  ),
                )
              : const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  if (_selectedMoveInDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a move-in date')),
                    );
                    return;
                  }
                  setState(() => _isLoading = true);
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      throw Exception('No user signed in');
                    }
                    await _bookingService.createBookingRequest(
                      houseId: widget.houseId,
                      houseTitle: widget.houseTitle,
                      houseImageUrl: widget.houseImageUrl,
                      houseLocation: widget.houseLocation,
                      tenantId: user.uid,
                      tenantName: user.displayName ?? 'No Name',
                      tenantEmail: user.email ?? 'No Email',
                      landlordId: widget.landlordId,
                      moveInDate: _selectedMoveInDate!,
                      rentalDurationMonths: _selectedRentalDuration,
                      verificationStatus: widget.verificationStatus, // Add verification status
                    );
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Booking request sent!')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to send booking request: $e')),
                    );
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send Request'),
        ),
      ],
    );
  }

  Widget _buildVerificationInfo() {
    Color backgroundColor;
    String statusText;
    Color textColor;

    switch (widget.verificationStatus) {
      case 'verified':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        statusText = 'Verified by Sheha';
        textColor = Colors.green;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        statusText = 'Verification Pending';
        textColor = Colors.orange;
        break;
      case 'rejected':
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        statusText = 'Verification Unsuccessful';
        textColor = Colors.red;
        break;
      case 'not_verified':
      default:
        backgroundColor = Colors.grey.withValues(alpha: 0.1);
        statusText = 'Not Verified';
        textColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: textColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Verification status is provided for transparency. Please conduct your own due diligence before making payments or signing agreements.',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary.withValues(alpha: 0.8),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _selectMoveInDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedMoveInDate) {
      setState(() {
        _selectedMoveInDate = picked;
      });
    }
  }

  Future<void> _selectRentalDuration() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Rental Duration'),
        content: SingleChildScrollView(
          child: ListBody(
            children: List.generate(12, (index) {
              final months = index + 1;
              return ListTile(
                title: Text('$months month${months > 1 ? 's' : ''}'),
                onTap: () {
                  setState(() {
                    _selectedRentalDuration = months;
                  });
                  Navigator.of(context).pop();
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}