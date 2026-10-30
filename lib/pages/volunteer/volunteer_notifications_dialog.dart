import 'package:flutter/material.dart';
import '../../services/food_rescue_service.dart';
import '../../services/supabase_service.dart';

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
  List<VolunteerNotificationItem> _generateNotifications() {
    final currentUserId = SupabaseService.currentUser?.id;
    final allBatches = FoodRescueService.instance.batches;
    final availableTasks = FoodRescueService.instance.availableDeliveryTasks;

    final List<VolunteerNotificationItem> items = [];

    // 1. Available tasks nearby
    for (final task in availableTasks.take(3)) {
      items.add(VolunteerNotificationItem(
        id: 'avail-${task.id}',
        title: 'New Pickup Available',
        message: '${task.quantityPortions} meals from ${task.providerName} ready for dispatch to ${task.claimedByNgo ?? "Shelter"}.',
        timeAgo: 'Ready',
        icon: Icons.delivery_dining_rounded,
        iconColor: const Color(0xFFD97706),
        isRead: false,
      ));
    }

    // 2. Active courier tasks
    final activeTasks = allBatches.where((b) {
      final isMine = currentUserId != null && b.assignedCourierId == currentUserId;
      final isTransit = b.status == BatchStatus.inTransitToPickup ||
          b.status == BatchStatus.arrivedAtPickup ||
          b.status == BatchStatus.pickedUp ||
          b.status == BatchStatus.inTransit ||
          b.status == BatchStatus.arrivedAtReceiver;
      return isTransit && (isMine || currentUserId == null);
    });

    for (final b in activeTasks) {
      if (b.status == BatchStatus.pickedUp || b.status == BatchStatus.inTransit) {
        items.add(VolunteerNotificationItem(
          id: 'transit-${b.id}',
          title: 'Food Picked Up — In Transit',
          message: 'Proceed to ${b.receiverDropoffAddress ?? (b.claimedByNgo ?? "Shelter")}. Collect delivery OTP upon arrival.',
          timeAgo: 'In Transit',
          icon: Icons.two_wheeler_rounded,
          iconColor: const Color(0xFF2563EB),
          isRead: false,
        ));
      } else if (b.status == BatchStatus.arrivedAtPickup) {
        items.add(VolunteerNotificationItem(
          id: 'pickup-${b.id}',
          title: 'At Kitchen Dock',
          message: 'Ask kitchen staff at ${b.providerName} for the 4-digit pickup OTP.',
          timeAgo: 'Now',
          icon: Icons.vpn_key_rounded,
          iconColor: const Color(0xFFFFC107),
          isRead: false,
        ));
      }
    }

    // 3. Completed deliveries
    final completedTasks = allBatches.where((b) =>
        b.status == BatchStatus.delivered && (currentUserId == null || b.assignedCourierId == currentUserId)).take(2);

    for (final b in completedTasks) {
      items.add(VolunteerNotificationItem(
        id: 'done-${b.id}',
        title: 'Delivery Completed ✓',
        message: 'Successfully delivered ${b.quantityPortions} meals. Courier stipend credited to your payout balance.',
        timeAgo: 'Completed',
        icon: Icons.check_circle_rounded,
        iconColor: const Color(0xFF10B981),
        isRead: true,
      ));
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

            // Notifications List or Empty State
            Flexible(
              child: notifications.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
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
                              'New delivery opportunities and live task updates will appear here.',
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
