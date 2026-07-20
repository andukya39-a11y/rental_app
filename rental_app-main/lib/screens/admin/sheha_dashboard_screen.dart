import 'package:flutter/material.dart';
import 'package:zanzrental/constants/app_colors.dart';
import 'package:zanzrental/screens/admin/tabs/admin_overview_tab.dart';
import 'package:zanzrental/screens/admin/tabs/admin_users_tab.dart';
import 'package:zanzrental/screens/admin/tabs/admin_properties_tab.dart';
import 'package:zanzrental/screens/admin/tabs/admin_finance_tab.dart';
import 'package:zanzrental/screens/admin/tabs/admin_support_tab.dart';

class ShehaDashboardScreen extends StatefulWidget {
  const ShehaDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ShehaDashboardScreen> createState() => _ShehaDashboardScreenState();
}

class _ShehaDashboardScreenState extends State<ShehaDashboardScreen> {
  int _selectedIndex = 0;
  final List<bool> _visited = [true, false, false, false, false];

  @override
  Widget build(BuildContext context) {
    _visited[_selectedIndex] = true;

    final screens = [
      const AdminOverviewTab(),
      _visited[1] ? const AdminUsersTab() : const SizedBox(),
      _visited[2] ? const AdminPropertiesTab() : const SizedBox(),
      _visited[3] ? const AdminFinanceTab() : const SizedBox(),
      _visited[4] ? const AdminSupportTab() : const SizedBox(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
        ),
        child: NavigationBar(
          height: 64,
          backgroundColor: Colors.white,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Users',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Properties',
            ),
            NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments_rounded),
              label: 'Finance',
            ),
            NavigationDestination(
              icon: Icon(Icons.support_agent_outlined),
              selectedIcon: Icon(Icons.support_agent_rounded),
              label: 'Support',
            ),
          ],
        ),
      ),
    );
  }
}
