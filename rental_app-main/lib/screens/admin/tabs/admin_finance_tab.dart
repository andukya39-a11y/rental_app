import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zanzrental/constants/app_colors.dart';

class AdminFinanceTab extends StatefulWidget {
  const AdminFinanceTab({Key? key}) : super(key: key);

  @override
  State<AdminFinanceTab> createState() => _AdminFinanceTabState();
}

class _AdminFinanceTabState extends State<AdminFinanceTab> {
  double _totalRevenue = 0;
  List<Map<String, dynamic>> _monthly = [];
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  int _year = DateTime.now().year;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('status', whereIn: ['confirmed', 'completed'])
          .orderBy('createdAt', descending: true)
          .get();

      double total = 0;
      final monthlyMap = <int, Map<String, dynamic>>{};
      final recentBookings = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final amount = double.tryParse((data['totalAmount'] ?? 0).toString()) ?? 0;
        final ts = data['createdAt'];
        if (ts is Timestamp) {
          final dt = ts.toDate();
          if (dt.year == _year) {
            total += amount;
            final m = dt.month;
            if (monthlyMap.containsKey(m)) {
              monthlyMap[m]!['total'] =
                  (monthlyMap[m]!['total'] as double) + amount;
              monthlyMap[m]!['count'] =
                  (monthlyMap[m]!['count'] as int) + 1;
            } else {
              monthlyMap[m] = {'month': m, 'total': amount, 'count': 1};
            }
          }
        }
        if (recentBookings.length < 10) {
          recentBookings.add({...data, 'id': doc.id});
        }
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _totalRevenue = total;
        _monthly = monthlyMap.values.toList()
          ..sort((a, b) => (a['month'] as int).compareTo(b['month'] as int));
        _bookings = recentBookings;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  double get _maxMonthly {
    if (_monthly.isEmpty) return 1;
    return _monthly
        .map((m) => (m['total'] as double))
        .reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Finance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Year selector ──────────────────────────────
                  Row(
                    children: [
                      const Text('Year:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                      ...List.generate(3, (i) {
                        final y = DateTime.now().year - i;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$y'),
                            selected: _year == y,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: _year == y
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) {
                              setState(() => _year = y);
                              _load();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Total revenue card ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A237E), Color(0xFF283593)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Revenue $_year',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _fmtAmount(_totalRevenue),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.calendar_month_rounded,
                              color: Colors.white54, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${_monthly.length} active month${_monthly.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Monthly bar chart ──────────────────────────
                  _sectionLabel('MONTHLY BREAKDOWN'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _monthly.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('No revenue this year',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                            ),
                          )
                        : Column(
                            children: [
                              SizedBox(
                                height: 120,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: List.generate(12, (i) {
                                    final monthNum = i + 1;
                                    final data = _monthly.firstWhere(
                                      (m) => m['month'] == monthNum,
                                      orElse: () => <String, dynamic>{},
                                    );
                                    final total = data.isNotEmpty
                                        ? (data['total'] as double)
                                        : 0.0;
                                    final ratio = _maxMonthly > 0
                                        ? total / _maxMonthly
                                        : 0.0;
                                    final isCurrentMonth =
                                        monthNum == DateTime.now().month &&
                                            _year == DateTime.now().year;

                                    return Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 600),
                                            height:
                                                (ratio * 90).clamp(4.0, 90.0),
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 2),
                                            decoration: BoxDecoration(
                                              color: isCurrentMonth
                                                  ? AppColors.primary
                                                  : AppColors.primary
                                                      .withValues(alpha: 0.35),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _months[i].substring(0, 1),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: isCurrentMonth
                                                  ? FontWeight.w800
                                                  : FontWeight.w400,
                                              color: isCurrentMonth
                                                  ? AppColors.primary
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._monthly.map((m) {
                                final month = (m['month'] as int) - 1;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(children: [
                                    SizedBox(
                                      width: 36,
                                      child: Text(_months[month],
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  AppColors.textSecondary)),
                                    ),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: _maxMonthly > 0
                                            ? (m['total'] as double) /
                                                _maxMonthly
                                            : 0,
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                AppColors.primary),
                                        minHeight: 6,
                                        borderRadius:
                                            BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _fmtAmount(m['total']),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${m['count']})',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary),
                                    ),
                                  ]),
                                );
                              }),
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),

                  // ── Recent bookings ────────────────────────────
                  _sectionLabel('RECENT BOOKINGS'),
                  const SizedBox(height: 12),
                  if (_bookings.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No bookings yet',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    ...(_bookings.map((bk) {
                      final status = bk['status'] as String? ?? 'pending';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bk['houseTitle'] as String? ?? '—',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tenant: ${bk['tenantName'] ?? '—'}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'TSh ${bk['totalAmount'] ?? 0}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary),
                              ),
                              const SizedBox(height: 4),
                              _StatusBadge(status: status),
                            ],
                          ),
                        ]),
                      );
                    })),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2));

  String _fmtAmount(dynamic v) {
    if (v == null) return 'TSh 0';
    final n = double.tryParse(v.toString()) ?? 0;
    if (n >= 1000000) return 'TSh ${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return 'TSh ${(n / 1000).toStringAsFixed(0)}K';
    return 'TSh ${n.toStringAsFixed(0)}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'confirmed': c = Colors.green; break;
      case 'cancelled': c = Colors.red; break;
      case 'completed': c = AppColors.primary; break;
      default: c = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: c)),
    );
  }
}
