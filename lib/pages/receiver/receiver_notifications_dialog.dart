import 'package:flutter/material.dart';

import '../../services/food_rescue_service.dart';
import '../../services/supabase_service.dart';

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

  List<ReceiverNotificationItem> _generateNotifications() {
    final user = SupabaseService.currentUser;
    final meta = user?.userMetadata ?? {};
    final receiverOrg = (meta['organization_name'] ??
            meta['full_name'] ??
            meta['name'] ??
            (user?.email?.split('@').first ?? ''))
        .toString()
        .trim()
        .toLowerCase();

    final allBatches = FoodRescueService.instance.batches;
    final myBatches = allBatches.where((b) {
      if (b.status == BatchStatus.available) return false;
      if (b.claimedByNgoId != null && user != null && b.claimedByNgoId == user.id) return true;
      if (b.claimedByNgo != null && receiverOrg.isNotEmpty && b.claimedByNgo!.toLowerCase().contains(receiverOrg)) return true;
      return false;
    }).toList();

    final List<ReceiverNotificationItem> items = [];

    for (final b in myBatches) {
      if (b.status == BatchStatus.delivered) {
        items.add(ReceiverNotificationItem(
          title: 'Food Distributed',
          message: '${b.quantityPortions} meals from ${b.providerName} successfully delivered and confirmed.',
          time: 'Delivered',
          icon: Icons.volunteer_activism_rounded,
          iconColor: const Color(0xFF10B981),
        ));
      } else if (b.status == BatchStatus.pickedUp || b.status == BatchStatus.inTransit) {
        items.add(ReceiverNotificationItem(
          title: 'Volunteer En Route',
          message: '${b.assignedCourierName ?? "Courier"} has collected food from ${b.providerName} and is in transit.',
          time: 'Active',
          icon: Icons.two_wheeler_rounded,
          iconColor: const Color(0xFFD97706),
          isUnread: true,
        ));
      } else if (b.status == BatchStatus.arrivedAtReceiver) {
        items.add(ReceiverNotificationItem(
          title: 'Volunteer Arrived',
          message: '${b.assignedCourierName ?? "Courier"} has arrived at your shelter dock with ${b.quantityPortions} meals.',
          time: 'Now',
          icon: Icons.verified_rounded,
          iconColor: const Color(0xFF2563EB),
          isUnread: true,
        ));
      } else if (b.status == BatchStatus.claimed || b.status == BatchStatus.volunteerAssigning || b.status == BatchStatus.inTransitToPickup) {
        items.add(ReceiverNotificationItem(
          title: 'Food Claimed',
          message: '${b.title} (${b.quantityPortions} meals) claimed. Volunteer courier assignment in progress.',
          time: 'Pending',
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF10B981),
          isUnread: true,
        ));
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _generateNotifications();

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

            // Notifications List or Empty State
            Flexible(
              child: notifications.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 44, color: Color(0xFF94A3B8)),
                            SizedBox(height: 10),
                            Text(
                              'No notifications right now',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Real-time updates on your claimed food and courier deliveries will appear here.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, idx) {
                        final item = notifications[idx];
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
