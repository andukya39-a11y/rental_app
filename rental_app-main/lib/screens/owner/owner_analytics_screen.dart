import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zanzrental/constants/app_colors.dart';
import 'package:zanzrental/models/house_model.dart';
import 'package:zanzrental/models/booking_model.dart';
import 'package:zanzrental/services/house_service.dart';
import 'package:zanzrental/services/booking_service.dart';

class OwnerAnalyticsScreen extends StatefulWidget {
  const OwnerAnalyticsScreen({super.key});

  @override
  State<OwnerAnalyticsScreen> createState() => _OwnerAnalyticsScreenState();
}

class _OwnerAnalyticsScreenState extends State<OwnerAnalyticsScreen> {
  List<HouseModel> _houses = [];
  List<BookingModel> _bookings = [];
  bool _loading = true;

  StreamSubscription? _housesSub;
  StreamSubscription? _bookingsSub;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _housesSub = HouseService()
        .getHousesByUserIdStream(uid)
        .listen((h) => _merge(houses: h));
    _bookingsSub = BookingService()
        .getOwnerBookingsStream()
        .listen((b) => _merge(bookings: b));
  }

  void _merge({List<HouseModel>? houses, List<BookingModel>? bookings}) {
    if (!mounted) return;
    setState(() {
      if (houses != null) _houses = houses;
      if (bookings != null) _bookings = bookings;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _housesSub?.cancel();
    _bookingsSub?.cancel();
    super.dispose();
  }

  // ── Computed metrics ──────────────────────────────────────────────

  int get _totalListings => _houses.length;
  int get _availableListings => _houses.where((h) => h.isAvailable).length;
  int get _rentedListings => _houses.where((h) => !h.isAvailable).length;
  int get _verifiedListings =>
      _houses.where((h) => h.verificationStatus == 'verified').length;

  int get _totalBookings => _bookings.length;
  int get _pendingBookings =>
      _bookings.where((b) => b.status == 'pending').length;
  int get _confirmedBookings =>
      _bookings.where((b) => b.status == 'confirmed').length;
  int get _rejectedBookings =>
      _bookings.where((b) => b.status == 'rejected').length;
  int get _cancelledBookings =>
      _bookings.where((b) => b.status == 'cancelled').length;

  double get _estimatedRevenue {
    double total = 0;
    final priceMap = {for (final h in _houses) h.id: h.price};
    for (final b in _bookings) {
      if (b.status == 'confirmed') {
        total += (priceMap[b.houseId] ?? 0) * b.rentalDurationMonths;
      }
    }
    return total;
  }

  // Last 6 months booking counts
  List<_MonthData> get _monthlyBookings {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - (5 - i));
      final count = _bookings.where((b) {
        return b.createdAt.year == month.year &&
            b.createdAt.month == month.month;
      }).length;
      return _MonthData(
        label: _shortMonth(month.month),
        count: count,
      );
    });
  }

  // Bookings per property (top 5)
  List<_PropStat> get _propertyStats {
    final stats = <String, _PropStat>{};
    for (final h in _houses) {
      stats[h.id] = _PropStat(
        title: h.title,
        bookings: 0,
        available: h.isAvailable,
      );
    }
    for (final b in _bookings) {
      if (stats.containsKey(b.houseId)) {
        stats[b.houseId] = _PropStat(
          title: stats[b.houseId]!.title,
          bookings: stats[b.houseId]!.bookings + 1,
          available: stats[b.houseId]!.available,
        );
      }
    }
    final sorted = stats.values.toList()
      ..sort((a, b) => b.bookings.compareTo(a.bookings));
    return sorted.take(5).toList();
  }

  String _shortMonth(int m) =>
      ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  String _fmtPrice(double v) {
    if (v >= 1000000) return 'TSh ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'TSh ${(v / 1000).toStringAsFixed(0)}K';
    return 'TSh ${v.toStringAsFixed(0)}';
  }

  // ── BUILD ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKpiRow(),
                    const SizedBox(height: 24),
                    _buildRevenueCard(),
                    const SizedBox(height: 24),
                    _buildMonthlyChart(),
                    const SizedBox(height: 24),
                    _buildStatusDonut(),
                    const SizedBox(height: 24),
                    _buildPropertyAvailability(),
                    const SizedBox(height: 24),
                    _buildPropertyPerformance(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Analytics',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.divider),
      ),
    );
  }

  // ── KPI cards ─────────────────────────────────────────────────────
  Widget _buildKpiRow() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _KpiCard(
          label: 'Total Listings',
          value: '$_totalListings',
          icon: Icons.home_work_rounded,
          color: AppColors.primary,
        ),
        _KpiCard(
          label: 'Total Bookings',
          value: '$_totalBookings',
          icon: Icons.calendar_month_rounded,
          color: const Color(0xFF7B1FA2),
        ),
        _KpiCard(
          label: 'Pending',
          value: '$_pendingBookings',
          icon: Icons.hourglass_top_rounded,
          color: Colors.orange,
        ),
        _KpiCard(
          label: 'Confirmed',
          value: '$_confirmedBookings',
          icon: Icons.check_circle_rounded,
          color: Colors.green,
        ),
      ],
    );
  }

  // ── Revenue card ──────────────────────────────────────────────────
  Widget _buildRevenueCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.payments_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estimated Revenue',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmtPrice(_estimatedRevenue),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'From confirmed bookings',
                  style: TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Monthly bookings bar chart ────────────────────────────────────
  Widget _buildMonthlyChart() {
    final data = _monthlyBookings;
    final maxY = data.map((d) => d.count).fold(0, (a, b) => a > b ? a : b);
    final yMax = (maxY < 5 ? 5 : maxY + 1).toDouble();

    return _Card(
      title: 'Booking Requests',
      subtitle: 'Last 6 months',
      icon: Icons.bar_chart_rounded,
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: yMax,
            minY: 0,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.primary.withValues(alpha: 0.9),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${data[groupIndex].label}\n${rod.toY.toInt()} bookings',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox();
                    return Text(
                      data[i].label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    );
                  },
                  reservedSize: 24,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: yMax > 10 ? (yMax / 5).ceilToDouble() : 1,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const SizedBox();
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                    );
                  },
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yMax > 10 ? (yMax / 5).ceilToDouble() : 1,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: AppColors.divider,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(data.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].count.toDouble(),
                    color: AppColors.primary,
                    width: 28,
                    borderRadius: BorderRadius.circular(6),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: yMax,
                      color: AppColors.primary.withValues(alpha: 0.07),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Booking status donut chart ────────────────────────────────────
  Widget _buildStatusDonut() {
    if (_totalBookings == 0) {
      return const _Card(
        title: 'Booking Status',
        subtitle: 'Breakdown by status',
        icon: Icons.donut_large_rounded,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('No bookings yet',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    final legend = <_LegendItem>[];

    void add(String label, int count, Color color) {
      if (count == 0) return;
      final pct = (count / _totalBookings * 100).toStringAsFixed(0);
      sections.add(PieChartSectionData(
        value: count.toDouble(),
        color: color,
        title: '$pct%',
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
        radius: 52,
      ));
      legend.add(_LegendItem(label: label, count: count, color: color));
    }

    add('Pending', _pendingBookings, Colors.orange);
    add('Confirmed', _confirmedBookings, Colors.green);
    add('Rejected', _rejectedBookings, Colors.red);
    add('Cancelled', _cancelledBookings, Colors.grey);

    return _Card(
      title: 'Booking Status',
      subtitle: 'Breakdown by status',
      icon: Icons.donut_large_rounded,
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 36,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: legend
                  .map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: l.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l.label,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                            Text(
                              '${l.count}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Property availability bars ────────────────────────────────────
  Widget _buildPropertyAvailability() {
    if (_totalListings == 0) return const SizedBox.shrink();

    final availPct =
        _totalListings > 0 ? _availableListings / _totalListings : 0.0;
    final rentedPct =
        _totalListings > 0 ? _rentedListings / _totalListings : 0.0;
    final verifiedPct =
        _totalListings > 0 ? _verifiedListings / _totalListings : 0.0;

    return _Card(
      title: 'Property Overview',
      subtitle: '$_totalListings total properties',
      icon: Icons.home_work_rounded,
      child: Column(
        children: [
          _ProgressRow(
            label: 'Available',
            count: _availableListings,
            total: _totalListings,
            fraction: availPct,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _ProgressRow(
            label: 'Rented',
            count: _rentedListings,
            total: _totalListings,
            fraction: rentedPct,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _ProgressRow(
            label: 'Verified',
            count: _verifiedListings,
            total: _totalListings,
            fraction: verifiedPct,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ── Top properties by bookings ────────────────────────────────────
  Widget _buildPropertyPerformance() {
    final stats = _propertyStats;
    if (stats.isEmpty) return const SizedBox.shrink();

    final maxBookings =
        stats.map((s) => s.bookings).fold(0, (a, b) => a > b ? a : b);

    return _Card(
      title: 'Property Performance',
      subtitle: 'Bookings per listing (top 5)',
      icon: Icons.leaderboard_rounded,
      child: Column(
        children: List.generate(stats.length, (i) {
          final s = stats[i];
          final frac =
              maxBookings > 0 ? s.bookings / maxBookings : 0.0;
          return Padding(
            padding: EdgeInsets.only(bottom: i < stats.length - 1 ? 14 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == 0
                            ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: i == 0
                              ? const Color(0xFFB8860B)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: s.available
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s.available ? 'Available' : 'Rented',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: s.available ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${s.bookings} req',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 5,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      i == 0 ? AppColors.primary : AppColors.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Small data classes ─────────────────────────────────────────────────────────

class _MonthData {
  final String label;
  final int count;
  const _MonthData({required this.label, required this.count});
}

class _PropStat {
  final String title;
  final int bookings;
  final bool available;
  const _PropStat(
      {required this.title, required this.bookings, required this.available});
}

class _LegendItem {
  final String label;
  final int count;
  final Color color;
  const _LegendItem(
      {required this.label, required this.count, required this.color});
}

// ── Reusable widgets ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _Card({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final double fraction;
  final Color color;

  const _ProgressRow({
    required this.label,
    required this.count,
    required this.total,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (fraction * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
            Text(
              '$count / $total  ($pct%)',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 7,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
