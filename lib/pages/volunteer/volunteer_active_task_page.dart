import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/food_rescue_service.dart';
import '../../widgets/osm_map_widget.dart';
import 'volunteer_payment_confirmation_page.dart';

enum DeliveryProgressStep {
  taskAccepted,
  goingToPickup,
  arrivedAtProvider,
  foodCollected,
  goingToReceiver,
  arrivedAtReceiver,
  foodDelivered,
  taskCompleted,
}

class VolunteerActiveTaskPage extends StatefulWidget {
  final SurplusBatch batch;
  final bool autoStartNavigation;

  const VolunteerActiveTaskPage({
    super.key,
    required this.batch,
    this.autoStartNavigation = false,
  });

  @override
  State<VolunteerActiveTaskPage> createState() => _VolunteerActiveTaskPageState();
}

class _VolunteerActiveTaskPageState extends State<VolunteerActiveTaskPage> {
  late DeliveryProgressStep _currentStep;
  late bool _isNavigating;
  final TextEditingController _noteCtrl = TextEditingController(text: 'Meal packets handed over to staff in good condition.');
  final TextEditingController _pickupOtpCtrl = TextEditingController();
  final TextEditingController _deliveryOtpCtrl = TextEditingController();
  String? _pickupOtpError;
  String? _deliveryOtpError;
  bool _hasOptionalPhoto = false;

  LatLng get _volunteerLocation => LatLng(
        widget.batch.location.latitude - 0.009,
        widget.batch.location.longitude - 0.007,
      );

  LatLng get _providerLocation => widget.batch.location;

  LatLng get _receiverLocation => LatLng(
        widget.batch.location.latitude + 0.018,
        widget.batch.location.longitude + 0.014,
      );

  @override
  void initState() {
    super.initState();
    _currentStep = _deriveStepFromBatch(widget.batch);
    _isNavigating = widget.autoStartNavigation ||
        _currentStep == DeliveryProgressStep.goingToPickup ||
        _currentStep == DeliveryProgressStep.goingToReceiver;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _pickupOtpCtrl.dispose();
    _deliveryOtpCtrl.dispose();
    super.dispose();
  }

  DeliveryProgressStep _deriveStepFromBatch(SurplusBatch batch) {
    if (batch.status == BatchStatus.delivered) {
      return DeliveryProgressStep.taskCompleted;
    } else if (batch.status == BatchStatus.pickedUp) {
      return DeliveryProgressStep.foodCollected;
    } else if (batch.status == BatchStatus.inTransitToPickup) {
      return DeliveryProgressStep.goingToPickup;
    }
    return DeliveryProgressStep.taskAccepted;
  }

  void _advanceStep(DeliveryProgressStep nextStep) {
    setState(() {
      _currentStep = nextStep;
    });

    if (nextStep == DeliveryProgressStep.foodCollected) {
      FoodRescueService.instance.updateTaskDeliveryStatus(widget.batch.id, BatchStatus.pickedUp);
    } else if (nextStep == DeliveryProgressStep.foodDelivered || nextStep == DeliveryProgressStep.taskCompleted) {
      FoodRescueService.instance.updateTaskDeliveryStatus(widget.batch.id, BatchStatus.delivered);
    }
  }

