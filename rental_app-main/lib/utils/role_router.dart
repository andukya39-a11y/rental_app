import 'package:flutter/material.dart';
import 'package:zanzrental/models/user_model.dart';
import 'package:zanzrental/screens/home/home_screen.dart';
import 'package:zanzrental/screens/owner/owner_dashboard_screen.dart';
import 'package:zanzrental/screens/admin/sheha_dashboard_screen.dart';
import 'package:zanzrental/screens/sheha/sheha_portal_screen.dart';

class RoleRouter {
  static Widget homeForUser(UserModel user) {
    if (user.isAdmin) return const ShehaDashboardScreen();
    if (user.isSheha) return const ShehaPortalScreen();
    if (user.isOwner) return const OwnerDashboardScreen();
    return const HomeScreen();
  }

  static void navigateHome(BuildContext context, UserModel user) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => homeForUser(user)),
      (_) => false,
    );
  }
}
