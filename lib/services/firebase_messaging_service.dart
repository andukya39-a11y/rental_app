import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rental_app/services/notification_model.dart';
import 'package:rental_app/main.dart';
import 'package:rental_app/screens/my_bookings_screen.dart';
import 'package:rental_app/screens/house_detail_screen.dart';
import 'package:rental_app/services/house_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  FirebaseMessagingService().handleBackgroundMessage(message);
}

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'app_notifications';

  final StreamController<NotificationModel> _notificationController =
      StreamController<NotificationModel>.broadcast();
  Stream<NotificationModel> get onNotification =>
      _notificationController.stream;

  FlutterLocalNotificationsPlugin? _localNotifications;

  Future<void> initialize() async {
    final permission = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (permission.authorizationStatus == AuthorizationStatus.authorized ||
        permission.authorizationStatus == AuthorizationStatus.provisional) {
      final token = await _fcm.getToken();
      await _saveTokenToFirestore(token);

      _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

      _localNotifications = FlutterLocalNotificationsPlugin();
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _localNotifications!.initialize(initSettings);

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage.data);
      }

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleNotificationTap(message.data);
      });
    }
  }

  Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('fcm_tokens').doc(user.uid).set({
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // FCM token storage is non-critical; device may not have Firestore rules configured yet
      debugPrint('Failed to save FCM token: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;

    if (notification != null) {
      await _showLocalNotification(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        payload: data['type'] ?? '',
      );
    }

    if (data['type'] != null) {
      final notif = NotificationModel(
        id: data['id'] ?? '',
        userId: data['userId'] ?? '',
        title: data['title'] ?? '',
        message: data['message'] ?? '',
        type: data['type'] ?? '',
        relatedId: data['relatedId'],
        createdAt: DateTime.now(),
      );
      _notificationController.add(notif);
    }
  }

  @pragma('vm:entry-point')
  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    final data = message.data;
    if (data['type'] != null) {
      final notif = NotificationModel(
        id: data['id'] ?? '',
        userId: data['userId'] ?? '',
        title: data['title'] ?? '',
        message: data['message'] ?? '',
        type: data['type'] ?? '',
        relatedId: data['relatedId'],
        createdAt: DateTime.now(),
      );
      _notificationController.add(notif);
    }
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'rental_channel',
      'Rental Notifications',
      channelDescription: 'Notifications from rental app',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotifications?.show(id, title, body, details, payload: payload);
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    // Handle navigation when notification is tapped using the global navigator key
    final type = data['type'] as String? ?? '';
    final relatedId = data['relatedId'] as String?;
    final context = navigatorKey.currentContext;
    if (context == null) return;

    switch (type) {
      case 'booking_request':
      case 'booking_accepted':
      case 'booking_rejected':
      case 'booking_cancelled':
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => const MyBookingsScreen(),
          ),
        );
        break;
      case 'verification':
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => const MyBookingsScreen(),
          ),
        );
        break;
      default:
        if (relatedId != null) {
          HouseService().getHouseById(relatedId).then((house) {
            if (house != null) {
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => HouseDetailScreen(house: house),
                ),
              );
            }
          });
        }
        break;
    }
  }

  // Create a server-side notification in Firestore
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
  }) async {
    try {
      final notification = NotificationModel(
        id: '',
        userId: userId,
        title: title,
        message: message,
        type: type,
        relatedId: relatedId,
        createdAt: DateTime.now(),
      );

      await _firestore.collection(_collectionName).add(notification.toMap());

      // Also trigger local notification service for real-time updates
      // (This is used by the notification_screen for in-app display)
      _notificationController.add(notification);

      // Send FCM push to the target user via Firestore triggers
      // The actual push delivery happens via Firebase Functions
      // We store a pending push in fcm_notifications collection
      await _firestore.collection('fcm_notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'relatedId': relatedId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail - notifications are non-critical
    }
  }

  // Stream notifications for a specific user
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromDocument(doc))
            .toList());
  }

  // Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection(_collectionName).doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      // Silently fail
    }
  }

  // Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      // Silently fail
    }
  }

  // Delete all notifications for a user
  Future<void> clearAll(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      // Silently fail
    }
  }

  void dispose() {
    _notificationController.close();
  }
}
