import 'package:flutter/material.dart';

class ReceiverNotificationItem {
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color iconColor;
  final bool isUnread;

  const ReceiverNotificationItem({
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.iconColor,
    this.isUnread = false,
  });
}

class ReceiverNotificationsDialog extends StatelessWidget {
  const ReceiverNotificationsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const ReceiverNotificationsDialog(),
    );
  }

  static const List<ReceiverNotificationItem> _notifications = [
    ReceiverNotificationItem(
      title: 'Food Claimed',
      message: 'Rice & Dal (50 meals) successfully claimed. Provider notified.',
      time: '12m ago',
      icon: Icons.check_circle_rounded,
      iconColor: Color(0xFF10B981),
      isUnread: true,
    ),
    ReceiverNotificationItem(
      title: 'Pickup Confirmed',
      message: 'Your food pickup has been confirmed by ABC Restaurant kitchen.',
      time: '35m ago',
      icon: Icons.done_all_rounded,
      iconColor: Color(0xFF3B82F6),
      isUnread: true,
    ),
    ReceiverNotificationItem(
      title: 'Provider is on the way',
      message: 'Volunteer courier Rahul Sharma is en route to your relief shelter.',
      time: '1h ago',
      icon: Icons.two_wheeler_rounded,
      iconColor: Color(0xFFD97706),
    ),
    ReceiverNotificationItem(
      title: 'Food Distributed',
      message: '50 meals were successfully distributed to community shelter families.',
      time: '3h ago',
      icon: Icons.volunteer_activism_rounded,
      iconColor: Color(0xFF10B981),
    ),
    ReceiverNotificationItem(
      title: 'New Food Available',
      message: 'Roti & Sabzi (35 portions) is available near you from Taj Culinary Kitchen.',
      time: '5h ago',
      icon: Icons.soup_kitchen_rounded,
      iconColor: Color(0xFFFFC107),
    ),
    ReceiverNotificationItem(
      title: 'Impact Updated',
      message: 'You helped redistribute 120 kg of surplus food this week. Thank you!',
      time: '1d ago',
      icon: Icons.eco_rounded,
      iconColor: Color(0xFF059669),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(20),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFD97706), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relief Notifications',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        'Real-time updates on food claims & delivery',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
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
                          child: Icon(item.icon, size: 16, color: item.iconColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: item.isUnread ? FontWeight.w900 : FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (item.isUnread) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFC107),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(
                                    item.time,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.message,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
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
