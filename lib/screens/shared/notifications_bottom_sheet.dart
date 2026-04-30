import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_notification.dart';
import '../../models/user_role.dart';
import '../../services/notification_service.dart';
import '../employee/complaint_detail_screen.dart';
import '../employee/my_leaves_screen.dart';
import '../hr/manage_leaves_screen.dart';
import '../legal/contract_detail_screen.dart';
import 'manage_complaint_detail_screen.dart';

class NotificationsBottomSheet extends StatefulWidget {
  final UserRole role;

  const NotificationsBottomSheet({
    super.key,
    required this.role,
  });

  @override
  State<NotificationsBottomSheet> createState() =>
      _NotificationsBottomSheetState();
}

class _NotificationsBottomSheetState extends State<NotificationsBottomSheet> {
  final _notificationService = NotificationService();

  IconData _topicIcon(NotificationTopic topic) {
    switch (topic) {
      case NotificationTopic.complaint:
        return Icons.report_rounded;
      case NotificationTopic.leave:
        return Icons.event_note_rounded;
      case NotificationTopic.contract:
        return Icons.description_rounded;
      case NotificationTopic.general:
        return Icons.notifications_rounded;
    }
  }

  Color _topicColor(NotificationTopic topic) {
    switch (topic) {
      case NotificationTopic.complaint:
        return const Color(0xFFC62828);
      case NotificationTopic.leave:
        return const Color(0xFF6A1B9A);
      case NotificationTopic.contract:
        return const Color(0xFF00695C);
      case NotificationTopic.general:
        return const Color(0xFF0D3B66);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final isSameDay =
        now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day;

    if (isSameDay) {
      return DateFormat('h:mm a').format(dateTime);
    }

    return DateFormat('MMM d, h:mm a').format(dateTime);
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    if (!notification.isRead) {
      await _notificationService.markAsRead(notification.id);
    }

    if (!mounted) return;

    final navigator = Navigator.of(context);
    final entityType = (notification.entityType ?? '').toLowerCase();
    final entityId = notification.entityId;

    navigator.pop();

    if (entityType == 'complaint' && entityId != null && entityId.isNotEmpty) {
      if (widget.role == UserRole.employee) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => ComplaintDetailScreen(complaintId: entityId),
          ),
        );
      } else if (widget.role == UserRole.hr) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => ManageComplaintDetailScreen(
              complaintId: entityId,
              primaryColor: const Color(0xFF6A1B9A),
              accentColor: const Color(0xFF8E24AA),
            ),
          ),
        );
      } else {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => ManageComplaintDetailScreen(
              complaintId: entityId,
              primaryColor: const Color(0xFF00695C),
              accentColor: const Color(0xFF00897B),
            ),
          ),
        );
      }
      return;
    }

    if (entityType == 'leave') {
      if (widget.role == UserRole.employee) {
        navigator.push(
          MaterialPageRoute(builder: (_) => const MyLeavesScreen()),
        );
      } else if (widget.role == UserRole.hr) {
        navigator.push(
          MaterialPageRoute(builder: (_) => const ManageLeavesScreen()),
        );
      }
      return;
    }

    if (entityType == 'contract' && entityId != null && entityId.isNotEmpty) {
      if (widget.role == UserRole.legal) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => ContractDetailScreen(contractId: entityId),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelHeight = MediaQuery.of(context).size.height * 0.5;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: panelHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mark all as read',
                    icon: const Icon(Icons.done_all_rounded),
                    onPressed: () async {
                      await _notificationService.markAllAsRead();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All notifications marked as read.'),
                          backgroundColor: Color(0xFF2E7D32),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Divider(color: Colors.grey.shade300, height: 1),
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
                stream: _notificationService.getMyNotificationsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Unable to load notifications right now.',
                          style: TextStyle(color: Colors.red.shade700),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final notifications = snapshot.data ?? const <AppNotification>[];
                  if (notifications.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_rounded,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No notifications yet',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Updates about complaints, leaves, and contracts will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final color = _topicColor(notification.topic);

                      return Card(
                        elevation: notification.isRead ? 1 : 2,
                        color: notification.isRead ? null : color.withOpacity(0.04),
                        child: InkWell(
                          onTap: () => _handleNotificationTap(notification),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(_topicIcon(notification.topic), color: color),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              notification.title,
                                              style: TextStyle(
                                                fontWeight: notification.isRead
                                                    ? FontWeight.w600
                                                    : FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatDateTime(notification.createdAt),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notification.message,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!notification.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}