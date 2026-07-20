import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zanzrental/screens/notifications/notification_screen.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationScreen()),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .where('readAt', isNull: true)
          .snapshots(),
      builder: (context, snap) {
        final unread = snap.data?.docs.length ?? 0;
        return IconButton(
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(
              unread > 9 ? '9+' : '$unread',
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
            backgroundColor: Colors.red,
            child: const Icon(Icons.notifications_outlined),
          ),
          tooltip: 'Notifications',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationScreen()),
          ),
        );
      },
    );
  }
}
