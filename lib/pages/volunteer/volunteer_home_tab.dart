import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/food_rescue_service.dart';
import '../../services/matching_service.dart';
import '../../widgets/shared_rescue_tracking_page.dart';
import 'volunteer_task_details_dialog.dart';

class VolunteerHomeTab extends StatelessWidget {
  final String volunteerName;
  final String location;
  final LatLng latLng;
  final bool isAvailable;
  final ValueChanged<bool> onAvailabilityChanged;
  final VoidCallback onOpenTasksTab;
  final VoidCallback onOpenHistoryTab;
  final VoidCallback? onOpenPaymentsTab;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final VoidCallback onDetectLocation;
  final VoidCallback? onSwitchRole;
  final VoidCallback? onOpenDrawer;

  const VolunteerHomeTab({
    super.key,
    required this.volunteerName,
    required this.location,
    required this.latLng,
    required this.isAvailable,
    required this.onAvailabilityChanged,
    required this.onOpenTasksTab,
    required this.onOpenHistoryTab,
    this.onOpenPaymentsTab,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.onDetectLocation,
    this.onSwitchRole,
    this.onOpenDrawer,
  });

  static const Distance _distCalc = Distance();

  double _getPickupDistance(LatLng target) {
    final m = _distCalc.as(LengthUnit.Meter, latLng, target);
    return double.parse((m / 1000.0).toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FoodRescueService.instance,
      builder: (context, _) {
        final availableBatches = FoodRescueService.instance.availableDeliveryTasks;
        final activeTask = FoodRescueService.instance.getActiveTaskForVolunteer();

        // Recommendations
        final recommendations = VolunteerRecommendationService.getRecommendations(
          availableTasks: availableBatches,
          volunteerLocation: latLng,
          maxResults: 2,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header
                  _buildHeader(context),
                  const SizedBox(height: 18),

                  // 2. Prominent Availability Toggle
                  _buildAvailabilityToggleCard(context),
                  const SizedBox(height: 18),

                  // Active Task Banner (if any is active)
                  if (activeTask != null) ...[
                    _buildActiveTaskNotice(context, activeTask),
                    const SizedBox(height: 18),
                  ],

                  // 3. Main CTA: Find Nearby Tasks
                  _buildFindTasksCta(context, availableBatches.length),
                  const SizedBox(height: 22),

                  // 4. Four Core Statistics
                  _buildStatsRow(),
                  const SizedBox(height: 18),

                  // 5. Courier Payouts Quick Banner
                  _buildPayoutBanner(context),
                  const SizedBox(height: 28),

                  // If offline, display prominent offline message
                  if (!isAvailable) ...[
                    _buildOfflineAlertCard(context),
                    const SizedBox(height: 28),
                  ] else ...[
                    // 5. Recommended For You (Smart Recommendations)
                    if (recommendations.isNotEmpty) ...[
                      _buildRecommendedSection(context, recommendations),
                      const SizedBox(height: 28),
                    ],

                    // 6. Nearby Delivery Tasks
                    _buildNearbyTasksSection(context, availableBatches),
                    const SizedBox(height: 28),

                    // 7. Nearby Delivery Map Preview
                    _buildDeliveryMapPreview(context, availableBatches.length),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Top Header Section
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B), size: 24),
          tooltip: 'Open Menu',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: onOpenDrawer,
        ),
        const SizedBox(width: 8),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning, $volunteerName 👋',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  // Availability Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isAvailable ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isAvailable ? 'Available' : 'Offline',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isAvailable ? const Color(0xFF166534) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Location chip
                  InkWell(
                    onTap: onDetectLocation,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFFFC107)),
                        const SizedBox(width: 3),
                        Text(
                          location.isNotEmpty ? location : 'Greater Noida Hub',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Notifications button
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1E293B), size: 20),
            tooltip: 'Notifications',
            onPressed: onOpenNotifications,
          ),
        ),
        const SizedBox(width: 8),

        // Profile button
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFC107)),
          ),
          child: IconButton(
            icon: const Icon(Icons.person_rounded, color: Color(0xFFD97706), size: 20),
            tooltip: 'Profile',
            onPressed: onOpenProfile,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Availability Toggle Card
  // ---------------------------------------------------------------------------
  Widget _buildAvailabilityToggleCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isAvailable ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAvailable ? const Color(0xFFFFC107) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isAvailable ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAvailable ? Icons.check_circle_outline_rounded : Icons.power_settings_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAvailable ? '🟢 Available for Tasks' : '⚪ Offline',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: isAvailable ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  isAvailable
                      ? 'You are active and receiving nearby delivery tasks'
                      : 'Toggle on to receive and accept food rescue tasks',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch(
            value: isAvailable,
            activeThumbColor: const Color(0xFFD97706),
            activeTrackColor: const Color(0xFFFFC107),
            onChanged: onAvailabilityChanged,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Active Task Notice (if volunteer has a delivery currently in progress)
  // ---------------------------------------------------------------------------
  Widget _buildActiveTaskNotice(BuildContext context, SurplusBatch task) {
    return InkWell(
      onTap: () {
        SharedRescueTrackingPage.open(
          context,
          batch: task,
          role: RescueTrackingRole.volunteer,
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.two_wheeler_rounded, color: Color(0xFF16A34A), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Delivery in Progress 🚴',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF166534)),
                  ),
                  Text(
                    '${task.title} (${task.quantityPortions} meals) • Tap to view live tracking & timeline',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF14532D)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF16A34A), size: 14),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main CTA: Find Nearby Tasks
  // ---------------------------------------------------------------------------
  Widget _buildFindTasksCta(BuildContext context, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC107).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.search_rounded, color: Color(0xFF1E293B), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find Nearby Tasks',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  count == 0
                      ? 'No claimed food awaiting delivery yet. When an NGO claims listed surplus, it will appear here.'
                      : '$count rescue delivery opportunities waiting in your area',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isAvailable
                ? onOpenTasksTab
                : () {
                    onAvailabilityChanged(true);
                    onOpenTasksTab();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Explore Tasks', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4 Core Statistics
  // ---------------------------------------------------------------------------
  Widget _buildStatsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth > 580
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard('12', 'Tasks Completed', Icons.check_circle_outline_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7), cardWidth),
            _buildStatCard('420', 'Meals Delivered', Icons.restaurant_rounded, const Color(0xFF2563EB), const Color(0xFFDBEAFE), cardWidth),
            _buildStatCard('210 kg', 'Food Rescued', Icons.inventory_2_rounded, const Color(0xFF16A34A), const Color(0xFFDCFCE7), cardWidth),
            _buildStatCard('28 kg', 'CO₂ Avoided', Icons.eco_rounded, const Color(0xFF9333EA), const Color(0xFFF3E8FF), cardWidth),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String val, String label, IconData icon, Color color, Color bg, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
              Text(
                val,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE047)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF854D0E), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Courier Payouts & Receipts',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF854D0E)),
                ),
                SizedBox(height: 2),
                Text(
                  'Instant UPI settlement active · 100% verified disbursals',
                  style: TextStyle(fontSize: 12, color: Color(0xFFA16207), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (onOpenPaymentsTab != null)
            ElevatedButton(
              onPressed: onOpenPaymentsTab,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF854D0E),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Offline Alert Card
  // ---------------------------------------------------------------------------
  Widget _buildOfflineAlertCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.pause_circle_outline_rounded, size: 42, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text(
            "You're Currently Offline",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toggle your availability to "Available for Tasks" to view and accept active food rescues.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => onAvailabilityChanged(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: const Color(0xFF1E293B),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Go Available 🟢', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recommended For You
  // ---------------------------------------------------------------------------
  Widget _buildRecommendedSection(BuildContext context, List<RecommendedDeliveryTask> recs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 20),
            SizedBox(width: 6),
            Text(
              'Recommended For You',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -0.2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...recs.map((r) => _buildRecommendationCard(context, r)),
      ],
    );
  }

  Widget _buildRecommendationCard(BuildContext context, RecommendedDeliveryTask rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFC107), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⭐ Best Match (${rec.matchScore}%)',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
              ),
              Text(
                rec.pickupWindow,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${rec.batch.title} • ${rec.batch.quantityPortions} meals',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(
            '${rec.pickupDistanceKm} km pickup • ${rec.deliveryDistanceKm} km delivery • Est. ${rec.totalRouteKm} km total route',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rec.recommendationReason,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
              ),
              ElevatedButton(
                onPressed: () {
                  VolunteerTaskDetailsDialog.show(
                    context,
                    batch: rec.batch,
                    pickupDistanceKm: rec.pickupDistanceKm,
                    deliveryDistanceKm: rec.deliveryDistanceKm,
                    totalRouteKm: rec.totalRouteKm,
                    pickupWindow: rec.pickupWindow,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('View Task', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Nearby Delivery Tasks Section
  // ---------------------------------------------------------------------------
  Widget _buildNearbyTasksSection(BuildContext context, List<SurplusBatch> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Nearby Delivery Tasks',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -0.2),
            ),
            TextButton(
              onPressed: onOpenTasksTab,
              child: const Text('See All Tasks', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No claimed food awaiting delivery right now. Once an NGO receiver claims listed surplus, courier dispatch will appear here.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...tasks.take(3).map((task) => _buildTaskCard(context, task)),
      ],
    );
  }

  Widget _buildTaskCard(BuildContext context, SurplusBatch batch) {
    final pickupKm = _getPickupDistance(batch.location);
    final deliveryKm = 2.8;
    final totalKm = double.parse((pickupKm + deliveryKm).toStringAsFixed(1));
    final window = '7:00 PM – 8:00 PM';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                batch.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${batch.quantityPortions} meals',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Pickup Row
          Row(
            children: [
              const Icon(Icons.store_rounded, size: 14, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              Text(
                'Pickup: ${batch.providerName} • $pickupKm km away',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Deliver Row
          Row(
            children: [
              const Icon(Icons.volunteer_activism_rounded, size: 14, color: Color(0xFF16A34A)),
              const SizedBox(width: 6),
              Text(
                'Deliver to: ${batch.claimedByNgo ?? 'Helping Hands NGO'} • $deliveryKm km away',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Distance: $totalKm km • $window',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              ElevatedButton(
                onPressed: () {
                  VolunteerTaskDetailsDialog.show(
                    context,
                    batch: batch,
                    pickupDistanceKm: pickupKm,
                    deliveryDistanceKm: deliveryKm,
                    totalRouteKm: totalKm,
                    pickupWindow: window,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('View Task', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Nearby Delivery Map Preview
  // ---------------------------------------------------------------------------
  Widget _buildDeliveryMapPreview(BuildContext context, int count) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.map_rounded, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Nearby Delivery Map',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              TextButton(
                onPressed: onOpenTasksTab,
                child: const Text('Explore Map', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$count pickup & dropoff checkpoints active in your current courier radius',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
