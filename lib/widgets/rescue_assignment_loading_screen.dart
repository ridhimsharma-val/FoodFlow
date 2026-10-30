import 'dart:async';
import 'package:flutter/material.dart';
import '../services/food_rescue_service.dart';
import 'shared_rescue_tracking_page.dart';

enum RescueLoadingRole {
  provider,
  receiver,
  volunteer,
}

class RescueAssignmentLoadingScreen extends StatefulWidget {
  final SurplusBatch batch;
  final RescueLoadingRole role;
  final VoidCallback? onCompleted;
  final bool autoNavigateToTracking;

  const RescueAssignmentLoadingScreen({
    super.key,
    required this.batch,
    required this.role,
    this.onCompleted,
    this.autoNavigateToTracking = true,
  });

  static Future<void> show(
    BuildContext context, {
    required SurplusBatch batch,
    required RescueLoadingRole role,
    bool autoNavigateToTracking = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RescueAssignmentLoadingScreen(
        batch: batch,
        role: role,
        autoNavigateToTracking: autoNavigateToTracking,
      ),
    );
  }

  @override
  State<RescueAssignmentLoadingScreen> createState() => _RescueAssignmentLoadingScreenState();
}

class _RescueAssignmentLoadingScreenState extends State<RescueAssignmentLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  bool _isSuccess = false;
  bool _hasFailed = false;
  Timer? _safetyTimer;
  Timer? _transitionTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // If volunteer, show phase 1 ("Accepting...") then phase 2 ("Accepted ✓")
    if (widget.role == RescueLoadingRole.volunteer) {
      Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() => _isSuccess = true);
        }
      });
    }

    // Safety timeout in case backend drops out (e.g. 10 seconds)
    _safetyTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && !_isSuccess) {
        final currentBatch = FoodRescueService.instance.batches.firstWhere(
          (b) => b.id == widget.batch.id,
          orElse: () => widget.batch,
        );
        if (currentBatch.status == BatchStatus.claimed || currentBatch.status == BatchStatus.reassigning) {
          setState(() => _hasFailed = true);
        }
      }
    });

    // Check status periodically for automatic transition
    _checkStatusAndTransition();
  }

  void _checkStatusAndTransition() {
    void listener() {
      if (!mounted) return;
      final currentBatch = FoodRescueService.instance.batches.firstWhere(
        (b) => b.id == widget.batch.id,
        orElse: () => widget.batch,
      );

      final isAssignedNow = currentBatch.status != BatchStatus.available &&
          currentBatch.status != BatchStatus.claimed &&
          currentBatch.status != BatchStatus.volunteerAssigning &&
          currentBatch.status != BatchStatus.cancelled &&
          currentBatch.status != BatchStatus.expired;

      if (isAssignedNow && !_isSuccess) {
        setState(() => _isSuccess = true);
        _scheduleTransition(currentBatch);
      }
    }

    FoodRescueService.instance.addListener(listener);
  }

  void _scheduleTransition(SurplusBatch liveBatch) {
    _transitionTimer?.cancel();
    _transitionTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;

      widget.onCompleted?.call();

      if (widget.autoNavigateToTracking) {
        // Pop the loading dialog/screen
        Navigator.of(context, rootNavigator: true).pop();

        // Navigate to unified live rescue tracking screen
        SharedRescueTrackingPage.open(
          context,
          batch: liveBatch,
          role: _mapToTrackingRole(widget.role),
        );
      }
    });
  }

  RescueTrackingRole _mapToTrackingRole(RescueLoadingRole role) {
    switch (role) {
      case RescueLoadingRole.provider:
        return RescueTrackingRole.provider;
      case RescueLoadingRole.receiver:
        return RescueTrackingRole.receiver;
      case RescueLoadingRole.volunteer:
        return RescueTrackingRole.volunteer;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _safetyTimer?.cancel();
    _transitionTimer?.cancel();
    super.dispose();
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

        final isStillAssigning = liveBatch.status == BatchStatus.volunteerAssigning;
        final isAssigned = !isStillAssigning &&
            liveBatch.status != BatchStatus.available &&
            liveBatch.status != BatchStatus.claimed &&
            liveBatch.status != BatchStatus.reassigning &&
            liveBatch.status != BatchStatus.cancelled &&
            liveBatch.status != BatchStatus.expired;

        if (isAssigned && !_isSuccess) {
          _isSuccess = true;
          _scheduleTransition(liveBatch);
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: _hasFailed
                      ? _buildFailureView(liveBatch)
                      : _buildContent(liveBatch),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(SurplusBatch batch) {
    switch (widget.role) {
      case RescueLoadingRole.provider:
        return _buildProviderView(batch);
      case RescueLoadingRole.receiver:
        return _buildReceiverView(batch);
      case RescueLoadingRole.volunteer:
        return _buildVolunteerView(batch);
    }
  }

  // PROVIDER VIEW
  Widget _buildProviderView(SurplusBatch batch) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isSuccess ? 1.0 : _pulseAnimation.value,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  border: Border.all(
                    color: _isSuccess ? const Color(0xFF10B981) : const Color(0xFFFFC107),
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _isSuccess ? Icons.check_circle_rounded : Icons.delivery_dining_rounded,
                    color: _isSuccess ? const Color(0xFF166534) : const Color(0xFFD97706),
                    size: 38,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          _isSuccess ? 'Volunteer Connected! ✓' : 'Volunteer Accepted — Connecting...',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _isSuccess
              ? 'Opening live GPS tracking screen...'
              : 'Please wait while we connect the volunteer to this rescue.',
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildInfoRow('Food Listing', batch.title),
              const Divider(height: 14, color: Color(0xFFE2E8F0)),
              _buildInfoRow('Quantity', '${batch.quantityPortions} servings'),
              const Divider(height: 14, color: Color(0xFFE2E8F0)),
              _buildInfoRow('Claimed By', batch.claimedByNgo ?? 'Relief NGO Partner'),
              const Divider(height: 14, color: Color(0xFFE2E8F0)),
              _buildInfoRow(
                'Assigned Courier',
                batch.assignedCourierName ?? 'Volunteer Courier',
                highlightValue: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!_isSuccess) ...[
          const LinearProgressIndicator(
            backgroundColor: Color(0xFFF1F5F9),
            color: Color(0xFFFFC107),
            minHeight: 5,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          const SizedBox(height: 10),
          const Text(
            'Estimated connection time: ~2 seconds',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_clock_rounded, size: 14, color: Color(0xFF166534)),
                SizedBox(width: 6),
                Text(
                  'Connected • Loading Live Map',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // RECEIVER VIEW
  Widget _buildReceiverView(SurplusBatch batch) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isSuccess ? 1.0 : _pulseAnimation.value,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  border: Border.all(
                    color: _isSuccess ? const Color(0xFF10B981) : const Color(0xFFFFC107),
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _isSuccess ? Icons.check_circle_rounded : Icons.two_wheeler_rounded,
                    color: _isSuccess ? const Color(0xFF166534) : const Color(0xFFD97706),
                    size: 38,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          _isSuccess ? 'Delivery Connected! ✓' : 'Pickup Confirmed — Connecting Volunteer...',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _isSuccess
              ? 'Opening real-time rescue tracking...'
              : 'Your volunteer has accepted the rescue.\nWe\'re connecting the pickup to your delivery.',
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildInfoRow('Food Item', batch.title),
              const Divider(height: 14, color: Color(0xFFE2E8F0)),
              _buildInfoRow('Portions', '${batch.quantityPortions} meals'),
              const Divider(height: 14, color: Color(0xFFE2E8F0)),
              _buildInfoRow('Provider Kitchen', batch.providerName),
              const Divider(height: 14, color: Color(0xFFE2E8F0)),
              _buildInfoRow(
                'Courier Squad',
                batch.assignedCourierName ?? 'Assigned Volunteer Courier',
                highlightValue: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!_isSuccess) ...[
          const LinearProgressIndicator(
            backgroundColor: Color(0xFFF1F5F9),
            color: Color(0xFFFFC107),
            minHeight: 5,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          const SizedBox(height: 10),
          const Text(
            'Connecting live GPS route to your facility...',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF166534)),
                SizedBox(width: 6),
                Text(
                  'Route Synchronized • Launching Live View',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // VOLUNTEER VIEW
  Widget _buildVolunteerView(SurplusBatch batch) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isSuccess ? 1.0 : _pulseAnimation.value,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  border: Border.all(
                    color: _isSuccess ? const Color(0xFF10B981) : const Color(0xFFFFC107),
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _isSuccess ? Icons.check_circle_rounded : Icons.navigation_rounded,
                    color: _isSuccess ? const Color(0xFF166534) : const Color(0xFFD97706),
                    size: 38,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          _isSuccess ? 'Rescue Accepted ✓' : 'Accepting Rescue...',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _isSuccess
              ? 'Your pickup is confirmed. Preparing navigation...'
              : 'Confirming your assignment and preparing navigation.',
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildInfoRow('Pickup Provider', batch.providerName),
              const Divider(height: 14, color: Color(0xFFE2E8F0)),
              _buildInfoRow('Delivery Receiver', batch.claimedByNgo ?? 'Helping Hands NGO'),
              const Divider(height: 14, color: Color(0xFFE2E8F0)),
              _buildInfoRow('Food Quantity', '${batch.quantityPortions} meals (${batch.dietaryType})'),
              const Divider(height: 14, color: Color(0xFFE2E8F0)),
              _buildInfoRow('Pickup Distance', '2.4 km (~12 min)'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!_isSuccess) ...[
          const LinearProgressIndicator(
            backgroundColor: Color(0xFFF1F5F9),
            color: Color(0xFFFFC107),
            minHeight: 5,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF166534)),
                SizedBox(width: 6),
                Text(
                  'Assignment Confirmed • Opening Map',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // FAILURE / REASSIGNMENT VIEW
  Widget _buildFailureView(SurplusBatch batch) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFEE2E2),
            border: Border.all(color: const Color(0xFFEF4444), width: 2),
          ),
          child: const Center(
            child: Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 38),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Volunteer Unavailable',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 6),
        const Text(
          'We\'re finding another eligible volunteer nearby for this rescue.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: const Color(0xFF1E293B),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Return to Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool highlightValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: highlightValue ? const Color(0xFFD97706) : const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
