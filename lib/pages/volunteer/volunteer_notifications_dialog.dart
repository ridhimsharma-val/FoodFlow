import 'package:flutter/material.dart';

class VolunteerNotificationItem {
  final String id;
  final String title;
  final String message;
  final String timeAgo;
  final IconData icon;
  final Color iconColor;
  final bool isRead;

  const VolunteerNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.icon,
    required this.iconColor,
    this.isRead = false,
  });
}

class VolunteerNotificationsDialog extends StatefulWidget {
  const VolunteerNotificationsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const VolunteerNotificationsDialog(),
    );
  }

  @override
  State<VolunteerNotificationsDialog> createState() => _VolunteerNotificationsDialogState();
}

class _VolunteerNotificationsDialogState extends State<VolunteerNotificationsDialog> {
  final List<VolunteerNotificationItem> _notifications = [
    const VolunteerNotificationItem(
      id: 'vn-1',
      title: 'New Task Nearby',
      message: '50 meals are available for pickup 1.2 km away at ABC Restaurant.',
      timeAgo: '5 mins ago',
      icon: Icons.delivery_dining_rounded,
      iconColor: Color(0xFFD97706),
      isRead: false,
    ),
    const VolunteerNotificationItem(
      id: 'vn-2',
      title: 'Task Accepted',
      message: "You've accepted the Rice & Dal delivery to Helping Hands NGO.",
      timeAgo: '25 mins ago',
      icon: Icons.check_circle_rounded,
      iconColor: Color(0xFF10B981),
      isRead: true,
    ),
    const VolunteerNotificationItem(
      id: 'vn-3',
      title: 'Pickup Confirmed',
      message: 'Food has been collected from ABC Restaurant. Route updated.',
      timeAgo: '45 mins ago',
      icon: Icons.inventory_2_rounded,
      iconColor: Color(0xFF2563EB),
      isRead: true,
    ),
    const VolunteerNotificationItem(
      id: 'vn-4',
      title: 'Delivery Reminder',
      message: 'Helping Hands NGO is expecting your delivery within 20 mins.',
      timeAgo: '1 hour ago',
      icon: Icons.alarm_rounded,
      iconColor: Color(0xFFD97706),
      isRead: true,
    ),
    const VolunteerNotificationItem(
      id: 'vn-5',
      title: 'Delivery Completed',
      message: '50 meals successfully delivered. 25 kg food saved from waste!',
      timeAgo: '2 hours ago',
      icon: Icons.volunteer_activism_rounded,
      iconColor: Color(0xFF16A34A),
      isRead: true,
    ),
    const VolunteerNotificationItem(
      id: 'vn-6',
      title: 'Urgent Task',
      message: '40 meals nearby are approaching their best-consumed-before time.',
      timeAgo: '3 hours ago',
      icon: Icons.priority_high_rounded,
      iconColor: Color(0xFFEA580C),
      isRead: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(22),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active_rounded, color: Color(0xFFD97706), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Notifications',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Notifications List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _notifications.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (ctx, idx) {
                  final item = _notifications[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: item.iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.icon, color: item.iconColor, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: item.isRead ? FontWeight.w700 : FontWeight.w900,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    item.timeAgo,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.message,
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
