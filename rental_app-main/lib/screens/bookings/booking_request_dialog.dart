import 'package:flutter/material.dart';
import 'package:zanzrental/services/booking_service.dart';
import 'package:zanzrental/services/auth_service.dart';
import 'package:zanzrental/constants/app_colors.dart';

class BookingRequestDialog extends StatefulWidget {
  final String houseId;
  final String houseTitle;
  final String houseImageUrl;
  final String houseLocation;
  final String landlordId;
  final String verificationStatus;
  final int minRentalMonths;
  final double pricePerMonth;

  const BookingRequestDialog({
    Key? key,
    required this.houseId,
    required this.houseTitle,
    required this.houseImageUrl,
    required this.houseLocation,
    required this.landlordId,
    required this.verificationStatus,
    this.minRentalMonths = 1,
    required this.pricePerMonth,
  }) : super(key: key);

  @override
  State<BookingRequestDialog> createState() => _BookingRequestDialogState();
}

class _BookingRequestDialogState extends State<BookingRequestDialog> {
  final BookingService _bookingService = BookingService();
  DateTime? _selectedMoveInDate;
  int _settlements = 1;
  bool _isLoading = false;

  int get _totalMonths => _settlements * widget.minRentalMonths;
  double get _totalPrice => _totalMonths * widget.pricePerMonth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVerificationBanner(),
                  const SizedBox(height: 16),
                  _buildDatePicker(),
                  const SizedBox(height: 16),
                  _buildSettlementPicker(),
                  const SizedBox(height: 16),
                  _buildPriceSummary(),
                  const SizedBox(height: 16),
                  _buildDisclaimer(),
                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header image ─────────────────────────────────────────────────
  Widget _buildHeader() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: widget.houseImageUrl.isNotEmpty
              ? Image.network(
                  widget.houseImageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(),
                )
              : _imagePlaceholder(),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 14,
          left: 16,
          right: 48,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.houseTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 13, color: Colors.white70),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      widget.houseLocation,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() => Container(
        height: 160,
        width: double.infinity,
        color: Colors.grey[200],
        child: Icon(Icons.house_rounded, size: 48, color: Colors.grey[400]),
      );

  // ── Verification banner ───────────────────────────────────────────
  Widget _buildVerificationBanner() {
    final cfg = _verificationConfig();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cfg.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cfg.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(cfg.icon, size: 18, color: cfg.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cfg.label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cfg.color),
            ),
          ),
        ],
      ),
    );
  }

  // ── Move-in date picker ───────────────────────────────────────────
  Widget _buildDatePicker() {
    return _PickerTile(
      icon: Icons.calendar_month_rounded,
      label: 'Move-in Date',
      value: _selectedMoveInDate == null
          ? 'Select a date'
          : _formatDate(_selectedMoveInDate!),
      hasValue: _selectedMoveInDate != null,
      onTap: _selectMoveInDate,
    );
  }

  // ── Settlement multiplier picker ──────────────────────────────────
  Widget _buildSettlementPicker() {
    final period = widget.minRentalMonths;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.repeat_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Number of Settlements',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '$_settlements × $period month${period == 1 ? '' : 's'} = $_totalMonths month${_totalMonths == 1 ? '' : 's'} total',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stepper row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DialogStepperBtn(
                icon: Icons.remove_rounded,
                enabled: _settlements > 1,
                onTap: () => setState(() => _settlements--),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Text(
                      '$_settlements',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'settlement(s)',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _DialogStepperBtn(
                icon: Icons.add_rounded,
                enabled: _settlements < 12,
                onTap: () => setState(() => _settlements++),
              ),
            ],
          ),
          if (period > 1) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Settlement period set by owner: $period months',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Price breakdown ───────────────────────────────────────────────
  Widget _buildPriceSummary() {
    String fmt(double v) {
      if (v >= 1000000) return 'TSh ${(v / 1000000).toStringAsFixed(2)}M';
      if (v >= 1000) return 'TSh ${(v / 1000).toStringAsFixed(0)}K';
      return 'TSh ${v.toStringAsFixed(0)}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price Breakdown',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          _PriceRow(
            label: 'Monthly rent',
            value: fmt(widget.pricePerMonth),
          ),
          const SizedBox(height: 6),
          _PriceRow(
            label: 'Duration',
            value:
                '$_totalMonths month${_totalMonths == 1 ? '' : 's'} ($_settlements × ${widget.minRentalMonths} mo.)',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                fmt(_totalPrice),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Disclaimer ────────────────────────────────────────────────────
  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16,
              color: AppColors.textSecondary.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Please verify the property in person before signing any agreements or making payments.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit button ─────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
        ),
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
                'Send Booking Request · ${_fmtShort(_totalPrice)}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────
  Future<void> _selectMoveInDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedMoveInDate = picked);
  }

  Future<void> _submit() async {
    if (_selectedMoveInDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a move-in date'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final storedUser = await AuthService().getStoredUser();
      if (storedUser == null) throw Exception('No user signed in');
      final response = await _bookingService.createBooking(
        propertyId: widget.houseId,
        startDate: _selectedMoveInDate!,
        endDate:
            _selectedMoveInDate!.add(Duration(days: _totalMonths * 30)),
        durationMonths: _totalMonths,
        houseTitle: widget.houseTitle,
        houseImageUrl: widget.houseImageUrl,
        houseLocation: widget.houseLocation,
        landlordId: widget.landlordId,
        tenantName: storedUser.name,
        tenantEmail: storedUser.email,
      );
      if (!mounted) return;
      if (!response.success) throw Exception(response.message);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking request sent!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send booking request: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────
  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _fmtShort(double v) {
    if (v >= 1000000) return 'TSh ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'TSh ${(v / 1000).toStringAsFixed(0)}K';
    return 'TSh ${v.toStringAsFixed(0)}';
  }

  _VerificationConfig _verificationConfig() {
    switch (widget.verificationStatus) {
      case 'verified':
        return const _VerificationConfig(
          color: Colors.green,
          icon: Icons.verified_rounded,
          label: 'Verified by Sheha',
        );
      case 'pending':
        return const _VerificationConfig(
          color: Colors.orange,
          icon: Icons.access_time_rounded,
          label: 'Verification Pending',
        );
      case 'rejected':
        return const _VerificationConfig(
          color: Colors.red,
          icon: Icons.cancel_rounded,
          label: 'Verification Unsuccessful',
        );
      default:
        return const _VerificationConfig(
          color: AppColors.textSecondary,
          icon: Icons.help_outline_rounded,
          label: 'Not Verified',
        );
    }
  }
}

// ─── Stepper button ───────────────────────────────────────────────────────────
class _DialogStepperBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _DialogStepperBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.1)
              : const Color(0xFFF0F0F0),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─── Price row ────────────────────────────────────────────────────────────────
class _PriceRow extends StatelessWidget {
  final String label;
  final String value;

  const _PriceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

// ─── Picker tile ──────────────────────────────────────────────────────────────
class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool hasValue;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.hasValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasValue
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: hasValue
                    ? AppColors.primary
                    : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasValue
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Verification config ──────────────────────────────────────────────────────
class _VerificationConfig {
  final Color color;
  final IconData icon;
  final String label;

  const _VerificationConfig({
    required this.color,
    required this.icon,
    required this.label,
  });
}
