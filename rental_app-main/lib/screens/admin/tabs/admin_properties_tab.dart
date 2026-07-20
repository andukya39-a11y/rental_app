import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zanzrental/constants/app_colors.dart';

class AdminPropertiesTab extends StatefulWidget {
  const AdminPropertiesTab({Key? key}) : super(key: key);

  @override
  State<AdminPropertiesTab> createState() => _AdminPropertiesTabState();
}

class _AdminPropertiesTabState extends State<AdminPropertiesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(
      () => setState(() => _searchQuery = _searchCtrl.text.trim()),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Properties'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              // ── Location search bar ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search by location or area…',
                    hintStyle: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 20, color: AppColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchCtrl.clear();
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              // ── Status tabs ──────────────────────────────────────
              TabBar(
                controller: _tabCtrl,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Approved'),
                  Tab(text: 'All'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _PropertyList(
              status: 'pending',
              showActions: true,
              searchQuery: _searchQuery),
          _PropertyList(status: 'approved', searchQuery: _searchQuery),
          _PropertyList(status: null, searchQuery: _searchQuery),
        ],
      ),
    );
  }
}

class _PropertyList extends StatefulWidget {
  final String? status;
  final bool showActions;
  final String searchQuery;

  const _PropertyList({
    this.status,
    this.showActions = false,
    this.searchQuery = '',
  });

  @override
  State<_PropertyList> createState() => _PropertyListState();
}

class _PropertyListState extends State<_PropertyList>
    with AutomaticKeepAliveClientMixin {
  List<QueryDocumentSnapshot> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      Query<Map<String, dynamic>> q =
          FirebaseFirestore.instance.collection('properties');
      if (widget.status != null) {
        q = q.where('status', isEqualTo: widget.status);
      }
      final snap = await q.orderBy('createdAt', descending: true).get();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _items = snap.docs;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _approve(String id) async {
    await FirebaseFirestore.instance
        .collection('properties')
        .doc(id)
        .update({'status': 'approved', 'updatedAt': FieldValue.serverTimestamp()});
    if (!mounted) return;
    setState(() => _items.removeWhere((d) => d.id == id));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Property approved')));
  }

  Future<void> _reject(String id) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(),
    );
    if (reason == null) return;
    await FirebaseFirestore.instance
        .collection('properties')
        .doc(id)
        .update({
      'status': 'rejected',
      'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    setState(() => _items.removeWhere((d) => d.id == id));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Property rejected')));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry')),
        ]),
      );
    }
    final q = widget.searchQuery.toLowerCase();
    final visible = q.isEmpty
        ? _items
        : _items.where((doc) {
            final p = doc.data() as Map<String, dynamic>;
            final location =
                (p['location'] as String? ?? '').toLowerCase();
            final title = (p['title'] as String? ?? '').toLowerCase();
            return location.contains(q) || title.contains(q);
          }).toList();

    if (visible.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.home_rounded, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            q.isNotEmpty
                ? 'No properties match "$q"'
                : widget.status == 'pending'
                    ? 'No pending properties'
                    : 'No properties found',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final doc = visible[i];
          final p = doc.data() as Map<String, dynamic>;
          return _PropertyCard(
            property: p,
            onApprove: widget.showActions ? () => _approve(doc.id) : null,
            onReject: widget.showActions ? () => _reject(doc.id) : null,
          );
        },
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _PropertyCard({required this.property, this.onApprove, this.onReject});

  @override
  Widget build(BuildContext context) {
    final imageUrls = property['imageUrls'] as List<dynamic>? ?? [];
    final imageUrl = imageUrls.isNotEmpty ? imageUrls.first as String? : null;
    final status = property['status'] as String? ?? 'pending';
    final ownerName = property['ownerName'] as String?;

    Color statusColor;
    switch (status) {
      case 'approved': statusColor = Colors.green; break;
      case 'rejected': statusColor = Colors.red; break;
      default: statusColor = Colors.orange;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property['title'] as String? ?? 'Property',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_rounded,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      property['location'] as String? ?? '—',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.category_rounded,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Text(
                    property['propertyType'] as String? ?? '—',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ]),
                if (ownerName != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.person_rounded,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      'Owner: $ownerName',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ]),
                ],
                const SizedBox(height: 4),
                Text(
                  'TSh ${property['price'] ?? 0}/month',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
                if (onApprove != null && onReject != null) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red[300]!),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        height: 150,
        width: double.infinity,
        color: const Color(0xFFF0F0F0),
        child: const Icon(Icons.home_rounded, size: 40, color: AppColors.border),
      );
}

class _RejectDialog extends StatefulWidget {
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Property'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please provide a reason for rejection:'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g. Incomplete information, fake listing…',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Reject',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
