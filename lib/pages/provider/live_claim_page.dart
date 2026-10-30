import 'package:flutter/material.dart';
import '../../services/food_rescue_service.dart';
import '../../services/matching_service.dart';
import '../../widgets/rescue_assignment_loading_screen.dart';
import '../../widgets/shared_rescue_tracking_page.dart';
import 'receiver_details_dialog.dart';

class LiveClaimPage extends StatefulWidget {
  final SurplusBatch batch;

  const LiveClaimPage({super.key, required this.batch});

  static void open(BuildContext context, SurplusBatch batch) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => LiveClaimPage(batch: batch)),
    );
  }

  @override
  State<LiveClaimPage> createState() => _LiveClaimPageState();
}

class _LiveClaimPageState extends State<LiveClaimPage> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerifyingOtp = false;
  bool _hasShownConnectingModal = false;

  int _getTimelineStep(BatchStatus status) {
    switch (status) {
      case BatchStatus.available:
        return 0;
      case BatchStatus.claimed:
        return 1;
      case BatchStatus.volunteerAssigning:
      case BatchStatus.inTransitToPickup:
      case BatchStatus.arrivedAtPickup:
        return 2;
      case BatchStatus.pickedUp:
      case BatchStatus.inTransit:
      case BatchStatus.arrivedAtReceiver:
        return 3;
      case BatchStatus.delivered:
        return 4;
      case BatchStatus.expired:
      case BatchStatus.cancelled:
      case BatchStatus.reassigning:
        return -1;
    }
  }

  void _verifyPickupPin(SurplusBatch liveBatch) {
    final entered = _otpController.text.trim();
    if (entered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 4-digit Handover PIN')),
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);
    final success = FoodRescueService.instance.verifyPickupOtp(liveBatch.id, entered);
    setState(() => _isVerifyingOtp = false);

    if (success) {
      _otpController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Handover verified! Food handed over to ${liveBatch.assignedCourierName ?? "courier"}.'),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Incorrect PIN. The correct kitchen PIN is ${liveBatch.pickupOtp}.'),
        ),
      );
    }
  }

  Future<void> _confirmWithdraw(BuildContext context, SurplusBatch batch) async {
    final isClaimed = batch.status != BatchStatus.available;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isClaimed ? 'Cancel & Withdraw Batch?' : 'Withdraw Listing?',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to withdraw "${batch.title}" (${batch.quantityPortions} servings)?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isClaimed
                          ? 'This batch has been claimed. Withdrawing will cancel the reservation, notify receivers and courier, and immediately delete the batch.'
                          : 'This will immediately delist this surplus food batch from the public network.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go Back', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: Text(isClaimed ? 'Cancel & Withdraw' : 'Withdraw Food'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await FoodRescueService.instance.deleteBatch(batch.id);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? const Color(0xFF1E293B) : const Color(0xFFEF4444),
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    success
                        ? 'Batch "${batch.title}" has been withdrawn and removed.'
                        : 'Failed to withdraw batch. Please try again.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        // Fetch fresh copy from service
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
                role: RescueLoadingRole.provider,
                autoNavigateToTracking: true,
              );
            }
          });
        }

        final currentStep = _getTimelineStep(liveBatch.status);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Live Claim Management',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            actions: [
              if (liveBatch.status != BatchStatus.delivered)
                IconButton(
                  tooltip: 'Withdraw Listing',
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  onPressed: () => _confirmWithdraw(context, liveBatch),
                ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Food Header Card
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
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text('🍲', style: TextStyle(fontSize: 30)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  liveBatch.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFC107),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${liveBatch.quantityPortions} meals',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      liveBatch.category,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '• ${liveBatch.dietaryType}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.w600,
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

                    const SizedBox(height: 20),

                    // Dynamic Pricing & Recovery Impact Card
                    _buildRecoveryImpactCard(liveBatch),

                    const SizedBox(height: 24),

                    // Claimed by Section
                    const Text(
                      'Claimed By',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.volunteer_activism_rounded, color: Color(0xFFD97706), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      liveBatch.claimedByNgo ?? 'Helping Hands NGO',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      '2.4 km away • Verified Relief Partner',
                                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    ReceiverDetailsDialog.show(
                                      context,
                                      receiver: ReceiverMatch(
                                        id: liveBatch.claimedByNgoId ?? 'REC-001',
                                        organizationName: liveBatch.claimedByNgo ?? 'Helping Hands NGO',
                                        category: 'Disaster Relief & Orphan Care',
                                        representative: 'Sister Teresa Maria',
                                        contactPhone: '+91 98765 43210',
                                        locationAddress: '2nd Cross, Indira Nagar',
                                        distanceKm: 2.4,
                                        intakeCapacity: 60,
                                        matchScorePercentage: 96,
                                        matchReasons: ['Closest location', 'Verified NGO'],
                                      ),
                                      mealsRequested: liveBatch.quantityPortions,
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text(
                                    'View Receiver',
                                    style: TextStyle(
                                      color: Color(0xFF1E293B),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Contacting ${liveBatch.claimedByNgo ?? "Receiver"}...'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFC107),
                                    foregroundColor: const Color(0xFF1E293B),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.phone_rounded, size: 18),
                                  label: const Text(
                                    'Contact',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Visual Progress Timeline
                    const Text(
                      'Rescue Progress Timeline',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildTimeline(currentStep),

                    if (liveBatch.assignedCourierId != null ||
                        liveBatch.status == BatchStatus.inTransitToPickup ||
                        liveBatch.status == BatchStatus.arrivedAtPickup ||
                        liveBatch.status == BatchStatus.pickedUp ||
                        liveBatch.status == BatchStatus.inTransit) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFC107), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFFD97706), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    liveBatch.assignedCourierName != null
                                        ? 'Volunteer ${liveBatch.assignedCourierName} Connected'
                                        : 'Volunteer En Route',
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    liveBatch.distanceRemainingKm != null
                                        ? '${liveBatch.distanceRemainingKm} km away • Live map updates active'
                                        : 'Live GPS route tracking active',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                SharedRescueTrackingPage.open(
                                  context,
                                  batch: liveBatch,
                                  role: RescueTrackingRole.provider,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              icon: const Icon(Icons.map_rounded, size: 16),
                              label: const Text('Track Live', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Handover OTP Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.key_rounded, color: Color(0xFFFFC107), size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Kitchen Handover PIN',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'PIN: ${liveBatch.pickupOtp}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Share this 4-digit PIN with the visiting volunteer or receiver courier at the dock to confirm food handover.',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
                          ),
                          if (liveBatch.status == BatchStatus.claimed ||
                              liveBatch.status == BatchStatus.inTransitToPickup) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _otpController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 4,
                                    decoration: InputDecoration(
                                      counterText: '',
                                      hintText: 'Verify Courier PIN',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: _isVerifyingOtp ? null : () => _verifyPickupPin(liveBatch),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFC107),
                                    foregroundColor: const Color(0xFF1E293B),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  child: const Text('Verify Handover', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (liveBatch.status != BatchStatus.delivered) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Withdraw Food Listing',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF991B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    liveBatch.status == BatchStatus.available
                                        ? 'Remove this food listing immediately from the network.'
                                        : 'Cancel this claim and release volunteers & receivers.',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () => _confirmWithdraw(context, liveBatch),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Withdraw', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeline(int currentStep) {
    final stages = [
      {'title': 'Available', 'desc': 'Food listed publicly on network'},
      {'title': 'Claimed', 'desc': 'NGO claimed batch & reserved pickup'},
      {'title': 'Pickup Confirmed', 'desc': 'Courier assigned and en route'},
      {'title': 'Handed Over', 'desc': 'Kitchen handover verified with PIN'},
      {'title': 'Completed', 'desc': 'Delivered and meals served'},
    ];

    return Column(
      children: List.generate(stages.length, (idx) {
        final isPast = currentStep > idx;
        final isCurrent = currentStep == idx;
        final isLast = idx == stages.length - 1;

        Color circleColor = const Color(0xFFE2E8F0);
        Color textColor = const Color(0xFF94A3B8);
        Widget iconWidget = Text('${idx + 1}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w700));

        if (isPast) {
          circleColor = const Color(0xFF10B981);
          textColor = const Color(0xFF1E293B);
          iconWidget = const Icon(Icons.check_rounded, color: Colors.white, size: 14);
        } else if (isCurrent) {
          circleColor = const Color(0xFFFFC107);
          textColor = const Color(0xFF1E293B);
          iconWidget = const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF1E293B), size: 14);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: iconWidget),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 36,
                    color: isPast ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stages[idx]['title']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isCurrent || isPast ? FontWeight.w800 : FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stages[idx]['desc']!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildRecoveryImpactCard(SurplusBatch liveBatch) {
    final baseTotal = liveBatch.basePrice * liveBatch.quantityPortions;
    final finalUnitPrice = liveBatch.lockedUnitPrice ?? liveBatch.dynamicPricing.currentPrice;
    final finalTotal = liveBatch.lockedTotalPrice ?? (finalUnitPrice * liveBatch.quantityPortions);
    final String discountLabel = (liveBatch.discountAtPurchase ?? liveBatch.dynamicPricing.discountBadge).toString();
    final isLocked = liveBatch.lockedUnitPrice != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.6), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.insights_rounded, size: 18, color: Color(0xFFB45309)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Redistribution Recovery Impact',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isLocked ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isLocked ? const Color(0xFF10B981) : const Color(0xFFFFC107)),
                ),
                child: Text(
                  isLocked ? 'Price Locked' : 'Live Dynamic',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isLocked ? const Color(0xFF065F46) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildImpactMetric(
                  'Original Value',
                  '₹${baseTotal.toStringAsFixed(0)}',
                  '₹${liveBatch.basePrice.toStringAsFixed(0)} / portion',
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFFCBD5E1)),
              Expanded(
                child: _buildImpactMetric(
                  isLocked ? 'Locked Recovery' : 'Current Valuation',
                  '₹${finalTotal.toStringAsFixed(0)}',
                  '₹${finalUnitPrice.toStringAsFixed(1)} / portion',
                  highlightColor: const Color(0xFFD97706),
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFFCBD5E1)),
              Expanded(
                child: _buildImpactMetric(
                  'Markdown',
                  discountLabel,
                  'NGO incentive',
                  highlightColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isLocked
                      ? 'Transaction finalized: Price locked at claim confirmation.'
                      : 'Decaying markdown model encourages prompt rescue before freshness lapses.',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactMetric(String label, String value, String subtext, {Color? highlightColor}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: highlightColor ?? const Color(0xFF1E293B)),
        ),
        const SizedBox(height: 1),
        Text(subtext, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
      ],
    );
  }
}
