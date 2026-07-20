import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zanzrental/constants/app_colors.dart';

class AdminSupportTab extends StatefulWidget {
  const AdminSupportTab({Key? key}) : super(key: key);

  @override
  State<AdminSupportTab> createState() => _AdminSupportTabState();
}

class _AdminSupportTabState extends State<AdminSupportTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Support'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Fraud Reports', icon: Icon(Icons.flag_rounded, size: 16)),
            Tab(text: 'Support Tickets', icon: Icon(Icons.support_agent_rounded, size: 16)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _FraudReportList(),
          _TicketList(),
        ],
      ),
    );
  }
}

// ── Fraud Reports ──────────────────────────────────────────────────────────────

class _FraudReportList extends StatefulWidget {
  const _FraudReportList();

  @override
  State<_FraudReportList> createState() => _FraudReportListState();
}

class _FraudReportListState extends State<_FraudReportList>
    with AutomaticKeepAliveClientMixin {
  List<QueryDocumentSnapshot> _reports = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      Query<Map<String, dynamic>> q =
          FirebaseFirestore.instance.collection('fraud_reports');
      if (_filter != 'all') q = q.where('status', isEqualTo: _filter);
      final snap = await q.orderBy('createdAt', descending: true).get();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _reports = snap.docs;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resolve(String id) async {
    final notes = await showDialog<String>(
      context: context,
      builder: (_) => const _NotesDialog(title: 'Resolve Report', hint: 'Admin notes…'),
    );
    if (notes == null) return;
    await FirebaseFirestore.instance
        .collection('fraud_reports')
        .doc(id)
        .update({
      'status': 'resolved',
      'adminNotes': notes,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    _load();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Report resolved')));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _FilterBar(
          selected: _filter,
          options: const ['all', 'pending', 'investigating', 'resolved'],
          onChanged: (v) { setState(() => _filter = v); _load(); },
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _reports.isEmpty
                  ? const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.shield_rounded, size: 56, color: AppColors.primary),
                        SizedBox(height: 12),
                        Text('No reports found',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reports.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final doc = _reports[i];
                          final r = doc.data() as Map<String, dynamic>;
                          final status = r['status'] as String? ?? 'pending';
                          final isPending = status == 'pending';
                          final ts = r['createdAt'];
                          final dateStr = ts is Timestamp
                              ? _fmtDate(ts.toDate())
                              : '';

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isPending
                                    ? Colors.red.withValues(alpha: 0.3)
                                    : AppColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Icon(Icons.flag_rounded,
                                      size: 14,
                                      color: isPending ? Colors.red : Colors.grey),
                                  const SizedBox(width: 6),
                                  _StatusPill(
                                    label: status,
                                    color: isPending
                                        ? Colors.red
                                        : status == 'resolved'
                                            ? Colors.green
                                            : Colors.orange,
                                  ),
                                  const Spacer(),
                                  Text(dateStr,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                ]),
                                const SizedBox(height: 8),
                                if (r['propertyTitle'] != null)
                                  Text(
                                    'Property: ${r['propertyTitle']}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  r['description'] as String? ?? '—',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.4),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Reported by: ${r['reporterName'] ?? '—'}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                                if (isPending) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _resolve(doc.id),
                                      icon: const Icon(Icons.check_rounded, size: 16),
                                      label: const Text('Mark as Resolved'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

// ── Support Tickets ────────────────────────────────────────────────────────────

class _TicketList extends StatefulWidget {
  const _TicketList();

  @override
  State<_TicketList> createState() => _TicketListState();
}

class _TicketListState extends State<_TicketList>
    with AutomaticKeepAliveClientMixin {
  List<QueryDocumentSnapshot> _tickets = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      Query<Map<String, dynamic>> q =
          FirebaseFirestore.instance.collection('support_tickets');
      if (_filter != 'all') q = q.where('status', isEqualTo: _filter);
      final snap = await q.orderBy('createdAt', descending: true).get();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _tickets = snap.docs;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _close(String id) async {
    final reply = await showDialog<String>(
      context: context,
      builder: (_) =>
          const _NotesDialog(title: 'Close Ticket', hint: 'Your reply to the user…'),
    );
    if (reply == null) return;
    await FirebaseFirestore.instance
        .collection('support_tickets')
        .doc(id)
        .update({
      'status': 'closed',
      'adminReply': reply,
      'closedAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    _load();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Ticket closed')));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _FilterBar(
          selected: _filter,
          options: const ['all', 'open', 'in_progress', 'closed'],
          labels: const ['All', 'Open', 'In Progress', 'Closed'],
          onChanged: (v) { setState(() => _filter = v); _load(); },
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _tickets.isEmpty
                  ? const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.support_agent_rounded,
                            size: 56, color: AppColors.primary),
                        SizedBox(height: 12),
                        Text('No tickets found',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tickets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final doc = _tickets[i];
                          final t = doc.data() as Map<String, dynamic>;
                          final status = t['status'] as String? ?? 'open';
                          final isOpen = status == 'open' || status == 'in_progress';
                          final ts = t['createdAt'];
                          final dateStr = ts is Timestamp
                              ? _fmtDate(ts.toDate())
                              : '';

                          Color statusColor;
                          switch (status) {
                            case 'closed': statusColor = Colors.grey; break;
                            case 'in_progress': statusColor = Colors.orange; break;
                            default: statusColor = Colors.red;
                          }

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isOpen
                                    ? Colors.orange.withValues(alpha: 0.4)
                                    : AppColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.confirmation_number_rounded,
                                      size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      t['subject'] as String? ?? 'No subject',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary),
                                    ),
                                  ),
                                  _StatusPill(label: status, color: statusColor),
                                ]),
                                const SizedBox(height: 6),
                                Text(
                                  t['message'] as String? ?? '—',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.4),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(children: [
                                  const Icon(Icons.person_rounded,
                                      size: 12, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    t['userName'] as String? ?? '—',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                  ),
                                  const Spacer(),
                                  Text(dateStr,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                ]),
                                if (t['adminReply'] != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.reply_rounded,
                                            size: 14, color: AppColors.primary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            t['adminReply'] as String,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textPrimary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (isOpen) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _close(doc.id),
                                      icon: const Icon(Icons.check_rounded,
                                          size: 16),
                                      label: const Text('Reply & Close'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(
                                            color: AppColors.primary),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

// ── Shared Widgets ─────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final List<String> options;
  final List<String>? labels;
  final ValueChanged<String> onChanged;

  const _FilterBar({
    required this.selected,
    required this.options,
    required this.onChanged,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final val = options[i];
          final label = labels != null ? labels![i] : _capitalize(val);
          final isSelected = selected == val;
          return GestureDetector(
            onTap: () => onChanged(val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _NotesDialog extends StatefulWidget {
  final String title;
  final String hint;
  const _NotesDialog({required this.title, required this.hint});

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
