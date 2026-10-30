import 'package:flutter/material.dart';

class ReceiverProviderDetailsDialog extends StatelessWidget {
  final String providerName;
  final String providerCategory;
  final String location;
  final double distanceKm;
  final int activePortions;
  final String pickupTime;

  const ReceiverProviderDetailsDialog({
    super.key,
    required this.providerName,
    required this.providerCategory,
    required this.location,
    required this.distanceKm,
    this.activePortions = 50,
    this.pickupTime = 'Today, 7:00 PM – 8:00 PM',
  });

  static Future<void> show(
    BuildContext context, {
    required String providerName,
    required String providerCategory,
    required String location,
    required double distanceKm,
    int activePortions = 50,
    String pickupTime = 'Today, 7:00 PM – 8:00 PM',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReceiverProviderDetailsDialog(
        providerName: providerName,
        providerCategory: providerCategory,
        location: location,
        distanceKm: distanceKm,
        activePortions: activePortions,
        pickupTime: pickupTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(22),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    child: const Icon(Icons.restaurant_rounded, color: Color(0xFFD97706), size: 26),
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
                                providerName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF3B82F6)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$providerCategory • Verified Kitchen Partner',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
              const SizedBox(height: 18),

              // Rating / Reliability Metric Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFC107)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reliability Rating: 4.9 ★ (98% on-time dispatch rate)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Details Group
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildRow(Icons.place_rounded, 'Location', location),
                    const Divider(height: 12, color: Color(0xFFE2E8F0)),
                    _buildRow(Icons.near_me_rounded, 'Distance', '${distanceKm.toStringAsFixed(1)} km from your hub'),
                    const Divider(height: 12, color: Color(0xFFE2E8F0)),
                    _buildRow(Icons.soup_kitchen_rounded, 'Meals Available', '$activePortions servings'),
                    const Divider(height: 12, color: Color(0xFFE2E8F0)),
                    _buildRow(Icons.schedule_rounded, 'Pickup Time', pickupTime),
                    const Divider(height: 12, color: Color(0xFFE2E8F0)),
                    _buildRow(Icons.check_circle_outline_rounded, 'Current Status', 'Kitchen Open • Packaging Active'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Contact Provider Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF1E293B),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        content: Row(
                          children: [
                            const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFFFC107), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('Calling $providerName Dispatch Desk: +91 98765 12345'),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: const Color(0xFF1E293B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: const Text(
                    'Contact Provider',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }
}
