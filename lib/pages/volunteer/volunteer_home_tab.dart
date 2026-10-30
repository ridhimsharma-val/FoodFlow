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

        // Smart Recommendations
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
                  // 1. Cleaner, modern Top App Bar
                  _buildTopAppBar(context),
                  const SizedBox(height: 18),

                  // 2. Volunteer Greeting and Operating Location
                  _buildGreetingAndLocation(context),
                  const SizedBox(height: 18),

                  // 3. Availability Status Toggle Card (Always prominent near top)
                  _buildAvailabilityToggleCard(context),
                  const SizedBox(height: 18),

                  // 4. Active Delivery Card (High Priority if active task exists)
                  if (activeTask != null) ...[
                    _buildActiveTaskNotice(context, activeTask),
                    const SizedBox(height: 18),
                  ],

                  // 5. Main Primary CTA: Find Nearby Tasks
                  _buildFindTasksCta(context, availableBatches.length),
                  const SizedBox(height: 24),

                  // 6. Recommended For You (Smart Suggestions, when available)
                  if (isAvailable && recommendations.isNotEmpty) ...[
                    _buildRecommendedSection(context, recommendations),
                    const SizedBox(height: 28),
                  ],

                  // 7. If offline, display prominent offline message; else show Genuine Tasks
                  if (!isAvailable) ...[
                    _buildOfflineAlertCard(context),
                    const SizedBox(height: 28),
                  ] else ...[
                    _buildNearbyTasksSection(context, availableBatches),
                    const SizedBox(height: 28),
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
  // Top App Bar
  // ---------------------------------------------------------------------------
  Widget _buildTopAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Food Flow logo placeholder
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.two_wheeler_rounded, color: Colors.black87, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Food Flow',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    'VOLUNTEER RESCUE SQUAD',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right: Notification icon + Profile avatar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onOpenNotifications,
                tooltip: 'Notifications',
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1E293B), size: 20),
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFC107),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Profile avatar
              InkWell(
                onTap: onOpenProfile,
                borderRadius: BorderRadius.circular(22),
                child: Tooltip(
                  message: 'Volunteer Profile & Settings',
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFFFC107),
                    child: Text(
                      volunteerName.isNotEmpty ? volunteerName[0].toUpperCase() : 'V',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Greeting & Location Context
  // ---------------------------------------------------------------------------
  Widget _buildGreetingAndLocation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good morning, $volunteerName 👋',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            letterSpacing: -0.4,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
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
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFFFC107)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        location.isNotEmpty ? location : 'Greater Noida Hub',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
  // Active Task Notice (Prioritized when courier is actively executing a task)
  // ---------------------------------------------------------------------------
  Widget _buildActiveTaskNotice(BuildContext context, SurplusBatch task) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF16A34A), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACTIVE DELIVERY IN PROGRESS 🚴',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF166534),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
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
                child: Text(
                  task.status == BatchStatus.inTransitToPickup
                      ? 'En Route Pickup'
                      : task.status == BatchStatus.arrivedAtPickup
                          ? 'At Provider'
                          : task.status == BatchStatus.pickedUp || task.status == BatchStatus.inTransit
                              ? 'In Transit'
                              : 'Arrived Dropoff',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFDCFCE7)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pickup: ${task.providerName} (${task.pickupAddress})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.volunteer_activism_rounded, size: 14, color: Color(0xFF16A34A)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Dropoff: ${task.claimedByNgo ?? 'Verified Relief NGO'} (${task.receiverDropoffAddress ?? 'Indiranagar Shelter'})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (task.courierEtaMinutes != null)
                Text(
                  '⏱️ ETA: ~${task.courierEtaMinutes} mins${task.distanceRemainingKm != null ? ' (${task.distanceRemainingKm} km)' : ''}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                )
              else
                Text(
                  '📦 ${task.quantityPortions} meals · OTP Protected',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                ),
              ElevatedButton.icon(
                onPressed: () {
                  SharedRescueTrackingPage.open(
                    context,
                    batch: task,
                    role: RescueTrackingRole.volunteer,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.navigation_rounded, size: 15),
                label: const Text('Open Tracking', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
            ],
          ),
        ],
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
            Row(
              children: [
                const Text(
                  'Nearby Delivery Tasks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -0.2),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: onOpenTasksTab,
              child: const Text('See All Tasks →', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (FoodRescueService.instance.lastFetchError != null && tasks.isEmpty)
          _buildErrorState()
        else if (tasks.isEmpty)
          _buildEmptyTasksCard()
        else
          ...tasks.take(4).map((task) => _buildTaskCard(context, task)),
      ],
    );
  }

  Widget _buildEmptyTasksCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.delivery_dining_outlined, size: 42, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text(
            'No pickup requests available right now.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'New pickup opportunities will appear here when food is ready for collection.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => FoodRescueService.instance.initSupabaseSync('refresh'),
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFD97706)),
            label: const Text('Refresh', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFFC107)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFFEF4444)),
          const SizedBox(height: 12),
          const Text(
            'Unable to load nearby pickup requests.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF991B1B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check your network connection and try again.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C)),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => FoodRescueService.instance.initSupabaseSync('retry'),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
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
  }

  Widget _buildTaskCard(BuildContext context, SurplusBatch batch) {
    final pickupKm = _getPickupDistance(batch.location);
    final deliveryKm = 2.8;
    final totalKm = double.parse((pickupKm + deliveryKm).toStringAsFixed(1));
    final window = 'Safe pickup window: ~${batch.remainingSafeTime.inHours}h remaining';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
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
              Flexible(
                child: Text(
                  batch.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
              Expanded(
                child: Text(
                  'Pickup: ${batch.providerName} • $pickupKm km away',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Deliver Row
          Row(
            children: [
              const Icon(Icons.volunteer_activism_rounded, size: 14, color: Color(0xFF16A34A)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Deliver to: ${batch.claimedByNgo ?? 'Verified Relief NGO'} • $deliveryKm km away',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Estimated Distance: $totalKm km • $window',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
}
