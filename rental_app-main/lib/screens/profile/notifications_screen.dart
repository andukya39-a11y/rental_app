import 'package:flutter/material.dart';
import 'package:zanzrental/utils/notification_service.dart';
import 'package:zanzrental/constants/app_colors.dart';

// ─── Model ────────────────────────────────────────────────────────
class _NotificationItem {
  final String message;
  final DateTime receivedAt;
  bool isRead = false;

  _NotificationItem({
    required this.message,
    required this.receivedAt,
  });

  bool get isToday {
    final now = DateTime.now();
    return receivedAt.year == now.year &&
        receivedAt.month == now.month &&
        receivedAt.day == now.day;
  }

  String get timeLabel {
    final diff = DateTime.now().difference(receivedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  // Derive icon and color from message content
  IconData get icon {
    final lower = message.toLowerCase();
    if (lower.contains('book') || lower.contains('reserv')) {
      return Icons.calendar_today_rounded;
    }
    if (lower.contains('verify') || lower.contains('approv') ||
        lower.contains('confirm')) {
      return Icons.verified_rounded;
    }
    if (lower.contains('message') || lower.contains('chat')) {
      return Icons.chat_bubble_outline_rounded;
    }
    if (lower.contains('pay') || lower.contains('payment')) {
      return Icons.payments_rounded;
    }
    if (lower.contains('cancel') || lower.contains('reject') ||
        lower.contains('declin')) {
      return Icons.cancel_outlined;
    }
    return Icons.notifications_rounded;
  }

  Color get iconColor {
    final lower = message.toLowerCase();
    if (lower.contains('cancel') || lower.contains('reject') ||
        lower.contains('declin')) {
      return Colors.red[600]!;
    }
    if (lower.contains('verify') || lower.contains('approv') ||
        lower.contains('confirm')) {
      return Colors.green[700]!;
    }
    if (lower.contains('pay')) return Colors.orange[700]!;
    return AppColors.primary;
  }
}

// ─── Screen ───────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final List<_NotificationItem> _items = [];

  int get _unreadCount => _items.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    _notificationService.notifications.listen((message) {
      if (mounted) {
        setState(() {
          _items.insert(
            0,
            _NotificationItem(
              message: message,
              receivedAt: DateTime.now(),
            ),
          );
        });
      }
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (final item in _items) {
        item.isRead = true;
      }
    });
  }

  void _clearAll() {
    setState(() => _items.clear());
  }

  @override
  Widget build(BuildContext context) {
    final todayItems = _items.where((n) => n.isToday).toList();
    final earlierItems = _items.where((n) => !n.isToday).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications'),
            if (_unreadCount > 0)
              Text(
                '$_unreadCount unread',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear all',
              onPressed: () => _showClearConfirm(),
            ),
        ],
      ),
      body: _items.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                if (todayItems.isNotEmpty) ...[
                  const _SectionHeader(label: 'Today'),
                  ...todayItems.map((item) => _buildCard(item)),
                ],
                if (earlierItems.isNotEmpty) ...[
                  _SectionHeader(
                      label: todayItems.isEmpty ? 'Notifications' : 'Earlier'),
                  ...earlierItems.map((item) => _buildCard(item)),
                ],
              ],
            ),
    );
  }

  Widget _buildCard(_NotificationItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () => setState(() => item.isRead = true),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: item.isRead
                ? Colors.white
                : AppColors.primary.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, size: 20, color: item.iconColor),
                ),
                const SizedBox(width: 12),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.message,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: item.isRead
                              ? FontWeight.w400
                              : FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.timeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Unread dot
                if (!item.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We\'ll notify you about bookings,\npayments, and property updates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear all notifications?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'This will remove all notifications. This action cannot be undone.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _clearAll();
            },
            child: const Text(
              'Clear all',
              style: TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
