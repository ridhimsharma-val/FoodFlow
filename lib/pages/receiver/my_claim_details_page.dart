import 'package:flutter/material.dart';
import '../../services/food_rescue_service.dart';
import '../../widgets/rescue_assignment_loading_screen.dart';
import '../../widgets/shared_rescue_tracking_page.dart';
import 'receiver_provider_details_dialog.dart';

class MyClaimDetailsPage extends StatefulWidget {
  final SurplusBatch batch;

  const MyClaimDetailsPage({
    super.key,
    required this.batch,
  });

  @override
  State<MyClaimDetailsPage> createState() => _MyClaimDetailsPageState();
}

class _MyClaimDetailsPageState extends State<MyClaimDetailsPage> {
  bool _hasShownConnectingModal = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        final liveBatch = FoodRescueService.instance.batches.firstWhere(
          (b) => b.id == widget.batch.id,
          orElse: () => widget.batch,
        );

        if (liveBatch.status == BatchStatus.volunteerAssigning && !_hasShownConnectingModal) {
          _hasShownConnectingModal = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              RescueAssignmentLoadingScreen.show(
                context,
                batch: liveBatch,
                role: RescueLoadingRole.receiver,
                autoNavigateToTracking: true,
              );
            }
          });
        }

        final isDelivered = liveBatch.status == BatchStatus.delivered;
        final isPickedUp = liveBatch.status == BatchStatus.pickedUp || isDelivered;
        final isConfirmed = liveBatch.status == BatchStatus.inTransitToPickup || isPickedUp;
        final isClaimed = liveBatch.status == BatchStatus.claimed || isConfirmed;
        final deliveryPin = liveBatch.deliveryOtp;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'My Claim',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Provider Information',
                icon: const Icon(Icons.storefront_rounded, color: Color(0xFF1E293B)),
                onPressed: () {
                  ReceiverProviderDetailsDialog.show(
                    context,
                    providerName: liveBatch.providerName,
                    providerCategory: liveBatch.providerCategory,
                    location: liveBatch.pickupAddress,
                    distanceKm: 1.2,
                    activePortions: liveBatch.quantityPortions,
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Food Overview Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text('🍲', style: TextStyle(fontSize: 28)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  liveBatch.title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${liveBatch.quantityPortions} servings • ${liveBatch.category} • ${liveBatch.dietaryType}',
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.place_rounded, size: 14, color: Color(0xFFD97706)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${liveBatch.providerName} • 1.2 km away',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                        overflow: TextOverflow.ellipsis,
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
                    const SizedBox(height: 16),

                    // Pickup Window Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFC107)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded, color: Color(0xFFB45309), size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scheduled Pickup Window',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                                ),
                                Text(
                                  'Today, 7:00 PM – 8:00 PM',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isConfirmed ? 'Pickup Confirmed' : 'Waiting for provider confirmation',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isConfirmed ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Delivery Verification OTP Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDelivered ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDelivered ? const Color(0xFF86EFAC) : const Color(0xFFFFC107),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isDelivered ? Icons.verified_rounded : Icons.pin_outlined,
                                  color: isDelivered ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Delivery Verification OTP',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: isDelivered ? const Color(0xFF166534) : const Color(0xFF92400E),
                                      ),
                                    ),
                                    Text(
                                      isDelivered
                                          ? 'Verified • Food received successfully'
                                          : 'Share with volunteer courier at drop-off',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDelivered ? const Color(0xFF15803D) : const Color(0xFF78350F),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDelivered ? const Color(0xFF86EFAC) : const Color(0xFFFFC107),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                     BoxShadow(
                                       color: Colors.black.withValues(alpha: 0.04),
                                       blurRadius: 4,
                                       offset: const Offset(0, 2),
                                     ),
                                  ],
                                ),
                                child: Text(
                                  deliveryPin,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4,
                                    color: isDelivered ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isDelivered
                                ? '✅ Delivery verified! Food package successfully authenticated and received at your facility.'
                                : 'When the volunteer courier arrives at your drop-off point, share this 4-digit OTP. The courier will enter it in their app to verify physical handover and complete distribution.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDelivered ? const Color(0xFF166534) : const Color(0xFF78350F),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status Timeline
                    const Text(
                      'Claim & Distribution Timeline',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildTimelineStep(
                            title: 'Claimed',
                            subtitle: 'Claim registered by your relief organization',
                            isCompleted: isClaimed,
                            isLast: false,
                            icon: Icons.check_circle_rounded,
                          ),
                          _buildTimelineStep(
                            title: 'Pickup Confirmed',
                            subtitle: isConfirmed
                                ? 'Provider prepared cambros & confirmed readiness'
                                : 'Waiting for provider kitchen confirmation...',
                            isCompleted: isConfirmed,
                            isLast: false,
                            icon: Icons.kitchen_rounded,
                          ),
                          _buildTimelineStep(
                            title: 'Handed Over',
                            subtitle: isPickedUp
                                ? 'Volunteer courier received food package'
                                : 'Pickup transit pending handover',
                            isCompleted: isPickedUp,
                            isLast: false,
                            icon: Icons.two_wheeler_rounded,
                          ),
                          _buildTimelineStep(
                            title: 'Completed',
                            subtitle: isDelivered
                                ? 'Successfully delivered to beneficiaries'
                                : 'Beneficiary distribution pending receipt',
                            isCompleted: isDelivered,
                            isLast: true,
                            icon: Icons.favorite_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                // Courier or Transit Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFDBEAFE),
                        radius: 20,
                        child: Icon(Icons.two_wheeler_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              liveBatch.assignedCourierName ?? 'Rahul Sharma (Volunteer Squad)',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              liveBatch.assignedCourierPhone ?? '+91 95556 51225',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'En Route',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Track Delivery Button (only when volunteer has explicitly accepted)
                if (liveBatch.isVolunteerAcceptedAndActive) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        SharedRescueTrackingPage.open(
                          context,
                          batch: liveBatch,
                          role: RescueTrackingRole.receiver,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 20, color: Color(0xFFFFC107)),
                      label: const Text(
                        'Track Live Delivery (GPS)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Contact Provider Action Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ReceiverProviderDetailsDialog.show(
                        context,
                        providerName: liveBatch.providerName,
                        providerCategory: liveBatch.providerCategory,
                        location: liveBatch.pickupAddress,
                        distanceKm: 1.2,
                        activePortions: liveBatch.quantityPortions,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 20, color: Color(0xFF1E293B)),
                    label: const Text(
                      'Contact Provider',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF1E293B)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  },
);
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isLast,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? const Color(0xFFFFC107) : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isCompleted ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? const Color(0xFFFFC107) : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isCompleted ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
