import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'bookings';

  // Create a booking request
  Future<void> createBookingRequest({
    required String houseId,
    required String houseTitle,
    required String houseImageUrl,
    required String houseLocation,
    required String tenantId,
    required String tenantName,
    required String tenantEmail,
    required String landlordId,
    required DateTime moveInDate,
    required int rentalDurationMonths,
    required String verificationStatus, // Added verification status
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      // Optionally verify that tenantId matches current user
      final booking = BookingModel(
        id: '',
        houseId: houseId,
        houseTitle: houseTitle,
        houseImageUrl: houseImageUrl,
        houseLocation: houseLocation,
        tenantId: tenantId,
        tenantName: tenantName,
        tenantEmail: tenantEmail,
        landlordId: landlordId,
        moveInDate: moveInDate,
        rentalDurationMonths: rentalDurationMonths,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'pending',
        message: null,
        verificationStatus: verificationStatus, // Set verification status
      );

      await _firestore.collection(_collectionName).add(booking.toMap());
    } catch (e) {
      throw Exception('Failed to create booking request: $e');
    }
  }

  // Get booking requests for a landlord (houses they own)
  Stream<List<BookingModel>> getLandlordBookingRequests(String landlordId) {
    return _firestore
        .collection(_collectionName)
        .where('landlordId', isEqualTo: landlordId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromDocument(doc))
            .toList());
  }

  // Get booking requests for a tenant (current user)
  Stream<List<BookingModel>> getTenantBookingRequests(String tenantId) {
    return _firestore
        .collection(_collectionName)
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromDocument(doc))
            .toList());
  }

  // Get a single booking by ID
  Future<BookingModel?> getBookingById(String id) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(id).get();
      if (doc.exists) {
        return BookingModel.fromDocument(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get booking: $e');
    }
  }

  // Update booking status (confirm/reject)
  Future<void> updateBookingStatus(String bookingId, String status,
      {String? message}) async {
    try {
      await _firestore.collection(_collectionName).doc(bookingId).update({
        'status': status,
        'updatedAt': DateTime.now(),
        if (message != null) 'message': message,
      });
    } catch (e) {
      throw Exception('Failed to update booking status: $e');
    }
  }

  // Delete booking (cancel)
  Future<void> deleteBooking(String bookingId) async {
    try {
      await _firestore.collection(_collectionName).doc(bookingId).delete();
    } catch (e) {
      throw Exception('Failed to delete booking: $e');
    }
  }
}
