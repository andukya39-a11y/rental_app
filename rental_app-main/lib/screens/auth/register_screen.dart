import 'package:flutter/material.dart';
import 'package:zanzrental/constants/app_colors.dart';
import 'package:zanzrental/services/auth_service.dart';
import 'package:zanzrental/utils/role_router.dart';
import 'package:zanzrental/widgets/location_search_field.dart';

// ── Steps:
//  0  Role          — who are you?
//  1  Contact       — email + phone
//  2  Personal      — name + national ID (+ shehia details if Sheha)
//  3  Password      — password + confirm

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  static const _totalSteps = 4;

  // ── Collected data ──────────────────────────────────────────────
  String _role = 'Tenant';
  String _email = '';
  String _phone = '';
  String _name = '';
  String _nationalId = '';
  String _shehia = '';
  String _shehiaFullAddress = '';
  double? _shehiaLat;
  double? _shehiaLng;
  String _shehaId = '';
  String _password = '';

  bool _isLoading = false;
  String? _error;

  final _authService = AuthService();

  void _next() {
    if (_step < _totalSteps - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() { _step++; _error = null; });
    }
  }

  void _back() {
    if (_step > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() { _step--; _error = null; });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await _authService.register(
        _name.trim(),
        _email.trim(),
        _phone.trim(),
        _password,
        role: _role,
        nationalId: _nationalId.trim().isEmpty ? null : _nationalId.trim(),
        shehia: _shehia.trim().isEmpty ? null : _shehia.trim(),
        shehiaFullAddress: _shehiaFullAddress.trim().isEmpty ? null : _shehiaFullAddress.trim(),
        shehiaLat: _shehiaLat,
        shehiaLng: _shehiaLng,
        shehaId: _shehaId.trim().isEmpty ? null : _shehaId.trim(),
      );
      if (!mounted) return;
      if (res.success) {
        final user = await _authService.getStoredUser();
        if (!mounted) return;
        if (user != null) RoleRouter.navigateHome(context, user);
      } else {
        setState(() => _error = res.message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildStepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepRole(
                    selected: _role,
                    onSelect: (r) { setState(() => _role = r); _next(); },
                  ),
                  _StepContact(
                    initialEmail: _email,
                    initialPhone: _phone,
                    onNext: (email, phone) {
                      setState(() { _email = email; _phone = phone; });
                      _next();
                    },
                    onBack: _back,
                    error: _step == 1 ? _error : null,
                  ),
                  _StepPersonal(
                    role: _role,
                    initialName: _name,
                    initialNationalId: _nationalId,
                    initialShehia: _shehia,
                    initialShehaId: _shehaId,
                    onNext: (name, nationalId, shehia, fullAddress, lat, lng, shehaId) {
                      setState(() {
                        _name = name;
                        _nationalId = nationalId;
                        _shehia = shehia;
                        _shehiaFullAddress = fullAddress;
                        _shehiaLat = lat;
                        _shehiaLng = lng;
                        _shehaId = shehaId;
                      });
                      _next();
                    },
                    onBack: _back,
                    error: _step == 2 ? _error : null,
                  ),
                  _StepPassword(
                    isLoading: _isLoading,
                    error: _step == 3 ? _error : null,
                    onSubmit: (password) {
                      setState(() => _password = password);
                      _submit();
                    },
                    onBack: _back,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _back,
          ),
          const Spacer(),
          Text(
            'Step ${_step + 1} of $_totalSteps',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        children: List.generate(_totalSteps * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2,
                color: (i ~/ 2) < _step
                    ? AppColors.primary
                    : AppColors.border,
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final isDone = stepIdx < _step;
          final isCurrent = stepIdx == _step;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.primary
                  : isCurrent
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.border.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: isCurrent || isDone ? AppColors.primary : AppColors.border,
                width: 2,
              ),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : Text(
                      '${stepIdx + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Step 0 — Role Selection ────────────────────────────────────────────────────

class _StepRole extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _StepRole({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Who are you?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose the role that best describes you.',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          _RoleCard(
            role: 'Tenant',
            icon: Icons.search_rounded,
            title: 'Tenant',
            subtitle: "I'm looking for a place to rent",
            selected: selected == 'Tenant',
            onTap: () => onSelect('Tenant'),
          ),
          const SizedBox(height: 14),
          _RoleCard(
            role: 'Owner',
            icon: Icons.home_rounded,
            title: 'Property Owner',
            subtitle: 'I own properties and want to list them',
            selected: selected == 'Owner',
            onTap: () => onSelect('Owner'),
          ),
          const SizedBox(height: 14),
          _RoleCard(
            role: 'Sheha',
            icon: Icons.verified_user_rounded,
            title: 'Sheha',
            subtitle: 'I am a local area administrator (Sheha)',
            selected: selected == 'Sheha',
            onTap: () => onSelect('Sheha'),
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text(
              'Tap a role to continue',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String role;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: 24,
                  color: selected ? AppColors.primary : AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── Step 1 — Contact ───────────────────────────────────────────────────────────

class _StepContact extends StatefulWidget {
  final String initialEmail;
  final String initialPhone;
  final void Function(String email, String phone) onNext;
  final VoidCallback onBack;
  final String? error;

  const _StepContact({
    required this.initialEmail,
    required this.initialPhone,
    required this.onNext,
    required this.onBack,
    this.error,
  });

  @override
  State<_StepContact> createState() => _StepContactState();
}

class _StepContactState extends State<_StepContact> {
  final _form = GlobalKey<FormState>();
  late final _emailCtrl = TextEditingController(text: widget.initialEmail);
  late final _phoneCtrl = TextEditingController(text: widget.initialPhone);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_form.currentState!.validate()) {
      widget.onNext(_emailCtrl.text.trim(), _phoneCtrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact details',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'We\'ll use these to reach you.',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(widget.error!),
            ],
            const SizedBox(height: 28),
            const _Label('Email address'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.email_outlined,
                    size: 20, color: AppColors.textSecondary),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v.trim())) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            const _Label('Phone number'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _next(),
              decoration: const InputDecoration(
                hintText: '+255 712 345 678',
                prefixIcon: Icon(Icons.phone_outlined,
                    size: 20, color: AppColors.textSecondary),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone number is required';
                return null;
              },
            ),
            const SizedBox(height: 36),
            _NextButton(onPressed: _next),
          ],
        ),
      ),
    );
  }
}

// ── Step 2 — Personal Info ─────────────────────────────────────────────────────

class _StepPersonal extends StatefulWidget {
  final String role;
  final String initialName;
  final String initialNationalId;
  final String initialShehia;
  final String initialShehaId;
  final void Function(
    String name,
    String nationalId,
    String shehia,
    String shehiaFullAddress,
    double? shehiaLat,
    double? shehiaLng,
    String shehaId,
  ) onNext;
  final VoidCallback onBack;
  final String? error;

  const _StepPersonal({
    required this.role,
    required this.initialName,
    required this.initialNationalId,
    required this.initialShehia,
    required this.initialShehaId,
    required this.onNext,
    required this.onBack,
    this.error,
  });

  @override
  State<_StepPersonal> createState() => _StepPersonalState();
}

class _StepPersonalState extends State<_StepPersonal> {
  final _form = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.initialName);
  late final _nationalIdCtrl = TextEditingController(text: widget.initialNationalId);
  late final _shehaIdCtrl = TextEditingController(text: widget.initialShehaId);

  // Location selected via Google Places
  LocationSearchResult? _shehiaResult;
  bool _shehiaTouched = false;

  bool get _isSheha => widget.role == 'Sheha';

  @override
  void initState() {
    super.initState();
    // Restore previously entered shehia name if user goes back
    if (widget.initialShehia.isNotEmpty) {
      _shehiaResult = LocationSearchResult(
        name: widget.initialShehia,
        fullAddress: widget.initialShehia,
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nationalIdCtrl.dispose();
    _shehaIdCtrl.dispose();
    super.dispose();
  }

  void _next() {
    setState(() => _shehiaTouched = true);
    if (!_form.currentState!.validate()) return;
    // Require a location with a non-empty name for Sheha
    if (_isSheha &&
        (_shehiaResult == null || _shehiaResult!.name.trim().isEmpty)) {
      return;
    }
    final shehiaName = _shehiaResult?.name.trim() ?? '';
    final shehiaFull = _shehiaResult?.fullAddress.trim().isNotEmpty == true
        ? _shehiaResult!.fullAddress.trim()
        : shehiaName; // always guarantee a non-empty fullAddress
    widget.onNext(
      _nameCtrl.text.trim(),
      _nationalIdCtrl.text.trim(),
      shehiaName,
      shehiaFull,
      _shehiaResult?.lat,
      _shehiaResult?.lng,
      _shehaIdCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal details',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tell us a bit about yourself.',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(widget.error!),
            ],
            const SizedBox(height: 28),
            const _Label('Full name'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Ali Hassan',
                prefixIcon: Icon(Icons.person_outline_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
            ),
            const SizedBox(height: 20),
            const _Label('National ID (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nationalIdCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'e.g. 19830101-12345-00001-7',
                prefixIcon: Icon(Icons.badge_outlined,
                    size: 20, color: AppColors.textSecondary),
              ),
            ),
            if (_isSheha) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded,
                        size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sheha details are required for verification and will be reviewed by an administrator.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.primary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _Label('Shehia area'),
              const SizedBox(height: 8),
              // ── Google Places location picker ──────────────────
              LocationSearchField(
                value: _shehiaResult?.name,
                hint: 'Search your shehia area on map…',
                errorText: (_shehiaTouched && _shehiaResult == null)
                    ? 'Please select your shehia area'
                    : null,
                onSelected: (result) {
                  setState(() {
                    _shehiaResult = result;
                    _shehiaTouched = true;
                  });
                },
              ),
              // Show full address once selected
              if (_shehiaResult != null &&
                  _shehiaResult!.fullAddress.isNotEmpty &&
                  _shehiaResult!.fullAddress != _shehiaResult!.name) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    _shehiaResult!.fullAddress,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const _Label('Sheha badge / registration number (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _shehaIdCtrl,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _next(),
                decoration: const InputDecoration(
                  hintText: 'e.g. SHE-2024-0042',
                  prefixIcon: Icon(Icons.numbers_rounded,
                      size: 20, color: AppColors.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 36),
            _NextButton(onPressed: _next),
          ],
        ),
      ),
    );
  }
}

// ── Step 3 — Password ──────────────────────────────────────────────────────────

class _StepPassword extends StatefulWidget {
  final bool isLoading;
  final String? error;
  final ValueChanged<String> onSubmit;
  final VoidCallback onBack;

  const _StepPassword({
    required this.isLoading,
    required this.onSubmit,
    required this.onBack,
    this.error,
  });

  @override
  State<_StepPassword> createState() => _StepPasswordState();
}

class _StepPasswordState extends State<_StepPassword> {
  final _form = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) widget.onSubmit(_passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set your password',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a strong password to protect your account.',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(widget.error!),
            ],
            const SizedBox(height: 28),
            const _Label('Password'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'Minimum 8 characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    size: 20, color: AppColors.textSecondary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 8) return 'Must be at least 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 20),
            const _Label('Confirm password'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Re-enter your password',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    size: 20, color: AppColors.textSecondary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm your password';
                if (v != _passCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: widget.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.5),
                ),
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Create account',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );
}

class _NextButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _NextButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Continue',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red[700], size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: Colors.red[700], fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
