import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/food_rescue_service.dart';
import 'osm_map_widget.dart';

enum RescueTrackingRole {
  provider,
  receiver,
  volunteer,
}

class SharedRescueTrackingPage extends StatefulWidget {
  final SurplusBatch batch;
  final RescueTrackingRole role;

  const SharedRescueTrackingPage({
    super.key,
    required this.batch,
    required this.role,
  });

  static void open(
    BuildContext context, {
    required SurplusBatch batch,
    required RescueTrackingRole role,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SharedRescueTrackingPage(batch: batch, role: role),
      ),
    );
  }

  @override
  State<SharedRescueTrackingPage> createState() => _SharedRescueTrackingPageState();
}

class _SharedRescueTrackingPageState extends State<SharedRescueTrackingPage> {
  final TextEditingController _otpInputCtrl = TextEditingController();
  String? _otpError;
  bool _isDetailsExpanded = true;
  double _currentSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    // Non-test environment: auto-start simulation if in transit
    bool isTest = false;
    try {
      isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      isTest = true;
    }
    if (!isTest && widget.role == RescueTrackingRole.volunteer) {
      FoodRescueService.instance.startSimulatedMovement(widget.batch.id, speedMultiplier: _currentSpeed);
    }
  }

  @override
  void dispose() {
    _otpInputCtrl.dispose();
    super.dispose();
  }

  int _getTimelineIndex(BatchStatus status) {
    switch (status) {
      case BatchStatus.available:
        return 0; // Listed
      case BatchStatus.claimed:
        return 1; // Claimed
      case BatchStatus.volunteerAssigning:
      case BatchStatus.inTransitToPickup:
        return 2; // Volunteer Assigned
      case BatchStatus.arrivedAtPickup:
        return 3; // Going/Arrived to Pickup
      case BatchStatus.pickedUp:
        return 4; // Picked Up
      case BatchStatus.inTransit:
      case BatchStatus.arrivedAtReceiver:
        return 5; // In Transit
      case BatchStatus.delivered:
        return 6; // Delivered
      case BatchStatus.expired:
      case BatchStatus.cancelled:
      case BatchStatus.reassigning:
        return -1;
    }
  }

  Color _getSafeTimeColor(Duration remaining) {
    if (remaining.inMinutes > 60) {
      return const Color(0xFF10B981); // Green (Safe window)
    } else if (remaining.inMinutes >= 30) {
      return const Color(0xFFF59E0B); // Orange (Urgent)
    } else {
      return const Color(0xFFEF4444); // Red (Critical)
    }
  }

  String _formatSafeTime(Duration remaining) {
    if (remaining == Duration.zero) return 'Expired';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return '$hours hr ${minutes}m left';
    }
    return '$minutes min left';
  }

  void _verifyPickupPinModal(SurplusBatch liveBatch) {
    _otpInputCtrl.clear();
    _otpError = null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.vpn_key_rounded, color: Color(0xFFFFC107)),
                SizedBox(width: 10),
                Text(
                  'Verify Pickup Handover',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the 4-digit Kitchen PIN provided by ${liveBatch.providerName} staff at the dock.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _otpInputCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    hintStyle: const TextStyle(letterSpacing: 8, color: Color(0xFFCBD5E1)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    errorText: _otpError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFC107), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '(Provider Kitchen PIN: ${liveBatch.pickupOtp})',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                onPressed: () {
                  final entered = _otpInputCtrl.text.trim();
                  if (entered.isEmpty) {
                    setModalState(() => _otpError = 'Please enter 4 digits');
                    return;
                  }
                  final valid = FoodRescueService.instance.verifyPickupOtp(liveBatch.id, entered);
                  if (valid) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF10B981),
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Handover confirmed! Food loaded from ${liveBatch.providerName}.'),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    setModalState(() => _otpError = 'Incorrect PIN. Check with kitchen staff.');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Verify & Collect', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _verifyDeliveryPinModal(SurplusBatch liveBatch) {
    _otpInputCtrl.clear();
    _otpError = null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.verified_rounded, color: Color(0xFF10B981)),
                SizedBox(width: 10),
                Text(
                  'Confirm Final Delivery',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask ${liveBatch.claimedByNgo ?? "Shelter"} representative for the 4-digit Delivery OTP.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _otpInputCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    hintStyle: const TextStyle(letterSpacing: 8, color: Color(0xFFCBD5E1)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    errorText: _otpError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '(Receiver Shelter OTP: ${liveBatch.deliveryOtp})',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                onPressed: () {
                  final entered = _otpInputCtrl.text.trim();
                  if (entered.isEmpty) {
                    setModalState(() => _otpError = 'Please enter 4 digits');
                    return;
                  }
                  final valid = FoodRescueService.instance.verifyDeliveryOtp(liveBatch.id, entered);
                  if (valid) {
                    Navigator.pop(ctx);
                    _showCelebrationDialog(liveBatch);
                  } else {
                    setModalState(() => _otpError = 'Incorrect OTP. Check with receiver staff.');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Confirm Handover', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCelebrationDialog(SurplusBatch batch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFDCFCE7),
              ),
              child: const Center(
                child: Text('🎉', style: TextStyle(fontSize: 42)),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Rescue Completed! 🎉',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${batch.quantityPortions} meals safely transported from ${batch.providerName} to ${batch.claimedByNgo ?? "Shelter"}. Zero food wasted!',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Finish & Return', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        final liveBatch = FoodRescueService.instance.batches.firstWhere(
          (b) => b.id == widget.batch.id,
          orElse: () => widget.batch,
        );

        final safeRemaining = liveBatch.remainingSafeTime;
        final safeColor = _getSafeTimeColor(safeRemaining);
        final currentStepIndex = _getTimelineIndex(liveBatch.status);

        final volunteerPos = liveBatch.courierLocation;
        final providerPos = liveBatch.location;
        final receiverPos = liveBatch.receiverCoordinates;

        // Construct map markers
        final markers = <OsmMapMarkerData>[
          // Provider Kitchen Marker
          OsmMapMarkerData(
            point: providerPos,
            label: liveBatch.providerName,
            subtitle: 'Pickup: ${liveBatch.quantityPortions} meals',
            badgeText: 'Pickup Dock',
            badgeColor: const Color(0xFFD97706),
            icon: Icons.storefront_rounded,
            iconColor: const Color(0xFFD97706),
          ),
          // Receiver Shelter Marker
          OsmMapMarkerData(
            point: receiverPos,
            label: liveBatch.claimedByNgo ?? 'Helping Hands NGO',
            subtitle: 'Dropoff Destination',
            badgeText: 'Destination',
            badgeColor: const Color(0xFF10B981),
            icon: Icons.volunteer_activism_rounded,
            iconColor: const Color(0xFF10B981),
          ),
          // Volunteer Courier Moving Marker
          OsmMapMarkerData(
            point: volunteerPos,
            label: liveBatch.assignedCourierName ?? 'Courier Squad',
            subtitle: liveBatch.distanceRemainingKm != null
                ? '${liveBatch.distanceRemainingKm} km remaining'
                : 'En Route',
            badgeText: liveBatch.status == BatchStatus.pickedUp || liveBatch.status == BatchStatus.inTransit
                ? 'Delivery Transit'
                : 'Pickup Transit',
            badgeColor: const Color(0xFF2563EB),
            icon: Icons.two_wheeler_rounded,
            iconColor: const Color(0xFF2563EB),
            isCenter: true,
          ),
        ];

        // Active polyline start/end based on current stage
        final LatLng routeStart;
        final LatLng routeEnd;
        if (liveBatch.status == BatchStatus.pickedUp ||
            liveBatch.status == BatchStatus.inTransit ||
            liveBatch.status == BatchStatus.arrivedAtReceiver) {
          routeStart = providerPos;
          routeEnd = receiverPos;
        } else {
          routeStart = volunteerPos;
          routeEnd = providerPos;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Live Delivery Tracking',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, size: 7, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            'LIVE GPS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  '${liveBatch.title} • ${liveBatch.quantityPortions} meals',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              // Safe-Until Expiry Badge
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: safeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: safeColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: safeColor),
                    const SizedBox(width: 4),
                    Text(
                      '⏳ ${_formatSafeTime(safeRemaining)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: safeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              if (isDesktop) {
                return _buildDesktopLayout(
                  liveBatch,
                  markers,
                  routeStart,
                  routeEnd,
                  currentStepIndex,
                  safeRemaining,
                );
              } else {
                return _buildMobileLayout(
                  liveBatch,
                  markers,
                  routeStart,
                  routeEnd,
                  currentStepIndex,
                  safeRemaining,
                );
              }
            },
          ),
        );
      },
    );
  }

  // DESKTOP SPLIT LAYOUT
  Widget _buildDesktopLayout(
    SurplusBatch batch,
    List<OsmMapMarkerData> markers,
    LatLng routeStart,
    LatLng routeEnd,
    int currentStepIndex,
    Duration safeRemaining,
  ) {
    return Row(
      children: [
        // Map Area
        Expanded(
          flex: 6,
          child: Stack(
            children: [
              OsmMapWidget(
                initialCenter: batch.courierLocation,
                initialZoom: 14.2,
                markers: markers,
                routeStart: routeStart,
                routeEnd: routeEnd,
                height: double.infinity,
                showControls: true,
              ),
              // Simulation Toolbar on Map
              Positioned(
                top: 14,
                left: 14,
                child: _buildSimulationBadge(batch),
              ),
            ],
          ),
        ),

        // Side Details & Action Panel
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusTimeline(currentStepIndex),
                  const SizedBox(height: 20),
                  _buildRoleSpecificPanel(batch),
                  const SizedBox(height: 20),
                  _buildRescueDetailsCard(batch, safeRemaining),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // MOBILE VERTICAL LAYOUT
  Widget _buildMobileLayout(
    SurplusBatch batch,
    List<OsmMapMarkerData> markers,
    LatLng routeStart,
    LatLng routeEnd,
    int currentStepIndex,
    Duration safeRemaining,
  ) {
    return Column(
      children: [
        // Map (Top 48% height)
        SizedBox(
          height: 290,
          child: Stack(
            children: [
              OsmMapWidget(
                initialCenter: batch.courierLocation,
                initialZoom: 13.8,
                markers: markers,
                routeStart: routeStart,
                routeEnd: routeEnd,
                height: 290,
                showControls: true,
              ),
              Positioned(
                top: 10,
                left: 10,
                child: _buildSimulationBadge(batch),
              ),
            ],
          ),
        ),

        // Scrollable Lower Area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusTimeline(currentStepIndex),
                const SizedBox(height: 16),
                _buildRoleSpecificPanel(batch),
                const SizedBox(height: 16),
                _buildRescueDetailsCard(batch, safeRemaining),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // COMPACT 7-STAGE STATUS TIMELINE
  Widget _buildStatusTimeline(int activeIndex) {
    final stages = [
      'Listed',
      'Claimed',
      'Assigned',
      'Pickup',
      'Picked Up',
      'In Transit',
      'Delivered',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rescue Lifecycle',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  stages[activeIndex.clamp(0, stages.length - 1)],
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(stages.length, (index) {
              final isDone = index < activeIndex;
              final isCurrent = index == activeIndex;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDone
                                  ? const Color(0xFF10B981)
                                  : isCurrent
                                      ? const Color(0xFFFFC107)
                                      : const Color(0xFFE2E8F0),
                              border: isCurrent
                                  ? Border.all(color: const Color(0xFFB45309), width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: isDone
                                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                                  : isCurrent
                                      ? Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFF1E293B),
                                          ),
                                        )
                                      : const SizedBox(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stages[index],
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                              color: isCurrent
                                  ? const Color(0xFF1E293B)
                                  : isDone
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF94A3B8),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (index < stages.length - 1)
                      Container(
                        height: 2.5,
                        width: 10,
                        margin: const EdgeInsets.only(bottom: 16),
                        color: isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ROLE SPECIFIC CONTROLS
  Widget _buildRoleSpecificPanel(SurplusBatch batch) {
    switch (widget.role) {
      case RescueTrackingRole.provider:
        return _buildProviderPanel(batch);
      case RescueTrackingRole.receiver:
        return _buildReceiverPanel(batch);
      case RescueTrackingRole.volunteer:
        return _buildVolunteerPanel(batch);
    }
  }

  // 1. PROVIDER PANEL
  Widget _buildProviderPanel(SurplusBatch batch) {
    final isHandedOver = batch.status == BatchStatus.pickedUp ||
        batch.status == BatchStatus.inTransit ||
        batch.status == BatchStatus.arrivedAtReceiver ||
        batch.status == BatchStatus.delivered;

    return Container(
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
                child: const Icon(Icons.pin_outlined, color: Color(0xFFB45309), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kitchen Handover PIN',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      isHandedOver ? '✅ Verified • Food Handed Over' : 'Share with volunteer courier at dock',
                      style: TextStyle(
                        fontSize: 12,
                        color: isHandedOver ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                        fontWeight: isHandedOver ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isHandedOver ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isHandedOver ? const Color(0xFF86EFAC) : const Color(0xFFFFC107),
                  ),
                ),
                child: Text(
                  batch.pickupOtp,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: isHandedOver ? const Color(0xFF166534) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          // Courier info & contact
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(Icons.two_wheeler_rounded, size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.assignedCourierName ?? 'Volunteer Courier',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      batch.assignedCourierPhone ?? '+91 95556 51225',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Calling courier ${batch.assignedCourierName ?? "Volunteer"}...')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.call, size: 15, color: Color(0xFF1E293B)),
                label: const Text('Call Courier', style: TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. RECEIVER PANEL
  Widget _buildReceiverPanel(SurplusBatch batch) {
    final isDelivered = batch.status == BatchStatus.delivered;

    return Container(
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
                  color: isDelivered ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDelivered ? Icons.verified_rounded : Icons.lock_outline_rounded,
                  color: isDelivered ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Verification OTP',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      isDelivered ? '✅ Received • Distribution Complete' : 'Give code to volunteer upon drop-off',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDelivered ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                        fontWeight: isDelivered ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDelivered ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDelivered ? const Color(0xFF86EFAC) : const Color(0xFFFFC107),
                  ),
                ),
                child: Text(
                  batch.deliveryOtp,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: isDelivered ? const Color(0xFF166534) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          // Courier tracking row
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(Icons.two_wheeler_rounded, size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.assignedCourierName ?? 'Volunteer Courier',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      batch.distanceRemainingKm != null
                          ? '${batch.distanceRemainingKm} km away • ETA ~${batch.courierEtaMinutes ?? 12} min'
                          : 'En Route to delivery',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Calling courier ${batch.assignedCourierName ?? "Volunteer"}...')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.call, size: 15, color: Color(0xFF1E293B)),
                label: const Text('Call', style: TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. VOLUNTEER PANEL & DYNAMIC ACTIONS
  Widget _buildVolunteerPanel(SurplusBatch batch) {
    final status = batch.status;

    return Container(
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
              const Icon(Icons.assistant_direction_rounded, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Volunteer Action Controls',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (batch.distanceRemainingKm != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${batch.distanceRemainingKm} km • ${batch.courierEtaMinutes ?? 12} min',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Primary Dynamic Action
          if (status == BatchStatus.inTransitToPickup || status == BatchStatus.volunteerAssigning) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Jump simulated location to kitchen dock
                  FoodRescueService.instance.updateTaskDeliveryStatus(batch.id, BatchStatus.arrivedAtPickup);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Arrived at kitchen dock! Ask staff for Kitchen PIN.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Arrived at Pickup Dock', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ] else if (status == BatchStatus.arrivedAtPickup) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _verifyPickupPinModal(batch),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.vpn_key_rounded, size: 18),
                label: const Text('Confirm Pickup (Enter PIN)', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ] else if (status == BatchStatus.pickedUp || status == BatchStatus.inTransit) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Jump simulated location to receiver
                  FoodRescueService.instance.updateTaskDeliveryStatus(batch.id, BatchStatus.arrivedAtReceiver);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Arrived at destination shelter! Ask receiver for Delivery OTP.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.near_me_rounded, size: 18),
                label: const Text('Arrived at Destination Shelter', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ] else if (status == BatchStatus.arrivedAtReceiver) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _verifyDeliveryPinModal(batch),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: const Text('Confirm Handover (Enter OTP)', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ] else if (status == BatchStatus.delivered) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF166534), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Delivery Completed Successfully ✓',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // RESCUE DETAILS CARD (Collapsible)
  Widget _buildRescueDetailsCard(SurplusBatch batch, Duration safeRemaining) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Collapsible Header
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _isDetailsExpanded = !_isDetailsExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: Text('🍲', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          '${batch.quantityPortions} servings • ${batch.dietaryType} • ₹${batch.basePrice.toStringAsFixed(0)}/portion',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isDetailsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          if (_isDetailsExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailItem('Pickup Location', batch.pickupAddress, icon: Icons.storefront_rounded),
                  const SizedBox(height: 12),
                  _buildDetailItem(
                    'Dropoff Facility',
                    batch.receiverDropoffAddress ?? '${batch.claimedByNgo ?? "Shelter"} Center',
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailItem(
                    'Packaging & Temperature',
                    '${batch.packagingType} • ${batch.temperatureCelsius}°C',
                    icon: Icons.thermostat_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailItem(
                    'Order ID',
                    batch.id,
                    icon: Icons.tag_rounded,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {required IconData icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // SIMULATION CONTROLS BADGE
  Widget _buildSimulationBadge(SurplusBatch batch) {
    final isRunning = FoodRescueService.instance.isSimulationRunning(batch.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRunning ? Icons.motion_photos_on_rounded : Icons.motion_photos_paused_rounded,
            size: 15,
            color: isRunning ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 6),
          Text(
            isRunning ? 'Simulating Movement (${_currentSpeed.toInt()}x)' : 'Simulation Paused',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              if (isRunning) {
                FoodRescueService.instance.pauseSimulatedMovement(batch.id);
              } else {
                FoodRescueService.instance.startSimulatedMovement(batch.id, speedMultiplier: _currentSpeed);
              }
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 14,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Speed Switcher
          InkWell(
            onTap: () {
              setState(() {
                if (_currentSpeed == 1.0) {
                  _currentSpeed = 2.0;
                } else if (_currentSpeed == 2.0) {
                  _currentSpeed = 5.0;
                } else {
                  _currentSpeed = 1.0;
                }
                FoodRescueService.instance.setSimulationSpeed(batch.id, _currentSpeed);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_currentSpeed.toInt()}x',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
