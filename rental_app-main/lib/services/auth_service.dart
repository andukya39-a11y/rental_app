import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // ── Login ──────────────────────────────────────────────────────

  Future<ApiResponse> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return ApiResponse.ok(message: 'Login successful');
    } on FirebaseAuthException catch (e) {
      return ApiResponse.error(_authMessage(e.code));
    } catch (e) {
      return ApiResponse.error('An unexpected error occurred.');
    }
  }

  // ── Register ───────────────────────────────────────────────────

  Future<ApiResponse> register(
    String name,
    String email,
    String phone,
    String password, {
    String? nationalId,
    String role = 'Tenant',
    String? shehia,
    String? shehiaFullAddress,
    double? shehiaLat,
    double? shehiaLng,
    String? shehaId,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;

      await _db.collection('users').doc(uid).set({
        'id': uid,
        'name': name.trim(),
        'email': email.trim(),
        'phoneNumber': phone.trim(),
        if (nationalId != null && nationalId.isNotEmpty)
          'nationalId': nationalId.trim(),
        'roleName': role,
        if (role == 'Sheha') ...{
          // Always save shehia name; it is required for Sheha accounts
          'shehia': shehia?.trim() ?? '',
          // Save full address; fall back to the area name so the field is never null
          'shehiaFullAddress': (shehiaFullAddress?.trim().isNotEmpty == true)
              ? shehiaFullAddress!.trim()
              : (shehia?.trim() ?? ''),
          if (shehiaLat != null) 'shehiaLat': shehiaLat,
          if (shehiaLng != null) 'shehiaLng': shehiaLng,
          if (shehaId != null && shehaId.isNotEmpty) 'shehaId': shehaId.trim(),
        },
        'isVerified': false,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await cred.user!.updateDisplayName(name.trim());

      return ApiResponse.ok(message: 'Registration successful');
    } on FirebaseAuthException catch (e) {
      return ApiResponse.error(_authMessage(e.code));
    } catch (e) {
      return ApiResponse.error('Registration failed. Please try again.');
    }
  }

  // ── Logout ─────────────────────────────────────────────────────

  Future<void> logout() async {
    await _auth.signOut();
  }

  // ── Forgot Password (sends email reset link) ───────────────────

  Future<ApiResponse> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return ApiResponse.ok(
        message: 'Password reset email sent. Please check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      return ApiResponse.error(_authMessage(e.code));
    } catch (e) {
      return ApiResponse.error('Failed to send reset email.');
    }
  }

  // ── Change Password ────────────────────────────────────────────

  Future<ApiResponse> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return ApiResponse.error('Not logged in.');
      }
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return ApiResponse.ok(message: 'Password updated successfully.');
    } on FirebaseAuthException catch (e) {
      return ApiResponse.error(_authMessage(e.code));
    } catch (e) {
      return ApiResponse.error('Failed to change password.');
    }
  }

  // ── Phone OTP (Firebase Phone Auth) ───────────────────────────

  Future<void> sendPhoneOtp(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
    void Function(PhoneAuthCredential)? onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      verificationCompleted: (cred) async {
        onAutoVerified?.call(cred);
      },
      verificationFailed: (e) {
        onFailed(_phoneMessage(e.code));
      },
      codeSent: (verificationId, _) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<ApiResponse> verifyPhoneOtp(
    String verificationId,
    String smsCode,
  ) async {
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final current = _auth.currentUser;
      if (current != null) {
        await current.linkWithCredential(cred);
        await _db
            .collection('users')
            .doc(current.uid)
            .update({'phoneVerified': true});
      } else {
        await _auth.signInWithCredential(cred);
      }
      return ApiResponse.ok(message: 'Phone verified');
    } on FirebaseAuthException catch (e) {
      return ApiResponse.error(_phoneMessage(e.code));
    } catch (e) {
      return ApiResponse.error('Verification failed. Please try again.');
    }
  }

  String _phoneMessage(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'Incorrect OTP code. Please try again.';
      case 'invalid-verification-id':
        return 'Verification session expired. Please resend the code.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'provider-already-linked':
        return 'This phone number is already linked to your account.';
      case 'credential-already-in-use':
        return 'This phone number is linked to another account.';
      default:
        return 'Phone verification failed. Please try again.';
    }
  }

  // ── Auth state ─────────────────────────────────────────────────

  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Get current user from Firestore ───────────────────────────

  Future<UserModel?> getCurrentUser() async {
    return getStoredUser();
  }

  Future<UserModel?> getStoredUser() async {
    final fireUser = _auth.currentUser;
    if (fireUser == null) return null;
    try {
      final doc = await _db.collection('users').doc(fireUser.uid).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = fireUser.uid;
      data['email'] = fireUser.email ?? data['email'] ?? '';
      return UserModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = uid;
      return UserModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  // ── Update profile in Firestore ───────────────────────────────

  Future<ApiResponse> updateProfile(Map<String, dynamic> fields) async {
    final fireUser = _auth.currentUser;
    if (fireUser == null) return ApiResponse.error('Not logged in.');
    try {
      await _db.collection('users').doc(fireUser.uid).update(fields);
      if (fields['name'] != null) {
        await fireUser.updateDisplayName(fields['name'] as String);
      }
      return ApiResponse.ok(message: 'Profile updated.');
    } catch (e) {
      return ApiResponse.error('Failed to update profile.');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────

  String _authMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
