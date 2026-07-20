import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';
import 'api_service.dart';

class BookingService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('bookings');

  BookingModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    data['id'] = doc.id;
    return BookingModel.fromJson(data);
  }

  // ── Create booking ─────────────────────────────────────────────

  Future<ApiResponse> createBooking({
    required String propertyId,
    required DateTime startDate,
    required DateTime endDate,
    required int durationMonths,
    String? notes,
    String? houseTitle,
    String? houseLocation,
    String? houseImageUrl,
    String? landlordId,
    String? tenantName,
    String? tenantEmail,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return ApiResponse.error('Not logged in.');

      final ref = await _col.add({
        'houseId': propertyId,
        'houseTitle': houseTitle ?? '',
        'houseImageUrl': houseImageUrl ?? '',
        'houseLocation': houseLocation ?? '',
        'tenantId': uid,
        'tenantName': tenantName ?? '',
        'tenantEmail': tenantEmail ?? '',
        'landlordId': landlordId ?? '',
        'moveInDate': Timestamp.fromDate(startDate),
        'moveOutDate': Timestamp.fromDate(endDate),
        'rentalDurationMonths': durationMonths,
        'status': 'pending',
        'message': notes ?? '',
        'verificationStatus': 'not_verified',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return ApiResponse.ok(
        data: {'id': ref.id},
        message: 'Booking request submitted.',
      );
    } catch (e) {
      return ApiResponse.error('Failed to create booking: $e');
    }
  }

  // ── Get user's bookings (tenant) ───────────────────────────────

  Future<ApiResponse> getUserBookings({int page = 1}) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return ApiResponse.ok(data: []);

      final snap = await _col
          .where('tenantId', isEqualTo: uid)
          .get();

      final bookings = snap.docs.map(_fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ApiResponse.ok(data: bookings);
    } catch (e) {
      return ApiResponse.error('Failed to load bookings: $e');
    }
  }

  // ── Check if property has an active confirmed booking ─────────
  Future<bool> isPropertyBooked(String houseId) async {
    try {
      final snap = await _col
          .where('houseId', isEqualTo: houseId)
          .where('status', isEqualTo: 'confirmed')
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<BookingModel?> getConfirmedBookingForProperty(String houseId) async {
    try {
      final snap = await _col
          .where('houseId', isEqualTo: houseId)
          .where('status', isEqualTo: 'confirmed')
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return _fromDoc(snap.docs.first);
    } catch (_) {
      return null;
    }
  }

  // ── Get owner's bookings ───────────────────────────────────────

  Future<ApiResponse> getOwnerBookings({int page = 1}) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return ApiResponse.ok(data: []);

      final snap = await _col
          .where('landlordId', isEqualTo: uid)
          .get();

      final bookings = snap.docs.map(_fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ApiResponse.ok(data: bookings);
    } catch (e) {
      return ApiResponse.error('Failed to load owner bookings: $e');
    }
  }

  // ── Streams for real-time updates ──────────────────────────────

  Stream<List<BookingModel>> getUserBookingsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _col
        .where('tenantId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(_fromDoc).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<List<BookingModel>> getOwnerBookingsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _col
        .where('landlordId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(_fromDoc).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // ── Get single booking ─────────────────────────────────────────

  Future<ApiResponse> getBooking(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) return ApiResponse.error('Booking not found.');
      return ApiResponse.ok(data: _fromDoc(doc));
    } catch (e) {
      return ApiResponse.error('Failed to load booking: $e');
    }
  }

  // ── Cancel booking ─────────────────────────────────────────────

  Future<ApiResponse> cancelBooking(String id) async {
    try {
      await _col.doc(id).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ApiResponse.ok(message: 'Booking cancelled.');
    } catch (e) {
      return ApiResponse.error('Failed to cancel booking: $e');
    }
  }

  // ── Confirm booking (owner) ────────────────────────────────────

  Future<ApiResponse> confirmBooking(String id) async {
    try {
      await _col.doc(id).update({
        'status': 'confirmed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ApiResponse.ok(message: 'Booking confirmed.');
    } catch (e) {
      return ApiResponse.error('Failed to confirm booking: $e');
    }
  }

  // ── Reject booking (owner) ─────────────────────────────────────

  Future<ApiResponse> rejectBooking(String id) async {
    try {
      await _col.doc(id).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ApiResponse.ok(message: 'Booking rejected.');
    } catch (e) {
      return ApiResponse.error('Failed to reject booking: $e');
    }
  }

  // ── Payment (stub — integrate real payment gateway separately) ─

  Future<ApiResponse> initiatePayment({
    required String bookingId,
    required String paymentMethod,
    required double amount,
  }) async {
    try {
      await _db.collection('payments').add({
        'bookingId': bookingId,
        'paymentMethod': paymentMethod,
        'amount': amount,
        'status': 'pending',
        'createdBy': _auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ApiResponse.ok(message: 'Payment initiated.');
    } catch (e) {
      return ApiResponse.error('Failed to initiate payment: $e');
    }
  }

  Future<ApiResponse> getPaymentHistory({int page = 1}) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return ApiResponse.ok(data: []);
      final snap = await _db
          .collection('payments')
          .where('createdBy', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();
      return ApiResponse.ok(data: snap.docs.map((d) => d.data()).toList());
    } catch (e) {
      return ApiResponse.error('Failed to load payment history: $e');
    }
  }
}
