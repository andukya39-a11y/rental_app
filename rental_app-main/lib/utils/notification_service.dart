import 'dart:async';

class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  final StreamController<String> _notificationController =
      StreamController<String>.broadcast();

  Stream<String> get notifications => _notificationController.stream;

  void showNotification(String message) {
    _notificationController.add(message);
  }

  void dispose() {
    _notificationController.close();
  }
}