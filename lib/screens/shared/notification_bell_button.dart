import 'package:flutter/material.dart';

import '../../models/user_role.dart';
import '../../services/notification_service.dart';
import 'notifications_bottom_sheet.dart';

class NotificationBellButton extends StatelessWidget {
  final UserRole role;

  const NotificationBellButton({
    super.key,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();

    return StreamBuilder<int>(
      stream: notificationService.getUnreadCountStream(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Builder(
          builder: (buttonContext) => IconButton(
            tooltip: '${role.displayName} notifications',
            onPressed: () {
              showModalBottomSheet<void>(
                context: buttonContext,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                backgroundColor: Theme.of(buttonContext).colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => NotificationsBottomSheet(role: role),
              );
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_rounded),
                if (unreadCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC62828),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