  void _verifyPickupOtp() {
    final entered = _pickupOtpCtrl.text.trim();
    if (entered.isEmpty) {
      setState(() {
        _pickupOtpError = 'Please enter the 4-digit Pickup OTP from provider.';
      });
      return;
    }

    final isValid = FoodRescueService.instance.verifyPickupOtp(widget.batch.id, entered);
    if (isValid) {
      setState(() {
        _pickupOtpError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Handover Verified! Provider & Volunteer authenticated for ${widget.batch.providerName}.'),
              ),
            ],
          ),
        ),
      );
      _advanceStep(DeliveryProgressStep.foodCollected);
      setState(() => _isNavigating = true);
    } else {
      setState(() {
        _pickupOtpError = 'Incorrect OTP. Ask provider kitchen staff for the 4-digit code.';
      });
    }
  }

  void _verifyDeliveryOtp() {
    final entered = _deliveryOtpCtrl.text.trim();
    if (entered.isEmpty) {
      setState(() {
        _deliveryOtpError = 'Please enter the 4-digit Delivery OTP from receiver.';
      });
      return;
    }

    final isValid = FoodRescueService.instance.verifyDeliveryOtp(widget.batch.id, entered);
    if (isValid) {
      setState(() {
        _deliveryOtpError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Delivery Verified! Receiver & Volunteer authenticated for ${widget.batch.claimedByNgo ?? "Receiver"}.'),
              ),
            ],
          ),
        ),
      );
      _advanceStep(DeliveryProgressStep.taskCompleted);
      _showCompletionCelebration();
    } else {
      setState(() {
        _deliveryOtpError = 'Incorrect OTP. Ask receiver shelter staff for the 4-digit code.';
      });
    }
  }

  void _showCancelDialog() {
    String selectedReason = 'Vehicle issue';
    final reasons = [
      'Emergency',
      'Vehicle issue',
      'Too far',
      'Cannot reach pickup',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 22),
              SizedBox(width: 8),
              Text('Cancel Task', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please select a reason for cancelling this rescue delivery:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              ...reasons.map((r) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(r, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: r,
                    groupValue: selectedReason,
                    onChanged: (val) => setDlgState(() => selectedReason = val!),
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                FoodRescueService.instance.cancelDeliveryTask(widget.batch.id, selectedReason);
                Navigator.pop(ctx); // close dialog
                Navigator.pop(context); // close active task page
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Cancel Delivery'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompletionCelebration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFC107), width: 2),
                ),
                child: const Center(child: Text('🎉', style: TextStyle(fontSize: 34))),
              ),
              const SizedBox(height: 16),
              const Text(
                'Task Completed 🎉',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You have successfully delivered ${widget.batch.quantityPortions} meals from ${widget.batch.providerName} to ${widget.batch.claimedByNgo ?? 'Helping Hands NGO'}.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.eco_rounded, color: Color(0xFF16A34A), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '+${(widget.batch.quantityPortions * 0.5).round()} kg Food Rescued',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context); // Return to Dashboard
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: const Color(0xFF1E293B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Live Delivery Tracking',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B)),
        ),
        actions: [
          if (_currentStep != DeliveryProgressStep.taskCompleted && _currentStep != DeliveryProgressStep.foodDelivered)
            TextButton(
              onPressed: _showCancelDialog,
              child: const Text('Cancel Task', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 13)),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Route Banner
                _buildLiveRouteBanner(),
                const SizedBox(height: 20),

                // Attached Live Navigation Map (when demanded / active)
                if (_isNavigating) ...[
                  _buildNavigationMapCard(),
                  const SizedBox(height: 20),
                ] else if (_currentStep != DeliveryProgressStep.taskCompleted && _currentStep != DeliveryProgressStep.foodDelivered) ...[
                  _buildMapPromptCard(),
                  const SizedBox(height: 20),
                ],

                // 8-Step Progress Timeline
                _buildProgressTimeline(),
                const SizedBox(height: 24),

                // Dynamic Step Action Panel
                _buildCurrentStepActionCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Live Route Banner: Provider -> Volunteer is on the way -> Receiver
  // ---------------------------------------------------------------------------
  Widget _buildLiveRouteBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107)),
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
                child: const Icon(Icons.delivery_dining_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.batch.title,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      '${widget.batch.quantityPortions} meals • Est. route: 4.0 km',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Route Diagram
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.store_rounded, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.batch.providerName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Text('📍 Pickup', style: TextStyle(fontSize: 11, color: Color(0xFF78350F), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFFB45309), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    const Text('🚴 Volunteer is on the way', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)), textAlign: TextAlign.center),
                    Text(
                      _currentStep.index >= DeliveryProgressStep.foodCollected.index
                          ? 'En route to Receiver'
                          : 'Heading to Provider',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFFB45309), size: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.volunteer_activism_rounded, size: 16, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.batch.claimedByNgo ?? 'Helping Hands NGO',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Text('📍 Delivery', style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Attached Live Navigation Map & Prompt Card
  // ---------------------------------------------------------------------------
  Widget _buildMapPromptCard() {
    final isPickupPhase = _currentStep.index < DeliveryProgressStep.foodCollected.index;
    final targetName = isPickupPhase ? widget.batch.providerName : (widget.batch.claimedByNgo ?? 'Receiver Shelter');
    final distanceText = isPickupPhase ? '1.2 km' : '2.8 km';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.map_rounded, color: Color(0xFFD97706), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GPS Route Map Available',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Live turn-by-turn guidance to $targetName ($distanceText)',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isNavigating = true;
                if (_currentStep == DeliveryProgressStep.taskAccepted) {
                  _advanceStep(DeliveryProgressStep.goingToPickup);
                } else if (_currentStep == DeliveryProgressStep.foodCollected) {
                  _advanceStep(DeliveryProgressStep.goingToReceiver);
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: const Color(0xFF1E293B),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.navigation_rounded, size: 16),
            label: const Text('Start Navigation', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationMapCard() {
    final isPickupPhase = _currentStep.index < DeliveryProgressStep.foodCollected.index;
    final startPoint = isPickupPhase ? _volunteerLocation : _providerLocation;
    final endPoint = isPickupPhase ? _providerLocation : _receiverLocation;
    final destTitle = isPickupPhase
        ? widget.batch.providerName
        : (widget.batch.claimedByNgo ?? 'Receiver Shelter');
    final destAddress = isPickupPhase
        ? widget.batch.pickupAddress
        : (widget.batch.receiverDropoffAddress ?? 'Helping Hands Shelter, Greater Noida');
    final destDistance = isPickupPhase ? '1.2 km' : '2.8 km';
    final destEta = isPickupPhase ? '~4 mins' : '~8 mins';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC107).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navigation Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isPickupPhase ? 'GPS NAVIGATION: TO PICKUP' : 'GPS NAVIGATION: TO DROPOFF',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF92400E),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '$destDistance • $destEta',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() => _isNavigating = false);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),

          // Target details strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isPickupPhase ? Icons.store_rounded : Icons.volunteer_activism_rounded,
                  size: 20,
                  color: isPickupPhase ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destTitle,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        destAddress,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPickupPhase ? 'Pickup Stage' : 'Delivery Stage',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),

          // Attached Interactive OSM Map
          ClipRRect(
            child: OsmMapWidget(
              initialCenter: _volunteerLocation,
              initialZoom: 14.5,
              height: 280,
              routeStart: startPoint,
              routeEnd: endPoint,
              markers: [
                OsmMapMarkerData(
                  point: _volunteerLocation,
                  label: 'Your Location',
                  subtitle: isPickupPhase ? 'En route to provider kitchen' : 'Transporting meals to shelter',
                  icon: Icons.two_wheeler_rounded,
                  iconColor: const Color(0xFF2563EB),
                  isCenter: true,
                ),
                if (isPickupPhase)
                  OsmMapMarkerData(
                    point: _providerLocation,
                    label: widget.batch.providerName,
                    subtitle: widget.batch.pickupAddress,
                    icon: Icons.store_rounded,
                    iconColor: const Color(0xFFD97706),
                  )
                else
                  OsmMapMarkerData(
                    point: _receiverLocation,
                    label: widget.batch.claimedByNgo ?? 'Receiver Shelter',
                    subtitle: widget.batch.receiverDropoffAddress ?? 'Helping Hands Shelter',
                    icon: Icons.volunteer_activism_rounded,
                    iconColor: const Color(0xFF16A34A),
                  ),
              ],
            ),
          ),

          // Turn-by-Turn Instruction Strip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.navigation_rounded, size: 18, color: Color(0xFFD97706)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPickupPhase
                        ? 'Turn-by-turn: Head north towards ${widget.batch.pickupAddress} (300m)'
                        : 'Turn-by-turn: Head east towards ${widget.batch.receiverDropoffAddress ?? 'Receiver Shelter'} (500m)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isNavigating = false);
                  },
                  icon: const Icon(Icons.visibility_off_rounded, size: 15, color: Color(0xFF64748B)),
                  label: const Text('Hide Map', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8-Step Timeline
  // ---------------------------------------------------------------------------
  Widget _buildProgressTimeline() {
    final steps = [
      'Task Accepted',
      'Going to Pickup',
      'Arrived at Provider',
      'Food Collected',
      'Going to Receiver',
      'Arrived at Receiver',
      'Food Delivered',
      'Task Completed',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Progress Timeline',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 14),
          ...List.generate(steps.length, (idx) {
            final isCurrent = idx == _currentStep.index;
            final isDone = idx < _currentStep.index;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFF10B981)
                            : (isCurrent ? const Color(0xFFFFC107) : const Color(0xFFE2E8F0)),
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(color: const Color(0xFFD97706), width: 2)
                            : null,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isCurrent ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                ),
                              ),
                      ),
                    ),
                    if (idx < steps.length - 1)
                      Container(
                        width: 2,
                        height: 22,
                        color: isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      steps[idx],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCurrent ? FontWeight.w900 : (isDone ? FontWeight.w700 : FontWeight.w500),
                        color: isCurrent
                            ? const Color(0xFFD97706)
                            : (isDone ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Current', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dynamic Step Action Panel
  // ---------------------------------------------------------------------------
  Widget _buildCurrentStepActionCard() {
    switch (_currentStep) {
      case DeliveryProgressStep.taskAccepted:
      case DeliveryProgressStep.goingToPickup:
        return _buildPickupNavigationCard();

      case DeliveryProgressStep.arrivedAtProvider:
        return _buildArrivedAtProviderCard();

      case DeliveryProgressStep.foodCollected:
      case DeliveryProgressStep.goingToReceiver:
        return _buildDeliveryNavigationCard();

      case DeliveryProgressStep.arrivedAtReceiver:
        return _buildArrivedAtReceiverCard();

      case DeliveryProgressStep.foodDelivered:
      case DeliveryProgressStep.taskCompleted:
        return _buildTaskCompletedCard();
    }
  }

  Widget _buildPickupNavigationCard() {
    final isJustAccepted = _currentStep == DeliveryProgressStep.taskAccepted;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pickup Food', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          _buildDetailRow('Provider', widget.batch.providerName),
          _buildDetailRow('Location', widget.batch.pickupAddress),
          _buildDetailRow('Distance', '1.2 km'),
          _buildDetailRow('Pickup time', '7:00 PM – 8:00 PM'),
          const SizedBox(height: 20),
          if (isJustAccepted) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isNavigating = true;
                    _advanceStep(DeliveryProgressStep.goingToPickup);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Starting Pickup: Moving to provider kitchen with live GPS map...'),
                      backgroundColor: Color(0xFF1E293B),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('Start Pickup', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isNavigating = true;
                      if (isJustAccepted) {
                        _advanceStep(DeliveryProgressStep.goingToPickup);
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Starting GPS turn-by-turn navigation to Provider...'),
                        backgroundColor: Color(0xFF1E293B),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFFC107)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.navigation_rounded, size: 18, color: Color(0xFFD97706)),
                  label: Text(
                    _isNavigating ? 'Navigation Active 🗺️' : 'Start Navigation',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _advanceStep(DeliveryProgressStep.arrivedAtProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: const Color(0xFF1E293B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("I've Arrived", style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArrivedAtProviderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Confirm Pickup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          _buildDetailRow('Food', widget.batch.title),
          _buildDetailRow('Quantity', '${widget.batch.quantityPortions} meals'),
          _buildDetailRow('Provider', widget.batch.providerName),
          const SizedBox(height: 14),
          // Provider OTP Authentication Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_clock_rounded, color: Color(0xFFD97706), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Provider Handover Verification OTP',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Ask kitchen staff at ${widget.batch.providerName} for the 4-digit handover PIN to authenticate pickup.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pickupOtpCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 6, color: Color(0xFF1E293B)),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '• • • •',
                          hintStyle: const TextStyle(letterSpacing: 6, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFFC107), width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _pickupOtpCtrl.text = widget.batch.pickupOtp;
                          _pickupOtpError = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFC107)),
                        ),
                        child: Column(
                          children: [
                            const Text('Auto-fill', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                            Text(widget.batch.pickupOtp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_pickupOtpError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _pickupOtpError!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _advanceStep(DeliveryProgressStep.goingToPickup),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _verifyPickupOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: const Color(0xFF1E293B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.verified_user_rounded, size: 18),
                  label: const Text('Confirm Pickup', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryNavigationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deliver Food', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          _buildDetailRow('Receiver', widget.batch.claimedByNgo ?? 'Helping Hands NGO'),
          _buildDetailRow('Delivery Location', widget.batch.receiverDropoffAddress ?? 'Greater Noida'),
          _buildDetailRow('Distance', '2.8 km'),
          _buildDetailRow('Food', '${widget.batch.title} (${widget.batch.quantityPortions} meals)'),
          _buildDetailRow('Status', 'Food Collected'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isNavigating = true;
                      if (_currentStep == DeliveryProgressStep.foodCollected) {
                        _advanceStep(DeliveryProgressStep.goingToReceiver);
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Starting GPS navigation to Receiver Shelter...'),
                        backgroundColor: Color(0xFF1E293B),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFFC107)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.navigation_rounded, size: 18, color: Color(0xFFD97706)),
                  label: Text(
                    _isNavigating ? 'Navigation Active 🗺️' : 'Start Navigation',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD97706), fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _advanceStep(DeliveryProgressStep.arrivedAtReceiver),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: const Color(0xFF1E293B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("I've Arrived", style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArrivedAtReceiverCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery Confirmation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          _buildDetailRow('Food', widget.batch.title),
          _buildDetailRow('Quantity', '${widget.batch.quantityPortions} meals'),
          _buildDetailRow('Receiver', widget.batch.claimedByNgo ?? 'Helping Hands NGO'),
          const SizedBox(height: 14),

          // Receiver Delivery OTP Authentication Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_clock_rounded, color: Color(0xFF16A34A), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Receiver Delivery Verification OTP',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Ask the intake staff at ${widget.batch.claimedByNgo ?? "Receiver Shelter"} for their 4-digit Delivery PIN to complete verified handover.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _deliveryOtpCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 6, color: Color(0xFF1E293B)),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '• • • •',
                          hintStyle: const TextStyle(letterSpacing: 6, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _deliveryOtpCtrl.text = widget.batch.deliveryOtp;
                          _deliveryOtpError = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Column(
                          children: [
                            const Text('Auto-fill', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF166534))),
                            Text(widget.batch.deliveryOtp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_deliveryOtpError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _deliveryOtpError!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Optional Proof of Delivery Note
          const Text('Proof of Delivery (Optional Note)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. 50 meal packets handed over to NGO staff.',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
          const SizedBox(height: 12),

          // Optional Photo check
          InkWell(
            onTap: () => setState(() => _hasOptionalPhoto = !_hasOptionalPhoto),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(
                  _hasOptionalPhoto ? Icons.check_box_rounded : Icons.camera_alt_outlined,
                  color: _hasOptionalPhoto ? const Color(0xFF10B981) : const Color(0xFF64748B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _hasOptionalPhoto ? 'Delivery photo attached ✓' : 'Add delivery photo (Optional)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _hasOptionalPhoto ? const Color(0xFF10B981) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Confirm Delivery Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _verifyDeliveryOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: const Color(0xFF1E293B),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.verified_rounded, size: 18),
              label: const Text('Confirm Delivery', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCompletedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
          const SizedBox(height: 8),
          const Text('Task Completed 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF166534))),
          const SizedBox(height: 4),
          Text(
            '${widget.batch.title} has been successfully delivered and distributed.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF14532D)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VolunteerPaymentConfirmationPage(batch: widget.batch),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: const Color(0xFF1E293B),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.receipt_long_rounded, size: 20),
              label: const Text('View Payment Details & Confirmation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF166534),
                side: const BorderSide(color: Color(0xFF86EFAC)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }
}
