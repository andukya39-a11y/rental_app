import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zanzrental/constants/app_colors.dart';
import 'package:zanzrental/services/auth_service.dart';
import 'package:zanzrental/utils/role_router.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String purpose; // 'registration' | 'login'

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.purpose,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  final _authService = AuthService();

  bool _isLoading = false;
  bool _isSending = true;
  bool _isResending = false;
  int _resendCooldown = 60;
  String? _error;
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  // ── Send / Resend OTP via Firebase ─────────────────────────────

  Future<void> _sendOtp() async {
    setState(() {
      _isSending = true;
      _error = null;
    });

    await _authService.sendPhoneOtp(
      widget.phoneNumber,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isSending = false;
        });
        _startCooldown();
      },
      onFailed: (error) {
        if (!mounted) return;
        setState(() {
          _isSending = false;
          _error = error;
        });
      },
      onAutoVerified: (cred) async {
        // Android auto-retrieval
        final res = await _authService.verifyPhoneOtp(
          cred.verificationId!,
          cred.smsCode!,
        );
        if (!mounted) return;
        if (res.success) {
          _navigateHome();
        } else {
          setState(() => _error = res.message);
        }
      },
    );
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _tick();
  }

  void _tick() {
    if (!mounted || _resendCooldown <= 0) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _resendCooldown--);
      _tick();
    });
  }

  // ── Verify ─────────────────────────────────────────────────────

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    final code = _otpCode;
    if (code.length < 6) {
      setState(() => _error = 'Please enter all 6 digits.');
      return;
    }
    if (_verificationId == null) {
      setState(() => _error = 'Verification session not ready. Please resend.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      final res = await _authService.verifyPhoneOtp(_verificationId!, code);
      if (!mounted) return;
      if (res.success) {
        _navigateHome();
      } else {
        setState(() => _error = res.message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateHome() async {
    final user = await _authService.getStoredUser();
    if (!mounted) return;
    if (user != null) {
      RoleRouter.navigateHome(context, user);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _isResending) return;
    setState(() { _isResending = true; _error = null; });
    for (final c in _controllers) { c.clear(); }
    _focusNodes.first.requestFocus();
    await _sendOtp();
    if (mounted) setState(() => _isResending = false);
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Verify your number')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _isSending
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text('Sending verification code…',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sms_outlined,
                          size: 36, color: AppColors.primary),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Enter verification code',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We sent a 6-digit code to ${widget.phoneNumber}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Error banner
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: Colors.red[700], size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                    color: Colors.red[700], fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 6-digit input row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children:
                          List.generate(6, (i) => _buildDigitBox(i)),
                    ),
                    const SizedBox(height: 36),

                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Verify',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Resend
                    Center(
                      child: _isResending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : GestureDetector(
                              onTap: _resendCooldown == 0 ? _resend : null,
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 14),
                                  children: [
                                    const TextSpan(
                                      text: "Didn't receive the code? ",
                                      style: TextStyle(
                                          color: AppColors.textSecondary),
                                    ),
                                    TextSpan(
                                      text: _resendCooldown > 0
                                          ? 'Resend in ${_resendCooldown}s'
                                          : 'Resend',
                                      style: TextStyle(
                                        color: _resendCooldown > 0
                                            ? AppColors.textSecondary
                                            : AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                        decoration: _resendCooldown == 0
                                            ? TextDecoration.underline
                                            : TextDecoration.none,
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
      ),
    );
  }

  Widget _buildDigitBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (index == 5 && value.isNotEmpty) _verify();
        },
        onTap: () {
          _controllers[index].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controllers[index].text.length,
          );
        },
      ),
    );
  }
}
