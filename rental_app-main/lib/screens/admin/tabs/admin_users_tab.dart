import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zanzrental/constants/app_colors.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({Key? key}) : super(key: key);

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _searchCtrl = TextEditingController();
  List<QueryDocumentSnapshot> _users = [];
  bool _isLoading = true;
  String _selectedRole = 'All';

  static const _roleFilters = [
    'All', 'Super Admin', 'Technical Admin', 'Owner', 'Tenant', 'Moderator'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      Query<Map<String, dynamic>> q =
          FirebaseFirestore.instance.collection('users');
      if (_selectedRole != 'All') {
        q = q.where('roleName', isEqualTo: _selectedRole);
      }
      final snap = await q.orderBy('createdAt', descending: true).get();
      if (!mounted) return;

      final search = _searchCtrl.text.trim().toLowerCase();
      final docs = search.isEmpty
          ? snap.docs
          : snap.docs.where((doc) {
              final data = doc.data();
              final name = (data['name'] as String? ?? '').toLowerCase();
              final email = (data['email'] as String? ?? '').toLowerCase();
              return name.contains(search) || email.contains(search);
            }).toList();

      setState(() {
        _isLoading = false;
        _users = docs;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSuspend(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final isSuspended = data['status'] == 'suspended';
    final name = data['name'] as String? ?? 'this user';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isSuspended ? 'Activate User' : 'Suspend User'),
        content: Text(
          isSuspended
              ? 'Activate $name? They will regain access.'
              : 'Suspend $name? They won\'t be able to log in.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuspended ? AppColors.primary : Colors.red,
            ),
            child: Text(isSuspended ? 'Activate' : 'Suspend'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('users').doc(doc.id).update({
      'status': isSuspended ? 'active' : 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    _load();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(isSuspended ? 'User activated' : 'User suspended')),
    );
  }

  void _showUserDetail(QueryDocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UserDetailSheet(
        user: doc.data() as Map<String, dynamic>,
        onToggleSuspend: () {
          Navigator.pop(context);
          _toggleSuspend(doc);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search by name or email…',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // ── Role filter chips ────────────────────────────────
          Container(
            color: Colors.white,
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _roleFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final role = _roleFilters[i];
                final selected = _selectedRole == role;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedRole = role);
                    _load();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // ── List ─────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : _users.isEmpty
                    ? const Center(
                        child: Text('No users found.',
                            style: TextStyle(
                                color: AppColors.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _users.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final doc = _users[i];
                            return _UserCard(
                              user: doc.data() as Map<String, dynamic>,
                              onTap: () => _showUserDetail(doc),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── User Card ──────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const _UserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = user['name'] as String? ?? 'Unknown';
    final email = user['email'] as String? ?? '';
    final role = user['roleName'] as String? ?? 'Tenant';
    final status = user['status'] as String? ?? 'active';
    final isVerified = user['isVerified'] == true;
    final isSuspended = status == 'suspended';
    final roleColor = _roleColor(role);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSuspended
                  ? Colors.red.withValues(alpha: 0.3)
                  : AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: roleColor.withValues(alpha: 0.15),
              child: Text(
                _getInitials(name),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: roleColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      if (isVerified)
                        const Icon(Icons.verified_rounded,
                            size: 14, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(email,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Badge(label: role, color: roleColor),
                      const SizedBox(width: 6),
                      _Badge(
                        label: status,
                        color: isSuspended ? Colors.red : Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Super Admin': return const Color(0xFF1A237E);
      case 'Technical Admin': return const Color(0xFF1565C0);
      case 'Moderator': return const Color(0xFF6A1B9A);
      case 'Owner': return const Color(0xFFE65100);
      default: return AppColors.primary;
    }
  }
}

// ── User Detail Sheet ──────────────────────────────────────────────────────────

class _UserDetailSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onToggleSuspend;

  const _UserDetailSheet({required this.user, required this.onToggleSuspend});

  @override
  Widget build(BuildContext context) {
    final name = user['name'] as String? ?? 'Unknown';
    final email = user['email'] as String? ?? '';
    final phone = user['phoneNumber'] as String? ?? '—';
    final role = user['roleName'] as String? ?? 'Tenant';
    final status = user['status'] as String? ?? 'active';
    final isVerified = user['isVerified'] == true;
    final isSuspended = status == 'suspended';
    final ts = user['createdAt'];
    final joinedStr = ts is Timestamp
        ? _fmtDate(ts.toDate())
        : '—';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                _getInitials(name),
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                if (isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded,
                      size: 18, color: AppColors.primary),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(icon: Icons.email_outlined, label: email),
            _InfoRow(icon: Icons.phone_outlined, label: phone),
            _InfoRow(icon: Icons.badge_outlined, label: role),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Joined $joinedStr',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onToggleSuspend,
                icon: Icon(
                  isSuspended
                      ? Icons.check_circle_rounded
                      : Icons.block_rounded,
                  size: 18,
                ),
                label: Text(
                  isSuspended ? 'Activate Account' : 'Suspend Account',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuspended ? AppColors.primary : Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

String _getInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'U';
  return trimmed[0].toUpperCase();
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}
