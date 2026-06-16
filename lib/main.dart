import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/house_detail_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'services/house_service.dart';
import 'services/firebase_messaging_service.dart';
import 'constants/app_colors.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Global navigator key so that FirebaseMessagingService can navigate
/// even when there is no BuildContext available (e.g. notification taps
/// from background or terminated state).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _initializeLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyC09kbgcFNW-k5WQphmb1IZ76OT5t9nwlU",
      appId: "1:282264546862:android:b313b87abe421be1cd39bf",
      messagingSenderId: "282264546862",
      projectId: "mwaki-s-zanzi-rentalapp",
    ),
  );
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );
  } catch (e) {
    // AppCheck may not be enabled in Firebase console yet; non-critical
    debugPrint('AppCheck activation skipped: $e');
  }
  await _initializeLocalNotifications();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessagingService().initialize();
  runApp(const MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyC09kbgcFNW-k5WQphmb1IZ76OT5t9nwlU",
      appId: "1:282264546862:android:b313b87abe421be1cd39bf",
      messagingSenderId: "282264546862",
      projectId: "mwaki-s-zanzi-rentalapp",
    ),
  );
  FirebaseMessagingService().handleBackgroundMessage(message);
}

/// Navigate to a screen based on notification type and related ID.
void navigateFromNotification(
    BuildContext context, String type, String? relatedId) {
  switch (type) {
    case 'booking_request':
    case 'booking_accepted':
    case 'booking_rejected':
    case 'booking_cancelled':
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const MyBookingsScreen(),
        ),
      );
      break;
    case 'verification':
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const MyBookingsScreen(),
        ),
      );
      break;
    default:
      if (relatedId != null) {
        HouseService().getHouseById(relatedId).then((house) {
          if (house != null && context.mounted) {
            Navigator.of(context).push(
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Zanzi Renta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Initializing...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            );
          }
          if (snapshot.hasData) {
            return const HomeScreen();
          } else {
            return const AuthScreen();
          }
        },
      ),
    );
  }
}
