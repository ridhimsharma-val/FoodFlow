import 'package:flutter/material.dart';
import '../../services/food_rescue_service.dart';
import 'volunteer_accept_task_dialog.dart';

class VolunteerTaskDetailsDialog extends StatelessWidget {
  final SurplusBatch batch;
  final double pickupDistanceKm;
  final double deliveryDistanceKm;
  final double totalRouteKm;
  final String pickupWindow;
  final VoidCallback? onTaskAccepted;

  const VolunteerTaskDetailsDialog({
    super.key,
    required this.batch,
    required this.pickupDistanceKm,
    required this.deliveryDistanceKm,
    required this.totalRouteKm,
    required this.pickupWindow,
    this.onTaskAccepted,
  });

  static Future<void> show(
    BuildContext context, {
    required SurplusBatch batch,
    required double pickupDistanceKm,
    required double deliveryDistanceKm,
    required double totalRouteKm,
    required String pickupWindow,
    VoidCallback? onTaskAccepted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => VolunteerTaskDetailsDialog(
        batch: batch,
        pickupDistanceKm: pickupDistanceKm,
        deliveryDistanceKm: deliveryDistanceKm,
        totalRouteKm: totalRouteKm,
        pickupWindow: pickupWindow,
        onTaskAccepted: onTaskAccepted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header image/accent strip
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: Color(0xFFFFC107), width: 1.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delivery_dining_rounded, color: Color(0xFFD97706), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            batch.title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${batch.quantityPortions} meals • Food Rescue Task',
                            style: const TextStyle(fontSize: 13, color: Color(0xFFB45309), fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Food type badge & portions
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              '${batch.foodEmoji} ${batch.category} • ${batch.dietaryType}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${batch.quantityPortions} meals',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Route Overview Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          // Pickup Node
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFFFC107), width: 2),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.store_rounded, size: 14, color: Color(0xFFD97706)),
                                    ),
                                  ),
                                  Container(width: 2, height: 32, color: const Color(0xFFCBD5E1)),
                                ],
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
                                            'Provider: ${batch.providerName}',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E293B)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$pickupDistanceKm km away',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Pickup Location: ${batch.pickupAddress}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Dropoff Node
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF10B981), width: 2),
                                ),
                                child: const Center(
                                  child: Icon(Icons.volunteer_activism_rounded, size: 14, color: Color(0xFF10B981)),
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
                                            'Receiver: ${batch.claimedByNgo ?? 'Helping Hands NGO'}',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E293B)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$deliveryDistanceKm km away',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Delivery Location: ${batch.receiverDropoffAddress ?? 'Helping Hands Shelter, Greater Noida'}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Route Specifications
                    _buildInfoRow(Icons.timeline_rounded, 'Total route:', '$totalRouteKm km'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.access_time_rounded, 'Pickup Window:', pickupWindow),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.shield_outlined, 'Special Instructions:', batch.specialInstructions ?? 'Handle with care'),
                    const SizedBox(height: 22),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              VolunteerAcceptTaskDialog.show(
                                context,
                                batch: batch,
                                pickupDistanceKm: pickupDistanceKm,
                                deliveryDistanceKm: deliveryDistanceKm,
                                totalRouteKm: totalRouteKm,
                                onAcceptSuccess: onTaskAccepted,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC107),
                              foregroundColor: const Color(0xFF1E293B),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: const Text('Accept Task', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
