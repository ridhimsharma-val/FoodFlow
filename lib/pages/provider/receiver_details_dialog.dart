import 'package:flutter/material.dart';
import '../../services/matching_service.dart';

class ReceiverDetailsDialog extends StatelessWidget {
  final ReceiverMatch receiver;
  final int? mealsRequested;
  final String? pickupTimeWindow;
  final String? pickupStatus;

  const ReceiverDetailsDialog({
    super.key,
    required this.receiver,
    this.mealsRequested,
    this.pickupTimeWindow,
    this.pickupStatus,
  });

  static void show(
    BuildContext context, {
    required ReceiverMatch receiver,
    int? mealsRequested,
    String? pickupTimeWindow,
    String? pickupStatus,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReceiverDetailsDialog(
        receiver: receiver,
        mealsRequested: mealsRequested,
        pickupTimeWindow: pickupTimeWindow,
        pickupStatus: pickupStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.volunteer_activism_rounded, color: Color(0xFFD97706), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              receiver.organizationName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        receiver.category,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),

            // Details List
            _buildDetailRow(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFFEF4444),
              label: 'Location & Distance',
              value: '${receiver.locationAddress} (${receiver.distanceKm.toStringAsFixed(1)} km away)',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.person_rounded,
              iconColor: const Color(0xFF3B82F6),
              label: 'Representative',
              value: receiver.representative,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.phone_rounded,
              iconColor: const Color(0xFF10B981),
              label: 'Contact Information',
              value: receiver.contactPhone,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.restaurant_menu_rounded,
              iconColor: const Color(0xFFD97706),
              label: 'Meals Requested / Capacity',
              value: '${mealsRequested ?? receiver.intakeCapacity} meals (Daily Intake: ${receiver.intakeCapacity})',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFF8B5CF6),
              label: 'Pickup Window & Status',
              value: '${pickupTimeWindow ?? "7:00 PM – 8:00 PM"} • ${pickupStatus ?? "Ready for Handover"}',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.notes_rounded,
              iconColor: const Color(0xFF64748B),
              label: 'Relevant Notes',
              value: receiver.operatingNotes,
            ),

            const SizedBox(height: 24),

            // Primary Contact Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF1E293B),
                      content: Row(
                        children: [
                          const Icon(Icons.call_rounded, color: Color(0xFFFFC107), size: 18),
                          const SizedBox(width: 8),
                          Text('Dialing ${receiver.organizationName} (${receiver.contactPhone})...'),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.phone_rounded, size: 20),
                label: const Text(
                  'Contact Receiver',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
