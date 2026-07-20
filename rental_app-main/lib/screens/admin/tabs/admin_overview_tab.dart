import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zanzrental/constants/app_colors.dart';
import 'package:zanzrental/models/user_model.dart';
import 'package:zanzrental/services/auth_service.dart';
import 'package:zanzrental/screens/auth/auth_screen.dart';
import 'package:zanzrental/widgets/notification_bell.dart';

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({Key? key}) : super(key: key);

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  Map<String, dynamic> _stats = {};
  UserModel? _admin;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('users').count().get(),
        db.collection('properties').count().get(),
        db.collection('bookings').count().get(),
        db.collection('bookings').where('status', isEqualTo: 'confirmed').count().get(),
        db.collection('properties').where('status', isEqualTo: 'pending').count().get(),
        db.collection('fraud_reports').where('status', isEqualTo: 'pending').count().get(),
        db.collection('support_tickets').where('status', whereIn: ['open', 'in_progress']).count().get(),
        db.collection('bookings').get(),
        AuthService().getStoredUser(),
      ]);

      // Revenue from bookings
      final bookingSnap = results[7] as QuerySnapshot;
      double totalRevenue = 0;
      double monthlyRevenue = 0;
      final now = DateTime.now();
      for (final doc in bookingSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = double.tryParse((data['totalAmount'] ?? 0).toString()) ?? 0;
        if (data['status'] == 'confirmed' || data['status'] == 'completed') {
          totalRevenue += amount;
          final ts = data['createdAt'];
          if (ts is Timestamp) {
            final dt = ts.toDate();
            if (dt.year == now.year && dt.month == now.month) {
              monthlyRevenue += amount;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _stats = {
          'total_users': (results[0] as AggregateQuerySnapshot).count ?? 0,
          'total_properties': (results[1] as AggregateQuerySnapshot).count ?? 0,
          'total_bookings': (results[2] as AggregateQuerySnapshot).count ?? 0,
          'active_bookings': (results[3] as AggregateQuerySnapshot).count ?? 0,
          'pending_approvals': (results[4] as AggregateQuerySnapshot).count ?? 0,
          'fraud_reports': (results[5] as AggregateQuerySnapshot).count ?? 0,
          'open_tickets': (results[6] as AggregateQuerySnapshot).count ?? 0,
          'total_revenue': totalRevenue,
          'monthly_revenue': monthlyRevenue,
        };
        _admin = results[8] as UserModel?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout_rounded,
                    size: 30, color: Colors.red.shade400),
              ),
              const SizedBox(height: 20),
              const Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Are you sure you want to log out of your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade500,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Log Out',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true || !mounted) return;
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 16,
                    8,
                    20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        _getInitials(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _admin?.name ?? 'Administrator',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _admin?.roleName ?? 'Admin',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const NotificationBell(),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded),
                      tooltip: 'Log out',
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else ...[
              if ((_stats['pending_approvals'] ?? 0) > 0)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFCA28)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pending_actions_rounded,
                            color: Color(0xFFFF8F00)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_stats['pending_approvals']} propert${((_stats['pending_approvals'] as num?)?.toInt() ?? 0) == 1 ? 'y' : 'ies'} waiting for approval',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF795548),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('OVERVIEW'),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.35,
                        children: [
                          _StatCard(
                            label: 'Total Users',
                            value: '${_stats['total_users'] ?? 0}',
                            icon: Icons.people_rounded,
                            color: const Color(0xFF1565C0),
                          ),
                          _StatCard(
                            label: 'Properties',
                            value: '${_stats['total_properties'] ?? 0}',
                            icon: Icons.home_rounded,
                            color: AppColors.primary,
                          ),
                          _StatCard(
                            label: 'Total Bookings',
                            value: '${_stats['total_bookings'] ?? 0}',
                            icon: Icons.calendar_month_rounded,
                            color: const Color(0xFF6A1B9A),
                          ),
                          _StatCard(
                            label: 'Revenue',
                            value: _fmtAmount(_stats['total_revenue']),
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF2E7D32),
                          ),
                          _StatCard(
                            label: 'This Month',
                            value: _fmtAmount(_stats['monthly_revenue']),
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xFFE65100),
                          ),
                          _StatCard(
                            label: 'Active Bookings',
                            value: '${_stats['active_bookings'] ?? 0}',
                            icon: Icons.event_available_rounded,
                            color: const Color(0xFF00838F),
                          ),
                          _StatCard(
                            label: 'Fraud Reports',
                            value: '${_stats['fraud_reports'] ?? 0}',
                            icon: Icons.flag_rounded,
                            color: Colors.red,
                          ),
                          _StatCard(
                            label: 'Open Tickets',
                            value: '${_stats['open_tickets'] ?? 0}',
                            icon: Icons.support_agent_rounded,
                            color: const Color(0xFF558B2F),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      );

  String _fmtAmount(dynamic v) {
    if (v == null) return 'TSh 0';
    final n = double.tryParse(v.toString()) ?? 0;
    if (n >= 1000000) return 'TSh ${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return 'TSh ${(n / 1000).toStringAsFixed(0)}K';
    return 'TSh ${n.toStringAsFixed(0)}';
  }

  String _getInitials() {
    final name = _admin?.name ?? 'A';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'A';
    return trimmed[0].toUpperCase();
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
